"""Tests del módulo de autenticación: register, login, me."""
from __future__ import annotations

import pytest

from app.models import Usuario


# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────
def _payload_cliente_valido() -> dict:
    return {
        "curp": "LOAJ900215HDFRPC08",   # 18 chars, formato real
        "nombres": "Juan",
        "apellido_paterno": "Lopez",
        "apellido_materno": "Aguilar",
        "email": "juan@example.com",
        "telefono": "5512345678",
        "password": "Password1",
    }


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ─────────────────────────────────────────────────────────────────────
# /register
# ─────────────────────────────────────────────────────────────────────
def test_register_exitoso_crea_cliente_y_usuario(client):
    r = client.post("/api/auth/register", json=_payload_cliente_valido())
    assert r.status_code == 201, f"Body: {r.get_json()} (status {r.status_code})"
    data = r.get_json()
    assert data["mensaje"] == "Cliente registrado con éxito"
    assert data["rol"] == "cliente"
    assert "access_token" in data and len(data["access_token"]) > 20
    assert data["cliente"]["curp"] == "LOAJ900215HDFRPC08"


def test_register_hash_no_se_devuelve_en_respuesta(client):
    r = client.post("/api/auth/register", json=_payload_cliente_valido())
    cuerpo = r.get_data(as_text=True)
    assert "password_hash" not in cuerpo
    assert "Password1" not in cuerpo


def test_register_falta_curp(client):
    p = _payload_cliente_valido()
    del p["curp"]
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400
    assert "curp" in r.get_json()["error"].lower()


def test_register_falta_password(client):
    p = _payload_cliente_valido()
    del p["password"]
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400


def test_register_password_debil_es_rechazado(client):
    p = _payload_cliente_valido()
    p["password"] = "abcdef"  # sin mayúscula ni dígito
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400
    assert "mayúscula" in r.get_json()["error"].lower() or "mayus" in r.get_json()["error"].lower()


def test_register_curp_invalido_es_rechazado(client):
    p = _payload_cliente_valido()
    p["curp"] = "no-es-curp"
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400
    assert "curp" in r.get_json()["error"].lower()


def test_register_email_invalido_es_rechazado(client):
    p = _payload_cliente_valido()
    p["email"] = "no-tiene-arroba"
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400


def test_register_curp_duplicado_retorna_409(client):
    """Registra dos veces con el MISMO CURP (cambia email) → 409."""
    payload = _payload_cliente_valido()
    assert client.post("/api/auth/register", json=payload).status_code == 201

    p2 = _payload_cliente_valido()
    p2["email"] = "otro@example.com"
    # mismo CURP que el primer registro:
    p2["curp"] = payload["curp"]
    r = client.post("/api/auth/register", json=p2)
    assert r.status_code == 409


def test_register_email_duplicado_retorna_409(client):
    assert (
        client.post("/api/auth/register", json=_payload_cliente_valido()).status_code
        == 201
    )

    p2 = _payload_cliente_valido()
    p2["curp"] = "OTRO000000HDFRRN77"
    r = client.post("/api/auth/register", json=p2)
    assert r.status_code == 409


def test_register_normaliza_email_a_minusculas(client, app):
    p = _payload_cliente_valido()
    p["email"] = "Juan@Example.COM"
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 201
    with app.app_context():
        u = Usuario.query.filter_by(email="juan@example.com").first()
    assert u is not None


# ─────────────────────────────────────────────────────────────────────
# /login
# ─────────────────────────────────────────────────────────────────────
def test_login_exitoso_devuelve_token_y_rol(client):
    client.post("/api/auth/register", json=_payload_cliente_valido())
    r = client.post(
        "/api/auth/login",
        json={"email": "juan@example.com", "password": "Password1"},
    )
    assert r.status_code == 200
    data = r.get_json()
    assert "access_token" in data
    assert data["rol"] == "cliente"
    assert data["perfil"]["curp"] == "LOAJ900215HDFRPC08"   # 18 chars


def test_login_password_incorrecto_retorna_401(client):
    client.post("/api/auth/register", json=_payload_cliente_valido())
    r = client.post(
        "/api/auth/login",
        json={"email": "juan@example.com", "password": "Equivocada1"},
    )
    assert r.status_code == 401
    assert "credenciales" in r.get_json()["error"].lower()


def test_login_email_inexistente_retorna_401(client):
    r = client.post(
        "/api/auth/login",
        json={"email": "no@existe.com", "password": "Cualquiera1"},
    )
    assert r.status_code == 401


def test_login_falta_campo_retorna_400(client):
    r = client.post("/api/auth/login", json={"email": "x@x.com"})
    assert r.status_code == 400


def test_login_no_revela_si_email_o_password_falla(client):
    """Mensaje idéntico para 'no existe' y 'password mal'."""
    r1 = client.post(
        "/api/auth/login",
        json={"email": "noexiste@x.com", "password": "Cual1quiera"},
    )
    client.post("/api/auth/register", json=_payload_cliente_valido())
    r2 = client.post(
        "/api/auth/login",
        json={"email": "juan@example.com", "password": "Equivocada1"},
    )
    assert r1.status_code == r2.status_code == 401
    assert r1.get_json() == r2.get_json()


