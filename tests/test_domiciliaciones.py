"""Tests para domiciliaciones."""


def test_listar_vacio(client):
    r = client.get("/api/domiciliaciones")
    assert r.status_code == 200
    assert r.get_json() == []


def test_crear_domiciliacion_exitosa(client, sucursal_factory, cuenta_factory):
    sucursal_factory()
    cuenta_factory()
    payload = {
        "codigo_cuenta": "CTA-0001",
        "servicio": "CFE",
        "monto_autorizado": 350.75,
        "dia_cobro": 10,
    }
    r = client.post("/api/domiciliaciones", json=payload)
    assert r.status_code == 201
    listado = client.get("/api/domiciliaciones").get_json()
    assert len(listado) == 1
    assert listado[0]["servicio"] == "CFE"
    assert listado[0]["monto_autorizado"] == 350.75
    assert listado[0]["dia_cobro"] == 10


def test_crear_domiciliacion_sin_monto(client, sucursal_factory, cuenta_factory):
    sucursal_factory()
    cuenta_factory()
    payload = {"codigo_cuenta": "CTA-0001", "servicio": "AGUA", "dia_cobro": 15}
    r = client.post("/api/domiciliaciones", json=payload)
    assert r.status_code == 201
    assert client.get("/api/domiciliaciones").get_json()[0]["monto_autorizado"] is None


def test_crear_domiciliacion_falta_servicio(client, sucursal_factory, cuenta_factory):
    sucursal_factory()
    cuenta_factory()
    payload = {"codigo_cuenta": "CTA-0001", "dia_cobro": 5}
    r = client.post("/api/domiciliaciones", json=payload)
    assert r.status_code == 400
    assert "servicio" in r.get_json()["error"]


def test_crear_domiciliacion_falta_dia_cobro(client, sucursal_factory, cuenta_factory):
    sucursal_factory()
    cuenta_factory()
    payload = {"codigo_cuenta": "CTA-0001", "servicio": "X"}
    r = client.post("/api/domiciliaciones", json=payload)
    assert r.status_code == 400
    assert "dia_cobro" in r.get_json()["error"]


def test_crear_domiciliacion_cuenta_inexistente_falla_fk(client):
    payload = {"codigo_cuenta": "NO-EXISTE", "servicio": "X", "dia_cobro": 1}
    r = client.post("/api/domiciliaciones", json=payload)
    assert r.status_code == 400
