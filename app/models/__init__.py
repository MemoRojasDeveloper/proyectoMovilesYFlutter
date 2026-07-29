"""Importa todos los modelos para que SQLAlchemy los registre."""
from .cliente import Cliente
from .cuenta import CuentaCorriente
from .domiciliacion import Domiciliacion
from .prestamo import Prestamo
from .privilegio import ClienteCuentaPrivilegio, Privilegio
from .sucursal import Sucursal
from .usuario import ROLES, Usuario, generar_hash, verificar_hash

__all__ = [
    "Cliente",
    "ClienteCuentaPrivilegio",
    "CuentaCorriente",
    "Domiciliacion",
    "Prestamo",
    "Privilegio",
    "ROLES",
    "Sucursal",
    "Usuario",
    "generar_hash",
    "verificar_hash",
]
