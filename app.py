import os
import stripe
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from dotenv import load_dotenv

# Cargar las variables del archivo .env
load_dotenv()

# Inicializar la aplicación Flask
app = Flask(__name__)

# Permitir acentos y caracteres especiales en los JSON de respuesta
app.json.ensure_ascii = False

# Configurar la conexión a la base de datos
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Inicializar SQLAlchemy
db = SQLAlchemy(app)

stripe.api_key = os.getenv('STRIPE_SECRET_KEY')

# ==========================================
# MODELOS DE LA BASE DE DATOS
# ==========================================

class Sucursal(db.Model):
    __tablename__ = 'sucursal'
    codigo_sucursal = db.Column(db.String(20), primary_key=True)
    nombre_sucursal = db.Column(db.String(100), nullable=False)
    direccion = db.Column(db.String(255))

class Cliente(db.Model):
    __tablename__ = 'cliente'
    curp = db.Column(db.String(18), primary_key=True)
    nombres = db.Column(db.String(100), nullable=False)
    apellido_paterno = db.Column(db.String(100), nullable=False)
    apellido_materno = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    telefono = db.Column(db.String(15))
    rol = db.Column(db.String(20), default='cliente')

class CuentaCorriente(db.Model):
    __tablename__ = 'cuenta_corriente'
    codigo_cuenta = db.Column(db.String(50), primary_key=True)
    codigo_sucursal = db.Column(db.String(20), db.ForeignKey('sucursal.codigo_sucursal', ondelete='RESTRICT', onupdate='CASCADE'), nullable=False)
    saldo = db.Column(db.Numeric(15, 2), default=0.00)
    fecha_apertura = db.Column(db.Date, nullable=False)

class Privilegio(db.Model):
    __tablename__ = 'privilegio'
    id_privilegio = db.Column(db.Integer, primary_key=True, autoincrement=True)
    nombre_operacion = db.Column(db.String(50), nullable=False, unique=True)
    descripcion = db.Column(db.String(255))

class ClienteCuentaPrivilegio(db.Model):
    __tablename__ = 'cliente_cuenta_privilegio'
    curp = db.Column(db.String(18), db.ForeignKey('cliente.curp', ondelete='CASCADE', onupdate='CASCADE'), primary_key=True)
    codigo_cuenta = db.Column(db.String(50), db.ForeignKey('cuenta_corriente.codigo_cuenta', ondelete='CASCADE', onupdate='CASCADE'), primary_key=True)
    id_privilegio = db.Column(db.Integer, db.ForeignKey('privilegio.id_privilegio', ondelete='CASCADE', onupdate='CASCADE'), primary_key=True)
    fecha_asignacion = db.Column(db.DateTime, default=db.func.current_timestamp())

class Domiciliacion(db.Model):
    __tablename__ = 'domiciliacion'
    id_domiciliacion = db.Column(db.Integer, primary_key=True, autoincrement=True)
    codigo_cuenta = db.Column(db.String(50), db.ForeignKey('cuenta_corriente.codigo_cuenta', ondelete='CASCADE', onupdate='CASCADE'), nullable=False)
    servicio = db.Column(db.String(100), nullable=False)
    monto_autorizado = db.Column(db.Numeric(10, 2))
    dia_cobro = db.Column(db.Integer, nullable=False)

class Prestamo(db.Model):
    __tablename__ = 'prestamo'
    id_prestamo = db.Column(db.Integer, primary_key=True, autoincrement=True)
    curp = db.Column(db.String(18), db.ForeignKey('cliente.curp', ondelete='CASCADE', onupdate='CASCADE'), nullable=False)
    monto_otorgado = db.Column(db.Numeric(15, 2), nullable=False)
    tasa_interes = db.Column(db.Numeric(5, 2), nullable=False)
    plazo_meses = db.Column(db.Integer, nullable=False)
    fecha_aprobacion = db.Column(db.Date, nullable=False)

# Ruta básica de prueba
@app.route('/')
def index():
    return {"mensaje": "API del Banco Santander funcionando correctamente"}

@app.route('/test-db')
def test_db():
    try:
        # Intentamos consultar la tabla Sucursal (aunque no tenga datos aún)
        Sucursal.query.first()
        return {"status": "success", "mensaje": "¡Conexión a la base de datos exitosa!"}
    except Exception as e:
        return {"status": "error", "mensaje": f"Error de conexión: {str(e)}"}

