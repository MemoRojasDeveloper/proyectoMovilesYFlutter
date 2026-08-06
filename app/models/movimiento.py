"""Modelo append-only para el historial/auditoria de movimientos
de dinero en las cuentas corrientes.

Se registra CADA operacion que afecta el saldo:
  - transferencias (enviadas y recibidas, como dos filas)
  - pagos de domiciliaciones (manual o automatico)
  - recargos por atraso
  - asignaciones del empleado (suma/resta)
  - pagos de cuotas de prestamo (futuro)

La idea es que cualquier usuario con acceso a la cuenta pueda
ver "quien, cuando y por que" se movio el dinero.
"""
from __future__ import annotations

from ..extensions import db


# Tipos validos (alineados con el CHECK de la BD)
TIPO_TRANSFERENCIA_ENVIADA = "transferencia_enviada"
TIPO_TRANSFERENCIA_RECIBIDA = "transferencia_recibida"
TIPO_PAGO_DOMI_MANUAL = "pago_domiciliacion_manual"
TIPO_COBRO_DOMI_AUTO = "cobro_domiciliacion_auto"
TIPO_COBRO_DOMI_RECARGO = "cobro_domiciliacion_recargo"
TIPO_ASIG_EMP_SUMA = "asignacion_empleado_suma"
TIPO_ASIG_EMP_RESTA = "asignacion_empleado_resta"
TIPO_PAGO_PRESTAMO_CUOTA = "pago_prestamo_cuota"

TIPOS_VALIDOS = {
    TIPO_TRANSFERENCIA_ENVIADA,
    TIPO_TRANSFERENCIA_RECIBIDA,
    TIPO_PAGO_DOMI_MANUAL,
    TIPO_COBRO_DOMI_AUTO,
    TIPO_COBRO_DOMI_RECARGO,
    TIPO_ASIG_EMP_SUMA,
    TIPO_ASIG_EMP_RESTA,
    TIPO_PAGO_PRESTAMO_CUOTA,
}


class Movimiento(db.Model):
    __tablename__ = "movimiento"

    id_movimiento = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    codigo_cuenta = db.Column(
        db.String(50),
        db.ForeignKey(
            "cuenta_corriente.codigo_cuenta",
            ondelete="RESTRICT",
            onupdate="CASCADE",
        ),
        nullable=False,
    )
    tipo = db.Column(db.String(30), nullable=False)
    monto = db.Column(db.Numeric(12, 2), nullable=False)
    contraparte_cuenta = db.Column(db.String(50), nullable=True)
    curp_actor = db.Column(
        db.String(18),
        db.ForeignKey(
            "cliente.curp", ondelete="SET NULL", onupdate="CASCADE"
        ),
        nullable=True,
    )
    concepto = db.Column(db.String(255), nullable=True)
    id_domiciliacion = db.Column(
        db.Integer,
        db.ForeignKey(
            "domiciliacion.id_domiciliacion",
            ondelete="SET NULL",
            onupdate="CASCADE",
        ),
        nullable=True,
    )
    stripe_charge_id = db.Column(db.String(100), nullable=True)
    stripe_receipt_url = db.Column(db.String(255), nullable=True)
    fecha = db.Column(db.DateTime, default=db.func.current_timestamp())

    # Relaciones para poder sacar el nombre del actor facilmente
    actor = db.relationship("Cliente", lazy="joined", foreign_keys=[curp_actor])
    domiciliacion = db.relationship(
        "Domiciliacion", lazy="joined", foreign_keys=[id_domiciliacion]
    )

    def to_dict(self) -> dict:
        actor_nombre = None
        if self.actor is not None:
            actor_nombre = self.actor.nombre_completo
        domi_servicio = None
        if self.domiciliacion is not None:
            domi_servicio = self.domiciliacion.servicio
        return {
            "id_movimiento": self.id_movimiento,
            "codigo_cuenta": self.codigo_cuenta,
            "tipo": self.tipo,
            "monto": float(self.monto),
            "contraparte_cuenta": self.contraparte_cuenta,
            "curp_actor": self.curp_actor,
            "actor_nombre": actor_nombre,
            "concepto": self.concepto,
            "id_domiciliacion": self.id_domiciliacion,
            "domiciliacion_servicio": domi_servicio,
            "stripe_charge_id": self.stripe_charge_id,
            "stripe_receipt_url": self.stripe_receipt_url,
            "fecha": self.fecha.isoformat() if self.fecha else None,
        }