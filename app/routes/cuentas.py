from datetime import date
from decimal import Decimal, InvalidOperation

from dateutil import parser
from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, get_jwt

from ..extensions import db
from ..models import (
    Cliente,
    ClienteCuentaPrivilegio,
    CuentaCorriente,
    Domiciliacion,
    Movimiento,
    Privilegio,
    Sucursal,
)
from ..models.movimiento import (
    TIPO_TRANSFERENCIA_ENVIADA,
    TIPO_TRANSFERENCIA_RECIBIDA,
)
from ..utils import require_auth

bp = Blueprint("cuentas", __name__)


def _parse_date(value) -> date | None:
    if value is None:
        return None
    if isinstance(value, date):
        return value
    try:
        return parser.isoparse(str(value)).date()
    except (ValueError, TypeError):
        return None


def _parse_decimal(value, default: Decimal | None = None) -> Decimal | None:
    if value is None:
        return default
    try:
        return Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return None


def _claims():
    return get_jwt()


def _current_curp() -> str:
    """El JWT identifica al cliente por su curp."""
    return get_jwt_identity()


def _tiene_privilegio(curp: str, codigo_cuenta: str, nombre_operacion: str) -> bool:
    priv = (
        db.session.query(Privilegio)
        .filter(Privilegio.nombre_operacion == nombre_operacion)
        .first()
    )
    if priv is None:
        return False
    asig = (
        db.session.query(ClienteCuentaPrivilegio)
        .filter(
            ClienteCuentaPrivilegio.curp == curp,
            ClienteCuentaPrivilegio.codigo_cuenta == codigo_cuenta,
            ClienteCuentaPrivilegio.id_privilegio == priv.id_privilegio,
        )
        .first()
    )
    return asig is not None


@bp.route("/cuentas", methods=["POST", "GET"])
def gestionar_cuentas():
    if request.method == "POST":
        try:
            data = request.get_json(silent=True) or {}
            campos_requeridos = {
                "codigo_cuenta",
                "codigo_sucursal",
                "fecha_apertura",
            }
            faltantes = campos_requeridos - data.keys()
            if faltantes:
                return (
                    jsonify(
                        {"error": f"Campos faltantes: {', '.join(sorted(faltantes))}"}
                    ),
                    400,
                )

            fecha = _parse_date(data["fecha_apertura"])
            if fecha is None:
                return (
                    jsonify({"error": "fecha_apertura inválida (use ISO YYYY-MM-DD)"}),
                    400,
                )

            saldo = _parse_decimal(data.get("saldo"), default=Decimal("0"))

            nueva = CuentaCorriente(
                codigo_cuenta=data["codigo_cuenta"],
                codigo_sucursal=data["codigo_sucursal"],
                saldo=saldo,
                fecha_apertura=fecha,
            )
            db.session.add(nueva)
            db.session.commit()
            return jsonify({"mensaje": "Cuenta registrada con éxito"}), 201
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": str(exc)}), 400

    cuentas = CuentaCorriente.query.all()
    return jsonify([c.to_dict() for c in cuentas]), 200


# GET /api/cuentas/<codigo>
@bp.route("/cuentas/<string:codigo>", methods=["GET"])
def obtener_cuenta(codigo: str):
    from ..utils.auth import require_auth as _ra
    @_ra()
    def _vista():
        return _servir_cuenta(codigo)
    return _vista()


def _check_auth_and_acceso(codigo_up: str):
    """Verifica JWT y que el cliente (no empleado) tenga acceso a la cuenta."""
    curp = _current_curp()
    rol = _claims().get("rol", "cliente")
    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return None, jsonify({"error": "Cuenta no encontrada"}), 404
    if rol != "empleado":
        asig = (
            db.session.query(ClienteCuentaPrivilegio)
            .filter(
                ClienteCuentaPrivilegio.curp == curp,
                ClienteCuentaPrivilegio.codigo_cuenta == codigo_up,
            )
            .first()
        )
        if asig is None:
            return None, jsonify({"error": "No tiene acceso a esta cuenta"}), 403
    return (curp, rol, cuenta), None, None


def _servir_cuenta(codigo: str):
    codigo_up = codigo.upper()
    ctx, err, code = _check_auth_and_acceso(codigo_up)
    if err is not None:
        return err, code
    _, _, cuenta = ctx
    return jsonify(cuenta.to_dict()), 200


