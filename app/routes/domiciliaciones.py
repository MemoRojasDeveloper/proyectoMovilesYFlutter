from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation

from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import (
    CatalogoServicio,
    ClienteCuentaPrivilegio,
    CuentaCorriente,
    Domiciliacion,
)
from ..utils import require_auth

bp = Blueprint("domiciliaciones", __name__)


def _utcnow() -> datetime:
    """Devuelve un datetime timezone-aware en UTC.

    Las columnas fecha_* son timestamptz en Supabase, por lo que
    comparar con naive (datetime.utcnow()) lanza TypeError.
    """
    return datetime.now(timezone.utc)


def _parse_decimal(value):
    if value is None:
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return None


# GET /api/catalogo-servicios?tipo=internet
# Lista los proveedores del catalogo (activos por defecto).
# Es publico: el cliente lo necesita para ver que puede domiciliar.
@bp.route("/catalogo-servicios", methods=["GET"])
def listar_catalogo_servicios():
    tipo = request.args.get("tipo")
    q = CatalogoServicio.query
    if tipo:
        q = q.filter(CatalogoServicio.tipo_servicio == tipo)
    # Por defecto solo mostramos los activos
    solo_activos = request.args.get("activo", "true").lower() != "false"
    if solo_activos:
        q = q.filter(CatalogoServicio.activo.is_(True))
    servicios = q.order_by(
        CatalogoServicio.tipo_servicio, CatalogoServicio.nombre_proveedor
    ).all()
    return jsonify({
        "total": len(servicios),
        "servicios": [s.to_dict() for s in servicios],
    }), 200


# POST /api/domiciliaciones
# Body: { codigo_cuenta, id_catalogo_servicio }
# El cliente domicilia un servicio del catalogo contra su cuenta.
# Reglas:
#   - La cuenta debe existir y estar activa.
#   - El cliente debe tener acceso a la cuenta (cliente_cuenta_privilegio).
#   - El servicio del catalogo debe existir y estar activo.
#   - No puede haber OTRA domiciliacion ACTIVA del mismo servicio en
#     la misma cuenta (UNIQUE logico).
@bp.route("/domiciliaciones", methods=["POST"])
@require_auth(roles=("cliente", "empleado"))
def crear_domiciliacion():
    from flask_jwt_extended import get_jwt, get_jwt_identity

    data = request.get_json(silent=True) or {}
    codigo_cuenta = (data.get("codigo_cuenta") or "").strip().upper()
    id_catalogo = data.get("id_catalogo_servicio")

    if not codigo_cuenta or id_catalogo is None:
        return jsonify({
            "error": "Faltan campos: codigo_cuenta y/o id_catalogo_servicio",
        }), 400

    try:
        id_catalogo_int = int(id_catalogo)
    except (ValueError, TypeError):
        return jsonify({"error": "id_catalogo_servicio invalido"}), 400

    cuenta = db.session.get(CuentaCorriente, codigo_cuenta)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404
    if not cuenta.activo:
        return jsonify({"error": "La cuenta no esta activa"}), 400

    # El cliente debe tener acceso a la cuenta (salvo empleado)
    rol = get_jwt().get("rol", "cliente")
    if rol != "empleado":
        curp = get_jwt_identity()
        acceso = (
            db.session.query(ClienteCuentaPrivilegio)
            .filter(
                ClienteCuentaPrivilegio.curp == curp,
                ClienteCuentaPrivilegio.codigo_cuenta == codigo_cuenta,
            )
            .first()
        )
        if acceso is None:
            return jsonify({"error": "No tienes acceso a esta cuenta"}), 403

    catalogo = db.session.get(CatalogoServicio, id_catalogo_int)
    if catalogo is None:
        return jsonify({
            "error": f"Servicio de catalogo {id_catalogo_int} no existe",
        }), 404
    if not catalogo.activo:
        return jsonify({"error": "Este servicio ya no esta disponible"}), 400

    # UNIQUE logico: no duplicar servicio activo en la misma cuenta
    ya_activa = (
        db.session.query(Domiciliacion)
        .filter(
            Domiciliacion.codigo_cuenta == codigo_cuenta,
            Domiciliacion.id_catalogo_servicio == id_catalogo_int,
            Domiciliacion.estado == "activa",
        )
        .first()
    )
    if ya_activa is not None:
        return jsonify({
            "error": "Esta cuenta ya tiene ese servicio domiciliado",
        }), 409

    ahora = _utcnow()
    nueva = Domiciliacion(
        codigo_cuenta=codigo_cuenta,
        servicio=f"{catalogo.tipo_servicio} - {catalogo.nombre_proveedor}",
        monto_autorizado=catalogo.monto,
        monto_original=catalogo.monto,
        dia_cobro=ahora.day,
        id_catalogo_servicio=id_catalogo_int,
        estado="activa",
        fecha_ultimo_cobro=ahora,
        fecha_limite_pago=ahora + timedelta(hours=1),
        horas_retraso=0,
        recargo_acumulado=Decimal("0"),
    )
    try:
        db.session.add(nueva)
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo domiciliar: {exc!s}"}), 500

    return jsonify({
        "mensaje": "Servicio domiciliado correctamente. "
                   "El cobrador automatico intentara cobrar cada hora.",
        "domiciliacion": nueva.to_dict(),
    }), 201


# DELETE /api/domiciliaciones/<id>
# Soft delete: cambia estado a 'baja'. Solo empleados.
@bp.route("/domiciliaciones/<int:id_domiciliacion>", methods=["DELETE"])
@require_auth(roles=("empleado",))
def dar_baja_domiciliacion(id_domiciliacion: int):
    dom = db.session.get(Domiciliacion, id_domiciliacion)
    if dom is None:
        return jsonify({"error": "Domiciliacion no encontrada"}), 404
    if dom.estado == "baja":
        return jsonify({"mensaje": "La domiciliacion ya estaba dada de baja"}), 200

    dom.estado = "baja"
    try:
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo dar de baja: {exc!s}"}), 500

    return jsonify({
        "mensaje": f"Domiciliacion {id_domiciliacion} dada de baja",
        "domiciliacion": dom.to_dict(),
    }), 200


# Compatibilidad: GET /api/domiciliaciones sigue devolviendo todas
# (comportamiento original del blueprint, util para admin).
@bp.route("/domiciliaciones", methods=["GET"])
def gestionar_domiciliaciones():
    domiciliaciones = Domiciliacion.query.all()
    return jsonify([d.to_dict() for d in domiciliaciones]), 200
