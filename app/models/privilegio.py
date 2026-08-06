from ..extensions import db


class Privilegio(db.Model):
    __tablename__ = "privilegio"

    id_privilegio = db.Column(db.Integer, primary_key=True, autoincrement=True)
    nombre_operacion = db.Column(db.String(50), nullable=False, unique=True)
    descripcion = db.Column(db.String(255))

    def to_dict(self) -> dict:
        return {
            "id_privilegio": self.id_privilegio,
            "nombre_operacion": self.nombre_operacion,
            "descripcion": self.descripcion,
        }


class ClienteCuentaPrivilegio(db.Model):
    __tablename__ = "cliente_cuenta_privilegio"

    curp = db.Column(
        db.String(18),
        db.ForeignKey("cliente.curp", ondelete="CASCADE", onupdate="CASCADE"),
        primary_key=True,
    )
    codigo_cuenta = db.Column(
        db.String(50),
        db.ForeignKey(
            "cuenta_corriente.codigo_cuenta",
            ondelete="CASCADE",
            onupdate="CASCADE",
        ),
        primary_key=True,
    )
    id_privilegio = db.Column(
        db.Integer,
        db.ForeignKey(
            "privilegio.id_privilegio", ondelete="CASCADE", onupdate="CASCADE"
        ),
        primary_key=True,
    )
    fecha_asignacion = db.Column(
        db.DateTime, default=db.func.current_timestamp()
    )
