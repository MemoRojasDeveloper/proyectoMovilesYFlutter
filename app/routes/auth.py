"""Blueprint de autenticación: register, login y me."""

from __future__ import annotations

from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import Cliente, Usuario
from ..utils import (
    require_auth,
    validar_curp,
    validar_email,
    validar_nombre,
    validar_password,
)
from ..utils.validation import normalizar_telefono

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


# ─────────────────────────────────────────────────────────────────
# POST /api/auth/register
#   Crea un CLIENTE nuevo y su credencial en una transacción.
#   Registro público; cualquier persona con CURP + email puede hacerlo.
#   Los empleados se crean manualmente en la BD (no por este endpoint).
# ─────────────────────────────────────────────────────────────────
@bp.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True) or {}

    # ── 1) Validar campos requeridos ─────────────────────────────
    campos = ("curp", "nombres", "apellido_paterno", "email", "password")
    faltantes = [c for c in campos if not data.get(c)]
    if faltantes:
        return (
            jsonify(
                {"error": f"Campos faltantes: {', '.join(faltantes)}"}
            ),
            400,
        )

    # ── 2) Validar cada campo con regex ──────────────────────────
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
            return (
                jsonify(
                    {"error": "Teléfono inválido (10 dígitos)"}
                ),
                400,
            )

    # ── 3) Verificar duplicados ──────────────────────────────────
    if db.session.get(Cliente, curp) is not None:
        return jsonify({"error": "Ya existe un cliente con ese CURP"}), 409

    existe_email = (
        db.session.query(Usuario)
        .filter(db.func.lower(Usuario.email) == email)
        .first()
    )
    if existe_email is not None:
        return jsonify({"error": "Ya existe un usuario con ese email"}), 409

    # ── 4) Crear cliente + usuario en una transacción ────────────
    try:
        nuevo_cliente = Cliente(
            curp=curp,
            nombres=data["nombres"].strip(),
            apellido_paterno=data["apellido_paterno"].strip(),
            apellido_materno=ap_materno.strip() if ap_materno else None,
            email=email,
            telefono=telefono,
        )
        db.session.add(nuevo_cliente)

        nuevo_usuario = Usuario(
            email=email,
            rol="cliente",
            curp=curp,
            activo=True,
        )
        nuevo_usuario.set_password(data["password"])
        db.session.add(nuevo_usuario)

        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo registrar: {exc!s}"}), 500

    # ── 5) Devolver token para entrar sin paso intermedio ────────
    token = nuevo_usuario.emitir_token()
    return (
        jsonify(
            {
                "mensaje": "Cliente registrado con éxito",
                "cliente": nuevo_cliente.to_dict(),
                "access_token": token,
                "rol": nuevo_usuario.rol,
            }
        ),
        201,
    )


# ─────────────────────────────────────────────────────────────────
# POST /api/auth/login
#   Autentica por email + password. Sirve para clientes y empleados.
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
    usuario = (
        db.session.query(Usuario)
        .filter(db.func.lower(Usuario.email) == email)
        .first()
    )

    if usuario is None or not usuario.check_password(data["password"]):
        # Mismo mensaje para email inexistente y password incorrecto
        return jsonify({"error": "Credenciales inválidas"}), 401

    if not usuario.activo:
        return jsonify({"error": "Cuenta desactivada"}), 403

    token = usuario.emitir_token()

    perfil = None
    if usuario.curp:
        cliente = db.session.get(Cliente, usuario.curp)
        if cliente:
            perfil = cliente.to_dict()

    return (
        jsonify(
            {
                "mensaje": "Login exitoso",
                "access_token": token,
                "rol": usuario.rol,
                "email": usuario.email,
                "perfil": perfil,
            }
        ),
        200,
    )


# ─────────────────────────────────────────────────────────────────
# GET /api/auth/me
#   Devuelve el perfil del usuario identificado por el token JWT.
# ─────────────────────────────────────────────────────────────────
@bp.route("/me", methods=["GET"])
@require_auth()
def me():
    from flask_jwt_extended import get_jwt, get_jwt_identity

    id_usuario = int(get_jwt_identity())
    claims = get_jwt()

    usuario = db.session.get(Usuario, id_usuario)
    if usuario is None:
        return jsonify({"error": "Usuario no encontrado"}), 404

    data = usuario.to_dict(include_sensitive=False)

    if usuario.curp:
        cliente = db.session.get(Cliente, usuario.curp)
        if cliente:
            data["perfil"] = cliente.to_dict()

    data["claims"] = {
        "rol": claims.get("rol"),
        "curp": claims.get("curp"),
        "exp": claims.get("exp"),
    }
    return jsonify(data), 200
