"""Blueprint de sucursales (CRUD + toggle operativo, sin DELETE).

Endpoints pensados para el dashboard de EMPLEADO:
  GET    /api/sucursales              -> lista (opcional ?activo=true|false)
  POST   /api/sucursales              -> crea una nueva
  GET    /api/sucursales/<codigo>     -> obtiene una
  PUT    /api/sucursales/<codigo>     -> actualiza todos los campos editables
  PATCH  /api/sucursales/<codigo>/activo -> marca operativa=true|false
                                          (sustituye al DELETE)
  DELETE /api/sucursales/<codigo>     -> 405 (no se elimina, se desactiva)
"""
from __future__ import annotations

import re

from flask import Blueprint, jsonify, request
from sqlalchemy import func

from ..extensions import db
from ..models import Sucursal
from ..utils import require_auth

bp = Blueprint("sucursales", __name__)


# ── Validadores locales (mantienen una sola fuente de verdad) ─────
CP_RE = re.compile(r"^[0-9]{5}$")
TEL_RE = re.compile(r"^[0-9]{10}$")
CODIGO_RE = re.compile(r"^[A-Z0-9-]{3,20}$")


def _err(msg: str, code: int = 400):
    return jsonify({"error": msg}), code


def _validar_payload(data: dict, *, es_creacion: bool) -> tuple[dict, dict | None]:
    """Devuelve (data_normalizada, errores_dict_o_None)."""
    errores = {}

    # codigo_sucursal
    codigo = (data.get("codigo_sucursal") or "").strip().upper()
    if es_creacion:
        if not codigo:
            errores["codigo_sucursal"] = "codigo_sucursal es obligatorio"
        elif not CODIGO_RE.match(codigo):
            errores["codigo_sucursal"] = (
                "codigo_sucursal debe tener 3-20 chars (A-Z, 0-9, guion)"
            )

    # nombre_sucursal
    nombre = (data.get("nombre_sucursal") or "").strip()
    if es_creacion and not nombre:
        errores["nombre_sucursal"] = "nombre_sucursal es obligatorio"
    elif nombre and len(nombre) > 100:
        errores["nombre_sucursal"] = "nombre_sucursal demasiado largo (max 100)"

    # codigo_postal
    cp = (data.get("codigo_postal") or "").strip()
    if cp and not CP_RE.match(cp):
        errores["codigo_postal"] = "codigo_postal debe tener 5 dígitos"

    # telefono
    tel = (data.get("telefono") or "").strip()
    if tel and not TEL_RE.match(tel):
        errores["telefono"] = "telefono debe tener 10 dígitos"

    # activo (solo si viene)
    activo = data.get("activo")
    if activo is not None and not isinstance(activo, bool):
        errores["activo"] = "activo debe ser booleano"

    normalizado = {
        "codigo_sucursal": codigo,
        "nombre_sucursal": nombre,
        "calle": (data.get("calle") or "").strip() or None,
        "numero": (data.get("numero") or "").strip() or None,
        "colonia": (data.get("colonia") or "").strip() or None,
        "ciudad": (data.get("ciudad") or "").strip() or None,
        "estado": (data.get("estado") or "").strip() or None,
        "codigo_postal": cp or None,
        "telefono": tel or None,
        "horario": (data.get("horario") or "").strip() or None,
    }
    if activo is not None:
        normalizado["activo"] = activo

    return normalizado, errores or None


# ── Endpoints ──────────────────────────────────────────────────────

# GET /api/sucursales   GET /api/sucursales?activo=true|false
@bp.route("/sucursales", methods=["GET"])
@require_auth()
def listar_sucursales():
    q = Sucursal.query
    flag = request.args.get("activo")
    if flag is not None:
        if flag.lower() in ("true", "1", "si", "yes"):
            q = q.filter(Sucursal.activo.is_(True))
        elif flag.lower() in ("false", "0", "no"):
            q = q.filter(Sucursal.activo.is_(False))
    sucursales = q.order_by(Sucursal.nombre_sucursal).all()
    return jsonify([s.to_dict() for s in sucursales]), 200


