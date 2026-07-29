"""Tests para el endpoint de pagos con Stripe (mockeado)."""
from decimal import Decimal

import pytest

from app.extensions import db
from app.models import CuentaCorriente
from app.services import StripePaymentError


def _consultar_saldo(app, codigo_cuenta: str) -> Decimal:
    with app.app_context():
        c = db.session.get(CuentaCorriente, codigo_cuenta)
        return c.saldo



# Tests

def test_pago_exitoso_descuenta_saldo(
    client,
    app,
    mocker,
    sucursal_factory,
    cuenta_factory,
    domiciliacion_factory,
):
    sucursal_factory(codigo="SUC-001")
    cuenta_factory(codigo="CTA-0001", codigo_sucursal="SUC-001", saldo="500.00")
    id_dom = domiciliacion_factory(
        codigo_cuenta="CTA-0001", servicio="CFE", monto="150.00"
    )

    mock_cobrar = mocker.patch(
        "app.routes.pagos.cobrar_domiciliacion",
        return_value=mocker.MagicMock(
            receipt_url="https://stripe.test/recibo/123", monto_centavos=15000
        ),
    )

    r = client.post("/api/pagar-domiciliacion", json={"id_domiciliacion": id_dom})

    assert r.status_code == 200
    data = r.get_json()
    assert "Pago procesado exitosamente" in data["mensaje"]
    assert data["recibo_stripe"] == "https://stripe.test/recibo/123"
    assert data["nuevo_saldo_cuenta"] == 350.00

    mock_cobrar.assert_called_once()
    kwargs = mock_cobrar.call_args.kwargs
    assert kwargs["monto"] == Decimal("150.00")
    assert "CFE" in kwargs["descripcion"]
    assert "CTA-0001" in kwargs["descripcion"]


def test_pago_domiciliacion_inexistente_retorna_404(client):
    r = client.post("/api/pagar-domiciliacion", json={"id_domiciliacion": 999})
    assert r.status_code == 404
    assert "no encontrada" in r.get_json()["error"]


def test_pago_sin_id_domiciliacion_retorna_400(client):
    r = client.post("/api/pagar-domiciliacion", json={})
    assert r.status_code == 400
    assert "id_domiciliacion" in r.get_json()["error"]


def test_pago_saldo_insuficiente_no_llama_stripe(
    client,
    app,
    mocker,
    sucursal_factory,
    cuenta_factory,
    domiciliacion_factory,
):
    """Si no alcanza el saldo, NO se debe llamar a Stripe."""
    sucursal_factory(codigo="SUC-001")
    cuenta_factory(codigo="CTA-0001", codigo_sucursal="SUC-001", saldo="100.00")
    id_dom = domiciliacion_factory(
        codigo_cuenta="CTA-0001", servicio="CFE", monto="500.00"
    )

    mock_cobrar = mocker.patch("app.routes.pagos.cobrar_domiciliacion")

    r = client.post("/api/pagar-domiciliacion", json={"id_domiciliacion": id_dom})

    assert r.status_code == 400
    assert "Saldo insuficiente" in r.get_json()["error"]
    mock_cobrar.assert_not_called()
    assert _consultar_saldo(app, "CTA-0001") == Decimal("100.00")


def test_pago_stripe_falla_no_descuenta_saldo(
    client,
    app,
    mocker,
    sucursal_factory,
    cuenta_factory,
    domiciliacion_factory,
):
    sucursal_factory(codigo="SUC-001")
    cuenta_factory(codigo="CTA-0001", codigo_sucursal="SUC-001", saldo="500.00")
    id_dom = domiciliacion_factory(
        codigo_cuenta="CTA-0001", servicio="CFE", monto="150.00"
    )

    mocker.patch(
        "app.routes.pagos.cobrar_domiciliacion",
        side_effect=StripePaymentError("Tarjeta rechazada"),
    )

    r = client.post("/api/pagar-domiciliacion", json={"id_domiciliacion": id_dom})

    assert r.status_code == 400
    assert "Tarjeta rechazada" in r.get_json()["error"]
    assert _consultar_saldo(app, "CTA-0001") == Decimal("500.00")


def test_pago_conversion_monto_a_centavos(mocker):
    """Verifica la conversión Decimal → centavos que internamente hace Stripe."""
    from decimal import Decimal as D

    from app.services import cobrar_domiciliacion

    mock_charge = mocker.patch("app.services.stripe_service.stripe.Charge.create")
    mock_charge.return_value = mocker.MagicMock(receipt_url="https://stripe.test/r")

    resultado = cobrar_domiciliacion(monto=D("150.00"), descripcion="test")
    assert resultado.monto_centavos == 15000
    assert resultado.receipt_url == "https://stripe.test/r"

    # Pruebas adicionales de redondeo seguro
    assert int(D("150.00") * 100) == 15000
    assert int(D("0.99") * 100) == 99
    assert int(D("1234.56") * 100) == 123456


@pytest.mark.parametrize(
    "saldo,monto,esperado,cta",
    [
        ("500.00", "150.00", 350.00, "CTA-0001"),
        ("100.00", "100.00", 0.00, "CTA-0002"),
        ("9999.99", "0.01", 9999.98, "CTA-0003"),
    ],
)
def test_pago_multiples_montos(
    client,
    app,
    mocker,
    sucursal_factory,
    cuenta_factory,
    domiciliacion_factory,
    saldo,
    monto,
    esperado,
    cta,
):
    sucursal_factory(codigo="SUC-001")
    cuenta_factory(codigo=cta, codigo_sucursal="SUC-001", saldo=saldo)
    id_dom = domiciliacion_factory(codigo_cuenta=cta, monto=monto)

    mocker.patch(
        "app.routes.pagos.cobrar_domiciliacion",
        return_value=mocker.MagicMock(
            receipt_url="https://stripe.test/r",
            monto_centavos=int(Decimal(monto) * 100),
        ),
    )

    r = client.post("/api/pagar-domiciliacion", json={"id_domiciliacion": id_dom})
    assert r.status_code == 200
    assert r.get_json()["nuevo_saldo_cuenta"] == esperado
