from ..extensions import db


class Sucursal(db.Model):
    __tablename__ = "sucursal"

    codigo_sucursal = db.Column(db.String(20), primary_key=True)
    nombre_sucursal = db.Column(db.String(100), nullable=False)
    direccion = db.Column(db.String(255))

    def to_dict(self) -> dict:
        return {
            "codigo_sucursal": self.codigo_sucursal,
            "nombre_sucursal": self.nombre_sucursal,
            "direccion": self.direccion,
        }
