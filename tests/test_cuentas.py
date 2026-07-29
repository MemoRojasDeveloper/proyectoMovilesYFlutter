"""Tests para el blueprint de cuentas corrientes."""


def test_listar_vacio(client):
    r = client.get("/api/cuentas")
    assert r.status_code == 200
    assert r.get_json() == []


def test_crear_cuenta_exitosa(client, sucursal_factory):
    sucursal_factory()
    payload = {
        "codigo_cuenta": "CTA-0001",
        "codigo_sucursal": "SUC-001",
        "saldo": 1500.50,
        "fecha_apertura": "2026-02-01",
    }
    r = client.post("/api/cuentas", json=payload)
    assert r.status_code == 201

    listado = client.get("/api/cuentas").get_json()
    assert len(listado) == 1
    assert listado[0]["saldo"] == 1500.50
    assert listado[0]["fecha_apertura"] == "2026-02-01"


def test_crear_cuenta_saldo_default_cero(client, sucursal_factory):
    sucursal_factory()
    payload = {
        "codigo_cuenta": "CTA-0002",
        "codigo_sucursal": "SUC-001",
        "fecha_apertura": "2026-02-01",
    }
    r = client.post("/api/cuentas", json=payload)
    assert r.status_code == 201
    assert client.get("/api/cuentas").get_json()[0]["saldo"] == 0.00


def test_crear_cuenta_falta_fecha_apertura(client, sucursal_factory):
    sucursal_factory()
    payload = {"codigo_cuenta": "CTA-0099", "codigo_sucursal": "SUC-001"}
    r = client.post("/api/cuentas", json=payload)
    assert r.status_code == 400
    assert "fecha_apertura" in r.get_json()["error"]


def test_crear_cuenta_fecha_invalida(client, sucursal_factory):
    sucursal_factory()
    payload = {
        "codigo_cuenta": "CTA-0099",
        "codigo_sucursal": "SUC-001",
        "fecha_apertura": "no-es-fecha",
    }
    r = client.post("/api/cuentas", json=payload)
    assert r.status_code == 400
    assert "fecha_apertura" in r.get_json()["error"]


def test_crear_cuenta_sucursal_inexistente_falla_por_fk(client):
    payload = {
        "codigo_cuenta": "CTA-FK",
        "codigo_sucursal": "NO-EXISTE",
        "fecha_apertura": "2026-02-01",
    }
    r = client.post("/api/cuentas", json=payload)
    assert r.status_code == 400
