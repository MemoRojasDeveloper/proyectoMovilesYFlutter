"""Utilidades transversales de la aplicación."""

from . import validation
from .auth import require_auth
from .validation import (
    CURP_REGEX,
    EMAIL_REGEX,
    NOMBRE_REGEX,
    PASSWORD_REGEX,
    TELEFONO_REGEX,
    normalizar_telefono,
    validar_curp,
    validar_email,
    validar_nombre,
    validar_password,
)

__all__ = [
    "CURP_REGEX",
    "EMAIL_REGEX",
    "NOMBRE_REGEX",
    "PASSWORD_REGEX",
    "TELEFONO_REGEX",
    "normalizar_telefono",
    "require_auth",
    "validar_curp",
    "validar_email",
    "validar_nombre",
    "validar_password",
    "validation",
]
