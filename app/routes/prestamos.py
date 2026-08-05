"""Endpoints de prestamos contra `public.prestamo` y `public.cuota_prestamo`.

Validacion legal: la tasa de interes convencional debe estar entre
9.0% y 18.0% anual. Fuera de ese rango el backend rechaza con 400.

Workflow:
  * El cliente (o alguien con permiso `solicitar_prestamo` en la cuenta)
    hace POST /api/clientes/<curp>/prestamos/solicitar -> estado 'pendiente'.
  * El empleado ve las solicitudes pendientes y las aprueba/rechaza.
  * Al aprobar, se generan las cuotas.
  * El historial completo queda en `public.prestamo_evento`.

Reglas:
  * Un cliente solo puede tener 1 solicitud activa (pendiente o aprobada)
    por mes natural (curp + mes).
  * Motivo de rechazo siempre es obligatorio.

Endpoints:
  POST  /api/clientes/<curp>/prestamos/solicitar -- cliente/solicitante
  GET   /api/clientes/<curp>/prestamos           -- lista prestamos del cliente
  GET   /api/prestamos/pendientes                -- empleado: cola de revision
  GET   /api/prestamos/<id>                      -- detalle de un prestamo
  GET   /api/prestamos/<id>/eventos             -- historial del prestamo
  PATCH /api/prestamos/<id>/aprobar             -- empleado aprueba
  PATCH /api/prestamos/<id>/rechazar            -- empleado rechaza
  PATCH /api/prestamos/<id>/cancelar            -- solicitante cancela
  GET   /api/prestamos/<id>/cuotas               -- lista las cuotas
  POST  /api/prestamos/simular                   -- simulacion sin persistir
  PATCH /api/prestamos/cuotas/<id>/pagar         -- marca cuota como pagada
"""
from __future__ import annotations

from datetime import date, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from dateutil import parser
from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt, get_jwt_identity

from ..extensions import db
from ..models import (  # noqa: F401
    Cliente,
    ClienteCuentaPrivilegio,
    CuotaPrestamo,
    Prestamo,
    PrestamoEvento,
    Privilegio,
)
from ..models.prestamo import (
    EST_PRESTAMO_APROBADO,
    EST_PRESTAMO_CANCELADO,
    EST_PRESTAMO_PENDIENTE,
    EST_PRESTAMO_RECHAZADO,
    ESTADOS_PRESTAMO,
)
from ..utils import require_auth

bp = Blueprint("prestamos", __name__)

TASA_MIN = Decimal("9.0")
TASA_MAX = Decimal("18.0")


# ── Helpers locales ────────────────────────────────────────────────────────────

def _usuario_tiene_permiso_prestamo(curp_usuario: str, codigo_cuenta: str) -> bool:
    """True si el curp_usuario tiene el privilegio 'solicitar_prestamo'
    sobre la cuenta dada.

    Privilegio por nombre_operacion = 'solicitar_prestamo'. Si en el futuro
    el nombre cambia, este helper es el unico lugar a tocar.
    """
    nombre = "solicitar_prestamo"
    priv = (
        db.session.query(Privilegio)
        .filter(Privilegio.nombre_operacion == nombre)
        .first()
    )
    if priv is None:
        return False
    rel = (
        db.session.query(ClienteCuentaPrivilegio)
        .filter(
            ClienteCuentaPrivilegio.curp == curp_usuario,
            ClienteCuentaPrivilegio.codigo_cuenta == codigo_cuenta,
            ClienteCuentaPrivilegio.id_privilegio == priv.id_privilegio,
        )
        .first()
    )
    return rel is not None


def _mes_key(d: date) -> str:
    return f"{d.year:04d}-{d.month:02d}"


