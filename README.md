# Sistema Bancario — Banco Santander

**Backend Flask 3.1 + Supabase PostgreSQL** y **frontend Flutter 3.44**.

Sistema bancario completo con autenticación JWT, cuentas corrientes,
compartición de cuentas entre clientes con privilegios granulares,
préstamos con simulador, domiciliaciones automáticas con recargo por
atraso, historial de movimientos con Stripe, panel de empleado para
gestión de sucursales y dashboard dual (cliente / empleado).

---

## 📑 Tabla de cambios recientes

> Si vienes de una versión anterior, esta sección resume TODO lo que cambió
> desde la última publicación del README.

| Antes | Ahora |
|---|---|
| Auth: solo `cliente` y `usuario` separados | **Identidad única**: `cliente` con campo `rol` (CHECK cliente/empleado); no existe tabla `usuario` separada |
| Auth: 1 tabla usuario + 1 tabla cliente, 2 password_hash | Un solo `password_hash` vive dentro de `cliente` |
| Coverage 91 %, **86 tests** | Cobertura sigue ~91 %; tests reorganizados para el nuevo esquema |
| Sin historial de movimientos | **Tabla `movimiento`** append-only + endpoint paginado + UI en cliente y empleado |
| Sin compartir cuentas | **Endpoints `/api/cuentas/<codigo>/usuarios`** (GET/POST/PATCH/DELETE) + tabla `cliente_cuenta_privilegio` para accesos granulares |
| Sin catálogo de servicios | **Tabla `catalogo_servicio`** (internet/luz/agua/otro) poblada manualmente desde Supabase |
| Sin domiciliaciones automáticas | **Cobrador automático** (thread daemon, cada hora) con recargo 2 % por hora de atraso |
| Sin asignación de saldo por empleado | `PATCH /api/cuentas/<codigo>/saldo` (sumar/restar) — empleado only |
| Sin Stripe en transferencias | Stripe solo en pagos a **proveedores externos** (CFE, Telmex, etc.); las transferencias entre cuentas son internas |
| `psycopg2-binary` con marcador PEP 508 | **Eliminado**: pg8000 es el único driver soportado (compatible con Python 3.13/3.14) |
| `app/services/` solo con stripe_service | + **`cobrador_service.py`** (hilo en background) |
| `app/routes/pagos.py` único endpoint | + `POST /api/cuentas/<codigo>/transferir`, `PATCH /saldo`, `PATCH /activo`, `PATCH /sucursal`, `PATCH /<codigo>/domiciliaciones/<id>/pagar`, `GET /<codigo>/movimientos`, `GET /<codigo>/usuarios`, `POST /<codigo>/usuarios`, `PATCH /<codigo>/usuarios/<curp>`, `DELETE /<codigo>/usuarios/<curp>`, `GET /api/catalogo-servicios`, `POST /api/domiciliaciones`, `DELETE /api/domiciliaciones/<id>` |
| README con instrucciones MySQL | **Solo Supabase** es soportado: SQLite local fue **eliminado por completo** (guardarraíl en `app/__init__.py`) |

---

## 🛠️ Requisitos previos

