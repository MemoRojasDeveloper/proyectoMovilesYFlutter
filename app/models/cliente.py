from ..extensions import db


class Cliente(db.Model):
    __tablename__ = "cliente"

    curp = db.Column(db.String(18), primary_key=True)
    nombres = db.Column(db.String(100), nullable=False)
    apellido_paterno = db.Column(db.String(100), nullable=False)
    apellido_materno = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    telefono = db.Column(db.String(15))

    def to_dict(self) -> dict:
        return {
            "curp": self.curp,
            "nombres": self.nombres,
            "apellido_paterno": self.apellido_paterno,
            "apellido_materno": self.apellido_materno,
            "email": self.email,
            "telefono": self.telefono,
        }
