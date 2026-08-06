from decimal import Decimal

from ..extensions import db


# Estados posibles de un prestamo segun el workflow.
EST_PRESTAMO_PENDIENTE = "pendiente"
EST_PRESTAMO_APROBADO = "aprobado"
EST_PRESTAMO_RECHAZADO = "rechazado"
EST_PRESTAMO_CANCELADO = "cancelado"
ESTADOS_PRESTAMO = (
    EST_PRESTAMO_PENDIENTE,
    EST_PRESTAMO_APROBADO,
    EST_PRESTAMO_RECHAZADO,
    EST_PRESTAMO_CANCELADO,
)


class Prestamo(db.Model):
    __tablename__ = "prestamo"

    id_prestamo = db.Column(db.Integer, primary_key=True, autoincrement=True)
    curp = db.Column(
        db.String(18),
        db.ForeignKey("cliente.curp", ondelete="CASCADE", onupdate="CASCADE"),
        nullable=False,
    )
    monto_otorgado = db.Column(db.Numeric(15, 2), nullable=False)
    tasa_interes = db.Column(db.Numeric(5, 2), nullable=False)
    plazo_meses = db.Column(db.Integer, nullable=False)
    fecha_aprobacion = db.Column(db.Date, nullable=False)

    # Workflow: 'pendiente' -> 'aprobado'|'rechazado'|'cancelado'
    estado = db.Column(
        db.String(20),
        nullable=False,
        default=EST_PRESTAMO_APROBADO,
        server_default=EST_PRESTAMO_APROBADO,
    )

    # Motivo / mensaje que dejo el solicitante
    motivo_solicitud = db.Column(db.Text)

    # Si lo solicita otro usuario con permiso, queda registrado
    curp_solicitante = db.Column(
        db.String(18),
        db.ForeignKey("cliente.curp", ondelete="SET NULL"),
        nullable=True,
    )

    # Snapshot JSON con info del ultimo evento
    # (motivo de aprob/rechazo, curp_empleado, etc.)
    estado_detalle = db.Column(
        db.JSON,
        nullable=False,
        default=dict,
        server_default=db.text("'{}'::jsonb"),
    )

    def to_dict(self) -> dict:
        return {
            "id_prestamo": self.id_prestamo,
            "curp": self.curp,
            "curp_solicitante": self.curp_solicitante,
            "monto_otorgado": float(self.monto_otorgado),
            "tasa_interes": float(self.tasa_interes),
            "plazo_meses": self.plazo_meses,
            "fecha_aprobacion": self.fecha_aprobacion.strftime("%Y-%m-%d")
            if self.fecha_aprobacion
            else None,
            "estado": self.estado,
            "motivo_solicitud": self.motivo_solicitud,
            "estado_detalle": self.estado_detalle or {},
        }

    def monto_cuota(self) -> Decimal:
        """Cuota mensual nivelada (sistema frances simplificado).

        M = P * (i * (1+i)^n) / ((1+i)^n - 1)
        donde i = tasa_mensual, n = plazo_meses.
        Si i=0, M = P / n.
        """
        P = Decimal(str(self.monto_otorgado))
        i = Decimal(str(self.tasa_interes)) / Decimal("100") / Decimal("12")
        n = Decimal(str(self.plazo_meses))
        if i == 0:
            return P / n
        uno_mas_i = Decimal("1") + i
        factor = uno_mas_i ** int(n)
        return P * (i * factor) / (factor - Decimal("1"))

    def interes_total(self) -> Decimal:
        return self.monto_cuota() * Decimal(str(self.plazo_meses)) - Decimal(
            str(self.monto_otorgado)
        )


class PrestamoEvento(db.Model):
    """Historial inmutable de eventos del workflow de un prestamo."""

    __tablename__ = "prestamo_evento"

    id_evento = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    id_prestamo = db.Column(
        db.Integer,
        db.ForeignKey("prestamo.id_prestamo", ondelete="CASCADE"),
        nullable=False,
    )
    tipo = db.Column(db.String(30), nullable=False)
    curp_actor = db.Column(
        db.String(18),
        db.ForeignKey("cliente.curp", ondelete="SET NULL"),
        nullable=True,
    )
    estado_anterior = db.Column(db.String(20))
    estado_nuevo = db.Column(db.String(20))
    motivo = db.Column(db.Text)
    metadata_json = db.Column(
        "metadata",
        db.JSON,
        nullable=False,
        default=dict,
        server_default=db.text("'{}'::jsonb"),
    )
    fecha = db.Column(
        db.DateTime(timezone=True),
        nullable=False,
        server_default=db.func.current_timestamp(),
    )

    def to_dict(self) -> dict:
        return {
            "id_evento": self.id_evento,
            "id_prestamo": self.id_prestamo,
            "tipo": self.tipo,
            "curp_actor": self.curp_actor,
            "estado_anterior": self.estado_anterior,
            "estado_nuevo": self.estado_nuevo,
            "motivo": self.motivo,
            "metadata": self.metadata_json,
            "fecha": self.fecha.isoformat() if self.fecha else None,
        }


class CuotaPrestamo(db.Model):
    __tablename__ = "cuota_prestamo"

    id_cuota = db.Column(db.Integer, primary_key=True, autoincrement=True)
    id_prestamo = db.Column(
        db.Integer,
        db.ForeignKey("prestamo.id_prestamo", ondelete="CASCADE"),
        nullable=False,
    )
    numero = db.Column(db.Integer, nullable=False)
    fecha_vencimiento = db.Column(db.Date, nullable=False)
    monto_cuota = db.Column(db.Numeric(15, 2), nullable=False)
    pagada = db.Column(db.Boolean, nullable=False, default=False)
    fecha_pago = db.Column(db.Date)

    def to_dict(self) -> dict:
        return {
            "id_cuota": self.id_cuota,
            "id_prestamo": self.id_prestamo,
            "numero": self.numero,
            "fecha_vencimiento": self.fecha_vencimiento.strftime("%Y-%m-%d")
            if self.fecha_vencimiento
            else None,
            "monto_cuota": float(self.monto_cuota),
            "pagada": self.pagada,
            "fecha_pago": self.fecha_pago.strftime("%Y-%m-%d")
            if self.fecha_pago
            else None,
        }
