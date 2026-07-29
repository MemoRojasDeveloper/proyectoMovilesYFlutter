"""Configuración de la aplicación por entorno."""
import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


class Config:
    """Configuración base compartida."""

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_AS_ASCII = False
    TESTING = False
    # Duración por defecto del JWT de acceso
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=12)


class DevelopmentConfig(Config):
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL")
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
    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")  # requerido, sin default


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


