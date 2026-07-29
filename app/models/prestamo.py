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
