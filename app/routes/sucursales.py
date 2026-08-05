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
from ..models import Cliente, CuentaCorriente, Sucursal
from ..utils import require_auth

bp = Blueprint("sucursales", __name__)


# ── Validadores locales (mantienen una sola fuente de verdad) ─────
CP_RE = re.compile(r"^[0-9]{5}$")
TEL_RE = re.compile(r"^[0-9]{10}$")
# codigo_sucursal lo genera la DB: 'SUC-001', 'SUC-002', ...
CODIGO_RE = re.compile(r"^SUC-[0-9]{3,}$")
HHMM_RE = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")

# Limites por columna (alineados con la migración DB).
MAX_LEN = {
    "nombre_sucursal": 100,
    "calle": 120,
    "numero": 10,
    "colonia": 120,
    "ciudad": 80,
    "estado": 40,
    "codigo_postal": 5,
    "telefono": 10,
}


def _err(msg: str, code: int = 400):
    return jsonify({"error": msg}), code


def _validar_horario(data: dict) -> tuple[dict | None, str | None]:
    """Lee y valida los campos de horario.

    Formato esperado (todos opcionales, pero si uno viene par):
        dias_semana: list[int]  con 1..7 (1=L ... 7=D)
        hora_apertura: "HH:MM"
        hora_cierre:   "HH:MM"

    Reglas:
        - Si llega `dias_semana`, `hora_apertura` y `hora_cierre` son OBLIGATORIOS.
        - Si llega uno de los dos horarios, el otro también.
        - cada día debe estar en [1,7]
        - cada hora debe matchear HHMM_RE

    Devuelve (dict_normalizado_horario, mensaje_error_o_None).
    """
    # `dias_semana` puede llegar como lista o como set
    dias_raw = data.get("dias_semana")
    ap_raw = data.get("hora_apertura")
    ci_raw = data.get("hora_cierre")

    # Cualquiera presente -> los 3 deben estar
    presente = sum(x is not None for x in (dias_raw, ap_raw, ci_raw))
    if 0 < presente < 3:
        return None, (
            "horario incompleto: si envias dias_semana u horas, "
            "debes enviar los 3 campos"
        )

    if presente == 0:
        return {"dias_semana": None, "hora_apertura": None, "hora_cierre": None}, None

    # dias_semana
    if not isinstance(dias_raw, list):
        return None, "dias_semana debe ser una lista de enteros [1..7]"
    try:
        dias = sorted({int(d) for d in dias_raw})
    except (TypeError, ValueError):
        return None, "dias_semana debe contener enteros"
    if not dias or any(d < 1 or d > 7 for d in dias):
        return None, "dias_semana debe contener enteros en [1, 7]"

    # horas
    ap = (str(ap_raw) or "").strip()
    ci = (str(ci_raw) or "").strip()
    if not HHMM_RE.match(ap) or not HHMM_RE.match(ci):
        return None, "hora_apertura/hora_cierre deben tener formato HH:MM (24h)"

    # Comparación simple de strings "HH:MM" para validar orden
    if ap >= ci:
        return None, "hora_apertura debe ser estrictamente menor a hora_cierre"

    return {"dias_semana": dias, "hora_apertura": ap, "hora_cierre": ci}, None


def _validar_payload(data: dict, *, es_creacion: bool) -> tuple[dict, dict | None]:
    """Devuelve (data_normalizada, errores_dict_o_None).

    En creación, `codigo_sucursal` se IGNORA del body: la DB lo asigna
    automáticamente con la secuencia `sucursal_codigo_seq` ->
    'SUC-001', 'SUC-002', ...
    En edición (PUT), el código viene por URL, no por body.
    """
    errores = {}

    # codigo_sucursal: SOLO lo validamos si llega en el body (caso raro).
    codigo = (data.get("codigo_sucursal") or "").strip().upper()
    if codigo and not CODIGO_RE.match(codigo):
        errores["codigo_sucursal"] = (
            "codigo_sucursal debe tener formato SUC-NNN (autogenerado)"
        )

    # nombre_sucursal
    nombre = (data.get("nombre_sucursal") or "").strip()
    if es_creacion and not nombre:
        errores["nombre_sucursal"] = "nombre_sucursal es obligatorio"
    elif nombre and len(nombre) > MAX_LEN["nombre_sucursal"]:
        errores["nombre_sucursal"] = (
            f"nombre_sucursal demasiado largo (max {MAX_LEN['nombre_sucursal']})"
        )

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

    # ── Horario normalizado ──
    horario_norm, horario_err = _validar_horario(data)
    if horario_err:
        # Asignamos el error al campo mas probable segun el mensaje
        errores["horario"] = horario_err

    # ── Lectura de los varchar libres y validación de longitud ──
    campos_libres = ("calle", "numero", "colonia", "ciudad", "estado")
    normalizado = {
        "nombre_sucursal": nombre,
        "calle": (data.get("calle") or "").strip() or None,
        "numero": (data.get("numero") or "").strip() or None,
        "colonia": (data.get("colonia") or "").strip() or None,
        "ciudad": (data.get("ciudad") or "").strip() or None,
        "estado": (data.get("estado") or "").strip() or None,
        "codigo_postal": cp or None,
        "telefono": tel or None,
    }
    if horario_norm:
        normalizado.update(horario_norm)

    for campo in campos_libres:
        valor = normalizado[campo]
        if valor is None:
            continue
        maximo = MAX_LEN[campo]
        if len(valor) > maximo:
            errores[campo] = (
                f"{campo} demasiado largo (max {maximo} caracteres)"
            )

    # Si el caller mandó codigo_sucursal (raro), lo aceptamos.
    if codigo:
        normalizado["codigo_sucursal"] = codigo
    if activo is not None:
        normalizado["activo"] = activo

    return normalizado, errores or None


