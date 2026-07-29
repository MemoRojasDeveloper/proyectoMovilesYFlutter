"""Application factory + registro de Blueprints."""
from __future__ import annotations

import os

import stripe
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from sqlalchemy import event
from sqlalchemy.engine import Engine

from .config import get_config
from .extensions import db


jwt = JWTManager()


@event.listens_for(Engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    """Activa las foreign keys en SQLite (que vienen deshabilitadas por defecto)."""
    try:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()
    except Exception:
        # No es SQLite; no pasa nada
        pass


def create_app(config_name: str | None = None) -> Flask:
    """Crea y configura una instancia de la aplicación Flask."""

    app = Flask(__name__)
    app.config.from_object(get_config(config_name))

    # CORS: permite que Flutter Web / clientes en otros dominios
    # consuman la API. En producción se ajustará al dominio real.
    CORS(
        app,
        resources={r"/api/*": {"origins": "*"}},
        supports_credentials=True,
    )

    # Si la DATABASE_URL apunta a postgresql sin driver explícito
    # y `pg8000` está instalado, lo añadimos al esquema de la URL.
    # Esto evita tener que editar `.env` para elegir driver.
    url = app.config.get("SQLALCHEMY_DATABASE_URI", "") or ""
    if url.startswith("postgresql://") and "+" not in url:
        app.config["SQLALCHEMY_DATABASE_URI"] = url.replace(
            "postgresql://", "postgresql+pg8000://", 1
        )

    # Supabase requiere TLS en el puerto 5432.
    final_uri = app.config.get("SQLALCHEMY_DATABASE_URI", "") or ""
    if final_uri.startswith("postgresql+pg8000://") and "sslmode" not in final_uri:
        sep = "&" if "?" in final_uri else "?"
        app.config["SQLALCHEMY_DATABASE_URI"] = final_uri + f"{sep}sslmode=require"

    # Inicializar extensiones
    db.init_app(app)
    jwt.init_app(app)

    # Configurar Stripe (puede ser una key dummy en tests)
    stripe.api_key = app.config.get("STRIPE_SECRET_KEY") or os.getenv(
        "STRIPE_SECRET_KEY", ""
    )

    # Registrar blueprints
    from .routes import register_blueprints

    register_blueprints(app)

    # Rutas de health check (no son blueprints para mantenerlas simples)
    @app.route("/")
    def index():
        return {"mensaje": "API del Banco Santander funcionando correctamente"}

    @app.route("/test-db")
    def test_db():
        try:
            db.session.execute(db.text("SELECT 1"))
            return {
                "status": "success",
                "mensaje": "¡Conexión a la base de datos exitosa!",
            }
        except Exception as exc:
            return {
                "status": "error",
                "mensaje": f"Error de conexión: {exc!s}",
            }

    # Crear tablas en desarrollo (en producción usar migraciones)
    with app.app_context():
        if app.config.get("DEBUG") and not app.config.get("TESTING"):
            try:
                db.create_all()
            except Exception:
                # En Supabase el pooler no permite DDL; se ignora silenciosamente
                pass

    return app
