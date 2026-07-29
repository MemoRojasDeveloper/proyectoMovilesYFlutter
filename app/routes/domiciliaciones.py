from decimal import Decimal, InvalidOperation

from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Domiciliacion

bp = Blueprint("domiciliaciones", __name__)


def _parse_decimal(value):
    if value is None:
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return None


@bp.route("/domiciliaciones", methods=["POST", "GET"])
def gestionar_domiciliaciones():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            campos = {"codigo_cuenta", "servicio", "dia_cobro"}
            faltantes = campos - data.keys()
            if faltantes:
                return (
                    jsonify(
                        {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                    ),
                    400,
                )

            monto = _parse_decimal(data.get("monto_autorizado"))

            nueva = Domiciliacion(
                codigo_cuenta=data["codigo_cuenta"],
                servicio=data["servicio"],
                monto_autorizado=monto,
                dia_cobro=int(data["dia_cobro"]),
            )
            db.session.add(nueva)
            db.session.commit()
            return jsonify({"mensaje": "Domiciliación registrada con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    domiciliaciones = Domiciliacion.query.all()
    return jsonify([d.to_dict() for d in domiciliaciones]), 200
