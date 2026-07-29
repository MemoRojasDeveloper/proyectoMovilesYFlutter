"""Fixtures compartidos por toda la suite de tests."""
from __future__ import annotations

from decimal import Decimal

import pytest

from app import create_app
from app.extensions import db as _db
from app.models import (
    Cliente,
    CuentaCorriente,
    Domiciliacion,
    Prestamo,
    Privilegio,
    Sucursal,
)


@pytest.fixture(scope="session")
def app():
    """Crea la app una sola vez por sesión con SQLite en memoria."""
    application = create_app("testing")
    application.config.update(TESTING=True)
    with application.app_context():
        _db.create_all()
        yield application
        _db.session.remove()
        _db.drop_all()


@pytest.fixture(autouse=True)
def _limpiar_tablas(app):
    """Trunca todas las tablas antes de cada test para aislarlos."""
    with app.app_context():
        # defensivo: aborta cualquier tx pendiente antes de truncar
        _db.session.rollback()
        for tabla in reversed(_db.metadata.sorted_tables):
            _db.session.execute(tabla.delete())
        _db.session.commit()
    # tambin rollback al final por si un test dejó algo a medias
    yield
    with app.app_context():
        try:
            _db.session.rollback()
        except Exception:
            pass


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def sucursal_factory(app):
    """Crea una sucursal válida en BD y devuelve su codigo_sucursal."""

    def _crear(codigo: str = "SUC-001", nombre: str = "Sucursal Centro") -> str:
        with app.app_context():
            s = Sucursal(codigo_sucursal=codigo, nombre_sucursal=nombre)
            _db.session.add(s)
            _db.session.commit()
            return s.codigo_sucursal

    return _crear


@pytest.fixture
def cliente_factory(app):
    def _crear(
        curp: str = "LOAJ900215HDFABCD00",
        nombres: str = "Juan",
        apellido_paterno: str = "Lopez",
        **kwargs,
    ) -> str:
        with app.app_context():
            c = Cliente(
                curp=curp,
                nombres=nombres,
                apellido_paterno=apellido_paterno,
                **kwargs,
            )
            _db.session.add(c)
            _db.session.commit()
            return c.curp

    return _crear


@pytest.fixture
def cuenta_factory(app):
    def _crear(
        codigo: str = "CTA-0001",
        codigo_sucursal: str = "SUC-001",
        saldo: str | Decimal = "1000.00",
        fecha_apertura: str = "2026-01-15",
    ) -> str:
        from datetime import date

        with app.app_context():
            c = CuentaCorriente(
                codigo_cuenta=codigo,
                codigo_sucursal=codigo_sucursal,
                saldo=Decimal(str(saldo)),
                fecha_apertura=date.fromisoformat(fecha_apertura),
            )
            _db.session.add(c)
            _db.session.commit()
            return c.codigo_cuenta

    return _crear


@pytest.fixture
def privilegio_factory(app):
    def _crear(
        nombre: str = "CONSULTAR_SALDO",
        descripcion: str = "Ver saldo",
        **kwargs,
    ) -> int:
        with app.app_context():
            p = Privilegio(
                nombre_operacion=nombre, descripcion=descripcion
            )
            _db.session.add(p)
            _db.session.commit()
            return p.id_privilegio

    return _crear


@pytest.fixture
def domiciliacion_factory(app):
    def _crear(
        codigo_cuenta: str = "CTA-0001",
        servicio: str = "CFE",
        monto: str | Decimal = "250.00",
        dia_cobro: int = 5,
    ) -> int:
        with app.app_context():
            d = Domiciliacion(
                codigo_cuenta=codigo_cuenta,
                servicio=servicio,
                monto_autorizado=Decimal(str(monto)),
                dia_cobro=dia_cobro,
            )
            _db.session.add(d)
            _db.session.commit()
            return d.id_domiciliacion

    return _crear


@pytest.fixture
def prestamo_factory(app):
    def _crear(curp: str, **kwargs) -> int:
        from datetime import date

        defaults = {
            "monto_otorgado": Decimal("50000.00"),
            "tasa_interes": Decimal("12.50"),
            "plazo_meses": 24,
            "fecha_aprobacion": date(2026, 1, 10),
        }
        defaults.update(kwargs)
        with app.app_context():
            p = Prestamo(curp=curp, **defaults)
            _db.session.add(p)
            _db.session.commit()
            return p.id_prestamo

    return _crear
