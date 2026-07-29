from datetime import date
from decimal import Decimal, InvalidOperation

from dateutil import parser
from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import CuentaCorriente

bp = Blueprint("cuentas", __name__)


def _parse_date(value) -> date | None:
    if value is None:
        return None
    if isinstance(value, date):
        return value
    try:
        return parser.isoparse(str(value)).date()
    except (ValueError, TypeError):
        return None


def _parse_decimal(value, default: Decimal | None = None) -> Decimal | None:
    if value is None:
        return default
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return None


@bp.route("/cuentas", methods=["POST", "GET"])
def gestionar_cuentas():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            campos_requeridos = {
                "codigo_cuenta",
                "codigo_sucursal",
                "fecha_apertura",
            }
            faltantes = campos_requeridos - data.keys()
            if faltantes:
                return (
                    jsonify(
                        {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                    ),
                    400,
                )

            fecha = _parse_date(data["fecha_apertura"])
            if fecha is None:
                return (
                    jsonify({"error": "fecha_apertura inválida (use ISO YYYY-MM-DD)"}),
                    400,
                )

            saldo = _parse_decimal(data.get("saldo"), default=Decimal("0"))

            nueva = CuentaCorriente(
                codigo_cuenta=data["codigo_cuenta"],
                codigo_sucursal=data["codigo_sucursal"],
                saldo=saldo,
                fecha_apertura=fecha,
            )
            db.session.add(nueva)
            db.session.commit()
            return jsonify({"mensaje": "Cuenta registrada con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    cuentas = CuentaCorriente.query.all()
    return jsonify([c.to_dict() for c in cuentas]), 200