# POST /api/sucursales
@bp.route("/sucursales", methods=["POST"])
@require_auth(roles=("empleado",))
def crear_sucursal():
    data = request.get_json(silent=True) or {}
    normalizado, errores = _validar_payload(data, es_creacion=True)
    if errores:
        return jsonify({"error": "Datos inválidos", "detalles": errores}), 400

    if db.session.get(Sucursal, normalizado["codigo_sucursal"]) is not None:
        return _err(f"Ya existe la sucursal {normalizado['codigo_sucursal']}", 409)

    try:
        nueva = Sucursal(**normalizado, activo=True)
        db.session.add(nueva)
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return _err(f"No se pudo crear: {exc!s}", 500)

    return jsonify({"mensaje": "Sucursal registrada con éxito", "sucursal": nueva.to_dict()}), 201


# GET /api/sucursales/<codigo>
@bp.route("/sucursales/<string:codigo>", methods=["GET"])
@require_auth()
def obtener_sucursal(codigo: str):
    suc = db.session.get(Sucursal, codigo.upper())
    if suc is None:
        return _err("Sucursal no encontrada", 404)
    return jsonify(suc.to_dict()), 200


# PUT /api/sucursales/<codigo>
@bp.route("/sucursales/<string:codigo>", methods=["PUT"])
@require_auth(roles=("empleado",))
def actualizar_sucursal(codigo: str):
    suc = db.session.get(Sucursal, codigo.upper())
    if suc is None:
        return _err("Sucursal no encontrada", 404)

    data = request.get_json(silent=True) or {}
    # en PUT no se exige codigo_sucursal (es la PK del path)
    normalizado, errores = _validar_payload(data, es_creacion=False)
    if errores:
        return jsonify({"error": "Datos inválidos", "detalles": errores}), 400

    if not normalizado["nombre_sucursal"]:
        return _err("nombre_sucursal es obligatorio", 400)

    try:
        for campo in (
            "nombre_sucursal", "calle", "numero", "colonia",
            "ciudad", "estado", "codigo_postal", "telefono", "horario",
        ):
            setattr(suc, campo, normalizado[campo])
        if "activo" in normalizado:
            suc.activo = normalizado["activo"]
        suc.actualizado_en = func.current_timestamp()
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return _err(f"No se pudo actualizar: {exc!s}", 500)

    return jsonify({"mensaje": "Sucursal actualizada", "sucursal": suc.to_dict()}), 200


# PATCH /api/sucursales/<codigo>/activo  body: {"activo": true|false}
@bp.route("/sucursales/<string:codigo>/activo", methods=["PATCH"])
@require_auth(roles=("empleado",))
def toggle_activo(codigo: str):
    suc = db.session.get(Sucursal, codigo.upper())
    if suc is None:
        return _err("Sucursal no encontrada", 404)

    data = request.get_json(silent=True) or {}
    if "activo" not in data or not isinstance(data["activo"], bool):
        return _err("Falta 'activo' (booleano) en el body", 400)

    try:
        suc.activo = data["activo"]
        suc.actualizado_en = func.current_timestamp()
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return _err(f"No se pudo cambiar el estado: {exc!s}", 500)

    estado = "operativa" if suc.activo else "no operativa"
    return jsonify({
        "mensaje": f"Sucursal marcada como {estado}",
        "sucursal": suc.to_dict(),
    }), 200


# DELETE /api/sucursales/<codigo> -> rechazado a propósito
@bp.route("/sucursales/<string:codigo>", methods=["DELETE"])
@require_auth(roles=("empleado",))
def rechazar_delete(codigo: str):
    return jsonify({
        "error": (
            "Las sucursales no se eliminan. Usa "
            f"PATCH /api/sucursales/{codigo.upper()}/activo "
            "para marcarla como no operativa."
        )
    }), 405