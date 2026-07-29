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


def test_crear_cliente_rol_default_es_cliente(client):
    payload = {
        "curp": "PEPJ800101HDFRPC01",
        "nombres": "X",
        "apellido_paterno": "Y",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 201
    listado = client.get("/api/clientes").get_json()
    assert listado[0]["rol"] == "cliente"


def test_crear_cliente_rol_empleado(client):
    payload = {
        "curp": "ADMN000000HDFAB001",
        "nombres": "Patricia",
        "apellido_paterno": "Hernandez",
        "email": "admin@banco.local",
        "rol": "empleado",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 201
    listado = client.get("/api/clientes?rol=empleado").get_json()
    assert len(listado) == 1
    assert listado[0]["rol"] == "empleado"


def test_crear_cliente_rol_invalido_rechazado(client):
    payload = {
        "curp": "INVLD000000HDFAB001",
        "nombres": "X",
        "apellido_paterno": "Y",
        "rol": "superadmin",
    }
    r = client.post("/api/clientes", json=payload)
    assert r.status_code == 400
    assert "Rol inválido" in r.get_json()["error"]


def test_listar_clientes_filtra_por_rol(client, app):
    """Crea 2 clientes (uno admin vía endpoint, otro via factory) y filtra."""
    # Cliente normal
    r1 = client.post("/api/clientes", json={
        "curp": "CLI0000000HDFAB001",
        "nombres": "Cliente",
        "apellido_paterno": "Banco",
        "email": "c@x.com",
    })
    assert r1.status_code == 201

    # Empleado (admin)
    r2 = client.post("/api/clientes", json={
        "curp": "EMP0000000HDFAB001",
        "nombres": "Admin",
        "apellido_paterno": "Banco",
        "email": "admin@banco.local",
        "rol": "empleado",
    })
    assert r2.status_code == 201

    # Filtro solo empleados
    listado = client.get("/api/clientes?rol=empleado").get_json()
    assert len(listado) == 1
    assert listado[0]["curp"] == "EMP0000000HDFAB001"
    assert listado[0]["rol"] == "empleado"

    # Sin filtro, ambos
    todos = client.get("/api/clientes").get_json()
    assert len(todos) == 2


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