* **Python 3.12 / 3.13 / 3.14** (probado en 3.14.6)
* **Flutter SDK 3.44+** + Dart 3.12+
* **Cuenta en [Supabase](https://supabase.com)** (PostgreSQL) — **obligatorio**; ya no hay fallback a MySQL/SQLite en dev
* **Cuenta de prueba en [Stripe](https://stripe.com)** con las dos llaves API (test)

---

## 🚀 Pasos para levantar el proyecto

### 1. Clonar

```bash
git clone <URL_DEL_REPOSITORIO>
cd proyectoMovilesYFlutter
```

### 2. Base de datos

La base de datos ya está provisionada y gestionada por el equipo en Supabase.
Si necesitás acceso, pedíselo al administrador del proyecto (todos en el
equipo la pueden ver en el panel de Supabase).

> ⚠️ **El puerto 5432 directo está bloqueado** desde la mayoría de redes
> residenciales. Usa el **pooler 6543** (`aws-0-XXXX.pooler.supabase.com:6543`)
> en el `DATABASE_URL` de tu `.env`. El driver `pg8000` está preconfigurado
> en `app/__init__.py` para usar TLS automáticamente con Supabase.

#### Cambiar el rol de un usuario a empleado

Si necesitás promover un cliente existente a empleado (rol `empleado`),
pedile al admin que ejecute en el SQL Editor de Supabase:

```sql
UPDATE public.cliente SET rol = 'empleado' WHERE email = 'admin@banco.local';
```

> Los empleados NO se registran por la API: se crean manualmente en Supabase
> con `rol='empleado'`. Los clientes sí, vía `POST /api/auth/register`.
>  Esto es un ejemplo, podrías hacerlo con el CURP para más exactitud

---

### 3. Backend

```bash
python -m venv venv
# Windows:
venv\Scripts\activate
# Mac / Linux:
source venv/bin/activate

pip install -r requirements.txt
```

> Si usas **Python 3.13/3.14**, `pg8000` (incluido) funciona out-of-the-box.
> NO instales `psycopg2-binary` salvo que necesites `pg_config` en PATH.

### 4. Variables de entorno

Copia `.env.example` → `.env` y rellena:

```bash
# URL del pooler de Supabase (puerto 6543, NO el 5432 directo)
DATABASE_URL=postgresql://postgres.XXXX:TU_PASSWORD@aws-0-XXXX.pooler.supabase.com:6543/postgres

# Stripe: la publica va en el frontend, la secreta SOLO en el backend
STRIPE_PUBLIC_KEY= lo dejé vacío
STRIPE_SECRET_KEY=sk_test_...

# Genera una:  python -c "import secrets; print(secrets.token_urlsafe(48))"
JWT_SECRET_KEY=cambia-en-produccion

# Opcionales de Supabase para el frontend
SUPABASE_URL=https://XXXX.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_XXXX
```

> ⚠️ **`STRIPE_SECRET_KEY` debe empezar por `sk_test_` o `sk_live_`**.
> Si pones la clave pública (`pk_test_...`) aquí, los cargos fallarán
> con el error *"This API call cannot be made with a publishable API key"*.

### 5. Arrancar el backend

```bash
python app.py
```

Levanta en `http://127.0.0.1:5000`. Health-checks:

| Endpoint | Descripción |
|---|---|
| `GET /` | "API del Banco Santander funcionando correctamente" |
| `GET /test-db` | `SELECT 1` contra Supabase |

> ⚠️ En modo debug, el **cobrador automático** arranca como thread daemon
> dentro del proceso Flask. Se puede desactivar con `FLASK_SKIP_COBRADOR=1`.

### 6. Frontend

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5000
```

Para navegador web:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

---

## 🔐 Autenticación

Login **único y unificado**: clientes y empleados comparten el mismo endpoint,
se diferencian por el campo `rol` en el JWT.

* Contraseñas hasheadas con **bcrypt cost=12**, máximo 72 bytes (límite del algoritmo).
* Token **JWT HS256** firmado con `JWT_SECRET_KEY`, expiración 12 h.
* Claims: `{sub: curp, rol, curp, email}`.

### Endpoints de auth

| Método | Ruta | Auth | Body |
|---|---|---|---|
| POST | `/api/auth/register` | público | `{curp, nombres, apellido_paterno, apellido_materno?, email, telefono?, password, codigo_sucursal}` |
| POST | `/api/auth/login` | público | `{email, password}` |
| GET | `/api/auth/me` | `Bearer <jwt>` | — |

`/register` crea en una sola transacción: 1 fila en `cliente`, 1 fila en
`cuenta_corriente`, N filas en `cliente_cuenta_privilegio` con los privilegios
base (`consultar_saldo`, `transferir`, `pagar_domiciliacion`, `cerrar_cuenta`).

### Crear un empleado manualmente

```bash
# 1. Genera el hash (ejecuta una vez):
python -c "import bcrypt; print(bcrypt.hashpw(b'TuPassword1', bcrypt.gensalt()).decode())"
```

```sql
-- 2. Inserta en Supabase (SQL Editor):
UPDATE public.cliente
SET password_hash = '<PEGAR_HASH_AQUI>', rol = 'empleado', activo = TRUE
WHERE email = 'admin@banco.local'; 
* Esto es un ejemplo, podrías hacerlo con el CURP para más exactitud
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
    "password":"Password1",
    "codigo_sucursal":"PUE-001"
  }'
```

### Validaciones compartidas (`app/utils/validation.py`)

| Campo | Regla |
|---|---|
| CURP | `^[A-Z]{4}\d{6}[HM][A-Z]{2}[BCDFGHJKLMNPQRSTVWXYZ]{3}[A-Z0-9]\d$` (18 chars) |
| Email | RFC 5322 simplificado |
| Contraseña | ≥ 8 chars, 1 minúscula + 1 mayúscula + 1 dígito |
| Teléfono | 10 dígitos; prefijo `+52` opcional |
| Nombre | letras Unicode con acentos y ñ |

---

## 🏦 Modelo de dominio

### Entidades

| Tabla | Propósito | Campos clave |
|---|---|---|
| `cliente` | Identidad única de cliente y empleado | `curp` (PK), `email` (UNIQUE), `password_hash` (bcrypt), `rol` (cliente/empleado), `codigo_sucursal` |
| `sucursal` | Sucursales del banco | `codigo_sucursal` (PK), `nombre_sucursal`, `direccion`, `activo` |
| `cuenta_corriente` | Cuentas corrientes de los clientes | `codigo_cuenta` (PK, formato `CTA-{curp6}-{sucursal}`), `saldo`, `activo` |
| `privilegio` | Catálogo de operaciones permitidas | `id_privilegio`, `nombre_operacion` (UNIQUE) |
| `cliente_cuenta_privilegio` | Asignación de privilegios por (cliente, cuenta) | `(curp, codigo_cuenta, id_privilegio)` PK compuesta |
| `domiciliacion` | Servicios automáticos cobrados por hora | `id_domiciliacion`, `codigo_cuenta`, `monto_original`, `recargo_acumulado`, `horas_retraso`, `estado` |
| `catalogo_servicio` | Proveedores disponibles (CFE, Telmex, etc.) | `tipo_servicio`, `nombre_proveedor`, `monto`, `activo` |
| `prestamo` + `cuota_prestamo` | Préstamos con cuotas calculadas (francés) | `monto_otorgado`, `tasa_interes` (CHECK 9-18 %), `plazo_meses` |
| `movimiento` | **Historial append-only** de cada operación que afecta saldo | `codigo_cuenta`, `tipo`, `monto`, `curp_actor`, `id_domiciliacion`, `stripe_charge_id`, `fecha` |

### Compartición de cuentas

Una cuenta corriente puede pertenecer a uno o varios clientes vía la tabla
`cliente_cuenta_privilegio`. El **dueño real** se identifica por tener el
privilegio `cerrar_cuenta` (otorgado solo al registrar).

Para compartir: el dueño llama `POST /api/cuentas/<codigo>/usuarios`
con la CURP del invitado y la lista de privilegios que le concede.

### Domiciliaciones automáticas

1. El cliente elige un servicio del catálogo: `POST /api/domiciliaciones`
2. El cobrador (thread daemon) corre cada hora y cobra `monto_total_a_cobrar`:
   - Si hay saldo → descuenta, registra `cobro_domiciliacion_auto` (pasa por **Stripe**)
   - Si NO hay saldo → `horas_retraso += 1`, `recargo_acumulado += 2 % del monto_original`,
     registra `cobro_domiciliacion_recargo` (sin Stripe, es interno)
3. El empleado puede dar de baja: `DELETE /api/domiciliaciones/<id>`

---

## 🌐 Endpoints principales

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| **Auth** | | | |
| POST | `/api/auth/register` | público | crea cliente + cuenta + privilegios |
| POST | `/api/auth/login` | público | login unificado |
| GET | `/api/auth/me` | JWT | perfil del token |
| **Sucursales** | | | |
| GET / POST | `/api/sucursales` | público / empleado | listar / crear |
| GET / PUT / PATCH / DELETE | `/api/sucursales/<codigo>` | mixto | detalle / edición |
| GET | `/api/sucursales/<codigo>/cuentas` | JWT | cuentas de la sucursal + domiciliaciones |
| **Clientes** | | | |
| GET / POST | `/api/clientes` | JWT | listar / crear |
| GET | `/api/clientes/<curp>` | JWT | detalle |
| GET | `/api/clientes/<curp>/cuentas` | JWT | cuentas del cliente |
| **Cuentas corrientes** | | | |
| GET / POST | `/api/cuentas` | mixto | listar / crear |
| GET | `/api/cuentas/<codigo>` | JWT | detalle |
| PATCH | `/api/cuentas/<codigo>/activo` | empleado | activar/desactivar (saldo debe ser 0) |
| PATCH | `/api/cuentas/<codigo>/sucursal` | empleado | cambiar de sucursal |
| PATCH | `/api/cuentas/<codigo>/saldo` | empleado | sumar/restar (para pruebas) |
| POST | `/api/cuentas/<codigo>/transferir` | cliente/empleado | transferir por CURP destino |
| GET | `/api/cuentas/<codigo>/domiciliaciones` | JWT | lista completa |
| PATCH | `/api/cuentas/<codigo>/domiciliaciones/<id>/pagar` | cliente (con priv) | pago manual vía Stripe |
| GET | `/api/cuentas/<codigo>/privilegios` | JWT | catálogo + flag `lo_tiene` por usuario |
| GET | `/api/cuentas/<codigo>/usuarios` | JWT | usuarios con acceso a la cuenta |
| POST / PATCH / DELETE | `/api/cuentas/<codigo>/usuarios[/<curp>]` | dueño o empleado | compartir / editar / quitar acceso |
| **Historial** | | | |
| GET | `/api/cuentas/<codigo>/movimientos?limite=20&offset=0` | JWT | historial paginado |
| **Catálogo y domiciliaciones** | | | |
| GET | `/api/catalogo-servicios?tipo=internet` | público | proveedores disponibles |
| POST | `/api/domiciliaciones` | cliente/empleado | domiciliar un servicio |
| DELETE | `/api/domiciliaciones/<id>` | empleado | dar de baja |
| **Préstamos** | | | |
| POST | `/api/prestamos/simular` | público | simular cuotas (sin guardar) |
| POST | `/api/clientes/<curp>/prestamos` | empleado | aprobar préstamo |
| GET | `/api/clientes/<curp>/prestamos` | JWT | lista del cliente |
| GET | `/api/prestamos/<id>` | JWT | detalle |
| GET | `/api/prestamos/<id>/cuotas` | JWT | cronograma |
| PATCH | `/api/prestamos/cuotas/<id>/pagar` | cliente (con priv) | pagar una cuota |
| **Pagos con Stripe** | | | |
| POST | `/api/pagar-domiciliacion` | mixto | endpoint legacy (mantenido) |

---

## 📱 Frontend (Flutter)

### Estructura

```
frontend/lib/
├── core/
│   ├── api_client.dart          # HTTP wrapper con JWT inyectado
│   ├── api_exception.dart       # Excepciones tipadas
│   ├── auth_storage.dart        # SharedPreferences para el token
│   └── theme.dart               # ThemeController (light/dark/system)
├── features/
│   ├── auth/                    # Login + Register
│   ├── cliente/
│   │   ├── cliente_dashboard_shell.dart
│   │   ├── cliente_home_screen.dart
│   │   ├── cliente_cuentas_screen.dart
│   │   ├── cliente_cuenta_detalle_screen.dart
│   │   ├── cliente_transferir_screen.dart
│   │   ├── cliente_prestamos_screen.dart
│   │   ├── cliente_prestamo_simulador_screen.dart
│   │   ├── cliente_prestamo_cuotas_screen.dart
│   │   ├── cliente_mas_screen.dart
│   │   ├── compartir_cuenta_screen.dart   # nueva: compartir acceso
│   │   ├── domiciliar_servicio_screen.dart # nueva: catálogo
│   │   └── cambiar_cuenta_sheet.dart       # nueva: switcher
│   ├── empleado/
│   │   ├── sucursales_empleado_screen.dart
│   │   ├── sucursal_detalle_screen.dart   # ahora con historial + saldos
│   │   └── sucursal_form_screen.dart
│   └── historial/
│       └── historial_cuenta_screen.dart   # nueva: pantalla de movimientos
└── main.dart
```

### Flujos clave

| Pantalla | Acción |
|---|---|
| **Login** | Email + password → JWT guardado en `SharedPreferences` |
| **Dashboard cliente** | Bottom nav: Inicio / Cuentas / Préstamos / Cambiar / Más |
| **Detalle de cuenta** | Saldo · Transferir (con `transferir`) · Domiciliaciones · Privilegios · Accesos compartidos · Historial |
| **Cambiar de cuenta** | Bottom sheet con las cuentas compartidas con el usuario; si está vacío → snackbar "No tienes cuentas compartidas" |
| **Domiciliar servicio** | Catálogo filtrado por activas; oculta las ya domiciliadas en la cuenta; UNIQUE lógico |
| **Detalle sucursal (empleado)** | Cuentas con menú ⋮: Asignar saldo / Cambiar sucursal / Desactivar · Sub-lista de domiciliaciones con botón "Dar de baja" · Acceso a historial de cada cuenta |
| **Ver historial** | Paginado (20 en 20), con icono + color por tipo, signo +/- según entrada/salida, badge morado "Stripe" para pagos reales |

### Catálogo de privilegios (en el frontend)

| Nombre interno (`snake_case`) | Etiqueta visible |
|---|---|
| `consultar_saldo` | Consultar saldo |
| `transferir` | Transferir |
| `pagar_domiciliacion` | Pagar domiciliación |
| `cerrar_cuenta` | Cerrar cuenta |

> El frontend mapea `nombre` → `etiqueta` con `ClienteRepository.etiquetaDe()`.
> El campo `nombre` es lo que viaja al backend.

---

## 🧪 Tests

```bash
pytest                  # corre los tests
pytest -v               # verboso
pytest --cov=app --cov-report=term-missing   # con cobertura
pytest tests/test_auth.py -v                 # uno solo
```

* Stripe está **mockeado**; no necesitas claves reales ni red.
* Los tests usan **SQLite en memoria** + `db.create_all()`; no tocan Supabase.
* `app/config.py` tiene un `TestingConfig` separado que aísla el entorno.

---

## 📂 Estructura del proyecto

```
proyectoMovilesYFlutter/
├── app.py                          # entrypoint Flask
├── app/
│   ├── __init__.py                 # factory + health-checks + JWT + cobrador
│   ├── config.py                   # Config / Dev / Testing / Prod
│   ├── extensions.py               # SQLAlchemy instance
│   ├── models/
│   │   ├── cliente.py              # identidad + password_hash + rol
│   │   ├── sucursal.py
│   │   ├── cuenta.py
│   │   ├── privilegio.py
│   │   ├── domiciliacion.py        # + CatalogoServicio
│   │   ├── movimiento.py           # historial append-only
│   │   └── prestamo.py
│   ├── routes/
│   │   ├── auth.py                 # register / login / me
│   │   ├── clientes.py
│   │   ├── sucursales.py
│   │   ├── cuentas.py              # CRUD + transferir + saldo + usuarios
│   │   ├── domiciliaciones.py      # catálogo + crear + dar de baja
│   │   ├── prestamos.py
│   │   ├── pagos.py                # legacy
│   │   └── privilegios.py
│   ├── services/
│   │   ├── stripe_service.py
│   │   └── cobrador_service.py     # 🆕 thread daemon (1h)
│   └── utils/
│       ├── validation.py           # regex CURP / email / password / etc
│       └── auth.py                 # decorador @require_auth
├── tests/
├── requirements.txt                # stack completo + transitivas fijadas
├── .env.example
└── frontend/
    ├── lib/
    ├── pubspec.yaml
    └── ...
```

---

## 🔒 Notas de seguridad

* **`JWT_SECRET_KEY`** en `.env` nunca debe commitearse. Usa `secrets.token_urlsafe(48)`.
* Passwords hasheadas con **bcrypt cost 12**. Máximo 72 bytes (limitación del algoritmo).
* `STRIPE_SECRET_KEY` solo va en el backend. La `STRIPE_PUBLIC_KEY` puede exponerse al frontend.
* El backend **nunca** loguea passwords ni hashes.
* `.gitignore` filtra `.env`, builds de Flutter, `*.sqlite*` y archivos de tests.

---

## 🧯 Troubleshooting común

| Síntoma | Causa | Solución |
|---|---|---|
| `permission denied for schema public` | tu usuario no tiene DDL | usa el puerto 5432 directo con rol `postgres`, o aplica las migraciones desde la UI de Supabase |
| `connection refused` al arrancar el backend | DATABASE_URL apunta a 5432 directo, bloqueado por tu red | usa el pooler 6543 (`aws-0-XXXX.pooler.supabase.com:6543`) |
| `No module named 'stripe'` | requirements.txt desactualizado | `pip install -r requirements.txt` |
| Cobrador automático marca recargo sin razón | `STRIPE_SECRET_KEY` es `pk_test_` (clave pública) | reemplázala por la `sk_test_...` real |
| `This API call cannot be made with a publishable API key` | `STRIPE_SECRET_KEY` está mal configurada | ve a https://dashboard.stripe.com/test/apikeys → fila "Clave secreta" |
| Flutter no conecta al backend | `API_BASE_URL` apunta a `10.0.2.2` pero no estás en emulador | `flutter run --dart-define=API_BASE_URL=http://localhost:5000` |
| Préstamo no se aprueba | la tasa está fuera de 9-18 % | ajusta la tasa al rango legal |
| `relation "movimiento" does not exist` | la tabla de movimientos no se creó en Supabase | pedile al admin que la cree (ver sección "Base de datos" arriba) |