# GET /api/cuentas/<codigo>/privilegios
@bp.route("/cuentas/<string:codigo>/privilegios", methods=["GET"])
def listar_privilegios_cuenta(codigo: str):
    from ..utils.auth import require_auth as _ra
    @_ra()
    def _vista():
        codigo_up = codigo.upper()
        curp, rol, cuenta = (None, _claims().get("rol", "cliente"), None)
        ctx, err, code = _check_auth_and_acceso(codigo_up)
        if err is not None:
            return err, code
        curp, rol, _ = ctx

        # Solo nos importan los privilegios del cliente actual
        # sobre esta cuenta. Si el caller es empleado, mostramos
        # el catalogo completo con lo_tiene=false (no le aplica
        # la restriccion a un empleado).
        if rol == "empleado":
            autorizados = set()
        else:
            rows = (
                db.session.query(Privilegio)
                .join(
                    ClienteCuentaPrivilegio,
                    ClienteCuentaPrivilegio.id_privilegio == Privilegio.id_privilegio,
                )
                .filter(
                    ClienteCuentaPrivilegio.codigo_cuenta == codigo_up,
                    ClienteCuentaPrivilegio.curp == curp,
                )
                .all()
            )
            autorizados = {p.nombre_operacion for p in rows if p is not None}
        todos = (
            db.session.query(Privilegio)
            .order_by(Privilegio.nombre_operacion)
            .all()
        )
        resultado = [
            {
                "id_privilegio": p.id_privilegio,
                "nombre_operacion": p.nombre_operacion,
                "descripcion": p.descripcion,
                "lo_tiene": p.nombre_operacion in autorizados,
            }
            for p in todos
        ]
        return jsonify({
            "codigo_cuenta": codigo_up,
            "total": len(resultado),
            "privilegios": resultado,
        }), 200
    return _vista()


# GET /api/cuentas/<codigo>/domiciliaciones
@bp.route("/cuentas/<string:codigo>/domiciliaciones", methods=["GET"])
def listar_domiciliaciones_cuenta(codigo: str):
    from ..utils.auth import require_auth as _ra
    @_ra()
    def _vista():
        codigo_up = codigo.upper()
        ctx, err, code = _check_auth_and_acceso(codigo_up)
        if err is not None:
            return err, code
        doms = (
            db.session.query(Domiciliacion)
            .filter(Domiciliacion.codigo_cuenta == codigo_up)
            .order_by(Domiciliacion.dia_cobro)
            .all()
        )
        return jsonify([d.to_dict() for d in doms]), 200
    return _vista()


# GET /api/cuentas/<codigo>/movimientos?limite=20&offset=0
# Historial paginado de una cuenta. Ordenado por fecha DESC.
@bp.route("/cuentas/<string:codigo>/movimientos", methods=["GET"])
def listar_movimientos_cuenta(codigo: str):
    from ..utils.auth import require_auth as _ra
    @_ra()
    def _vista():
        codigo_up = codigo.upper()
        ctx, err, code = _check_auth_and_acceso(codigo_up)
        if err is not None:
            return err, code

        # Parametros de paginacion
        try:
            limite = min(int(request.args.get("limite", 20)), 100)
            offset = max(int(request.args.get("offset", 0)), 0)
        except (ValueError, TypeError):
            return jsonify({"error": "limite/offset invalidos"}), 400

        q = (
            db.session.query(Movimiento)
            .filter(Movimiento.codigo_cuenta == codigo_up)
            .order_by(Movimiento.fecha.desc(), Movimiento.id_movimiento.desc())
        )
        total = q.count()
        rows = q.limit(limite).offset(offset).all()

        return jsonify({
            "codigo_cuenta": codigo_up,
            "total": total,
            "limite": limite,
            "offset": offset,
            "movimientos": [m.to_dict() for m in rows],
        }), 200
    return _vista()


