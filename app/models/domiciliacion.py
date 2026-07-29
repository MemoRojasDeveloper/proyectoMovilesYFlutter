from ..extensions import db


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

    def to_dict(self) -> dict:
        return {
            "id_domiciliacion": self.id_domiciliacion,
            "codigo_cuenta": self.codigo_cuenta,
            "servicio": self.servicio,
            "monto_autorizado": float(self.monto_autorizado)
            if self.monto_autorizado is not None
            else None,
            "dia_cobro": self.dia_cobro,
        }
