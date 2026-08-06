"""Cobrador automatico de domiciliaciones.

Corre como un thread en background dentro del proceso Flask.
Cada hora (o al arrancar si se atrasa) itera sobre las
domiciliaciones activas:

  * Si la cuenta tiene saldo suficiente, descuenta
    `monto_total_a_cobrar` (monto_original + recargo_acumulado)
    y resetea contadores.
  * Si NO tiene saldo, suma 1 hora a `horas_retraso` y agrega
    un 2% del monto_original al `recargo_acumulado`.

Pensado para el contexto de "pruebas". En produccion se
reemplazaria por un cron externo o un worker dedicado.
"""
from __future__ import annotations

import logging
import threading
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from ..extensions import db
from ..models import CuentaCorriente, Domiciliacion

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# Constantes de operacion
INTERVALO_SEGUNDOS = 3600  # 1 hora entre cobros
PORCENTAJE_RECARGO = Decimal("0.02")  # 2% por hora atrasada


def _procesar_domiciliacion(d: Domiciliacion) -> None:
    """Procesa UNA domiciliacion. Hace commit por fila."""
    # Import lazy: evita ciclos si el modulo se importa antes que extensions
    from ..models import Movimiento
    from ..models.movimiento import (
        TIPO_COBRO_DOMI_AUTO,
        TIPO_COBRO_DOMI_RECARGO,
    )

    cuenta = db.session.get(CuentaCorriente, d.codigo_cuenta)
    if cuenta is None:
        logger.warning(
            "Domiciliacion %s apunta a cuenta inexistente: %s",
            d.id_domiciliacion, d.codigo_cuenta,
        )
        return

    ahora = _utcnow()
    base = Decimal(str(d.monto_original or d.monto_autorizado or 0))
    recargo_previo = Decimal(str(d.recargo_acumulado or 0))
    a_cobrar = base + recargo_previo
    saldo = Decimal(str(cuenta.saldo or 0))

    if saldo >= a_cobrar:
        # ─────────────────────────────────────────────────────────
        # Camino feliz: cobramos via Stripe y registramos movimiento.
        # ─────────────────────────────────────────────────────────
        stripe_charge_id = None
        stripe_receipt_url = None
        try:
            # Import lazy para no romper tests que no importen Stripe
            from ..services import cobrar_domiciliacion, StripePaymentError
            resultado = cobrar_domiciliacion(
                monto=a_cobrar,
                descripcion=(
                    f"Cobro automatico {d.servicio} "
                    f"(cuenta {d.codigo_cuenta})"
                ),
            )
            stripe_receipt_url = resultado.receipt_url
        except Exception as exc:
            # Si Stripe falla (incluso por clave dummy), NO debitamos
            # saldo: marcamos atraso y recargo como si no hubiera fondos.
            logger.warning(
                "Cobrador: Stripe fallo para domi %s: %s. "
                "Aplicando recargo.",
                d.id_domiciliacion, exc,
            )
            d.horas_retraso = (d.horas_retraso or 0) + 1
            d.recargo_acumulado = recargo_previo + (base * PORCENTAJE_RECARGO)
            if d.fecha_limite_pago is None:
                d.fecha_limite_pago = ahora + timedelta(seconds=INTERVALO_SEGUNDOS)
            db.session.commit()
            return

        cuenta.saldo = saldo - a_cobrar
        d.horas_retraso = 0
        d.recargo_acumulado = Decimal("0")
        d.fecha_ultimo_cobro = ahora
        d.fecha_limite_pago = ahora + timedelta(seconds=INTERVALO_SEGUNDOS)
        db.session.add(Movimiento(
            codigo_cuenta=d.codigo_cuenta,
            tipo=TIPO_COBRO_DOMI_AUTO,
            monto=a_cobrar,
            concepto=f"Cobro automatico de {d.servicio}",
            id_domiciliacion=d.id_domiciliacion,
            stripe_charge_id=stripe_charge_id,
            stripe_receipt_url=stripe_receipt_url,
            # curp_actor queda NULL: lo dispara el sistema, no una persona
        ))
        db.session.commit()
        logger.info(
            "Cobrado $%s de %s a cuenta %s (domi %s)",
            a_cobrar, d.servicio, d.codigo_cuenta, d.id_domiciliacion,
        )
        return

    # ─────────────────────────────────────────────────────────
    # Sin saldo suficiente: atraso + recargo (movimiento virtual,
    # porque NO se cobro nada, solo se programa el recargo).
    # ─────────────────────────────────────────────────────────
    nuevo_recargo = recargo_previo + (base * PORCENTAJE_RECARGO)
    delta_recargo = nuevo_recargo - recargo_previo  # 2% del original
    d.horas_retraso = (d.horas_retraso or 0) + 1
    d.recargo_acumulado = nuevo_recargo
    if d.fecha_limite_pago is None:
        d.fecha_limite_pago = ahora + timedelta(seconds=INTERVALO_SEGUNDOS)
    # Solo registramos el delta del recargo como movimiento (no el
    # monto completo) para que el historial refleje "se sumo este
    # recargo a la deuda" sin inflar la suma de cargos.
    db.session.add(Movimiento(
        codigo_cuenta=d.codigo_cuenta,
        tipo=TIPO_COBRO_DOMI_RECARGO,
        monto=delta_recargo,
        concepto=(
            f"Recargo por atraso ({d.horas_retraso}h) en {d.servicio}"
        ),
        id_domiciliacion=d.id_domiciliacion,
    ))
    db.session.commit()
    logger.warning(
        "SIN SALDO domi %s (%s) cuenta %s atraso=%sh recargo=$%s",
        d.id_domiciliacion, d.servicio, d.codigo_cuenta,
        d.horas_retraso, d.recargo_acumulado,
    )


def ejecutar_ciclo() -> int:
    """Ejecuta un ciclo completo de cobros. Devuelve cuantos proceso."""
    activas = (
        db.session.query(Domiciliacion)
        .filter(Domiciliacion.estado == "activa")
        .all()
    )
    procesadas = 0
    for d in activas:
        try:
            _procesar_domiciliacion(d)
            procesadas += 1
        except Exception:
            db.session.rollback()
            logger.exception("Error procesando domiciliacion %s", d.id_domiciliacion)
    return procesadas


def _loop_continuo() -> None:
    """Loop infinito que ejecuta el ciclo cada INTERVALO_SEGUNDOS."""
    logger.info("Cobrador automatico iniciado (cada %ss)", INTERVALO_SEGUNDOS)
    while True:
        try:
            ejecutar_ciclo()
        except Exception:
            logger.exception("Error en ciclo del cobrador")
        time.sleep(INTERVALO_SEGUNDOS)


def iniciar_en_background(app) -> threading.Thread:
    """Arranca el cobrador en un thread daemon.

    Devuelve el Thread para que el caller pueda llevar registro
    (o None si ya estaba corriendo).
    """
    if getattr(app, "_cobrador_thread", None) is not None:
        return None  # ya estaba corriendo

    def _target():
        # Necesitamos un app context para usar db.session
        with app.app_context():
            _loop_continuo()

    t = threading.Thread(target=_target, name="cobrador-domiciliaciones", daemon=True)
    t.start()
    app._cobrador_thread = t
    return t