# POST /api/cuentas/<codigo>/transferir
# body: {"curp_destino": "...", "monto": 123.45, "concepto": "..."}
@bp.route("/cuentas/<string:codigo>/transferir", methods=["POST"])
def transferir(codigo: str):
    from ..utils.auth import require_auth as _ra
    @_ra(roles=("cliente", "empleado"))
    def _vista():
        curp_origen = _current_curp()
        codigo_up = codigo.upper()
        data = request.get_json(silent=True) or {}

        curp_destino = (data.get("curp_destino") or "").strip().upper()
        if not curp_destino:
            return jsonify({"error": "curp_destino obligatorio"}), 400
        if curp_destino == curp_origen:
            return jsonify({"error": "No puedes transferirte a ti mismo"}), 400

        monto = _parse_decimal(data.get("monto"))
        if monto is None or monto <= Decimal("0"):
            return jsonify({"error": "monto debe ser mayor a 0"}), 400
        concepto = (data.get("concepto") or "").strip() or None

        origen = db.session.get(CuentaCorriente, codigo_up)
        if origen is None:
            return jsonify({"error": "Cuenta origen no encontrada"}), 404
        if (origen.saldo or Decimal("0")) < monto:
            return jsonify({"error": "Saldo insuficiente"}), 400

        cliente_destino = db.session.get(Cliente, curp_destino)
        if cliente_destino is None:
            return jsonify({"error": f"Cliente destino {curp_destino} no existe"}), 404

        # La cuenta destino debe estar ligada al cliente destino
        cuentas_destino = (
            db.session.query(CuentaCorriente)
            .join(
                ClienteCuentaPrivilegio,
                ClienteCuentaPrivilegio.codigo_cuenta == CuentaCorriente.codigo_cuenta,
            )
            .filter(ClienteCuentaPrivilegio.curp == curp_destino)
            .all()
        )
        if not cuentas_destino:
            return jsonify({"error": "El cliente destino no tiene cuentas"}), 400

        destino = next(
            (c for c in cuentas_destino if c.codigo_sucursal == origen.codigo_sucursal),
            cuentas_destino[0],
        )

        try:
            origen.saldo = (origen.saldo or Decimal("0")) - monto
            destino.saldo = (destino.saldo or Decimal("0")) + monto
            # Historial: dos filas (una por cuenta) en la misma transaccion
            db.session.add(Movimiento(
                codigo_cuenta=origen.codigo_cuenta,
                tipo=TIPO_TRANSFERENCIA_ENVIADA,
                monto=monto,
                contraparte_cuenta=destino.codigo_cuenta,
                curp_actor=curp_origen,
                concepto=concepto,
            ))
            db.session.add(Movimiento(
                codigo_cuenta=destino.codigo_cuenta,
                tipo=TIPO_TRANSFERENCIA_RECIBIDA,
                monto=monto,
                contraparte_cuenta=origen.codigo_cuenta,
                curp_actor=curp_origen,
                concepto=concepto,
            ))
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": f"No se pudo transferir: {exc!s}"}), 500

        return jsonify({
            "mensaje": "Transferencia exitosa",
            "origen": {
                "codigo_cuenta": origen.codigo_cuenta,
                "saldo": float(origen.saldo),
            },
            "destino": {
                "codigo_cuenta": destino.codigo_cuenta,
                "curp_destino": curp_destino,
                "nombre_destino": cliente_destino.nombre_completo,
            },
            "monto": float(monto),
            "concepto": concepto,
        }), 200
    return _vista()


