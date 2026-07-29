"""Registro de Blueprints de la API."""
from flask import Flask

from .auth import bp as auth_bp
from .clientes import bp as clientes_bp
from .cuentas import bp as cuentas_bp
from .domiciliaciones import bp as domiciliaciones_bp
from .pagos import bp as pagos_bp
from .prestamos import bp as prestamos_bp
from .privilegios import bp as privilegios_bp
from .sucursales import bp as sucursales_bp


def register_blueprints(app: Flask) -> None:
    app.register_blueprint(auth_bp)  # ya tiene url_prefix="/api/auth"
    app.register_blueprint(clientes_bp, url_prefix="/api")
    app.register_blueprint(sucursales_bp, url_prefix="/api")
    app.register_blueprint(cuentas_bp, url_prefix="/api")
    app.register_blueprint(privilegios_bp, url_prefix="/api")
    app.register_blueprint(domiciliaciones_bp, url_prefix="/api")
    app.register_blueprint(prestamos_bp, url_prefix="/api")
    app.register_blueprint(pagos_bp, url_prefix="/api")
