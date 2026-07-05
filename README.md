# Sistema Bancario - Proyecto Móviles y Flutter

Este repositorio contiene la arquitectura completa del proyecto. El backend está construido en **Python (Flask)** con una base de datos **MySQL**, y el frontend está desarrollado en **Flutter**.

---

## 🛠️ Requisitos Previos
Antes de iniciar, asegúrate de tener instalado en tu computadora:
* [Python 3.x](https://www.python.org/downloads/)
* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* Laragon, XAMPP o cualquier servidor de MySQL local.
* Una cuenta de prueba en [Stripe](https://stripe.com/es) (o las llaves compartidas del equipo).

---

## 🚀 Pasos para levantar el proyecto localmente

### 1. Clonar el repositorio
Abre tu terminal y ejecuta:
---bash
git clone <URL_DEL_REPOSITORIO_AQUI>
cd proyectoMovilesYFlutter

### 2. Configurar la Base de Datos

Abre tu gestor de base de datos (Laragon/phpMyAdmin/HeidiSQL).

Crea una base de datos vacía llamada banco_santander.

Importa el archivo banco_santander.sql (solicítalo al administrador del proyecto, ya que por seguridad no está en este repositorio).

### 3. Configurar el Backend (Flask)
Desde la raíz del proyecto (proyectoMovilesYFlutter), crea y activa un entorno virtual para no ensuciar tu sistema:

En Windows:

---Bash
python -m venv venv
venv\Scripts\activate
En Mac/Linux:

---Bash
python3 -m venv venv
source venv/bin/activate
Instala las dependencias del proyecto:

---Bash
pip install -r requirements.txt

### 4. Variables de Entorno (.env)
Duplica el archivo .env.example y renómbralo a .env.

Abre el archivo .env y configura tus accesos:

DATABASE_URL: Ajusta el usuario y contraseña según tu MySQL local (ej. mysql+pymysql://root:@localhost/banco_santander).

STRIPE: Ingresa las llaves de prueba proporcionadas por el equipo.

### 5. Iniciar el Servidor Backend
Con el entorno virtual activado, ejecuta:

---Bash
python app.py
Verás que el servidor inicia en http://127.0.0.1:5000. ¡Déjalo corriendo!

### 6. Configurar e Iniciar el Frontend (Flutter)
Abre una nueva terminal (deja el backend corriendo en la otra) y navega a la carpeta del frontend:

---Bash
cd frontend
Descarga las dependencias de Flutter:

---Bash
flutter pub get
Levanta la aplicación (asegúrate de tener un emulador abierto o un dispositivo conectado):

---Bash
flutter run