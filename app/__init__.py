"""Application factory + registro de Blueprints."""
from __future__ import annotations

import os

import stripe
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager

from .config import get_config
from .extensions import db


jwt = JWTManager()


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

    # Guardarraíl: en development/production NO permitimos que la URL
    # apunte a nada que no sea Supabase. Si alguien pone un SQLite
    # local, fallamos ruidosamente en lugar de aceptarlo.
    final_uri = app.config.get("SQLALCHEMY_DATABASE_URI", "") or ""
    is_testing = bool(app.config.get("TESTING"))
    if not is_testing and not final_uri.startswith("postgresql"):
        raise RuntimeError(
            "DATABASE_URL debe apuntar a Supabase (postgresql://...). "
            f"Valor actual: {final_uri!r}"
        )

    # Supabase (puerto 5432 o 6543 pooler) requiere TLS. pg8000 NO acepta
    # `sslmode=require` en la URL; necesita `connect_args` aparte.
    if final_uri.startswith("postgresql+pg8000://") and "sslmode" not in final_uri:
        app.config.setdefault("SQLALCHEMY_ENGINE_OPTIONS", {}).update({
            "connect_args": {"ssl_context": True},
        })

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

    # Arrancamos el cobrador automatico de domiciliaciones SOLO en
    # el proceso WSGI real (no en tests ni en reload del reloader).
    # Evita que se dispare dos veces cuando Flask esta en modo debug.
    import os as _os
    if not app.config.get("TESTING") and not _os.getenv("FLASK_SKIP_COBRADOR"):
        if not _os.getenv("WERKZEUG_RUN_MAIN") and app.debug:
            # Primer arranque del reloader: solo el hijo debe lanzar el thread
            pass
        else:
            try:
                from .services.cobrador_service import iniciar_en_background
                iniciar_en_background(app)
            except Exception:
                import logging as _log
                _log.getLogger(__name__).exception(
                    "No se pudo iniciar el cobrador automatico"
                )

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

    # NO crear tablas en arranque. El esquema vive en Supabase y se
    # gestiona con migraciones SQL ejecutadas desde el panel.
    # Si necesitas crear/alterar tablas, edita supabase/*.sql y
    # ejecútalo desde SQL Editor de Supabase.

    return app
