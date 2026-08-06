"""Importa todos los modelos para que SQLAlchemy los registre."""
from .cliente import Cliente, ROLES_PERMITIDOS, ROL_POR_DEFECTO
from .cuenta import CuentaCorriente
from .domiciliacion import CatalogoServicio, Domiciliacion
from .movimiento import Movimiento
from .prestamo import CuotaPrestamo, Prestamo, PrestamoEvento
from .privilegio import ClienteCuentaPrivilegio, Privilegio
from .sucursal import Sucursal

__all__ = [
    "CatalogoServicio",
    "Cliente",
    "ClienteCuentaPrivilegio",
    "CuotaPrestamo",
    "CuentaCorriente",
    "Domiciliacion",
    "Movimiento",
    "Prestamo",
    "PrestamoEvento",
    "Privilegio",
    "ROLES_PERMITIDOS",
    "ROL_POR_DEFECTO",
    "Sucursal",
]