# PATCH /api/cuentas/<codigo>/domiciliaciones/<id>/pagar
# Pago MANUAL de una domiciliacion. Pasa por Stripe porque es un
# cargo a un proveedor externo. Registra un movimiento.
@bp.route("/cuentas/<string:codigo>/domiciliaciones/<int:id>/pagar", methods=["PATCH"])
def pagar_domiciliacion(codigo: str, id: int):
    from ..utils.auth import require_auth as _ra
    from ..models.movimiento import TIPO_PAGO_DOMI_MANUAL
    from ..services import StripePaymentError, cobrar_domiciliacion

    @_ra()
    def _vista():
        curp = _current_curp()
        rol = _claims().get("rol", "cliente")
        codigo_up = codigo.upper()
        cuenta = db.session.get(CuentaCorriente, codigo_up)
        if cuenta is None:
            return jsonify({"error": "Cuenta no encontrada"}), 404

        if rol != "empleado":
            asig = (
                db.session.query(ClienteCuentaPrivilegio)
                .filter(
                    ClienteCuentaPrivilegio.curp == curp,
                    ClienteCuentaPrivilegio.codigo_cuenta == codigo_up,
                )
                .first()
            )
            if asig is None:
                return jsonify({"error": "No tiene acceso a esta cuenta"}), 403
            if not _tiene_privilegio(curp, codigo_up, "pagar_domiciliacion"):
                return jsonify({
                    "error": "No tienes el privilegio 'pagar_domiciliacion' en esta cuenta"
                }), 403

        dom = db.session.get(Domiciliacion, id)
        if dom is None or dom.codigo_cuenta != codigo_up:
            return jsonify({"error": "Domiciliacion no encontrada"}), 404

        # Cobramos el total (original + recargos si hay atraso)
        monto = Decimal(str(dom.monto_total_a_cobrar))
        if (cuenta.saldo or Decimal("0")) < monto:
            return jsonify({"error": "Saldo insuficiente"}), 400

        # 1) Cobro a Stripe
        stripe_charge_id = None
        stripe_receipt_url = None
        try:
            resultado = cobrar_domiciliacion(
                monto=monto,
                descripcion=(
                    f"Pago manual de {dom.servicio} "
                    f"(cuenta {cuenta.codigo_cuenta})"
                ),
            )
            stripe_receipt_url = resultado.receipt_url
        except StripePaymentError as exc:
            return jsonify({
                "error": f"Stripe rechazo el cargo: {exc}",
            }), 400
        except Exception as exc:
            # Si la clave es la dummy, devolvemos 503 claro
            return jsonify({
                "error": "No se pudo contactar a Stripe. "
                         "Revisa STRIPE_SECRET_KEY en .env.",
                "detalle": str(exc),
            }), 503

        # 2) Descontamos saldo + reseteamos contadores + movimiento
        try:
            cuenta.saldo = (cuenta.saldo or Decimal("0")) - monto
            dom.horas_retraso = 0
            dom.recargo_acumulado = Decimal("0")
            db.session.add(Movimiento(
                codigo_cuenta=cuenta.codigo_cuenta,
                tipo=TIPO_PAGO_DOMI_MANUAL,
                monto=monto,
                curp_actor=curp,
                concepto=f"Pago manual de {dom.servicio}",
                id_domiciliacion=dom.id_domiciliacion,
                stripe_charge_id=stripe_charge_id,
                stripe_receipt_url=stripe_receipt_url,
            ))
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            return jsonify({"error": f"No se pudo registrar el pago: {exc!s}"}), 500

        return jsonify({
            "mensaje": f"Pago de {dom.servicio} realizado",
            "monto": float(monto),
            "recibo_stripe": stripe_receipt_url,
            "cuenta": {
                "codigo_cuenta": cuenta.codigo_cuenta,
                "saldo": float(cuenta.saldo),
            },
        }), 200
    return _vista()

# PATCH /api/cuentas/<codigo>/activo
# body: {"activo": true|false}. Solo empleados.
# Regla: NO se desactiva si saldo != 0.
@bp.route("/cuentas/<string:codigo>/activo", methods=["PATCH"])
@require_auth(roles=("empleado",))
def toggle_activo_cuenta(codigo: str):
    from flask_jwt_extended import get_jwt, get_jwt_identity
    data = request.get_json(silent=True) or {}
    if "activo" not in data or not isinstance(data["activo"], bool):
        return jsonify({"error": "Falta ''activo'' (booleano) en el body"}), 400

    codigo_up = codigo.upper()
    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404

    # Solo bloqueamos desactivacion si saldo != 0. Si saldo == 0
    # y quiere desactivar, se permite.
    if data["activo"] is False and cuenta.activo is True:
        if (cuenta.saldo or 0) != 0:
            return jsonify({
                "error": "No se puede desactivar la cuenta: tiene saldo "
                         f"${float(cuenta.saldo):.2f}. Transfiere o retira "
                         "el dinero antes de darla de baja.",
                "saldo_actual": float(cuenta.saldo),
            }), 409

    try:
        cuenta.activo = data["activo"]
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo cambiar el estado: {exc!s}"}), 500

    estado = "activa" if cuenta.activo else "dada de baja"
    return jsonify({
        "mensaje": f"Cuenta {codigo_up} {estado}",
        "cuenta": cuenta.to_dict(),
    }), 200