def _validar_payload_solicitud(data: dict) -> tuple[dict | None, dict | None]:
    """Devuelve (payload_normalizado, errores_dict)."""
    errores = {}
    monto = _parse_decimal(data.get("monto_otorgado"))
    if monto is None or monto <= 0:
        errores["monto_otorgado"] = "monto_otorgado debe ser mayor a 0"
    tasa = _parse_decimal(data.get("tasa_interes"))
    if tasa is None:
        errores["tasa_interes"] = "tasa_interes obligatoria"
    elif tasa:
        ok, err = _validar_tasa(tasa)
        if not ok:
            errores["tasa_interes"] = err
    try:
        plazo = int(data.get("plazo_meses"))
    except (TypeError, ValueError):
        plazo = None
        errores["plazo_meses"] = "plazo_meses debe ser entero"
    if plazo is not None and plazo <= 0:
        errores["plazo_meses"] = "plazo_meses debe ser mayor a 0"

    motivo = (data.get("motivo_solicitud") or "").strip()
    if not motivo:
        errores["motivo_solicitud"] = (
            "motivo_solicitud obligatorio: explicá brevemente "
            "para qué necesitás el préstamo"
        )
    elif len(motivo) > 1000:
        errores["motivo_solicitud"] = "motivo_solicitud demasiado largo (max 1000)"

    codigo_cuenta = (data.get("codigo_cuenta") or "").strip().upper()
    if not codigo_cuenta:
        errores["codigo_cuenta"] = "codigo_cuenta obligatorio"

    if errores:
        return None, errores

    return {
        "monto_otorgado": monto,
        "tasa_interes": tasa,
        "plazo_meses": plazo,
        "motivo_solicitud": motivo,
        "codigo_cuenta": codigo_cuenta,
    }, None


def _registrar_evento(
    prestamo: Prestamo,
    *,
    tipo: str,
    curp_actor: str | None,
    estado_anterior: str | None,
    estado_nuevo: str | None,
    motivo: str | None = None,
    metadata: dict | None = None,
) -> PrestamoEvento:
    """Helper para registrar un evento en el historial."""
    ev = PrestamoEvento(
        id_prestamo=prestamo.id_prestamo,
        tipo=tipo,
        curp_actor=curp_actor,
        estado_anterior=estado_anterior,
        estado_nuevo=estado_nuevo,
        motivo=motivo,
        metadata_json=metadata or {},
    )
    db.session.add(ev)
    return ev


def _parse_decimal(v, default=None):
    if v is None:
        return default
    try:
        return Decimal(str(v))
    except (InvalidOperation, TypeError, ValueError):
        return None


def _parse_date(v) -> date | None:
    if v is None:
        return None
    if isinstance(v, date):
        return v
    try:
        return parser.isoparse(str(v)).date()
    except (ValueError, TypeError):
        return None


def _validar_tasa(tasa: Decimal) -> tuple[bool, str | None]:
    if tasa < TASA_MIN:
        return False, (
            f"Tasa {tasa}% inferior al 9% (umbral no usurero). "
            "Ajustala al menos al 9.0%."
        )
    if tasa > TASA_MAX:
        return False, (
            f"Tasa {tasa}% superior al 18% (doble del legal). "
            "Ajustala como maximo al 18.0%."
        )
    return True, None


def _calcular_cuota_y_total(monto: Decimal, tasa: Decimal, plazo: int):
    """Sistema frances nivelado."""
    P = Decimal(str(monto))
    i = Decimal(str(tasa)) / Decimal("100") / Decimal("12")
    n = int(plazo)
    if i == 0:
        cuota = P / Decimal(n)
        interes_total = Decimal("0")
    else:
        uno_mas_i = Decimal("1") + i
        factor = uno_mas_i ** n
        cuota = P * (i * factor) / (factor - Decimal("1"))
        interes_total = cuota * Decimal(n) - P
    # redondeo a 2 decimales (centavos)
    cuota = cuota.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    interes_total = interes_total.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return cuota, interes_total


# POST /api/prestamos/simular
# body: {monto, tasa_interes, plazo_meses}
# Devuelve cuota mensual + interes total + tabla de amortizacion.
# No requiere auth: cualquier cliente puede simular antes de contratar.
@bp.route("/prestamos/simular", methods=["POST"])
def simular_prestamo():
    data = request.get_json(silent=True) or {}
    monto = _parse_decimal(data.get("monto_otorgado") or data.get("monto"))
    tasa = _parse_decimal(data.get("tasa_interes"))
    plazo = data.get("plazo_meses")

    if monto is None or monto <= 0:
        return jsonify({"error": "monto debe ser mayor a 0"}), 400
    if tasa is None:
        return jsonify({"error": "tasa_interes obligatoria"}), 400
    try:
        plazo = int(plazo)
    except (TypeError, ValueError):
        return jsonify({"error": "plazo_meses debe ser entero"}), 400
    if plazo <= 0:
        return jsonify({"error": "plazo_meses debe ser mayor a 0"}), 400

    ok, err = _validar_tasa(tasa)
    if not ok:
        return jsonify({"error": err, "tasa_min": float(TASA_MIN), "tasa_max": float(TASA_MAX)}), 400

    cuota, interes_total = _calcular_cuota_y_total(monto, tasa, plazo)
    return jsonify({
        "monto_otorgado": float(monto),
        "tasa_interes": float(tasa),
        "plazo_meses": plazo,
        "cuota_mensual": float(cuota),
        "interes_total": float(interes_total),
        "total_a_pagar": float(cuota * Decimal(plazo)),
    }), 200


