from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Cliente

bp = Blueprint("clientes", __name__)


@bp.route("/clientes", methods=["POST", "GET"])
def gestionar_clientes():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            campos_requeridos = {"curp", "nombres", "apellido_paterno"}
            faltantes = campos_requeridos - data.keys()
            if faltantes:
                return (
                    jsonify(
                        {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                    ),
                    400,
                )

            nuevo_cliente = Cliente(
                curp=data["curp"],
                nombres=data["nombres"],
                apellido_paterno=data["apellido_paterno"],
                apellido_materno=data.get("apellido_materno"),
                email=data.get("email"),
                telefono=data.get("telefono"),
            )
            db.session.add(nuevo_cliente)
            db.session.commit()
            return jsonify({"mensaje": "Cliente registrado con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    clientes = Cliente.query.all()
    return jsonify([c.to_dict() for c in clientes]), 200