# PATCH /api/cuentas/<codigo>/sucursal
# body: {"codigo_sucursal": "PUE-002"}. Solo empleados.
# Reglas: la nueva sucursal debe existir y estar activa.
@bp.route("/cuentas/<string:codigo>/sucursal", methods=["PATCH"])
@require_auth(roles=("empleado",))
def cambiar_sucursal_cuenta(codigo: str):
    from flask_jwt_extended import get_jwt, get_jwt_identity
    data = request.get_json(silent=True) or {}
    nuevo_codigo = (data.get("codigo_sucursal") or "").strip().upper()
    if not nuevo_codigo:
        return jsonify({"error": "codigo_sucursal obligatorio"}), 400

    codigo_up = codigo.upper()
    if nuevo_codigo == codigo_up:
        return jsonify({"error": "La cuenta ya pertenece a esa sucursal"}), 400

    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404

    nueva_sucursal = db.session.get(Sucursal, nuevo_codigo)
    if nueva_sucursal is None:
        return jsonify({"error": f"Sucursal {nuevo_codigo} no existe"}), 404
    if not nueva_sucursal.activo:
        return jsonify({"error": "La sucursal destino no esta operativa"}), 400

    anterior = cuenta.codigo_sucursal
    try:
        cuenta.codigo_sucursal = nuevo_codigo
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo cambiar: {exc!s}"}), 500

    return jsonify({
        "mensaje": f"Cuenta {codigo_up} movida de {anterior} a {nuevo_codigo}",
        "cuenta": cuenta.to_dict(),
    }), 200


# ─────────────────────────────────────────────────────────────────
# Endpoints de "Acceso compartido" (compartir cuenta con mas clientes)
# ─────────────────────────────────────────────────────────────────
#
# Reglas:
#   * El cliente identificado por el JWT debe tener la cuenta en su
#     tabla de privilegios para poder verla (`_check_auth_and_acceso`).
#   * Para ADMINISTRAR los accesos de otros (listar con detalle, agregar,
#     modificar privilegios o quitar) se requiere ademas el privilegio
#     `cerrar_cuenta` sobre la cuenta. Esto identifica al dueno real:
#     ese privilegio solo se otorga al registrar la cuenta.
#   * Un usuario NO puede quitarse a si mismo (perderia su propio acceso).
# ─────────────────────────────────────────────────────────────────


def _es_dueno(curp: str, codigo_cuenta: str) -> bool:
    """Verifica que el cliente tiene el privilegio `cerrar_cuenta`
    en la cuenta. Es el marcador del dueno real."""
    return _tiene_privilegio(curp, codigo_cuenta, "cerrar_cuenta")


def _privilegios_de(curp: str, codigo_cuenta: str) -> list[str]:
    """Devuelve la lista de nombres de operacion que tiene el cliente
    sobre la cuenta."""
    rows = (
        db.session.query(Privilegio)
        .join(
            ClienteCuentaPrivilegio,
            ClienteCuentaPrivilegio.id_privilegio == Privilegio.id_privilegio,
        )
        .filter(
            ClienteCuentaPrivilegio.curp == curp,
            ClienteCuentaPrivilegio.codigo_cuenta == codigo_cuenta,
        )
        .all()
    )
    return sorted(p.nombre_operacion for p in rows)


def _reemplazar_privilegios(
    curp: str,
    codigo_cuenta: str,
    nombres_operacion: list[str],
) -> tuple[list[str], list[str]]:
    """Borra los privilegios actuales del cliente sobre la cuenta y
    asigna los nuevos. Devuelve (ids_asignados, nombres_asignados)."""
    # Borra existentes
    db.session.query(ClienteCuentaPrivilegio).filter(
        ClienteCuentaPrivilegio.curp == curp,
        ClienteCuentaPrivilegio.codigo_cuenta == codigo_cuenta,
    ).delete(synchronize_session=False)

    # Valida que cada nombre existe en la tabla privilegio
    if not nombres_operacion:
        return [], []
    cats = (
        db.session.query(Privilegio)
        .filter(Privilegio.nombre_operacion.in_(nombres_operacion))
        .all()
    )
    encontrados = {p.nombre_operacion: p.id_privilegio for p in cats}
    for nombre in nombres_operacion:
        id_priv = encontrados.get(nombre)
        if id_priv is None:
            raise ValueError(f"Privilegio desconocido: {nombre}")
        db.session.add(ClienteCuentaPrivilegio(
            curp=curp,
            codigo_cuenta=codigo_cuenta,
            id_privilegio=id_priv,
        ))
    return list(encontrados.values()), sorted(encontrados.keys())


