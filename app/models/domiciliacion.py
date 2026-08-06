from datetime import datetime, timezone

from ..extensions import db


class CatalogoServicio(db.Model):
    """Catalogo de proveedores/servicios disponibles para domiciliar.

    Vive en Supabase y se pobla manualmente desde el SQL Editor.
    El frontend SOLO LEE este catalogo (no crea ni edita filas).
    """

    __tablename__ = "catalogo_servicio"

    id_catalogo_servicio = db.Column(
        db.Integer, primary_key=True, autoincrement=True
    )
    tipo_servicio = db.Column(db.String(30), nullable=False)
    nombre_proveedor = db.Column(db.String(120), nullable=False)
    monto = db.Column(db.Numeric(10, 2), nullable=False)
    descripcion = db.Column(db.String(255))
    activo = db.Column(db.Boolean, nullable=False, default=True)
    creado_en = db.Column(db.DateTime, default=db.func.current_timestamp())

    def to_dict(self) -> dict:
        return {
            "id_catalogo_servicio": self.id_catalogo_servicio,
            "tipo_servicio": self.tipo_servicio,
            "nombre_proveedor": self.nombre_proveedor,
            "monto": float(self.monto) if self.monto is not None else None,
            "descripcion": self.descripcion,
            "activo": self.activo,
            "creado_en": self.creado_en.isoformat() if self.creado_en else None,
        }


class Domiciliacion(db.Model):
    __tablename__ = "domiciliacion"

    id_domiciliacion = db.Column(
        db.Integer, primary_key=True, autoincrement=True
    )
    codigo_cuenta = db.Column(
        db.String(50),
        db.ForeignKey(
            "cuenta_corriente.codigo_cuenta",
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        nullable=False,
    )
    servicio = db.Column(db.String(100), nullable=False)
    monto_autorizado = db.Column(db.Numeric(10, 2))
    dia_cobro = db.Column(db.Integer, nullable=False)

    # ─── Campos nuevos (esquema de Supabase actualizado) ───
    id_catalogo_servicio = db.Column(
        db.Integer,
        db.ForeignKey(
            "catalogo_servicio.id_catalogo_servicio",
            ondelete="RESTRICT",
            onupdate="CASCADE",
        ),
        nullable=True,
    )
    estado = db.Column(db.String(20), nullable=False, default="activa")
    fecha_registro = db.Column(
        db.DateTime, default=db.func.current_timestamp()
    )
    fecha_ultimo_cobro = db.Column(db.DateTime, nullable=True)
    fecha_limite_pago = db.Column(db.DateTime, nullable=True)
    horas_retraso = db.Column(db.Integer, nullable=False, default=0)
    recargo_acumulado = db.Column(
        db.Numeric(10, 2), nullable=False, default=0
    )
    monto_original = db.Column(db.Numeric(10, 2), nullable=True)

    catalogo = db.relationship(
        "CatalogoServicio", lazy="joined", foreign_keys=[id_catalogo_servicio]
    )

    @property
    def esta_atrasada(self) -> bool:
        """Hay atraso si la fecha_limite_pago ya paso y no se ha cobrado."""
        if self.fecha_limite_pago is None:
            return False
        # Supabase devuelve timestamptz offset-aware; usamos aware aqui tambien
        return datetime.now(timezone.utc) > self.fecha_limite_pago

    @property
    def monto_total_a_cobrar(self) -> float:
        """Lo que se cobra en el proximo ciclo: original + recargos."""
        base = float(self.monto_original or self.monto_autorizado or 0)
        return base + float(self.recargo_acumulado or 0)

    def to_dict(self) -> dict:
        base = float(self.monto_original or self.monto_autorizado or 0)
        recargo = float(self.recargo_acumulado or 0)
        return {
            "id_domiciliacion": self.id_domiciliacion,
            "codigo_cuenta": self.codigo_cuenta,
            "servicio": self.servicio,
            "monto_autorizado": float(self.monto_autorizado)
            if self.monto_autorizado is not None
            else None,
            "monto_original": float(self.monto_original)
            if self.monto_original is not None
            else None,
            "monto_total_a_cobrar": base + recargo,
            "recargo_acumulado": recargo,
            "dia_cobro": self.dia_cobro,
            "id_catalogo_servicio": self.id_catalogo_servicio,
            "estado": self.estado,
            "horas_retraso": self.horas_retraso,
            "esta_atrasada": self.esta_atrasada,
            "fecha_registro": self.fecha_registro.isoformat()
            if self.fecha_registro
            else None,
            "fecha_ultimo_cobro": self.fecha_ultimo_cobro.isoformat()
            if self.fecha_ultimo_cobro
            else None,
            "fecha_limite_pago": self.fecha_limite_pago.isoformat()
            if self.fecha_limite_pago
            else None,
            "catalogo": self.catalogo.to_dict()
            if self.catalogo is not None
            else None,
        }
