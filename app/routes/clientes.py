"""CRUD de clientes contra `public.cliente` en Supabase.

La creación se hace desde `POST /api/auth/register` (que valida y
hashea el password). Este blueprint solo expone consultas y
actualizaciones sobre clientes ya registrados.
"""
from __future__ import annotations

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt, get_jwt_identity
from sqlalchemy import func

from ..extensions import db
from ..models import Cliente, ClienteCuentaPrivilegio, CuentaCorriente, Sucursal
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


# GET /api/clientes/<curp>/cuentas
# Lista las cuentas corrientes asociadas al cliente (vía tabla de privilegios).
# Si el caller es 'cliente', solo puede ver SUS cuentas (curp del JWT == path).
# Si el caller es 'empleado', puede ver las de cualquier cliente.
@bp.route("/clientes/<string:curp>/cuentas", methods=["GET"])
@require_auth()
def listar_cuentas_cliente(curp: str):
    curp_up = curp.upper()
    curp_jwt = get_jwt_identity()
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado" and curp_up != curp_jwt:
        return jsonify({"error": "Solo puedes ver tus propias cuentas"}), 403

    cliente = db.session.get(Cliente, curp_up)
    if cliente is None:
        return jsonify({"error": "Cliente no encontrado"}), 404

    # JOIN con la tabla de privilegios para traer solo las cuentas del cliente
    rows = (
        db.session.query(CuentaCorriente, Sucursal)
        .join(
            ClienteCuentaPrivilegio,
            ClienteCuentaPrivilegio.codigo_cuenta == CuentaCorriente.codigo_cuenta,
        )
        .outerjoin(
            Sucursal,
            Sucursal.codigo_sucursal == CuentaCorriente.codigo_sucursal,
        )
        .filter(ClienteCuentaPrivilegio.curp == curp_up)
        .order_by(CuentaCorriente.codigo_cuenta)
        .all()
    )

    cuentas = []
    for c, suc in rows:
        d = c.to_dict()
        if suc is not None:
            d["nombre_sucursal"] = suc.nombre_sucursal
            d["ciudad"] = suc.ciudad
            d["activo_sucursal"] = suc.activo
        cuentas.append(d)

    return jsonify({
        "curp": curp_up,
        "nombre": cliente.nombre_completo,
        "total": len(cuentas),
        "saldo_total": float(sum((c[0].saldo or 0) for c in rows)),
        "cuentas": cuentas,
    }), 200