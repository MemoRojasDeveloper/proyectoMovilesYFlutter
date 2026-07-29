"""Endpoints de pago con Stripe."""
from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import CuentaCorriente, Domiciliacion
from ..services import StripePaymentError, cobrar_domiciliacion

bp = Blueprint("pagos", __name__)


@bp.route("/pagar-domiciliacion", methods=["POST"])
def pagar_domiciliacion():
    try:
        data = request.get_json(silent=True) or {}
        if "id_domiciliacion" not in data:
            return jsonify({"error": "Campo faltante: id_domiciliacion"}), 400

        id_dom = data["id_domiciliacion"]
        domiciliacion = db.session.get(Domiciliacion, id_dom)
        if not domiciliacion:
            return jsonify({"error": "Domiciliación no encontrada"}), 404

        cuenta = db.session.get(CuentaCorriente, domiciliacion.codigo_cuenta)
        if not cuenta:
            return jsonify({"error": "Cuenta asociada no encontrada"}), 404

        monto = domiciliacion.monto_autorizado
        if monto is None or cuenta.saldo is None or cuenta.saldo < monto:
            return jsonify({"error": "Saldo insuficiente en la cuenta"}), 400

        resultado = cobrar_domiciliacion(
            monto=monto,
            descripcion=(
                f"Pago de domiciliación: {domiciliacion.servicio} "
                f"(Cuenta {cuenta.codigo_cuenta})"
            ),
        )

        # Solo si Stripe aprueba, descontamos el saldo
        cuenta.saldo = cuenta.saldo - monto
        db.session.commit()

        return (
            jsonify(
                {
                    "mensaje": "Pago procesado exitosamente con Stripe y saldo actualizado",
                    "recibo_stripe": resultado.receipt_url,
                    "nuevo_saldo_cuenta": float(cuenta.saldo),
                }
            ),
            200,
        )

    except StripePaymentError as exc:
        return jsonify({"error": f"Error de pago con Stripe: {exc}"}), 400
    except Exception as exc:
        db.session.rollback()
        return jsonify({"error": str(exc)}), 500
