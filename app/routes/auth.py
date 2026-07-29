"""Blueprint de autenticación: register, login y me.

Opera UNICAMENTE sobre `public.cliente` en Supabase. No existe tabla
`usuario` separada; el hash de password vive dentro de `cliente`.
"""
from __future__ import annotations

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt, get_jwt_identity
from sqlalchemy import func

from ..extensions import db
from ..models import Cliente
from ..utils import require_auth
from ..utils.validation import (
    normalizar_telefono,
    validar_curp,
    validar_email,
    validar_nombre,
    validar_password,
)

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


# ─────────────────────────────────────────────────────────────────
# POST /api/auth/register
#   Crea un Cliente nuevo (con password_hash embebido) en una sola
#   operacion atomica contra Supabase.
# ─────────────────────────────────────────────────────────────────
@bp.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True) or {}

    campos = ("curp", "nombres", "apellido_paterno", "email", "password")
    faltantes = [c for c in campos if not data.get(c)]
    if faltantes:
        return (
            jsonify({"error": f"Campos faltantes: {', '.join(faltantes)}"}),
            400,
        )

    ok, err = validar_curp(data["curp"])
    if not ok:
        return jsonify({"error": err}), 400
    curp = data["curp"].strip().upper()

    ok, err = validar_email(data["email"])
    if not ok:
        return jsonify({"error": err}), 400
    email = data["email"].strip().lower()

    ok, err = validar_password(data["password"])
    if not ok:
        return jsonify({"error": err}), 400

    ok, err = validar_nombre("Nombres", data["nombres"])
    if not ok:
        return jsonify({"error": err}), 400
    ok, err = validar_nombre("Apellido paterno", data["apellido_paterno"])
    if not ok:
        return jsonify({"error": err}), 400
    ap_materno = data.get("apellido_materno")
    if ap_materno:
        ok, err = validar_nombre("Apellido materno", ap_materno)
        if not ok:
            return jsonify({"error": err}), 400

    telefono = None
    if data.get("telefono"):
        telefono = normalizar_telefono(data["telefono"])
        if telefono is None:
            return jsonify({"error": "Telefono invalido (10 digitos)"}), 400

    # Duplicados
    if db.session.get(Cliente, curp) is not None:
        return jsonify({"error": "Ya existe un cliente con ese CURP"}), 409

    existe_email = (
        db.session.query(Cliente)
        .filter(func.lower(Cliente.email) == email)
        .first()
    )
    if existe_email is not None:
        return jsonify({"error": "Ya existe un cliente con ese email"}), 409

    try:
        nuevo = Cliente(
            curp=curp,
            nombres=data["nombres"].strip(),
            apellido_paterno=data["apellido_paterno"].strip(),
            apellido_materno=ap_materno.strip() if ap_materno else None,
            email=email,
            telefono=telefono,
            rol="cliente",
            activo=True,
        )
        nuevo.set_password(data["password"])
        db.session.add(nuevo)
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo registrar: {exc!s}"}), 500

    token = nuevo.emitir_token()
    return (
        jsonify(
            {
                "mensaje": "Cliente registrado con exito",
                "cliente": nuevo.to_dict(),
                "access_token": token,
                "rol": nuevo.rol,
            }
        ),
        201,
    )


# ─────────────────────────────────────────────────────────────────
# POST /api/auth/login
#   Autentica por email + password contra public.cliente en Supabase.
# ─────────────────────────────────────────────────────────────────
@bp.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}

    if not data.get("email") or not data.get("password"):
        return (
            jsonify({"error": "Email y password son obligatorios"}),
            400,
        )

    email = data["email"].strip().lower()
    cliente = (
        db.session.query(Cliente)
        .filter(func.lower(Cliente.email) == email)
        .first()
    )

    if cliente is None or not cliente.check_password(data["password"]):
        return jsonify({"error": "Credenciales invalidas"}), 401

    if not cliente.activo:
        return jsonify({"error": "Cuenta desactivada"}), 403

    try:
        cliente.ultimo_acceso = func.current_timestamp()
        db.session.commit()
    except Exception:
        db.session.rollback()

    token = cliente.emitir_token()
    return (
        jsonify(
            {
                "mensaje": "Login exitoso",
                "access_token": token,
                "rol": cliente.rol,
                "email": cliente.email,
                "perfil": cliente.to_dict(),
            }
        ),
        200,
    )


# ─────────────────────────────────────────────────────────────────
# GET /api/auth/me
#   Devuelve el perfil del cliente identificado por el token JWT.
# ─────────────────────────────────────────────────────────────────
@bp.route("/me", methods=["GET"])
@require_auth()
def me():
    curp = get_jwt_identity()
    claims = get_jwt()

    cliente = db.session.get(Cliente, curp)
    if cliente is None:
        return jsonify({"error": "Cliente no encontrado"}), 404

    data = cliente.to_dict(include_sensitive=True)
    data["claims"] = {
        "rol": claims.get("rol"),
        "curp": claims.get("curp"),
        "exp": claims.get("exp"),
    }
    return jsonify(data), 200