"""Tests para préstamos."""


def test_listar_vacio(client):
    r = client.get("/api/prestamos")
    assert r.status_code == 200
    assert r.get_json() == []


def test_crear_prestamo_exitoso(client, cliente_factory):
    cliente_factory(curp="LOAJ900215HDFABCD00")
    payload = {
        "curp": "LOAJ900215HDFABCD00",
        "monto_otorgado": 75000,
        "tasa_interes": 18.5,
        "plazo_meses": 36,
        "fecha_aprobacion": "2026-03-01",
    }
    r = client.post("/api/prestamos", json=payload)
    assert r.status_code == 201
    listado = client.get("/api/prestamos").get_json()
    assert len(listado) == 1
    assert listado[0]["curp"] == "LOAJ900215HDFABCD00"
    assert listado[0]["monto_otorgado"] == 75000
    assert listado[0]["tasa_interes"] == 18.5


def test_crear_prestamo_falta_curp(client):
    payload = {
        "monto_otorgado": 1,
        "tasa_interes": 1,
        "plazo_meses": 1,
        "fecha_aprobacion": "2026-01-01",
    }
    r = client.post("/api/prestamos", json=payload)
    assert r.status_code == 400


def test_crear_prestamo_cliente_inexistente_falla_fk(client):
    payload = {
        "curp": "NOEXISTE0000000000",
        "monto_otorgado": 1,
        "tasa_interes": 1,
        "plazo_meses": 1,
        "fecha_aprobacion": "2026-01-01",
    }
    r = client.post("/api/prestamos", json=payload)
    assert r.status_code == 400


def test_crear_prestamo_fecha_invalida(client, cliente_factory):
    cliente_factory()
    payload = {
        "curp": "LOAJ900215HDFABCD00",
        "monto_otorgado": 1000,
        "tasa_interes": 10,
        "plazo_meses": 12,
        "fecha_aprobacion": "ayer",
    }
    r = client.post("/api/prestamos", json=payload)
    assert r.status_code == 400
