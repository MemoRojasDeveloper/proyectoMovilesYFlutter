from decimal import Decimal

from ..extensions import db


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

    def to_dict(self) -> dict:
        return {
            "id_prestamo": self.id_prestamo,
            "curp": self.curp,
            "monto_otorgado": float(self.monto_otorgado),
            "tasa_interes": float(self.tasa_interes),
            "plazo_meses": self.plazo_meses,
            "fecha_aprobacion": self.fecha_aprobacion.strftime("%Y-%m-%d")
            if self.fecha_aprobacion
            else None,
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