# GET /api/cuentas/<codigo>/usuarios
# Devuelve la lista de clientes que tienen acceso a la cuenta
# (con sus privilegios). Solo el dueno la ve con detalle de
# privilegios; el resto la ve con un resumen minimo.
@bp.route("/cuentas/<string:codigo>/usuarios", methods=["GET"])
@require_auth()
def listar_usuarios_cuenta(codigo: str):
    codigo_up = codigo.upper()
    curp_jwt = _current_curp()
    rol = _claims().get("rol", "cliente")

    # Cualquier usuario con acceso (o empleado) puede ver la lista
    if rol != "empleado":
        acceso = (
            db.session.query(ClienteCuentaPrivilegio)
            .filter(
                ClienteCuentaPrivilegio.curp == curp_jwt,
                ClienteCuentaPrivilegio.codigo_cuenta == codigo_up,
            )
            .first()
        )
        if acceso is None:
            return jsonify({"error": "No tiene acceso a esta cuenta"}), 403

    # JOIN cliente + cliente_cuenta_privilegio + privilegio
    rows = (
        db.session.query(Cliente, ClienteCuentaPrivilegio, Privilegio)
        .join(
            ClienteCuentaPrivilegio,
            ClienteCuentaPrivilegio.curp == Cliente.curp,
        )
        .join(
            Privilegio,
            Privilegio.id_privilegio == ClienteCuentaPrivilegio.id_privilegio,
        )
        .filter(ClienteCuentaPrivilegio.codigo_cuenta == codigo_up)
        .order_by(Cliente.apellido_paterno, Cliente.nombres, Privilegio.nombre_operacion)
        .all()
    )

    # Agrupar por curp
    agrupado: dict[str, dict] = {}
    for cli, _asig, priv in rows:
        d = agrupado.get(cli.curp)
        if d is None:
            d = {
                "curp": cli.curp,
                "nombre_completo": cli.nombre_completo,
                "email": cli.email,
                "activo": cli.activo,
                "fecha_asignacion": None,
                "es_dueno": False,
                "privilegios": [],
            }
            agrupado[cli.curp] = d
        d["privilegios"].append(priv.nombre_operacion)
        d["fecha_asignacion"] = (
            d["fecha_asignacion"] or _asig.fecha_asignacion
        )

    # Marcar dueno
    for curp, d in agrupado.items():
        d["es_dueno"] = "cerrar_cuenta" in d["privilegios"]
        d["privilegios"] = sorted(d["privilegios"])

    usuarios = sorted(
        agrupado.values(),
        key=lambda u: (not u["es_dueno"], u["nombre_completo"] or ""),
    )

    return jsonify({
        "codigo_cuenta": codigo_up,
        "total": len(usuarios),
        "usuarios": usuarios,
    }), 200


