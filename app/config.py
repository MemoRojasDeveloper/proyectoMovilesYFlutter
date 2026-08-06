"""Configuración de la aplicación por entorno."""
import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


def _missing_env(name: str) -> str:
    """Helper para fallar ruidosamente si falta una variable de entorno."""
    raise RuntimeError(
        f"Falta la variable de entorno {name}. "
        "Defínela en .env antes de arrancar la aplicación."
    )


# Alias para errores específicos de BD (mensaje más claro).
_missing_db_url = _missing_env


class Config:
    """Configuración base compartida."""

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_AS_ASCII = False
    TESTING = False
    # Duración por defecto del JWT de acceso
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=12)


class DevelopmentConfig(Config):
    DEBUG = True
    # En desarrollo TODO debe ir contra Supabase. Si no hay DATABASE_URL,
    # fallamos ruidosamente: NO usamos SQLite como fallback silencioso,
    # porque eso es exactamente lo que rompió la integración con la nube.
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL") or (
        _missing_db_url("DATABASE_URL")
    )
    JWT_SECRET_KEY = os.getenv(
        "JWT_SECRET_KEY",
        "dev-secret-cambia-en-produccion",  # noqa: S105 (placeholder dev)
    )


class TestingConfig(Config):
    """Configuración para tests: SQLite en memoria con StaticPool (1 sola conexión)."""

    TESTING = True
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_ENGINE_OPTIONS = {
        "connect_args": {"check_same_thread": False},
        "poolclass": __import__("sqlalchemy.pool", fromlist=["StaticPool"]).StaticPool,
    }
    STRIPE_SECRET_KEY = "sk_test_dummy"
    # Fijo para que los tests sean deterministas (no random cada vez)
    JWT_SECRET_KEY = "test-secret-fijo-para-tests-de-al-menos-32-bytes"


class ProductionConfig(Config):
    DEBUG = False
    # Producción exige DATABASE_URL real apuntando a Supabase.
    # Si falta, falla al arrancar (no fallback a SQLite).
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL") or (
        _missing_db_url("DATABASE_URL")
    )
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY") or (
        _missing_env("JWT_SECRET_KEY")
    )


CONFIG_MAP = {
    "development": DevelopmentConfig,
    "testing": TestingConfig,
    "production": ProductionConfig,
}


def get_config(name: str | None = None):
    """Resuelve la clase de configuración según nombre o variable de entorno."""

    if name is None:
        name = os.getenv("FLASK_ENV", "development")
    return CONFIG_MAP.get(name, DevelopmentConfig)


