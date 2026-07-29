from datetime import date

from dateutil import parser
from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Prestamo

bp = Blueprint("prestamos", __name__)


def _parse_date(value) -> date | None:
    if value is None:
        return None
    if isinstance(value, date):
        return value
    try:
        return parser.isoparse(str(value)).date()
    except (ValueError, TypeError):
        return None


@bp.route("/prestamos", methods=["POST", "GET"])
def gestionar_prestamos():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            campos = {
                "curp",
                "monto_otorgado",
                "tasa_interes",
                "plazo_meses",
                "fecha_aprobacion",
            }
            faltantes = campos - data.keys()
            if faltantes:
                return (
                    jsonify(
                        {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                    ),
                    400,
                )

            fecha = _parse_date(data["fecha_aprobacion"])
            if fecha is None:
                return (
                    jsonify(
                        {"error": "fecha_aprobacion inválida (use ISO YYYY-MM-DD)"}
                    ),
                    400,
                )

            nuevo = Prestamo(
                curp=data["curp"],
                monto_otorgado=data["monto_otorgado"],
                tasa_interes=data["tasa_interes"],
                plazo_meses=int(data["plazo_meses"]),
                fecha_aprobacion=fecha,
            )
            db.session.add(nuevo)
            db.session.commit()
            return jsonify({"mensaje": "Préstamo registrado con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    prestamos = Prestamo.query.all()
    return jsonify([p.to_dict() for p in prestamos]), 200
