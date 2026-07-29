# Sistema Bancario — Proyecto Móviles y Flutter

Arquitectura completa del proyecto: **backend Flask + SQLAlchemy** y **frontend Flutter**.

---

## 🛠️ Requisitos Previos

* [Python 3.x](https://www.python.org/downloads/)
* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* Servidor MySQL local (Laragon / XAMPP / HeidiSQL) **o** cuenta en [Supabase](https://supabase.com) (PostgreSQL en la nube)
* Cuenta de prueba en [Stripe](https://stripe.com/es) con sus llaves API

---

## 🔐 Autenticación

El backend expone un único login compartido entre clientes y empleados. La
contraseña se hashea con **bcrypt** y se devuelve un **JWT** firmado con
`JWT_SECRET_KEY`.

### Tabla `usuario` (Supabase)

```sql
CREATE TABLE public.usuario (
    id_usuario       SERIAL PRIMARY KEY,
    email            VARCHAR(120) NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    rol              VARCHAR(20)  NOT NULL DEFAULT 'cliente'
                     CHECK (rol IN ('cliente', 'empleado')),
    curp             VARCHAR(18)  UNIQUE
                     REFERENCES public.cliente(curp)
                     ON DELETE CASCADE,
    activo           BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
```

El script completo está en [`supabase/01_create_usuario.sql`](supabase/01_create_usuario.sql).
**No crea ningún usuario.** Los empleados se dan de alta manualmente desde
Supabase; los clientes se registran por sí mismos desde el frontend.

### Endpoints

| Método | Ruta | Body | Devuelve |
|---|---|---|---|
| POST | `/api/auth/register` | `{curp, nombres, apellido_paterno, apellido_materno?, email, telefono?, password}` | `201` + token JWT |
| POST | `/api/auth/login` | `{email, password}` | `200` + token JWT + rol + perfil |
| GET  | `/api/auth/me` | (header `Authorization: Bearer <jwt>`) | `200` + perfil + claims |

### Validaciones backend (regex compartidas)

Las mismas regex viven en **`app/utils/validation.py`** y deberían usarse en
el cliente Flutter para validar antes de enviar:

| Campo | Regla |
|---|---|
| CURP | 18 chars: `^[A-Z]{4}\d{6}[HM][A-Z]{2}[BCDFGHJKLMNPQRSTVWXYZ]{3}[A-Z0-9]\d$` |
| Email | RFC 5322 simplificado |
| Contraseña | mínimo 8 chars, 1 minúscula + 1 mayúscula + 1 dígito |
| Teléfono | 10 dígitos (lada + número), opcional prefijo +52 |
| Nombre | letras Unicode con acentos y ñ |

---

## 🚀 Pasos para levantar el proyecto

### 1. Clonar

```bash
git clone <URL_DEL_REPOSITORIO>
cd proyectoMovilesYFlutter
```

### 2. Crear base de datos (solo la primera vez)

**Opción A — MySQL local**

1. Abre tu gestor favorito (Laragon / phpMyAdmin / HeidiSQL).
2. Crea una base de datos vacía llamada `banco_santander`.
3. Importa el archivo `banco_santander.sql` (solicítalo al administrador; no está en el repo por seguridad).

**Opción B — Supabase**

1. Crea un proyecto nuevo en [supabase.com](https://supabase.com).
2. Ve a **Project Settings → Database → Connection string → URI**.
3. Copia la cadena del puerto **5432** (NO el 6543 pooler — el pooler no permite DDL).
4. Ejecuta el SQL del paso 2 en el SQL Editor de Supabase.

### 3. Configurar el Backend

Crea el entorno virtual e instala dependencias:

```bash
python -m venv venv
# Windows:
venv\Scripts\activate
# Mac / Linux:
source venv/bin/activate

pip install -r requirements.txt
```

> ⚠️ Si vas a usar **PostgreSQL / Supabase** y tu Python es ≤ 3.12, instala también:
> `pip install psycopg2-binary`. Para Python 3.13/3.14 instala primero PostgreSQL local (necesitas `pg_config` en el PATH) o un wheel precompilado.

### 4. Variables de entorno

Copia `.env.example` → `.env` y rellena los valores:

```dotenv
# Opción A — MySQL local
DATABASE_URL=mysql+pymysql://root:TU_PASSWORD@localhost/banco_santander

# Opción B — Supabase (¡usa el 5432 directo, NO el pooler 6543!)
DATABASE_URL=postgresql://postgres.gimombupqxvybkzv:TU_PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres

STRIPE_PUBLIC_KEY=pk_test_xxxx
STRIPE_SECRET_KEY=sk_test_xxxx
FLASK_ENV=development
```

### 5. Arrancar el backend

```bash
python app.py
```

Levanta en `http://127.0.0.1:5000`. Endpoints de health-check:

* `GET /` → mensaje de bienvenida
* `GET /test-db` → prueba la conexión a la BD

### 6. Arrancar el frontend Flutter

En otra terminal:

```bash
cd frontend
flutter pub get
flutter run            # necesita emulador o dispositivo conectado
```

---

## 🧪 Tests del Backend

Suite completa con **pytest** + SQLite en memoria:

```bash
# Solo ejecutar
pytest

# Verboso
pytest -v

# Con reporte de cobertura
pytest --cov=app --cov-report=term-missing

# Un archivo concreto
pytest tests/test_pagos.py -v
```

Los tests usan **mocks** para Stripe, así que **no necesitas claves reales** ni conexión de red. Cobertura actual: **93 %**.

---

## 📂 Estructura del proyecto

```
proyectoMovilesYFlutter/
├── app.py                    # entrypoint (≤10 líneas)
├── app/                      # paquete del backend (factory + blueprints)
│   ├── __init__.py           # create_app() + health-checks
│   ├── config.py             # Config / Dev / Testing / Prod
│   ├── extensions.py         # SQLAlchemy instance
│   ├── models/               # ORM: Cliente, Sucursal, CuentaCorriente,
│   │                         # Privilegio, Domiciliacion, Prestamo
│   ├── routes/               # Blueprints: clientes, sucursales, cuentas,
│   │                         # privilegios, domiciliaciones, prestamos, pagos
│   └── services/             # Capa de servicios: stripe_service (aislado para mockear)
├── tests/                    # 49 tests: CRUD + lógica + Stripe mockeado
│   ├── conftest.py           # fixtures (app, client, factories)
│   └── test_*.py             # uno por blueprint
├── pytest.ini
├── requirements.txt
├── .env.example
└── frontend/                 # proyecto Flutter
```

### Endpoints disponibles

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST / GET | `/api/clientes` | Crear / listar clientes |
| POST / GET | `/api/sucursales` | Crear / listar sucursales |
| POST / GET | `/api/cuentas` | Crear / listar cuentas corrientes |
| POST / GET | `/api/privilegios` | Crear / listar privilegios |
| POST | `/api/asignar-privilegios` | Asignar privilegio a cliente↔cuenta |
| POST / GET | `/api/domiciliaciones` | Crear / listar domiciliaciones |
| POST / GET | `/api/prestamos` | Crear / listar préstamos |
| POST | `/api/pagar-domiciliacion` | Cobra con Stripe y descuenta saldo |
