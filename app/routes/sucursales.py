from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Sucursal

bp = Blueprint("sucursales", __name__)


@bp.route("/sucursales", methods=["POST", "GET"])
def gestionar_sucursales():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            campos_requeridos = {"codigo_sucursal", "nombre_sucursal"}
            faltantes = campos_requeridos - data.keys()
            if faltantes:
                return (
                    jsonify(
                        {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                    ),
                    400,
                )

            nueva = Sucursal(
                codigo_sucursal=data["codigo_sucursal"],
                nombre_sucursal=data["nombre_sucursal"],
                direccion=data.get("direccion"),
            )
            db.session.add(nueva)
            db.session.commit()
            return jsonify({"mensaje": "Sucursal registrada con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    sucursales = Sucursal.query.all()
    return jsonify([s.to_dict() for s in sucursales]), 200
