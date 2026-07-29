# Sistema Bancario — Proyecto Móviles y Flutter

Backend **Flask + SQLAlchemy + JWT** y frontend **Flutter**.

---

## 📑 Tabla de cambios recientes

> Estas son las últimas alteraciones al proyecto. Si vienes de una versión
> anterior, aquí está todo lo que cambió.

| Antes | Ahora |
|---|---|
| Coverage **93 %**, **49 tests** | Coverage **91 %**, **86 tests** (37 nuevos de auth) |
| `app/models/` con 6 archivos | 7 archivos — se añadió **`usuario.py`** |
| `app/routes/` sin auth | 8 Blueprints — se añadió **`auth.py`** con register/login/me |
| Sin login en backend | **JWT + bcrypt** con decorador `@require_auth(roles=...)` |
| Sin validación de formularios | **`app/utils/validation.py`** con regex compartidas (CURP, email, password, teléfono, nombre) |
| `psycopg2-binary` listado en requirements para todos los Pythons | Restringido a `python_version < "3.13"`; en 3.13/3.14 se omite |
| Único `.sql` cargado a mano | Carpeta **`supabase/`** con migrations versionados (DDL puro, sin seeds) |
| `.gitignore` básico (venv + .env) | Cobertura completa de Flutter, builds nativos, IDEs, OS y reportes |
| La rama del enunciado indicaba login con empleados pero no se había implementado | Decisión registrada: empleados se registran manualmente en Supabase (no por la API); clientes vía `POST /api/auth/register` |

---

## 🛠️ Requisitos Previos