# POST /api/clientes/<curp>/prestamos
# Solo empleados. Crea el prestamo + sus cuotas.
# (Workflow viejo: el empleado crea directo. Se conserva por compat.)
@bp.route("/clientes/<string:curp>/prestamos", methods=["POST"])
@require_auth(roles=("empleado",))
def crear_prestamo(curp: str):
    curp_up = curp.upper()
    cliente = db.session.get(Cliente, curp_up)
    if cliente is None:
        return jsonify({"error": "Cliente no encontrado"}), 404

    data = request.get_json(silent=True) or {}
    monto = _parse_decimal(data.get("monto_otorgado"))
    tasa = _parse_decimal(data.get("tasa_interes"))
    plazo = data.get("plazo_meses")
    fecha_aprobacion = _parse_date(data.get("fecha_aprobacion")) or date.today()

    if monto is None or monto <= 0:
        return jsonify({"error": "monto_otorgado debe ser mayor a 0"}), 400
    if tasa is None:
        return jsonify({"error": "tasa_interes obligatoria"}), 400
    try:
        plazo = int(plazo)
    except (TypeError, ValueError):
        return jsonify({"error": "plazo_meses debe ser entero"}), 400
    if plazo <= 0:
        return jsonify({"error": "plazo_meses debe ser mayor a 0"}), 400

    ok, err = _validar_tasa(tasa)
    if not ok:
        return jsonify({
            "error": err,
            "tasa_min": float(TASA_MIN),
            "tasa_max": float(TASA_MAX),
        }), 400

    cuota_mensual, _ = _calcular_cuota_y_total(monto, tasa, plazo)

    try:
        prestamo = Prestamo(
            curp=curp_up,
            monto_otorgado=monto,
            tasa_interes=tasa,
            plazo_meses=plazo,
            fecha_aprobacion=fecha_aprobacion,
        )
        db.session.add(prestamo)
        db.session.flush()  # para obtener id_prestamo

        # Genera las cuotas (mensuales niveladas)
        for n in range(1, plazo + 1):
            vencimiento = fecha_aprobacion + timedelta(days=30 * n)
            db.session.add(CuotaPrestamo(
                id_prestamo=prestamo.id_prestamo,
                numero=n,
                fecha_vencimiento=vencimiento,
                monto_cuota=cuota_mensual,
                pagada=False,
            ))
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo crear: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Prestamo creado",
        "prestamo": prestamo.to_dict(),
        "cuota_mensual": float(cuota_mensual),
        "total_cuotas": plazo,
    }), 201


