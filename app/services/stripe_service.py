"""Capa de servicio para Stripe: aísla el SDK para poder mockearlo en tests."""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from typing import Any

import stripe


class StripePaymentError(Exception):
    """Error al procesar un pago con Stripe."""


@dataclass
class PagoResultado:
    receipt_url: str
    monto_centavos: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "receipt_url": self.receipt_url,
            "monto_centavos": self.monto_centavos,
        }


def cobrar_domiciliacion(
    monto: Decimal,
    descripcion: str,
    *,
    source: str = "tok_visa",
    currency: str = "mxn",
) -> PagoResultado:
    """
    Realiza un cargo a través de Stripe.

    Convierte el monto Decimal a centavos (int) como exige Stripe.
    Lanza StripePaymentError si el SDK rechaza la operación.
    """

    monto_centavos = int(Decimal(monto) * 100)
    try:
        cargo = stripe.Charge.create(
            amount=monto_centavos,
            currency=currency,
            source=source,
            description=descripcion,
        )
    except stripe.error.StripeError as exc:
        raise StripePaymentError(str(exc)) from exc

    return PagoResultado(
        receipt_url=cargo.receipt_url or "",
        monto_centavos=monto_centavos,
    )
