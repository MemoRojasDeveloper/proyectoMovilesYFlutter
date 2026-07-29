"""Tests para el blueprint de sucursales."""


def test_listar_vacio(client):
    r = client.get("/api/sucursales")
    assert r.status_code == 200
    assert r.get_json() == []


def test_crear_sucursal_exitosa(client):
    payload = {
        "codigo_sucursal": "SUC-001",
        "nombre_sucursal": "Centro",
        "direccion": "Av. Reforma 100",
    }
    r = client.post("/api/sucursales", json=payload)
    assert r.status_code == 201

    listado = client.get("/api/sucursales").get_json()
    assert len(listado) == 1
    assert listado[0]["codigo_sucursal"] == "SUC-001"
    assert listado[0]["direccion"] == "Av. Reforma 100"


def test_crear_sucursal_sin_direccion(client):
    payload = {"codigo_sucursal": "SUC-002", "nombre_sucursal": "Norte"}
    r = client.post("/api/sucursales", json=payload)
    assert r.status_code == 201


def test_crear_sucursal_falta_codigo(client):
    payload = {"nombre_sucursal": "Sur"}
    r = client.post("/api/sucursales", json=payload)
    assert r.status_code == 400
    assert "codigo_sucursal" in r.get_json()["error"]


def test_crear_sucursal_falta_nombre(client):
    payload = {"codigo_sucursal": "SUC-003"}
    r = client.post("/api/sucursales", json=payload)
    assert r.status_code == 400
    assert "nombre_sucursal" in r.get_json()["error"]


def test_crear_sucursal_codigo_duplicado(client):
    payload1 = {"codigo_sucursal": "SUC-100", "nombre_sucursal": "A"}
    payload2 = {"codigo_sucursal": "SUC-100", "nombre_sucursal": "B"}
    assert client.post("/api/sucursales", json=payload1).status_code == 201
    assert client.post("/api/sucursales", json=payload2).status_code == 400
