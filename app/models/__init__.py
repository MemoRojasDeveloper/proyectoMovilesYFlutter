"""Importa todos los modelos para que SQLAlchemy los registre."""
from .cliente import Cliente, ROLES_PERMITIDOS, ROL_POR_DEFECTO
from .cuenta import CuentaCorriente
from .domiciliacion import Domiciliacion
from .prestamo import Prestamo
from .privilegio import ClienteCuentaPrivilegio, Privilegio
from .sucursal import Sucursal

__all__ = [
    "Cliente",
    "ClienteCuentaPrivilegio",
    "CuentaCorriente",
    "Domiciliacion",
    "Prestamo",
    "Privilegio",
    "ROLES_PERMITIDOS",
    "ROL_POR_DEFECTO",
    "Sucursal",
]
