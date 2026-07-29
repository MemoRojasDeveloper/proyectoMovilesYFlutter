"""Modelo ORM para `cliente`.

Tabla única de identidad para clientes del banco. Aquí vive también
el `password_hash` (no hay tabla `usuario` separada; la única tabla
existente en Supabase es `public.cliente`).
"""
from __future__ import annotations

import bcrypt
from flask_jwt_extended import create_access_token

from ..extensions import db

ROLES_PERMITIDOS = ("cliente", "empleado")
ROL_POR_DEFECTO = "cliente"


class Cliente(db.Model):
    __tablename__ = "cliente"

    curp = db.Column(db.String(18), primary_key=True)
    nombres = db.Column(db.String(100), nullable=False)
    apellido_paterno = db.Column(db.String(100), nullable=False)
    apellido_materno = db.Column(db.String(100))
    email = db.Column(db.String(120), unique=True, nullable=False)
    telefono = db.Column(db.String(15))

    # auth embebido en cliente (es la única tabla de identidad)
    password_hash = db.Column(db.String(255), nullable=False)
    activo = db.Column(db.Boolean, nullable=False, default=True)
    creado_en = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        server_default=db.func.current_timestamp(),
    )
    ultimo_acceso = db.Column(db.DateTime(timezone=True))

    # Diferencia un cliente del banco de un usuario-administrador.
    # Por defecto 'cliente'. Solo el alta manual en BD puede
    # crear un 'empleado'.
    rol = db.Column(
        db.String(20),
        nullable=False,
        default=ROL_POR_DEFECTO,
        server_default=ROL_POR_DEFECTO,
    )

    # ── password ───────────────────────────────────────────────
    def set_password(self, password_plano: str) -> None:
        crudo = password_plano.encode("utf-8")[:72]
        sal = bcrypt.gensalt()
        self.password_hash = bcrypt.hashpw(crudo, sal).decode("utf-8")

    def check_password(self, password_plano: str) -> bool:
        if not self.password_hash:
            return False
        crudo = password_plano.encode("utf-8")[:72]
        try:
            return bcrypt.checkpw(crudo, self.password_hash.encode("utf-8"))
        except (ValueError, TypeError):
            return False

    # ── JWT ────────────────────────────────────────────────────
    def emitir_token(self) -> str:
        claims = {
            "rol": self.rol,
            "curp": self.curp,
            "email": self.email,
        }
        return create_access_token(
            identity=self.curp, additional_claims=claims
        )

    # ── utilidades ─────────────────────────────────────────────
    @property
    def is_empleado(self) -> bool:
        return self.rol == "empleado"

    @property
    def nombre_completo(self) -> str:
        partes = [self.nombres, self.apellido_paterno]
        if self.apellido_materno:
            partes.append(self.apellido_materno)
        return " ".join(partes)

    def to_dict(self, include_sensitive: bool = False) -> dict:
        data = {
            "curp": self.curp,
            "nombres": self.nombres,
            "apellido_paterno": self.apellido_paterno,
            "apellido_materno": self.apellido_materno,
            "email": self.email,
            "telefono": self.telefono,
            "rol": self.rol,
            "activo": self.activo,
        }
        if include_sensitive:
            data["creado_en"] = (
                self.creado_en.isoformat() if self.creado_en else None
            )
            data["ultimo_acceso"] = (
                self.ultimo_acceso.isoformat() if self.ultimo_acceso else None
            )
        return data
