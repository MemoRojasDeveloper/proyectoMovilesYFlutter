"""Modelo ORM para `sucursal`.

Esquema real en Supabase (alineado con la migración aplicada):

    codigo_sucursal  PK
        DEFAULT  'SUC-' || lpad(nextval('sucursal_codigo_seq'), 3, '0')
        CHECK    ~ '^SUC-[0-9]{3,}$'
        Generado por trigger `trg_sucursal_codigo` si llega NULL.
    nombre_sucursal  NOT NULL
    calle            NULL
    numero           NULL
    colonia          NULL
    ciudad           NULL
    estado           NULL
    codigo_postal    NULL   CHECK '^[0-9]{5}$'
    telefono         NULL   CHECK '^[0-9]{10}$'
    dias_semana      int[]   -- 1=L, 2=M, 3=X, 4=J, 5=V, 6=S, 7=D
    hora_apertura    time    -- NULLABLE
    hora_cierre      time    -- NULLABLE; CHECK par con apertura
    activo           NOT NULL DEFAULT TRUE
    creado_en        NOT NULL DEFAULT NOW()
    actualizado_en   NOT NULL DEFAULT NOW()
"""
from __future__ import annotations

from sqlalchemy.dialects.postgresql import ARRAY, TIME
from sqlalchemy import Integer

from ..extensions import db


class Sucursal(db.Model):
    __tablename__ = "sucursal"

    # La PK es autonumérica estilo 'SUC-001', 'SUC-002', ...
    # Generada en la DB (DEFAULT + trigger). El backend NO la asigna.
    codigo_sucursal = db.Column(
        db.String(20),
        primary_key=True,
        server_default=db.text(
            "('SUC-' || lpad(nextval('public.sucursal_codigo_seq')::text, 3, '0'))"
        ),
    )
    nombre_sucursal = db.Column(db.String(100), nullable=False)

    calle = db.Column(db.String(120))
    numero = db.Column(db.String(10))
    colonia = db.Column(db.String(120))
    ciudad = db.Column(db.String(80))
    estado = db.Column(db.String(40))
    codigo_postal = db.Column(db.String(5))
    telefono = db.Column(db.String(10))

    # Horario normalizado
    # dias_semana: lista de enteros 1..7 (1=Lunes, 7=Domingo)
    dias_semana = db.Column(ARRAY(Integer), nullable=True)
    hora_apertura = db.Column(TIME, nullable=True)
    hora_cierre = db.Column(TIME, nullable=True)

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
            "dias_semana": list(self.dias_semana) if self.dias_semana else None,
            "hora_apertura": (
                self.hora_apertura.strftime("%H:%M")
                if self.hora_apertura is not None
                else None
            ),
            "hora_cierre": (
                self.hora_cierre.strftime("%H:%M")
                if self.hora_cierre is not None
                else None
            ),
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