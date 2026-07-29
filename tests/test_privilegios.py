"""Tests para privilegios y asignación cliente↔cuenta↔privilegio."""


def test_listar_privilegios_vacio(client):
    r = client.get("/api/privilegios")
    assert r.status_code == 200
    assert r.get_json() == []


def test_crear_privilegio_exitoso(client):
    payload = {"nombre_operacion": "RETIRAR", "descripcion": "Retirar efectivo"}
    r = client.post("/api/privilegios", json=payload)
    assert r.status_code == 201
    listado = client.get("/api/privilegios").get_json()
    assert listado[0]["id_privilegio"] == 1
    assert listado[0]["nombre_operacion"] == "RETIRAR"


def test_crear_privilegio_sin_descripcion(client):
    r = client.post("/api/privilegios", json={"nombre_operacion": "DEPOSITAR"})
    assert r.status_code == 201


def test_crear_privilegio_falta_nombre_operacion(client):
    r = client.post("/api/privilegios", json={"descripcion": "x"})
    assert r.status_code == 400
    assert "nombre_operacion" in r.get_json()["error"]


def test_crear_privilegio_nombre_duplicado(client):
    r1 = client.post("/api/privilegios", json={"nombre_operacion": "X"})
    r2 = client.post("/api/privilegios", json={"nombre_operacion": "X"})
    assert r1.status_code == 201
    assert r2.status_code == 400


def test_asignar_privilegio_exitoso(
    client, cliente_factory, sucursal_factory, cuenta_factory, privilegio_factory
):
    cliente_factory(curp="ABCD000000HDFXXX00")
    sucursal_factory()
    cuenta_factory()
    id_priv = privilegio_factory(nombre_operacion="RETIRAR")

    r = client.post(
        "/api/asignar-privilegios",
        json={
            "curp": "ABCD000000HDFXXX00",
            "codigo_cuenta": "CTA-0001",
            "id_privilegio": id_priv,
        },
    )
    assert r.status_code == 201


def test_asignar_privilegio_campos_faltantes(client):
    r = client.post(
        "/api/asignar-privilegios",
        json={"curp": "X"},
    )
    assert r.status_code == 400


def test_asignar_privilegio_combinacion_duplicada(
    client, cliente_factory, sucursal_factory, cuenta_factory, privilegio_factory
):
    """La PK compuesta (curp, codigo_cuenta, id_privilegio) no debe repetirse."""
    cliente_factory(curp="ABCD000000HDFXXX00")
    sucursal_factory()
    cuenta_factory()
    id_priv = privilegio_factory()

    payload = {
        "curp": "ABCD000000HDFXXX00",
        "codigo_cuenta": "CTA-0001",
        "id_privilegio": id_priv,
    }
    assert client.post("/api/asignar-privilegios", json=payload).status_code == 201
    assert client.post("/api/asignar-privilegios", json=payload).status_code == 400