# POST /api/clientes/<curp>/prestamos/solicitar
# Solicitud de prestamo (workflow nuevo).
# Roles permitidos:
#   - Cliente autenticado pide para SI MISMO (curp == curp_jwt)
#   - Cliente con permiso 'solicitar_prestamo' sobre la cuenta indicada
# Reglas:
#   - 1 solicitud Pendiente o prestamo Aprobado por mes natural por cliente titular
#   - codigo_cuenta obligatorio (debe existir y estar activa)
@bp.route("/clientes/<string:curp>/prestamos/solicitar", methods=["POST"])
@require_auth()
def solicitar_prestamo(curp: str):
    curp_up = curp.upper()
    cliente = db.session.get(Cliente, curp_up)
    if cliente is None:
        return jsonify({"error": "Cliente no encontrado"}), 404

    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")

    data = request.get_json(silent=True) or {}
    payload, errores = _validar_payload_solicitud(data)
    if errores:
        return jsonify({"error": "Datos inválidos", "detalles": errores}), 400

    # Permisos: el solicitante puede ser el titular de la cuenta
    # o alguien con el privilegio 'solicitar_prestamo'.
    if curp_jwt != curp_up:
        if not _usuario_tiene_permiso_prestamo(curp_jwt, payload["codigo_cuenta"]):
            return jsonify({
                "error": "No tenés permiso para solicitar préstamos "
                         "sobre esta cuenta",
            }), 403

    # Regla 1: max 1 solicitud/prestamo por mes natural por curp titular
    hoy = date.today()
    mes_actual = _mes_key(hoy)
    existe_mes = (
        db.session.query(Prestamo)
        .filter(
            Prestamo.curp == curp_up,
            Prestamo.estado.in_(
                (EST_PRESTAMO_PENDIENTE, EST_PRESTAMO_APROBADO)
            ),
        )
        .all()
    )
    for p in existe_mes:
        if p.fecha_aprobacion and _mes_key(p.fecha_aprobacion) == mes_actual:
            return jsonify({
                "error": "Ya tenés un préstamo o solicitud en este mes. "
                         f"({p.estado})",
                "id_prestamo_existente": p.id_prestamo,
                "estado_existente": p.estado,
            }), 409

    # Crear la solicitud en estado 'pendiente'.
    try:
        prestamo = Prestamo(
            curp=curp_up,
            curp_solicitante=curp_jwt,
            monto_otorgado=payload["monto_otorgado"],
            tasa_interes=payload["tasa_interes"],
            plazo_meses=payload["plazo_meses"],
            fecha_aprobacion=hoy,  # fecha tentativa, sirve para el mes
            estado=EST_PRESTAMO_PENDIENTE,
            motivo_solicitud=payload["motivo_solicitud"],
            estado_detalle={"codigo_cuenta": payload["codigo_cuenta"]},
        )
        db.session.add(prestamo)
        db.session.flush()

        _registrar_evento(
            prestamo,
            tipo="solicitud",
            curp_actor=curp_jwt,
            estado_anterior=None,
            estado_nuevo=EST_PRESTAMO_PENDIENTE,
            motivo=payload["motivo_solicitud"],
            metadata={
                "codigo_cuenta": payload["codigo_cuenta"],
                "monto_otorgado": float(payload["monto_otorgado"]),
                "tasa_interes": float(payload["tasa_interes"]),
                "plazo_meses": payload["plazo_meses"],
                "solicitado_por": curp_jwt,
                "es_titular": curp_jwt == curp_up,
            },
        )
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo crear la solicitud: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Solicitud registrada. Queda pendiente de revisión.",
        "prestamo": prestamo.to_dict(),
    }), 201


# GET /api/prestamos/pendientes
# Solo empleados. Cola de solicitudes a revisar.
@bp.route("/prestamos/pendientes", methods=["GET"])
@require_auth(roles=("empleado",))
def listar_pendientes():
    pendientes = (
        db.session.query(Prestamo)
        .filter(Prestamo.estado == EST_PRESTAMO_PENDIENTE)
        .order_by(Prestamo.fecha_aprobacion.asc())
        .all()
    )
    return jsonify({
        "total": len(pendientes),
        "prestamos": [p.to_dict() for p in pendientes],
    }), 200


