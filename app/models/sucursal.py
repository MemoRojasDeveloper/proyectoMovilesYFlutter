"""Modelo ORM para `sucursal`.

Esquema real en Supabase (alineado con la migración aplicada):

    codigo_sucursal  PK
    nombre_sucursal  NOT NULL
    calle            NULL
    numero           NULL
    colonia          NULL
    ciudad           NULL
    estado           NULL
    codigo_postal    NULL   CHECK '^[0-9]{5}$'
    telefono         NULL   CHECK '^[0-9]{10}$'
    horario          NULL
    activo           NOT NULL DEFAULT TRUE
    creado_en        NOT NULL DEFAULT NOW()
    actualizado_en   NOT NULL DEFAULT NOW()
"""
from __future__ import annotations

from ..extensions import db


class Sucursal(db.Model):
    __tablename__ = "sucursal"

    codigo_sucursal = db.Column(db.String(20), primary_key=True)
    nombre_sucursal = db.Column(db.String(100), nullable=False)

    calle = db.Column(db.String(120))
    numero = db.Column(db.String(20))
    colonia = db.Column(db.String(120))
    ciudad = db.Column(db.String(80))
    estado = db.Column(db.String(80))
    codigo_postal = db.Column(db.String(5))
    telefono = db.Column(db.String(15))
    horario = db.Column(db.String(120))

    activo = db.Column(db.Boolean, nullable=False, default=True)
    creado_en = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        server_default=db.func.current_timestamp(),
    )
    actualizado_en = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        server_default=db.func.current_timestamp(),
    )

    def to_dict(self) -> dict:
        return {
            "codigo_sucursal": self.codigo_sucursal,
            "nombre_sucursal": self.nombre_sucursal,
            "calle": self.calle,
            "numero": self.numero,
            "colonia": self.colonia,
            "ciudad": self.ciudad,
            "estado": self.estado,
            "codigo_postal": self.codigo_postal,
            "telefono": self.telefono,
            "horario": self.horario,
            "activo": self.activo,
            "creado_en": self.creado_en.isoformat() if self.creado_en else None,
            "actualizado_en": (
                self.actualizado_en.isoformat() if self.actualizado_en else None
            ),
        }

    def direccion_corta(self) -> str:
        partes = []
        if self.calle:
            sn = self.calle
            if self.numero:
                sn = f"{self.calle} {self.numero}"
            partes.append(sn)
        if self.colonia:
            partes.append(f"col. {self.colonia}")
        if self.ciudad:
            partes.append(self.ciudad)
        if self.estado:
            partes.append(self.estado)
        if self.codigo_postal:
            partes.append(f"C.P. {self.codigo_postal}")
        return ", ".join(partes) if partes else "Sin dirección registrada"