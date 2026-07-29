"""CRUD de clientes contra `public.cliente` en Supabase.

La creación se hace desde `POST /api/auth/register` (que valida y
hashea el password). Este blueprint solo expone consultas y
actualizaciones sobre clientes ya registrados.
"""
from __future__ import annotations

from flask import Blueprint, jsonify, request
from sqlalchemy import func

from ..extensions import db
from ..models import Cliente
from ..utils import require_auth

bp = Blueprint("clientes", __name__)


# GET /api/clientes
# GET /api/clientes?rol=cliente|empleado
@bp.route("/clientes", methods=["GET"])
@require_auth()
def listar_clientes():
    rol = request.args.get("rol")
    q = Cliente.query
    if rol:
        q = q.filter(Cliente.rol == rol)
    clientes = q.order_by(Cliente.apellido_paterno).all()
    return jsonify([c.to_dict() for c in clientes]), 200


# GET /api/clientes/<curp>
@bp.route("/clientes/<string:curp>", methods=["GET"])
@require_auth()
def obtener_cliente(curp: str):
    cliente = db.session.get(Cliente, curp.upper())
    if cliente is None:
        return jsonify({"error": "Cliente no encontrado"}), 404
    return jsonify(cliente.to_dict(include_sensitive=True)), 200


# GET /api/clientes/buscar?email=...
@bp.route("/clientes/buscar", methods=["GET"])
@require_auth()
def buscar_por_email():
    email = request.args.get("email", "").strip().lower()
    if not email:
        return jsonify({"error": "Falta parametro email"}), 400
    cliente = (
        db.session.query(Cliente)
        .filter(func.lower(Cliente.email) == email)
        .first()
    )
    if cliente is None:
        return jsonify({"error": "Cliente no encontrado"}), 404
    return jsonify(cliente.to_dict()), 200