# PATCH /api/prestamos/<id>/aprobar
# Solo empleados. Aprueba y genera las cuotas.
# Body: {"motivo": "..."} (motivo obligatorio)
@bp.route("/prestamos/<int:id>/aprobar", methods=["PATCH"])
@require_auth(roles=("empleado",))
def aprobar_prestamo(id: int):
    p = db.session.get(Prestamo, id)
    if p is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    if p.estado != EST_PRESTAMO_PENDIENTE:
        return jsonify({
            "error": f"La solicitud está en estado '{p.estado}', "
                     "solo se aprueban solicitudes 'pendiente'",
        }), 409

    data = request.get_json(silent=True) or {}
    motivo = (data.get("motivo") or "").strip()
    if not motivo:
        return jsonify({
            "error": "motivo obligatorio: dejá un comentario al aprobar",
        }), 400
    if len(motivo) > 500:
        return jsonify({"error": "motivo demasiado largo (max 500)"}), 400

    curp_jwt = get_jwt_identity()

    # Calcular cuota y generar las cuotas niveladas
    cuota_mensual, _ = _calcular_cuota_y_total(
        p.monto_otorgado, p.tasa_interes, p.plazo_meses
    )
    fecha_aprob = date.today()

    try:
        estado_anterior = p.estado
        p.estado = EST_PRESTAMO_APROBADO
        p.fecha_aprobacion = fecha_aprob
        p.estado_detalle = {
            **(p.estado_detalle or {}),
            "aprobado_por": curp_jwt,
            "motivo_aprobacion": motivo,
            "fecha_aprobacion": fecha_aprob.isoformat(),
        }
        for n in range(1, p.plazo_meses + 1):
            vencimiento = fecha_aprob + timedelta(days=30 * n)
            db.session.add(CuotaPrestamo(
                id_prestamo=p.id_prestamo,
                numero=n,
                fecha_vencimiento=vencimiento,
                monto_cuota=cuota_mensual,
                pagada=False,
            ))
        _registrar_evento(
            p,
            tipo="aprobacion",
            curp_actor=curp_jwt,
            estado_anterior=estado_anterior,
            estado_nuevo=EST_PRESTAMO_APROBADO,
            motivo=motivo,
            metadata={"cuota_mensual": float(cuota_mensual)},
        )
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo aprobar: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Solicitud aprobada.",
        "prestamo": p.to_dict(),
        "cuota_mensual": float(cuota_mensual),
    }), 200


# PATCH /api/prestamos/<id>/rechazar
# Solo empleados. Rechaza con motivo (obligatorio).
@bp.route("/prestamos/<int:id>/rechazar", methods=["PATCH"])
@require_auth(roles=("empleado",))
def rechazar_prestamo(id: int):
    p = db.session.get(Prestamo, id)
    if p is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    if p.estado != EST_PRESTAMO_PENDIENTE:
        return jsonify({
            "error": f"La solicitud está en estado '{p.estado}', "
                     "solo se rechazan solicitudes 'pendiente'",
        }), 409

    data = request.get_json(silent=True) or {}
    motivo = (data.get("motivo") or "").strip()
    if not motivo:
        return jsonify({
            "error": "motivo obligatorio: explicá por qué rechazás",
        }), 400
    if len(motivo) > 500:
        return jsonify({"error": "motivo demasiado largo (max 500)"}), 400

    curp_jwt = get_jwt_identity()

    try:
        estado_anterior = p.estado
        p.estado = EST_PRESTAMO_RECHAZADO
        p.estado_detalle = {
            **(p.estado_detalle or {}),
            "rechazado_por": curp_jwt,
            "motivo_rechazo": motivo,
            "fecha_rechazo": date.today().isoformat(),
        }
        _registrar_evento(
            p,
            tipo="rechazo",
            curp_actor=curp_jwt,
            estado_anterior=estado_anterior,
            estado_nuevo=EST_PRESTAMO_RECHAZADO,
            motivo=motivo,
        )
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo rechazar: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Solicitud rechazada.",
        "prestamo": p.to_dict(),
    }), 200


# PATCH /api/prestamos/<id>/cancelar
# El propio solicitante cancela una solicitud en estado pendiente.
@bp.route("/prestamos/<int:id>/cancelar", methods=["PATCH"])
@require_auth()
def cancelar_prestamo(id: int):
    p = db.session.get(Prestamo, id)
    if p is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    if p.estado != EST_PRESTAMO_PENDIENTE:
        return jsonify({
            "error": f"No se puede cancelar en estado '{p.estado}'",
        }), 409

    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    # Solo el solicitante, el titular de la cuenta, o un empleado pueden cancelar
    if curp_jwt not in (p.curp_solicitante, p.curp) and rol != "empleado":
        return jsonify({"error": "No podés cancelar esta solicitud"}), 403

    data = request.get_json(silent=True) or {}
    motivo = (data.get("motivo") or "").strip() or "Cancelado por el usuario"

    try:
        estado_anterior = p.estado
        p.estado = EST_PRESTAMO_CANCELADO
        p.estado_detalle = {
            **(p.estado_detalle or {}),
            "cancelado_por": curp_jwt,
            "motivo_cancelacion": motivo,
        }
        _registrar_evento(
            p,
            tipo="cancelacion",
            curp_actor=curp_jwt,
            estado_anterior=estado_anterior,
            estado_nuevo=EST_PRESTAMO_CANCELADO,
            motivo=motivo,
        )
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo cancelar: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Solicitud cancelada.",
        "prestamo": p.to_dict(),
    }), 200


