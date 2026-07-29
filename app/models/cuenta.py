from ..extensions import db


class CuentaCorriente(db.Model):
    __tablename__ = "cuenta_corriente"

    codigo_cuenta = db.Column(db.String(50), primary_key=True)
    codigo_sucursal = db.Column(
        db.String(20),
        db.ForeignKey(
            "sucursal.codigo_sucursal", ondelete="RESTRICT", onupdate="CASCADE"
        ),
        nullable=False,
    )
    saldo = db.Column(db.Numeric(15, 2), default=0.00)
    fecha_apertura = db.Column(db.Date, nullable=False)

    def to_dict(self) -> dict:
        return {
            "codigo_cuenta": self.codigo_cuenta,
            "codigo_sucursal": self.codigo_sucursal,
            "saldo": float(self.saldo) if self.saldo is not None else 0.0,
            "fecha_apertura": self.fecha_apertura.strftime("%Y-%m-%d")
            if self.fecha_apertura
            else None,
        }
