from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import ClienteCuentaPrivilegio, Privilegio

bp = Blueprint("privilegios", __name__)


@bp.route("/privilegios", methods=["POST", "GET"])
def gestionar_privilegios():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            if "nombre_operacion" not in data:
                return (
                    jsonify({"error": "Campo faltante: nombre_operacion"}),
                    400,
                )

            nuevo = Privilegio(
                nombre_operacion=data["nombre_operacion"],
                descripcion=data.get("descripcion"),
            )
            db.session.add(nuevo)
            db.session.commit()
            return jsonify({"mensaje": "Privilegio registrado con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    privilegios = Privilegio.query.all()
    return jsonify([p.to_dict() for p in privilegios]), 200


@bp.route("/asignar-privilegios", methods=["POST"])
def asignar_privilegio():
    try:
        data = request.get_json(silent=True) or {}
        campos = {"curp", "codigo_cuenta", "id_privilegio"}
        faltantes = campos - data.keys()
        if faltantes:
            return (
                jsonify(
                    {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                ),
                400,
            )

        nueva = ClienteCuentaPrivilegio(
            curp=data["curp"],
            codigo_cuenta=data["codigo_cuenta"],
            id_privilegio=data["id_privilegio"],
        )
        db.session.add(nueva)
        db.session.commit()
        return jsonify({"mensaje": "Privilegio asignado exitosamente"}), 201
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": str(exc)}), 400
