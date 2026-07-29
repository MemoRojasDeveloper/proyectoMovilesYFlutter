"""Tests para el blueprint de clientes."""


def test_listar_clientes_vacio(client):
    r = client.get("/api/clientes")
    assert r.status_code == 200
    assert r.get_json() == []


def test_crear_cliente_exitoso(client):
    payload = {
        "curp": "LOAJ900215HDFABCD00",
        "nombres": "Juan",
        "apellido_paterno": "Lopez",
        "apellido_materno": "Aguilar",
        "email": "juan@example.com",
        "telefono": "5551234567",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 201
    assert r.get_json() == {"mensaje": "Cliente registrado con éxito"}

    listado = client.get("/api/clientes").get_json()
    assert len(listado) == 1
    assert listado[0]["curp"] == "LOAJ900215HDFABCD00"
    assert listado[0]["email"] == "juan@example.com"


def test_crear_cliente_solo_campos_obligatorios(client):
    payload = {
        "curp": "PEPJ800101HDFRRN05",
        "nombres": "Pedro",
        "apellido_paterno": "Perez",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 201


def test_crear_cliente_falta_curp(client):
    payload = {"nombres": "X", "apellido_paterno": "Y"}
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 400
    assert "curp" in r.get_json()["error"]


def test_crear_cliente_falta_nombres(client):
    payload = {"curp": "ABCD123456HDFXXX00", "apellido_paterno": "Y"}
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 400
    assert "nombres" in r.get_json()["error"]


def test_crear_cliente_falta_apellido_paterno(client):
    payload = {"curp": "ABCD123456HDFXXX00", "nombres": "Y"}
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 400
    assert "apellido_paterno" in r.get_json()["error"]


def test_crear_cliente_curp_duplicada(client, cliente_factory):
    cliente_factory(curp="DUPL000000HDFXXX00")
    payload = {
        "curp": "DUPL000000HDFXXX00",
        "nombres": "Otro",
        "apellido_paterno": "X",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 400


def test_crear_cliente_sin_body_json(client):
    r = client.post("/api/clientes", data="no-json", content_type="text/plain")
    assert r.status_code == 400


def test_email_duplicado_es_rechazado(client, cliente_factory):
    cliente_factory(curp="AAA000000HDFXXX00", email="dupo@x.com")
    payload = {
        "curp": "BBB000000HDFXXX00",
        "nombres": "Otro",
        "apellido_paterno": "Distinto",
        "email": "dupo@x.com",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 400