# POST /api/cuentas/<codigo>/usuarios
# Body: { "curp": "...", "privilegios": ["transferir", "pagar_domiciliacion"] }
# Solo el dueno (cerrar_cuenta) puede compartir.
@bp.route("/cuentas/<string:codigo>/usuarios", methods=["POST"])
@require_auth(roles=("cliente", "empleado"))
def compartir_cuenta(codigo: str):
    curp_jwt = _current_curp()
    codigo_up = codigo.upper()
    data = request.get_json(silent=True) or {}

    curp_nuevo = (data.get("curp") or "").strip().upper()
    privilegios_in = data.get("privilegios") or []
    if not curp_nuevo:
        return jsonify({"error": "Falta 'curp'"}), 400
    if not isinstance(privilegios_in, list) or not privilegios_in:
        return jsonify({
            "error": "'privilegios' debe ser una lista no vacia "
                     "(ej: ['consultar_saldo', 'transferir'])",
        }), 400

    # Verificar cuenta y que el caller tiene acceso de dueno
    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404

    rol = _claims().get("rol", "cliente")
    if rol != "empleado" and not _es_dueno(curp_jwt, codigo_up):
        return jsonify({
            "error": "Solo el dueno de la cuenta (privilegio "
                     "'cerrar_cuenta') puede compartirla",
        }), 403

    # No compartir consigo mismo (redundante; ya tiene acceso)
    if curp_nuevo == curp_jwt:
        return jsonify({
            "error": "Ya tienes acceso a esta cuenta",
        }), 400

    # Validar cliente destino
    cliente_destino = db.session.get(Cliente, curp_nuevo)
    if cliente_destino is None:
        return jsonify({
            "error": f"El cliente con CURP {curp_nuevo} no existe",
        }), 404
    if not cliente_destino.activo:
        return jsonify({
            "error": "El cliente destino esta desactivado",
        }), 400

    try:
        # Borrar privilegios previos del destino sobre esta cuenta
        # (idempotente: si ya tenia acceso, lo reemplazamos).
        _reemplazar_privilegios(
            curp_nuevo, codigo_up,
            [str(p).strip() for p in privilegios_in if str(p).strip()],
        )
        db.session.commit()
    except ValueError as ve:
        db.session.rollback()
        return jsonify({"error": str(ve)}), 400
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo compartir: {exc!s}"}), 500

    return jsonify({
        "mensaje": f"Acceso concedido a {curp_nuevo} sobre {codigo_up}",
        "codigo_cuenta": codigo_up,
        "curp": curp_nuevo,
        "nombre_completo": cliente_destino.nombre_completo,
        "privilegios": sorted({str(p).strip() for p in privilegios_in}),
    }), 201


# PATCH /api/cuentas/<codigo>/usuarios/<curp>
# Body: { "privilegios": [...] }
# Reemplaza el set de privilegios del usuario sobre la cuenta.
@bp.route("/cuentas/<string:codigo>/usuarios/<string:curp>", methods=["PATCH"])
@require_auth(roles=("cliente", "empleado"))
def editar_privilegios_usuario(codigo: str, curp: str):
    curp_jwt = _current_curp()
    rol = _claims().get("rol", "cliente")
    codigo_up = codigo.upper()
    curp_up = curp.strip().upper()

    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404

    if rol != "empleado" and not _es_dueno(curp_jwt, codigo_up):
        return jsonify({
            "error": "Solo el dueno de la cuenta puede modificar "
                     "los privilegios de otros usuarios",
        }), 403

    # El usuario destino debe existir y tener acceso
    existe_acceso = (
        db.session.query(ClienteCuentaPrivilegio)
        .filter(
            ClienteCuentaPrivilegio.curp == curp_up,
            ClienteCuentaPrivilegio.codigo_cuenta == codigo_up,
        )
        .first()
    )
    if existe_acceso is None:
        return jsonify({
            "error": f"El usuario {curp_up} no tiene acceso a esta cuenta",
        }), 404

    data = request.get_json(silent=True) or {}
    privilegios_in = data.get("privilegios")
    if privilegios_in is None or not isinstance(privilegios_in, list):
        return jsonify({"error": "Falta 'privilegios' (lista)"}), 400

    try:
        ids, nombres = _reemplazar_privilegios(
            curp_up, codigo_up,
            [str(p).strip() for p in privilegios_in if str(p).strip()],
        )
        db.session.commit()
    except ValueError as ve:
        db.session.rollback()
        return jsonify({"error": str(ve)}), 400
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo actualizar: {exc!s}"}), 500

    return jsonify({
        "mensaje": f"Privilegios de {curp_up} actualizados en {codigo_up}",
        "codigo_cuenta": codigo_up,
        "curp": curp_up,
        "privilegios": nombres,
    }), 200