# GET /api/prestamos/<id>/eventos
# Historial completo de un prestamo.
@bp.route("/prestamos/<int:id>/eventos", methods=["GET"])
@require_auth()
def listar_eventos(id: int):
    p = db.session.get(Prestamo, id)
    if p is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado" and curp_jwt not in (p.curp, p.curp_solicitante):
        return jsonify({"error": "No tenés permiso para ver este historial"}), 403

    eventos = (
        db.session.query(PrestamoEvento)
        .filter(PrestamoEvento.id_prestamo == id)
        .order_by(PrestamoEvento.fecha.desc())
        .all()
    )
    return jsonify({
        "id_prestamo": id,
        "total": len(eventos),
        "eventos": [e.to_dict() for e in eventos],
    }), 200


# GET /api/clientes/<curp>/prestamos
# Lista los prestamos del cliente autenticado o de cualquier cliente si es empleado.
@bp.route("/clientes/<string:curp>/prestamos", methods=["GET"])
@require_auth()
def listar_prestamos(curp: str):
    curp_up = curp.upper()
    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado" and curp_up != curp_jwt:
        return jsonify({"error": "Solo puedes ver tus propios prestamos"}), 403

    prestamos = (
        db.session.query(Prestamo)
        .filter(Prestamo.curp == curp_up)
        .order_by(Prestamo.fecha_aprobacion.desc())
        .all()
    )
    return jsonify({
        "curp": curp_up,
        "total": len(prestamos),
        "prestamos": [p.to_dict() for p in prestamos],
    }), 200


# GET /api/prestamos/<id>
@bp.route("/prestamos/<int:id>", methods=["GET"])
@require_auth()
def obtener_prestamo(id: int):
    p = db.session.get(Prestamo, id)
    if p is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado" and p.curp != curp_jwt:
        return jsonify({"error": "Solo puedes ver tus propios prestamos"}), 403
    data = p.to_dict()
    data["cuota_mensual"] = float(p.monto_cuota())
    data["interes_total"] = float(p.interes_total())
    data["total_a_pagar"] = float(p.monto_cuota() * Decimal(p.plazo_meses))
    return jsonify(data), 200


# GET /api/prestamos/<id>/cuotas
@bp.route("/prestamos/<int:id>/cuotas", methods=["GET"])
@require_auth()
def listar_cuotas(id: int):
    p = db.session.get(Prestamo, id)
    if p is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado" and p.curp != curp_jwt:
        return jsonify({"error": "Solo puedes ver tus propias cuotas"}), 403
    cuotas = (
        db.session.query(CuotaPrestamo)
        .filter(CuotaPrestamo.id_prestamo == id)
        .order_by(CuotaPrestamo.numero)
        .all()
    )
    pagadas = sum(1 for c in cuotas if c.pagada)
    return jsonify({
        "id_prestamo": id,
        "total": len(cuotas),
        "pagadas": pagadas,
        "pendientes": len(cuotas) - pagadas,
        "saldo_pendiente": float(
            sum((c.monto_cuota for c in cuotas if not c.pagada), Decimal("0"))
        ),
        "cuotas": [c.to_dict() for c in cuotas],
    }), 200


# PATCH /api/prestamos/cuotas/<id>/pagar
@bp.route("/prestamos/cuotas/<int:id>/pagar", methods=["PATCH"])
@require_auth()
def pagar_cuota(id: int):
    cuota = db.session.get(CuotaPrestamo, id)
    if cuota is None:
        return jsonify({"error": "Cuota no encontrada"}), 404
    prestamo = db.session.get(Prestamo, cuota.id_prestamo)
    if prestamo is None:
        return jsonify({"error": "Prestamo no encontrado"}), 404
    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado" and prestamo.curp != curp_jwt:
        return jsonify({"error": "Solo puedes pagar tus propias cuotas"}), 403
    if cuota.pagada:
        return jsonify({"error": "Esta cuota ya esta pagada"}), 400

    try:
        cuota.pagada = True
        cuota.fecha_pago = date.today()
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo pagar: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Cuota pagada",
        "cuota": cuota.to_dict(),
    }), 200