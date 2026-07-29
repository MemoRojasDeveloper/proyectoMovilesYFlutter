from ..extensions import db

ROLES_PERMITIDOS = ("cliente", "empleado")
ROL_POR_DEFECTO = "cliente"


class Cliente(db.Model):
    __tablename__ = "cliente"

    curp = db.Column(db.String(18), primary_key=True)
    nombres = db.Column(db.String(100), nullable=False)
    apellido_paterno = db.Column(db.String(100), nullable=False)
    apellido_materno = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    telefono = db.Column(db.String(15))

    # Diferencia un cliente del banco de un usuario-administrador.
    # Por defecto 'cliente'. Solo el alta manual en BD puede
    # crear un 'empleado'.
    rol = db.Column(
        db.String(20),
        nullable=False,
        default=ROL_POR_DEFECTO,
        server_default=ROL_POR_DEFECTO,
    )

    def to_dict(self) -> dict:
        return {
            "curp": self.curp,
            "nombres": self.nombres,
            "apellido_paterno": self.apellido_paterno,
            "apellido_materno": self.apellido_materno,
            "email": self.email,
            "telefono": self.telefono,
            "rol": self.rol,
        }

    @property
    def is_empleado(self) -> bool:
        return self.rol == "empleado"
