"""Modelo ORM para `usuario`.

SQL equivalente para Supabase (en /supabase/01_create_usuario.sql):

CREATE TABLE public.usuario (
    id_usuario       SERIAL PRIMARY KEY,
    email            VARCHAR(120) NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    rol              VARCHAR(20)  NOT NULL DEFAULT 'cliente'
                     CHECK (rol IN ('cliente', 'empleado')),
    curp             VARCHAR(18)  UNIQUE
                     REFERENCES public.cliente(curp)
                     ON DELETE CASCADE,
    activo           BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
"""

from __future__ import annotations

import bcrypt
from flask_jwt_extended import create_access_token

from ..extensions import db

ROLES = ("cliente", "empleado")


class Usuario(db.Model):
    __tablename__ = "usuario"

    id_usuario = db.Column(db.Integer, primary_key=True, autoincrement=True)
    email = db.Column(db.String(120), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    rol = db.Column(db.String(20), nullable=False, default="cliente")
    curp = db.Column(
        db.String(18),
        db.ForeignKey("cliente.curp", ondelete="CASCADE", onupdate="CASCADE"),
        unique=True,
        nullable=True,
    )
    activo = db.Column(db.Boolean, nullable=False, default=True)
    creado_en = db.Column(
        db.DateTime(timezone=True), default=db.func.current_timestamp()
    )

    # ── métodos de seguridad (interfaz) ────────────────────────────
    def set_password(self, password_plano: str) -> None:
        """Hashea con bcrypt (cost por defecto = 12 rondas)."""
        # bcrypt sólo soporta hasta 72 bytes en el password
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

    def to_dict(self, include_sensitive: bool = False) -> dict:
        data = {
            "id_usuario": self.id_usuario,
            "email": self.email,
            "rol": self.rol,
            "curp": self.curp,
            "activo": self.activo,
        }
        if include_sensitive:
            data["creado_en"] = (
                self.creado_en.isoformat() if self.creado_en else None
            )
        return data

    def emitir_token(self) -> str:
        """Genera un JWT de acceso con los claims del usuario."""
        claims = {
            "rol": self.rol,
            "curp": self.curp,
            "email": self.email,
        }
        return create_access_token(
            identity=str(self.id_usuario), additional_claims=claims
        )


# ── funciones de módulo para evitar duplicación en tests/externos ──
def generar_hash(password_plano: str) -> str:
    """Devuelve un hash bcrypt como string listo para INSERT."""
    crudo = password_plano.encode("utf-8")[:72]
    return bcrypt.hashpw(crudo, bcrypt.gensalt()).decode("utf-8")


def verificar_hash(password_plano: str, hash_guardado: str) -> bool:
    if not hash_guardado:
        return False
    crudo = password_plano.encode("utf-8")[:72]
    try:
        return bcrypt.checkpw(crudo, hash_guardado.encode("utf-8"))
    except (ValueError, TypeError):
        return False