# ── Endpoints ──────────────────────────────────────────────────────

# GET /api/sucursales   GET /api/sucursales?activo=true|false
#
# Lectura publica: cualquiera (incluso antes del login) puede listar
# las sucursales activas para escoger una al registrarse. Si quieres
# ver TODAS (incluyendo inactivas), la llamada debe llevar JWT.
@bp.route("/sucursales", methods=["GET"])
def listar_sucursales():
    flag = request.args.get("activo")
    # Si el caller no especifica 'activo', exigimos token para evitar
    # exponer la lista completa.
    if flag is None:
        from flask_jwt_extended import verify_jwt_in_request
        try:
            verify_jwt_in_request()
        except Exception:
            return _err("Autenticacion requerida para listar todas las sucursales", 401)
        q = Sucursal.query
    else:
        quiere = None
        if flag.lower() in ("true", "1", "si", "yes"):
            quiere = True
        elif flag.lower() in ("false", "0", "no"):
            quiere = False
        q = Sucursal.query.filter(Sucursal.activo == quiere)

    sucursales = q.order_by(Sucursal.nombre_sucursal).all()
    return jsonify([s.to_dict() for s in sucursales]), 200


# POST /api/sucursales
@bp.route("/sucursales", methods=["POST"])
@require_auth(roles=("empleado",))
def crear_sucursal():
    """Crea una sucursal. El `codigo_sucursal` lo genera la DB.

    Body esperado (sin codigo_sucursal):
        {
            "nombre_sucursal": "Sucursal Centro",
            "calle": "...",
            ...
        }

    Respuesta: 201 con la sucursal completa, incluyendo el codigo_sucursal
    autogenerado.
    """
    data = request.get_json(silent=True) or {}
    normalizado, errores = _validar_payload(data, es_creacion=True)
    if errores:
        return jsonify({"error": "Datos inválidos", "detalles": errores}), 400

    # Si el cliente mandó codigo_sucursal, lo respetamos (caso raro);
    # si no, lo dejamos None y la DB lo asigna con la secuencia.
    codigo_cliente = normalizado.pop("codigo_sucursal", None)

    try:
        # Si no vino 'activo' en el body, forzar True al crear.
        normalizado.setdefault("activo", True)
        nueva = Sucursal(codigo_sucursal=codigo_cliente, **normalizado)
        db.session.add(nueva)
        db.session.commit()
        # Refresca para traer el codigo_sucursal asignado por la DB
        db.session.refresh(nueva)
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


# GET /api/sucursales/<codigo>/cuentas
# Lista las cuentas corrientes asociadas a esta sucursal
# (para mostrar en el dashboard de detalle).
# Tambien incluye, para cada cuenta, el listado resumido de
# domiciliaciones activas (para que el empleado pueda ver y dar
# de baja).
@bp.route("/sucursales/<string:codigo>/cuentas", methods=["GET"])
@require_auth()
def listar_cuentas_sucursal(codigo: str):
    codigo_up = codigo.upper()
    suc = db.session.get(Sucursal, codigo_up)
    if suc is None:
        return _err("Sucursal no encontrada", 404)

    cuentas = (
        db.session.query(CuentaCorriente)
        .filter(CuentaCorriente.codigo_sucursal == codigo_up)
        .order_by(CuentaCorriente.codigo_cuenta)
        .all()
    )
    clientes_count = (
        db.session.query(func.count(Cliente.curp))
        .filter(Cliente.codigo_sucursal == codigo_up)
        .scalar()
    )

    # Domiciliaciones agrupadas por cuenta (solo activas + bajas)
    codigos = [c.codigo_cuenta for c in cuentas]
    domis_por_cuenta: dict[str, list] = {k: [] for k in codigos}
    if codigos:
        from ..models import Domiciliacion  # lazy import
        rows = (
            db.session.query(Domiciliacion)
            .filter(Domiciliacion.codigo_cuenta.in_(codigos))
            .order_by(Domiciliacion.codigo_cuenta, Domiciliacion.id_domiciliacion)
            .all()
        )
        for d in rows:
            domis_por_cuenta.setdefault(d.codigo_cuenta, []).append(d.to_dict())

    cuentas_payload = []
    for c in cuentas:
        d = c.to_dict()
        d["domiciliaciones"] = domis_por_cuenta.get(c.codigo_cuenta, [])
        cuentas_payload.append(d)

    return jsonify({
        "codigo_sucursal": codigo_up,
        "total_cuentas": len(cuentas),
        "total_clientes": clientes_count,
        "cuentas": cuentas_payload,
    }), 200


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
            "ciudad", "estado", "codigo_postal", "telefono",
            "dias_semana", "hora_apertura", "hora_cierre",
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

    # Bloquear desactivacion si tiene clientes o cuentas asociadas.
    if data["activo"] is False and suc.activo is True:
        cuentas_count = (
            db.session.query(func.count(CuentaCorriente.codigo_cuenta))
            .filter(CuentaCorriente.codigo_sucursal == suc.codigo_sucursal)
            .scalar()
        )
        clientes_count = (
            db.session.query(func.count(Cliente.curp))
            .filter(Cliente.codigo_sucursal == suc.codigo_sucursal)
            .scalar()
        )
        if (cuentas_count or 0) + (clientes_count or 0) > 0:
            return jsonify({
                "error": (
                    "No se puede desactivar la sucursal: tiene "
                    f"{cuentas_count} cuenta(s) y {clientes_count} "
                    "cliente(s) asociados."
                ),
                "cuentas_asociadas": int(cuentas_count or 0),
                "clientes_asociados": int(clientes_count or 0),
            }), 409

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