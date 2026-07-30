"""Endpoints de prestamos contra `public.prestamo` y `public.cuota_prestamo`.

Validacion legal: la tasa de interes convencional debe estar entre
9.0% y 18.0% anual. Fuera de ese rango el backend rechaza con 400.

Endpoints:
  POST  /api/clientes/<curp>/prestamos       -- empleado crea prestamo + cuotas
  GET   /api/clientes/<curp>/prestamos       -- lista prestamos del cliente
  GET   /api/prestamos/<id>                  -- detalle de un prestamo
  GET   /api/prestamos/<id>/cuotas           -- lista las cuotas
  POST  /api/prestamos/simular               -- simulacion sin persistir
  PATCH /api/prestamos/cuotas/<id>/pagar     -- marca cuota como pagada
"""
from __future__ import annotations

from datetime import date, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

from dateutil import parser
from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt, get_jwt_identity

from ..extensions import db
from ..models import Cliente, CuotaPrestamo, Prestamo
from ..utils import require_auth

bp = Blueprint("prestamos", __name__)

TASA_MIN = Decimal("9.0")
TASA_MAX = Decimal("18.0")


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