# ─────────────────────────────────────────────────────────────────────
# /me
# ─────────────────────────────────────────────────────────────────────
def test_me_con_token_valido_devuelve_perfil(client):
    r = client.post("/api/auth/register", json=_payload_cliente_valido())
    token = r.get_json()["access_token"]

    r2 = client.get("/api/auth/me", headers=_auth_header(token))
    assert r2.status_code == 200
    data = r2.get_json()
    assert data["email"] == "juan@example.com"
    assert data["rol"] == "cliente"
    assert data["perfil"]["curp"] == "LOAJ900215HDFRPC08"   # 18 chars
    assert data["claims"]["rol"] == "cliente"


def test_me_sin_token_retorna_401(client):
    r = client.get("/api/auth/me")
    assert r.status_code == 401


def test_me_token_invalido_retorna_401(client):
    r = client.get(
        "/api/auth/me", headers=_auth_header("token-que-no-es-jwt")
    )
    assert r.status_code == 401


# ─────────────────────────────────────────────────────────────────────
# Hash / password
# ─────────────────────────────────────────────────────────────────────
def test_password_se_hashea_con_bcrypt_no_plano(client, app):
    """Comprueba que en BD NO se guarda la contraseña en texto plano."""
    from app.extensions import db

    client.post("/api/auth/register", json=_payload_cliente_valido())
    with app.app_context():
        u = (
            db.session.query(Usuario)
            .filter_by(email="juan@example.com")
            .first()
        )
    assert u is not None
    assert u.password_hash != "Password1"
    assert u.password_hash.startswith("$2b$")


def test_verificar_hash_acepta_password_correcto():
    from app.models import generar_hash, verificar_hash

    h = generar_hash("MiPass1")
    assert verificar_hash("MiPass1", h) is True


def test_verificar_hash_rechaza_password_incorrecto():
    from app.models import generar_hash, verificar_hash

    h = generar_hash("MiPass1")
    assert verificar_hash("otraCosa", h) is False


def test_verificar_hash_con_string_vacio_no_crashea():
    from app.models import verificar_hash

    assert verificar_hash("cualquiera", "") is False


# ─────────────────────────────────────────────────────────────────────
# Parametrizadas de regex (CURP, email, password, nombre)
# ─────────────────────────────────────────────────────────────────────
@pytest.mark.parametrize(
    "curp,email",
    [
        ("PEPJ800101HDFRRN01", "u1@x.com"),
        ("GODE850621HDFRYR02", "u2@x.com"),
        ("MARA850315HDFRYR03", "u3@x.com"),
    ],
)
def test_register_acepta_curps_validos(client, curp, email):
    p = _payload_cliente_valido()
    p["curp"] = curp
    p["email"] = email
    assert client.post("/api/auth/register", json=p).status_code == 201


@pytest.mark.parametrize(
    "curp",
    [
        "ABCD",                          # muy corto
        "loaj900215hdfabcd00",           # muy largo / minúsculas
        "1234567890ABCDEFGH",            # no empieza con letras
        "LOAJ9002151DFABCD00",           # 7° carácter no es letra
    ],
)
def test_register_rechaza_curps_invalidos(client, curp):
    p = _payload_cliente_valido()
    p["curp"] = curp
    p["email"] = "x@example.com"
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400


@pytest.mark.parametrize(
    "password,email,curp",
    [
        ("Password1", "pw1@x.com", "PWXX000000HDFRPC11"),
        ("Validad0",  "pw2@x.com", "PWXX000000HDFRPC22"),
        ("Mayus1Min", "pw3@x.com", "PWXX000000HDFRPC33"),
        ("ABCdef12",  "pw4@x.com", "PWXX000000HDFRPC44"),
    ],
)
def test_register_acepta_passwords_validos(client, password, email, curp):
    p = _payload_cliente_valido()
    p["password"] = password
    p["email"] = email
    p["curp"] = curp
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 201, f"{password} / {email} / {curp}: {r.get_json()}"


@pytest.mark.parametrize(
    "password,curp",
    [
        ("Corta12",     "PWXX000001HDFRPC55"),     # 7 caracteres (< 8)
        ("todnminab",   "PWXX000002HDFRPC66"),     # sin mayúscula
        ("TODOMAYUS",   "PWXX000003HDFRPC77"),     # sin minúscula ni dígito
        ("SinNumeroXy", "PWXX000004HDFRPC88"),     # sin dígito
    ],
)
def test_register_rechaza_passwords_invalidos(client, password, curp):
    p = _payload_cliente_valido()
    p["password"] = password
    p["email"] = f"{password}@x.com"
    p["curp"] = curp
    r = client.post("/api/auth/register", json=p)
    assert r.status_code == 400