# ==========================================
# RUTAS DE LA API (Endpoints)
# ==========================================

# 1. Crear y Obtener Clientes
@app.route('/api/clientes', methods=['POST', 'GET'])
def gestionar_clientes():
    if request.method == 'POST':
        try:
            data = request.json
            nuevo_cliente = Cliente(
                curp=data['curp'],
                nombres=data['nombres'],
                apellido_paterno=data['apellido_paterno'],
                apellido_materno=data.get('apellido_materno'), # get() por si viene vacío
                email=data.get('email'),
                telefono=data.get('telefono')
            )
            db.session.add(nuevo_cliente)
            db.session.commit()
            return jsonify({"mensaje": "Cliente registrado con éxito"}), 201
            
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 400

    elif request.method == 'GET':
        clientes = Cliente.query.all()
        lista_clientes = []
        for c in clientes:
            lista_clientes.append({
                "curp": c.curp,
                "nombres": c.nombres,
                "apellido_paterno": c.apellido_paterno,
                "apellido_materno": c.apellido_materno,
                "email": c.email,
                "telefono": c.telefono
            })
        return jsonify(lista_clientes), 200
    
# 2. Crear y Obtener Sucursales
@app.route('/api/sucursales', methods=['POST', 'GET'])
def gestionar_sucursales():
    if request.method == 'POST':
        try:
            data = request.json
            nueva_sucursal = Sucursal(
                codigo_sucursal=data['codigo_sucursal'],
                nombre_sucursal=data['nombre_sucursal'],
                direccion=data.get('direccion')
            )
            db.session.add(nueva_sucursal)
            db.session.commit()
            return jsonify({"mensaje": "Sucursal registrada con éxito"}), 201
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 400

    elif request.method == 'GET':
        sucursales = Sucursal.query.all()
        return jsonify([{"codigo_sucursal": s.codigo_sucursal, "nombre_sucursal": s.nombre_sucursal, "direccion": s.direccion} for s in sucursales]), 200

# 3. Crear y Obtener Cuentas Corrientes
@app.route('/api/cuentas', methods=['POST', 'GET'])
def gestionar_cuentas():
    if request.method == 'POST':
        try:
            data = request.json
            nueva_cuenta = CuentaCorriente(
                codigo_cuenta=data['codigo_cuenta'],
                codigo_sucursal=data['codigo_sucursal'],
                saldo=data.get('saldo', 0.00),
                fecha_apertura=data['fecha_apertura']
            )
            db.session.add(nueva_cuenta)
            db.session.commit()
            return jsonify({"mensaje": "Cuenta registrada con éxito"}), 201
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 400

    elif request.method == 'GET':
        cuentas = CuentaCorriente.query.all()
        return jsonify([{
            "codigo_cuenta": c.codigo_cuenta, 
            "codigo_sucursal": c.codigo_sucursal, 
            "saldo": float(c.saldo), 
            "fecha_apertura": c.fecha_apertura.strftime('%Y-%m-%d')
        } for c in cuentas]), 200
    
# 4. Crear y Obtener Privilegios (Catálogo de operaciones)
@app.route('/api/privilegios', methods=['POST', 'GET'])
def gestionar_privilegios():
    if request.method == 'POST':
        try:
            data = request.json
            nuevo_privilegio = Privilegio(
                nombre_operacion=data['nombre_operacion'],
                descripcion=data.get('descripcion')
            )
            db.session.add(nuevo_privilegio)
            db.session.commit()
            return jsonify({"mensaje": "Privilegio registrado con éxito"}), 201
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 400

    elif request.method == 'GET':
        privilegios = Privilegio.query.all()
        return jsonify([{
            "id_privilegio": p.id_privilegio, 
            "nombre_operacion": p.nombre_operacion, 
            "descripcion": p.descripcion
        } for p in privilegios]), 200