* Python 3.x
* Flutter SDK
* MySQL local (Laragon / XAMPP / HeidiSQL) **o** cuenta en [Supabase](https://supabase.com) (PostgreSQL)
* Cuenta de prueba en [Stripe](https://stripe.com/es) con llaves API

---

## 🚀 Pasos para levantar el proyecto

### 1. Clonar

```bash
git clone <URL_DEL_REPOSITORIO>
cd proyectoMovilesYFlutter
```

### 2. Crear la base de datos

**Opción A — MySQL local**

1. Crea una base de datos vacía llamada `banco_santander`.
2. Importa el dump (`banco_santander.sql`) — solicítalo al administrador; **no se sube al repo por seguridad**.

> Antes se mencionaba "importar el SQL desde el repositorio". Ahora no se incluye: `.gitignore` filtra `*.sql` salvo los de `supabase/`.

**Opción B — Supabase (recomendado)**

1. Crea un proyecto nuevo en supabase.com.
2. Copia la cadena **URI puerto 5432** desde *Project Settings → Database → Connection string*. **No uses el pooler 6543** — no permite DDL.
3. Ejecuta los migrations en orden en el SQL Editor de Supabase:
   - [`supabase/01_create_usuario.sql`](supabase/01_create_usuario.sql) — crea la tabla `usuario`.

### 🗂️ Cómo correr las migraciones

Los migrations son archivos `.sql` en [`supabase/`](supabase/). Cada uno crea o modifica tablas
y se ejecuta **una vez por entorno** (local, staging, producción).

#### 1. Abre el SQL Editor

En el panel de Supabase: **SQL Editor → New query**.

#### 2. Carga el archivo

Opción A — pegar manualmente:

1. Abre el archivo en tu editor (`supabase/01_create_usuario.sql`).
2. Copia todo su contenido.
3. Pega en el SQL Editor de Supabase.

Opción B — desde la terminal si tienes `psql` instalado:

```bash
psql "postgresql://postgres:TU_PASSWORD@db.TU_PROYECTO.supabase.co:5432/postgres" \
  -f supabase/01_create_usuario.sql
```

#### 3. Ejecuta

Click en **Run** (o `Ctrl+Enter`). Verás el resultado de cada sentencia.

#### 4. Verifica

```sql
-- Debe devolver 0 filas hasta que alguien se registre:
SELECT id_usuario, email, rol, activo FROM public.usuario;

-- Debe existir la tabla con sus constraints:
SELECT conname, contype FROM pg_constraint
WHERE conrelid = 'public.usuario'::regclass;
```

Deberías ver:

- `usuario_pkey` (PRIMARY KEY)
- `usuario_email_key` (UNIQUE sobre `email`)
- `usuario_curp_key` (UNIQUE sobre `curp`)
- `usuario_rol_check` (CHECK sobre `rol`)
- `usuario_curp_fk` (FOREIGN KEY a `cliente(curp)`)

#### Orden de migrations

Por ahora solo hay una, pero el prefijo numérico (`01_`) indica el orden:

```
supabase/
└── 01_create_usuario.sql    # ← ejecuta primero
├── 02_xxx.sql               # ← siguiente (cuando exista)
└── ...
```

> Antes no había convención de migrations: el SQL del banco lo pedías al admin.
> Ahora `supabase/01_*` es la fuente de verdad del esquema y vive en el repo.
> Los dumps de datos (`banco_santander.sql`) **siguen fuera** del repo por seguridad.

#### Si algo falla al correrlas

| Síntoma | Causa | Solución |
|---|---|---|
| `permission denied for schema public` | tu usuario no tiene privilegios DDL | usa el rol `postgres` (no el `pooler`) en el puerto 5432 |
| `relation "cliente" does not exist` | corriste 01 antes de tener la tabla `cliente` | importa primero las tablas base (`banco_santander.sql`) |
| `syntax error` al pegar | se cortó el script a la mitad | pega el archivo completo, no por bloques |
| `psycopg2-binary` no instala | Python 3.13/3.14 sin wheels | instala PostgreSQL local primero para tener `pg_config` en el PATH |

> Antes había un único script SQL genérico. Ahora es solo el DDL (sin insert del admin), porque los empleados los das de alta tú manualmente desde Supabase.

### 3. Backend

```bash
python -m venv venv

# Windows:
venv\Scripts\activate
# Mac / Linux:
source venv/bin/activate

pip install -r requirements.txt
```

> Antes había que instalar `psycopg2-binary` por separado para usar Postgres.
> Ahora `requirements.txt` lo incluye **solo si tu Python es < 3.13** (vía marcador PEP 508).
> En Python 3.13/3.14 instala primero PostgreSQL local para tener `pg_config` en el PATH.

### 4. Variables de entorno

Copia `.env.example` → `.env`:

```dotenv
# MySQL local
DATABASE_URL=mysql+pymysql://root:TU_PASSWORD@localhost/banco_santander

# o Supabase directo (5432, NO el pooler 6543)
DATABASE_URL=postgresql://postgres:TU_PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres

STRIPE_PUBLIC_KEY=pk_test_xxxx
STRIPE_SECRET_KEY=sk_test_xxxx
FLASK_ENV=development

# Genera uno:  python -c "import secrets; print(secrets.token_urlsafe(48))"
JWT_SECRET_KEY=cambia-en-produccion
```

> Antes no había `JWT_SECRET_KEY` (no existía login). Ahora es obligatorio firmando los tokens.

### 5. Arrancar backend

```bash
python app.py
```

Levanta en `http://127.0.0.1:5000`. Health-checks: `GET /`, `GET /test-db`.

### 6. Frontend

```bash
cd frontend
flutter pub get
flutter run
```

---

## 🔐 Autenticación

Login único compartido entre clientes y empleados. La contraseña se hashea con **bcrypt** y se devuelve un **JWT** firmado con `JWT_SECRET_KEY`.

### Crear un empleado / administrador manualmente

```bash
# 1. Genera el hash (ejecuta una vez):
python -c "import bcrypt; print(bcrypt.hashpw(b'TuPassword1', bcrypt.gensalt()).decode())"
```

```sql
-- 2. Inserta en Supabase (SQL Editor):
INSERT INTO public.usuario (email, password_hash, rol, activo)
VALUES ('admin@banco.local', '<PEGAR_HASH_AQUI>', 'empleado', TRUE);
```

### Crear un cliente (vía API / frontend)

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "curp":"LOAJ900215HDFRPC08",
    "nombres":"Juan",
    "apellido_paterno":"Lopez",
    "apellido_materno":"Aguilar",
    "email":"juan@example.com",
    "telefono":"5512345678",
    "password":"Password1"
  }'
```

### Endpoints

| Método | Ruta | Auth | Body |
|---|---|---|---|
| POST | `/api/auth/register` | público | `{curp, nombres, apellido_paterno, apellido_materno?, email, telefono?, password}` |
| POST | `/api/auth/login` | público | `{email, password}` |
| GET  | `/api/auth/me` | `Bearer <jwt>` | — |

`/register` hace INSERT transaccional en `cliente` y `usuario`. Devuelve `201` + JWT.

### Validaciones backend (regex compartidas)

Las mismas regex viven en **`app/utils/validation.py`** y deberían usarse en Flutter:

| Campo | Regla |
|---|---|
| CURP | `^[A-Z]{4}\d{6}[HM][A-Z]{2}[BCDFGHJKLMNPQRSTVWXYZ]{3}[A-Z0-9]\d$` |
| Email | RFC 5322 simplificado |
| Contraseña | mínimo 8 chars, 1 minúscula + 1 mayúscula + 1 dígito |
| Teléfono | 10 dígitos; prefijo `+52` opcional |
| Nombre | letras Unicode con acentos y ñ |

> Antes no había validación alguna. Ahora todas las regex están centralizadas en
> `app/utils/validation.py` — mismo archivo para backend y (próximamente) Flutter.

---

## 🧪 Tests

```bash
pytest                  # 86 tests, ~5 s
pytest -v               # verboso
pytest --cov=app --cov-report=term-missing   # con cobertura
pytest tests/test_auth.py -v                 # uno solo
```

- **86 / 86** pasando en ~5 s.
- **91 %** de cobertura.
- Stripe está **mockeado**; no necesitas claves reales ni red.
- Los migrations de Supabase **no se ejecutan en tests**: se usa SQLite en memoria + `db.create_all()`.

---

## 📂 Estructura del proyecto

```
proyectoMovilesYFlutter/
├── app.py                          # entrypoint (≤10 líneas)
├── app/
│   ├── __init__.py                 # create_app() + health-checks + JWT
│   ├── config.py                   # Config / Dev / Testing / Prod
│   ├── extensions.py               # SQLAlchemy instance
│   ├── models/                     # ORM
│   │   ├── cliente.py
│   │   ├── sucursal.py
│   │   ├── cuenta.py
│   │   ├── privilegio.py
│   │   ├── domiciliacion.py
│   │   ├── prestamo.py
│   │   └── usuario.py              # 🆕 auth + bcrypt + JWT
│   ├── routes/                     # Blueprints
│   │   ├── clientes.py
│   │   ├── sucursales.py
│   │   ├── cuentas.py
│   │   ├── privilegios.py
│   │   ├── domiciliaciones.py
│   │   ├── prestamos.py
│   │   ├── pagos.py
│   │   └── auth.py                 # 🆕 register / login / me
│   ├── services/
│   │   └── stripe_service.py       # aislado para mockear
│   └── utils/                      # 🆕
│       ├── validation.py           # 🆕 regex compartidas
│       └── auth.py                 # 🆕 @require_auth(roles=...)
├── supabase/                       # 🆕 migrations SQL versionados
│   └── 01_create_usuario.sql       # 🆕 DDL de la tabla usuario
├── tests/                          # 86 tests
│   ├── conftest.py
│   ├── test_*.py                   # uno por blueprint + test_auth.py
├── pytest.ini
├── requirements.txt
├── .env.example
└── frontend/                       # proyecto Flutter
```

> Antes el backend era **monolítico en `app.py`**. Ahora es un paquete `app/` con **factory + Blueprints + servicios + utilidades**.

### Endpoints disponibles

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST / GET | `/api/auth/register` | público | crear cliente + credencial |
| POST | `/api/auth/login` | público | login unificado |
| GET | `/api/auth/me` | JWT | perfil del token |
| POST / GET | `/api/clientes` | público | CRUD clientes |
| POST / GET | `/api/sucursales` | público | CRUD sucursales |
| POST / GET | `/api/cuentas` | público | CRUD cuentas corrientes |
| POST / GET | `/api/privilegios` | público | CRUD privilegios |
| POST | `/api/asignar-privilegios` | público | asignar privilegio |
| POST / GET | `/api/domiciliaciones` | público | CRUD domiciliaciones |
| POST / GET | `/api/prestamos` | público | CRUD préstamos |
| POST | `/api/pagar-domiciliacion` | público | cobra con Stripe y descuenta saldo |

> Antes `/api/*` no tenía endpoints con auth. Ahora `/api/auth/*` introduce autenticación JWT.
> Los demás endpoints siguen sin proteger — protégelos cuando los consuma el frontend usando
> el decorador `@require_auth(roles=("cliente","empleado"))`.

---

## 🔒 Notas de seguridad

- **`JWT_SECRET_KEY`** en `.env` nunca debe commitearse. Usa `secrets.token_urlsafe(48)`.
- Las passwords se hashean con **bcrypt cost 12** — no se almacenan en texto plano.
- El backend **nunca** loguea passwords ni hashes.
- `.gitignore` actual filtra `.env`, builds de Flutter y `.sqlite*`.