# DELETE /api/cuentas/<codigo>/usuarios/<curp>
# Quita TODOS los privilegios del usuario sobre la cuenta.
# No permite auto-eliminarse (perderias tu propio acceso).
@bp.route("/cuentas/<string:codigo>/usuarios/<string:curp>", methods=["DELETE"])
@require_auth(roles=("cliente", "empleado"))
def quitar_acceso_usuario(codigo: str, curp: str):
    curp_jwt = _current_curp()
    rol = _claims().get("rol", "cliente")
    codigo_up = codigo.upper()
    curp_up = curp.strip().upper()

    if curp_up == curp_jwt:
        return jsonify({
            "error": "No puedes quitarte a ti mismo. Si quieres dejar "
                     "de tener acceso, contacta al dueno de la cuenta.",
        }), 400

    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404

    if rol != "empleado" and not _es_dueno(curp_jwt, codigo_up):
        return jsonify({
            "error": "Solo el dueno de la cuenta puede quitar accesos",
        }), 403

    rows_borrados = (
        db.session.query(ClienteCuentaPrivilegio)
        .filter(
            ClienteCuentaPrivilegio.curp == curp_up,
            ClienteCuentaPrivilegio.codigo_cuenta == codigo_up,
        )
        .delete(synchronize_session=False)
    )
    if rows_borrados == 0:
        return jsonify({
            "error": f"El usuario {curp_up} no tiene acceso a esta cuenta",
        }), 404

    try:
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo quitar acceso: {exc!s}"}), 500

    return jsonify({
        "mensaje": f"Acceso de {curp_up} eliminado de {codigo_up}",
        "codigo_cuenta": codigo_up,
        "curp": curp_up,
        "privilegios_eliminados": rows_borrados,
    }), 200


# PATCH /api/cuentas/<codigo>/saldo
# Body: { "monto": 1000.00, "operacion": "sumar" | "restar", "motivo": "..." }
# Solo empleados. Usado para asignar saldo de prueba a una cuenta.
# - sumar: cuenta.saldo += monto
# - restar: cuenta.saldo -= monto (si quedara < 0, se rechaza)
@bp.route("/cuentas/<string:codigo>/saldo", methods=["PATCH"])
@require_auth(roles=("empleado",))
def asignar_saldo_cuenta(codigo: str):
    data = request.get_json(silent=True) or {}

    operacion = (data.get("operacion") or "sumar").lower()
    if operacion not in ("sumar", "restar"):
        return jsonify({
            "error": "operacion debe ser 'sumar' o 'restar'",
        }), 400

    monto = _parse_decimal(data.get("monto"))
    if monto is None or monto <= Decimal("0"):
        return jsonify({"error": "monto debe ser mayor a 0"}), 400
    if monto > Decimal("1000000"):
        return jsonify({
            "error": "monto demasiado grande (max $1,000,000 por operacion)",
        }), 400

    codigo_up = codigo.upper()
    cuenta = db.session.get(CuentaCorriente, codigo_up)
    if cuenta is None:
        return jsonify({"error": "Cuenta no encontrada"}), 404

    saldo_actual = Decimal(str(cuenta.saldo or 0))
    motivo = (data.get("motivo") or "").strip() or None

    if operacion == "sumar":
        nuevo_saldo = saldo_actual + monto
        msg = f"Se sumaron ${float(monto):.2f} a {codigo_up}"
    else:
        if saldo_actual < monto:
            return jsonify({
                "error": f"Saldo insuficiente para restar ${float(monto):.2f}. "
                         f"Saldo actual: ${float(saldo_actual):.2f}",
                "saldo_actual": float(saldo_actual),
            }), 409
        nuevo_saldo = saldo_actual - monto
        msg = f"Se restaron ${float(monto):.2f} de {codigo_up}"

    try:
        from ..models.movimiento import (
            TIPO_ASIG_EMP_SUMA,
            TIPO_ASIG_EMP_RESTA,
        )
        tipo_mov = (
            TIPO_ASIG_EMP_SUMA if operacion == "sumar"
            else TIPO_ASIG_EMP_RESTA
        )
        cuenta.saldo = nuevo_saldo
        # curp_actor = empleado que hace la operacion
        curp_actor = _current_curp()
        concepto = f"{operacion.capitalize()} de ${float(monto):.2f}"
        if motivo:
            concepto += f" · motivo: {motivo}"
        db.session.add(Movimiento(
            codigo_cuenta=codigo_up,
            tipo=tipo_mov,
            monto=monto,
            curp_actor=curp_actor,
            concepto=concepto,
        ))
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": f"No se pudo actualizar saldo: {exc!s}"}), 500

    return jsonify({
        "mensaje": msg,
        "motivo": motivo,
        "cuenta": cuenta.to_dict(),
        "saldo_anterior": float(saldo_actual),
        "saldo_nuevo": float(nuevo_saldo),
    }), 200