# 5. Asignar un Privilegio a un Cliente sobre una Cuenta
@app.route('/api/asignar-privilegios', methods=['POST'])
def asignar_privilegio():
    try:
        data = request.json
        nueva_asignacion = ClienteCuentaPrivilegio(
            curp=data['curp'],
            codigo_cuenta=data['codigo_cuenta'],
            id_privilegio=data['id_privilegio']
        )
        db.session.add(nueva_asignacion)
        db.session.commit()
        return jsonify({"mensaje": "Privilegio asignado exitosamente"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 400
    
# 6. Crear y Obtener Domiciliaciones
@app.route('/api/domiciliaciones', methods=['POST', 'GET'])
def gestionar_domiciliaciones():
    if request.method == 'POST':
        try:
            data = request.json
            nueva_domiciliacion = Domiciliacion(
                codigo_cuenta=data['codigo_cuenta'],
                servicio=data['servicio'],
                monto_autorizado=data.get('monto_autorizado'),
                dia_cobro=data['dia_cobro']
            )
            db.session.add(nueva_domiciliacion)
            db.session.commit()
            return jsonify({"mensaje": "Domiciliación registrada con éxito"}), 201
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 400

    elif request.method == 'GET':
        domiciliaciones = Domiciliacion.query.all()
        return jsonify([{
            "id_domiciliacion": d.id_domiciliacion,
            "codigo_cuenta": d.codigo_cuenta,
            "servicio": d.servicio,
            "monto_autorizado": float(d.monto_autorizado) if d.monto_autorizado else None,
            "dia_cobro": d.dia_cobro
        } for d in domiciliaciones]), 200

# 7. Crear y Obtener Préstamos
@app.route('/api/prestamos', methods=['POST', 'GET'])
def gestionar_prestamos():
    if request.method == 'POST':
        try:
            data = request.json
            nuevo_prestamo = Prestamo(
                curp=data['curp'],
                monto_otorgado=data['monto_otorgado'],
                tasa_interes=data['tasa_interes'],
                plazo_meses=data['plazo_meses'],
                fecha_aprobacion=data['fecha_aprobacion']
            )
            db.session.add(nuevo_prestamo)
            db.session.commit()
            return jsonify({"mensaje": "Préstamo registrado con éxito"}), 201
        except Exception as e:
            db.session.rollback()
            return jsonify({"error": str(e)}), 400

    elif request.method == 'GET':
        prestamos = Prestamo.query.all()
        return jsonify([{
            "id_prestamo": p.id_prestamo,
            "curp": p.curp,
            "monto_otorgado": float(p.monto_otorgado),
            "tasa_interes": float(p.tasa_interes),
            "plazo_meses": p.plazo_meses,
            "fecha_aprobacion": p.fecha_aprobacion.strftime('%Y-%m-%d')
        } for p in prestamos]), 200
    
# 8. Procesar el pago de una domiciliación con Stripe
@app.route('/api/pagar-domiciliacion', methods=['POST'])
def pagar_domiciliacion():
    try:
        data = request.json
        id_domiciliacion = data['id_domiciliacion']

        # 1. Buscar la domiciliación en la BD
        domiciliacion = db.session.get(Domiciliacion, id_domiciliacion)
        if not domiciliacion:
            return jsonify({"error": "Domiciliación no encontrada"}), 404

        # 2. Buscar la cuenta asociada para ver si tiene saldo
        cuenta = db.session.get(CuentaCorriente, domiciliacion.codigo_cuenta)
        
        # Dejamos el monto como Decimal (manzana) para la base de datos
        monto_a_cobrar_bd = domiciliacion.monto_autorizado
        
        # Hacemos una copia en float (pera) para calcular los centavos de Stripe
        monto_a_cobrar_float = float(monto_a_cobrar_bd)

        # Comparamos manzana con manzana
        if cuenta.saldo < monto_a_cobrar_bd:
            return jsonify({"error": "Saldo insuficiente en la cuenta"}), 400

        # 3. Intentar hacer el cobro con Stripe (usamos la pera)
        monto_stripe = int(monto_a_cobrar_float * 100) 
        
        cargo = stripe.Charge.create(
            amount=monto_stripe,
            currency="mxn",
            source="tok_visa",
            description=f"Pago de domiciliación: {domiciliacion.servicio} (Cuenta {cuenta.codigo_cuenta})"
        )

        # 4. Si Stripe aprueba, descontamos el saldo (restamos manzana con manzana)
        cuenta.saldo -= monto_a_cobrar_bd
        db.session.commit()

        return jsonify({
            "mensaje": "Pago procesado exitosamente con Stripe y saldo actualizado",
            "recibo_stripe": cargo.receipt_url,
            "nuevo_saldo_cuenta": float(cuenta.saldo)
        }), 200

    except stripe.error.StripeError as e:
        return jsonify({"error": f"Error de pago con Stripe: {str(e)}"}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)