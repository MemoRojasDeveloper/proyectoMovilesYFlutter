/// Repositorio HTTP del cliente contra el backend Flask.
///
/// Maneja todas las llamadas de la app del cliente:
///   - Sus cuentas (GET /api/clientes/<curp>/cuentas)
///   - Detalle / privilegios / domiciliaciones de una cuenta
///   - Transferencias entre cuentas
///   - Pago de domiciliaciones
///   - Préstamos (lista, simulacion, detalle, cuotas, pago)
///   - Acceso compartido a una cuenta (listar, compartir, editar,
///     quitar)
library;

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';

/// ────────────── Cuentas ──────────────

class ClienteCuenta {
  const ClienteCuenta({
    required this.codigoCuenta,
    required this.codigoSucursal,
    required this.saldo,
    this.fechaApertura,
    this.nombreSucursal,
    this.ciudad,
    this.activoSucursal,
    this.activo = true,
  });

  final String codigoCuenta;
  final String codigoSucursal;
  final double saldo;
  final DateTime? fechaApertura;
  final String? nombreSucursal;
  final String? ciudad;
  final bool? activoSucursal;

  /// Estado de la cuenta (`cuenta_corriente.activo`).
  final bool activo;

  factory ClienteCuenta.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double parseSaldo(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return ClienteCuenta(
      codigoCuenta: json['codigo_cuenta'] as String,
      codigoSucursal: json['codigo_sucursal'] as String,
      saldo: parseSaldo(json['saldo']),
      fechaApertura: parseDate(json['fecha_apertura']),
      nombreSucursal: json['nombre_sucursal'] as String?,
      ciudad: json['ciudad'] as String?,
      activoSucursal: json['activo_sucursal'] as bool?,
      activo: json['activo'] as bool? ?? true,
    );
  }
}

class ClienteCuentasResponse {
  const ClienteCuentasResponse({
    required this.curp,
    required this.nombre,
    required this.total,
    required this.saldoTotal,
    required this.cuentas,
  });
  final String curp;
  final String nombre;
  final int total;
  final double saldoTotal;
  final List<ClienteCuenta> cuentas;

  factory ClienteCuentasResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['cuentas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ClienteCuenta.fromJson)
        .toList();
    return ClienteCuentasResponse(
      curp: json['curp'] as String,
      nombre: json['nombre'] as String? ?? '',
      total: json['total'] as int? ?? list.length,
      saldoTotal: (json['saldo_total'] as num?)?.toDouble() ?? 0,
      cuentas: list,
    );
  }
}

/// ────────────── Privilegios ──────────────

class Privilegio {
  const Privilegio({
    required this.idPrivilegio,
    required this.nombreOperacion,
    this.descripcion,
    required this.loTiene,
  });
  final int idPrivilegio;
  final String nombreOperacion;
  final String? descripcion;
  final bool loTiene;

  factory Privilegio.fromJson(Map<String, dynamic> json) {
    return Privilegio(
      idPrivilegio: json['id_privilegio'] as int,
      nombreOperacion: json['nombre_operacion'] as String,
      descripcion: json['descripcion'] as String?,
      loTiene: json['lo_tiene'] as bool? ?? false,
    );
  }
}

class PrivilegiosResponse {
  const PrivilegiosResponse({
    required this.codigoCuenta,
    required this.privilegios,
  });
  final String codigoCuenta;
  final List<Privilegio> privilegios;

  factory PrivilegiosResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['privilegios'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Privilegio.fromJson)
        .toList();
    return PrivilegiosResponse(
      codigoCuenta: json['codigo_cuenta'] as String,
      privilegios: list,
    );
  }
}

/// ────────────── Domiciliaciones ──────────────

class Domiciliacion {
  const Domiciliacion({
    required this.idDomiciliacion,
    required this.codigoCuenta,
    required this.servicio,
    this.montoAutorizado,
    this.montoOriginal,
    this.montoTotalACobrar,
    this.recargoAcumulado = 0,
    required this.diaCobro,
    this.idCatalogoServicio,
    this.estado = 'activa',
    this.horasRetraso = 0,
    this.estaAtrasada = false,
    this.catalogo,
    this.fechaRegistro,
    this.fechaUltimoCobro,
    this.fechaLimitePago,
  });
  final int idDomiciliacion;
  final String codigoCuenta;
  final String servicio;
  final double? montoAutorizado;
  final double? montoOriginal;

  /// Monto que se cobra en el proximo ciclo (original + recargos).
  final double? montoTotalACobrar;
  final double recargoAcumulado;
  final int diaCobro;
  final int? idCatalogoServicio;
  final String estado;
  final int horasRetraso;
  final bool estaAtrasada;
  final CatalogoServicio? catalogo;
  final DateTime? fechaRegistro;
  final DateTime? fechaUltimoCobro;
  final DateTime? fechaLimitePago;

  bool get activa => estado == 'activa';

  factory Domiciliacion.fromJson(Map<String, dynamic> json) {
    double? parseMonto(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final catJson = json['catalogo'];
    return Domiciliacion(
      idDomiciliacion: json['id_domiciliacion'] as int,
      codigoCuenta: json['codigo_cuenta'] as String,
      servicio: json['servicio'] as String,
      montoAutorizado: parseMonto(json['monto_autorizado']),
      montoOriginal: parseMonto(json['monto_original']),
      montoTotalACobrar: parseMonto(json['monto_total_a_cobrar']),
      recargoAcumulado: parseMonto(json['recargo_acumulado']) ?? 0,
      diaCobro: json['dia_cobro'] as int,
      idCatalogoServicio: json['id_catalogo_servicio'] as int?,
      estado: json['estado'] as String? ?? 'activa',
      horasRetraso: json['horas_retraso'] as int? ?? 0,
      estaAtrasada: json['esta_atrasada'] as bool? ?? false,
      catalogo: catJson is Map<String, dynamic>
          ? CatalogoServicio.fromJson(catJson)
          : null,
      fechaRegistro: parseDate(json['fecha_registro']),
      fechaUltimoCobro: parseDate(json['fecha_ultimo_cobro']),
      fechaLimitePago: parseDate(json['fecha_limite_pago']),
    );
  }
}

class CatalogoServicio {
  const CatalogoServicio({
    required this.idCatalogoServicio,
    required this.tipoServicio,
    required this.nombreProveedor,
    required this.monto,
    this.descripcion,
    this.activo = true,
  });
  final int idCatalogoServicio;
  final String tipoServicio;
  final String nombreProveedor;
  final double monto;
  final String? descripcion;
  final bool activo;

  /// Icono segun el tipo de servicio.
  String get iconoSegunTipo {
    switch (tipoServicio) {
      case 'internet':
        return 'wifi';
      case 'luz':
        return 'bolt';
      case 'agua':
        return 'water_drop';
      default:
        return 'receipt_long';
    }
  }

  String get etiquetaTipo {
    switch (tipoServicio) {
      case 'internet':
        return 'Internet';
      case 'luz':
        return 'Luz';
      case 'agua':
        return 'Agua';
      default:
        return 'Otro';
    }
  }

  factory CatalogoServicio.fromJson(Map<String, dynamic> json) {
    double parseMonto(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return CatalogoServicio(
      idCatalogoServicio: json['id_catalogo_servicio'] as int,
      tipoServicio: json['tipo_servicio'] as String,
      nombreProveedor: json['nombre_proveedor'] as String,
      monto: parseMonto(json['monto']),
      descripcion: json['descripcion'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }
}

class CatalogoServiciosResponse {
  const CatalogoServiciosResponse({required this.servicios});
  final List<CatalogoServicio> servicios;

  factory CatalogoServiciosResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['servicios'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogoServicio.fromJson)
        .toList();
    return CatalogoServiciosResponse(servicios: list);
  }
}

/// ────────────── Movimientos (historial) ──────────────

class Movimiento {
  const Movimiento({
    required this.idMovimiento,
    required this.codigoCuenta,
    required this.tipo,
    required this.monto,
    this.contraparteCuenta,
    this.curpActor,
    this.actorNombre,
    this.concepto,
    this.idDomiciliacion,
    this.domiciliacionServicio,
    this.stripeChargeId,
    this.stripeReceiptUrl,
    this.fecha,
  });

  final int idMovimiento;
  final String codigoCuenta;
  final String tipo;
  final double monto;
  final String? contraparteCuenta;
  final String? curpActor;
  final String? actorNombre;
  final String? concepto;
  final int? idDomiciliacion;
  final String? domiciliacionServicio;
  final String? stripeChargeId;
  final String? stripeReceiptUrl;
  final DateTime? fecha;

  /// Etiqueta humanizada para el tipo de movimiento.
  String get etiquetaTipo {
    switch (tipo) {
      case 'transferencia_enviada':
        return 'Transferencia enviada';
      case 'transferencia_recibida':
        return 'Transferencia recibida';
      case 'pago_domiciliacion_manual':
        return 'Pago manual de servicio';
      case 'cobro_domiciliacion_auto':
        return 'Cobro automatico de servicio';
      case 'cobro_domiciliacion_recargo':
        return 'Recargo por atraso';
      case 'asignacion_empleado_suma':
        return 'Deposito de sucursal';
      case 'asignacion_empleado_resta':
        return 'Retiro de sucursal';
      case 'pago_prestamo_cuota':
        return 'Pago de cuota';
      default:
        return tipo;
    }
  }

  /// True si el monto salio de la cuenta (resta al saldo).
  bool get esSalida {
    switch (tipo) {
      case 'transferencia_enviada':
      case 'pago_domiciliacion_manual':
      case 'cobro_domiciliacion_auto':
      case 'cobro_domiciliacion_recargo':
      case 'asignacion_empleado_resta':
      case 'pago_prestamo_cuota':
        return true;
      default:
        return false;
    }
  }

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    double parseMonto(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return Movimiento(
      idMovimiento: json['id_movimiento'] as int,
      codigoCuenta: json['codigo_cuenta'] as String,
      tipo: json['tipo'] as String,
      monto: parseMonto(json['monto']),
      contraparteCuenta: json['contraparte_cuenta'] as String?,
      curpActor: json['curp_actor'] as String?,
      actorNombre: json['actor_nombre'] as String?,
      concepto: json['concepto'] as String?,
      idDomiciliacion: json['id_domiciliacion'] as int?,
      domiciliacionServicio: json['domiciliacion_servicio'] as String?,
      stripeChargeId: json['stripe_charge_id'] as String?,
      stripeReceiptUrl: json['stripe_receipt_url'] as String?,
      fecha: parseDate(json['fecha']),
    );
  }
}

class MovimientosResponse {
  const MovimientosResponse({
    required this.codigoCuenta,
    required this.total,
    required this.limite,
    required this.offset,
    required this.movimientos,
  });
  final String codigoCuenta;
  final int total;
  final int limite;
  final int offset;
  final List<Movimiento> movimientos;

  bool get hayMas => (offset + limite) < total;

  factory MovimientosResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['movimientos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Movimiento.fromJson)
        .toList();
    return MovimientosResponse(
      codigoCuenta: json['codigo_cuenta'] as String,
      total: json['total'] as int? ?? list.length,
      limite: json['limite'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      movimientos: list,
    );
  }
}

/// ────────────── Préstamos ──────────────

class Prestamo {
  const Prestamo({
    required this.idPrestamo,
    required this.curp,
    required this.montoOtorgado,
    required this.tasaInteres,
    required this.plazoMeses,
    this.curpSolicitante,
    this.fechaAprobacion,
    this.cuotaMensual,
    this.interesTotal,
    this.totalAPagar,
    this.estado = 'aprobado',
    this.motivoSolicitud,
    this.estadoDetalle = const {},
  });
  final int idPrestamo;
  final String curp;
  final String? curpSolicitante;
  final double montoOtorgado;
  final double tasaInteres;
  final int plazoMeses;
  final DateTime? fechaAprobacion;
  final double? cuotaMensual;
  final double? interesTotal;
  final double? totalAPagar;

  /// 'pendiente' | 'aprobado' | 'rechazado' | 'cancelado'
  final String estado;
  final String? motivoSolicitud;
  final Map<String, dynamic> estadoDetalle;

  factory Prestamo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double parseMonto(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    double? parseOpt(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final detalle = json['estado_detalle'];
    Map<String, dynamic> detalleMap = const {};
    if (detalle is Map<String, dynamic>) {
      detalleMap = detalle;
    }

    return Prestamo(
      idPrestamo: json['id_prestamo'] as int,
      curp: json['curp'] as String,
      curpSolicitante: json['curp_solicitante'] as String?,
      montoOtorgado: parseMonto(json['monto_otorgado']),
      tasaInteres: parseMonto(json['tasa_interes']),
      plazoMeses: json['plazo_meses'] as int,
      fechaAprobacion: parseDate(json['fecha_aprobacion']),
      cuotaMensual: parseOpt(json['cuota_mensual']),
      interesTotal: parseOpt(json['interes_total']),
      totalAPagar: parseOpt(json['total_a_pagar']),
      estado: json['estado'] as String? ?? 'aprobado',
      motivoSolicitud: json['motivo_solicitud'] as String?,
      estadoDetalle: detalleMap,
    );
  }
}

class Cuota {
  const Cuota({
    required this.idCuota,
    required this.idPrestamo,
    required this.numero,
    this.fechaVencimiento,
    required this.montoCuota,
    required this.pagada,
    this.fechaPago,
  });
  final int idCuota;
  final int idPrestamo;
  final int numero;
  final DateTime? fechaVencimiento;
  final double montoCuota;
  final bool pagada;
  final DateTime? fechaPago;

  factory Cuota.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double parseMonto(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return Cuota(
      idCuota: json['id_cuota'] as int,
      idPrestamo: json['id_prestamo'] as int,
      numero: json['numero'] as int,
      fechaVencimiento: parseDate(json['fecha_vencimiento']),
      montoCuota: parseMonto(json['monto_cuota']),
      pagada: json['pagada'] as bool? ?? false,
      fechaPago: parseDate(json['fecha_pago']),
    );
  }
}

class CuotasResponse {
  const CuotasResponse({
    required this.idPrestamo,
    required this.total,
    required this.pagadas,
    required this.pendientes,
    required this.saldoPendiente,
    required this.cuotas,
  });
  final int idPrestamo;
  final int total;
  final int pagadas;
  final int pendientes;
  final double saldoPendiente;
  final List<Cuota> cuotas;

  factory CuotasResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['cuotas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Cuota.fromJson)
        .toList();
    return CuotasResponse(
      idPrestamo: json['id_prestamo'] as int,
      total: json['total'] as int? ?? list.length,
      pagadas: json['pagadas'] as int? ?? 0,
      pendientes: json['pendientes'] as int? ?? 0,
      saldoPendiente: (json['saldo_pendiente'] as num?)?.toDouble() ?? 0,
      cuotas: list,
    );
  }
}

class SimulacionPrestamo {
  const SimulacionPrestamo({
    required this.montoOtorgado,
    required this.tasaInteres,
    required this.plazoMeses,
    required this.cuotaMensual,
    required this.interesTotal,
    required this.totalAPagar,
  });
  final double montoOtorgado;
  final double tasaInteres;
  final int plazoMeses;
  final double cuotaMensual;
  final double interesTotal;
  final double totalAPagar;

  factory SimulacionPrestamo.fromJson(Map<String, dynamic> json) {
    double p(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return SimulacionPrestamo(
      montoOtorgado: p(json['monto_otorgado']),
      tasaInteres: p(json['tasa_interes']),
      plazoMeses: json['plazo_meses'] as int,
      cuotaMensual: p(json['cuota_mensual']),
      interesTotal: p(json['interes_total']),
      totalAPagar: p(json['total_a_pagar']),
    );
  }
}

/// ────────────── Repositorio ──────────────

class ClienteRepository {
  ClienteRepository({ApiClient? api, AuthStorage? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? AuthStorage();

  final ApiClient _api;
  final AuthStorage _storage;

  Future<String> _token() async {
    final t = await _storage.token;
    if (t == null || t.isEmpty) {
      throw UnauthorizedApiException(message: 'No hay sesión activa');
    }
    return t;
  }

  Future<ClienteCuentasResponse> obtenerCuentas(String curp) async {
    final tok = await _token();
    final res = await _api.get('/api/clientes/${curp.toUpperCase()}/cuentas', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return ClienteCuentasResponse.fromJson(res);
  }

  Future<ClienteCuenta> obtenerDetalleCuenta(String codigo) async {
    final tok = await _token();
    final res = await _api.get('/api/cuentas/${codigo.toUpperCase()}', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final c = ClienteCuenta.fromJson(res);
    return c;
  }

  Future<PrivilegiosResponse> obtenerPrivilegios(String codigo) async {
    final tok = await _token();
    final res = await _api.get('/api/cuentas/${codigo.toUpperCase()}/privilegios', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return PrivilegiosResponse.fromJson(res);
  }

  Future<List<Domiciliacion>> obtenerDomiciliaciones(String codigo) async {
    final tok = await _token();
    final res = await _api.get('/api/cuentas/${codigo.toUpperCase()}/domiciliaciones', token: tok);
    if (res is! List) {
      throw ServerApiException();
    }
    return res.whereType<Map<String, dynamic>>().map(Domiciliacion.fromJson).toList();
  }

  Future<Map<String, dynamic>> transferir({
    required String codigoCuenta,
    required String curpDestino,
    required double monto,
    String? concepto,
  }) async {
    final tok = await _token();
    final res = await _api.post(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/transferir',
      body: {
        'curp_destino': curpDestino.toUpperCase(),
        'monto': monto,
        if (concepto != null && concepto.isNotEmpty) 'concepto': concepto,
      },
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  Future<Map<String, dynamic>> pagarDomiciliacion({
    required String codigoCuenta,
    required int idDomiciliacion,
  }) async {
    final tok = await _token();
    final res = await _api.patch(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/domiciliaciones/$idDomiciliacion/pagar',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  Future<List<Prestamo>> obtenerPrestamos(String curp) async {
    final tok = await _token();
    final res = await _api.get(
      '/api/clientes/${curp.toUpperCase()}/prestamos',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return (res['prestamos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Prestamo.fromJson)
        .toList();
  }

  Future<Prestamo> obtenerDetallePrestamo(int id) async {
    final tok = await _token();
    final res = await _api.get('/api/prestamos/$id', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return Prestamo.fromJson(res);
  }

  Future<CuotasResponse> obtenerCuotas(int idPrestamo) async {
    final tok = await _token();
    final res = await _api.get('/api/prestamos/$idPrestamo/cuotas', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return CuotasResponse.fromJson(res);
  }

  Future<Map<String, dynamic>> pagarCuota(int idCuota) async {
    final tok = await _token();
    final res = await _api.patch('/api/prestamos/cuotas/$idCuota/pagar', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// Simulacion de prestamo (no requiere token porque el endpoint
  /// /api/prestamos/simular es publico).
  Future<SimulacionPrestamo> simular({
    required double monto,
    required double tasa,
    required int plazo,
  }) async {
    final res = await _api.post('/api/prestamos/simular', body: {
      'monto_otorgado': monto,
      'tasa_interes': tasa,
      'plazo_meses': plazo,
    });
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return SimulacionPrestamo.fromJson(res);
  }

  /// ──────────── Solicitud de préstamos (workflow nuevo) ────────────

  /// Solicita un préstamo. Curp = titular de la cuenta.
  /// El solicitante puede ser el titular o alguien con permiso 'solicitar_prestamo'.
  Future<Prestamo> solicitarPrestamo({
    required String curpTitular,
    required String codigoCuenta,
    required double monto,
    required double tasa,
    required int plazo,
    required String motivo,
  }) async {
    final tok = await _token();
    final res = await _api.post(
      '/api/clientes/${curpTitular.toUpperCase()}/prestamos/solicitar',
      body: {
        'codigo_cuenta': codigoCuenta.toUpperCase(),
        'monto_otorgado': monto,
        'tasa_interes': tasa,
        'plazo_meses': plazo,
        'motivo_solicitud': motivo,
      },
      token: tok,
    );
    if (res is! Map<String, dynamic> || res['prestamo'] is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return Prestamo.fromJson(res['prestamo'] as Map<String, dynamic>);
  }

  /// Cancela una solicitud pendiente (la que el usuario autenticado haya hecho).
  Future<Prestamo> cancelarSolicitud(int idPrestamo, {String? motivo}) async {
    final tok = await _token();
    final res = await _api.patch(
      '/api/prestamos/$idPrestamo/cancelar',
      body: {'motivo': motivo ?? 'Cancelado por el usuario'},
      token: tok,
    );
    if (res is! Map<String, dynamic> || res['prestamo'] is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return Prestamo.fromJson(res['prestamo'] as Map<String, dynamic>);
  }

  /// Historial de eventos del préstamo.
  Future<List<dynamic>> obtenerEventos(int idPrestamo) async {
    final tok = await _token();
    final res = await _api.get(
      '/api/prestamos/$idPrestamo/eventos',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return (res['eventos'] as List? ?? const []);
  }

  /// ──────────── Acceso compartido a cuenta ────────────

  /// Catálogo de privilegios que el frontend sabe manejar.
  /// El backend rechaza cualquier nombre desconocido.
  /// `etiqueta` es la versión humanizada (con espacios y "ñ") que se
  /// muestra en la UI; `nombre` es el identificador que viaja al backend.
  static const List<PrivilegioCatalogo> catalogoPrivilegios = [
    PrivilegioCatalogo(
      nombre: 'consultar_saldo',
      etiqueta: 'Consultar saldo',
      descripcion: 'Ver saldo y datos de la cuenta',
    ),
    PrivilegioCatalogo(
      nombre: 'transferir',
      etiqueta: 'Transferir',
      descripcion: 'Realizar transferencias a otras cuentas',
    ),
    PrivilegioCatalogo(
      nombre: 'pagar_domiciliacion',
      etiqueta: 'Pagar domiciliación',
      descripcion: 'Pagar las domiciliaciones asociadas',
    ),
    PrivilegioCatalogo(
      nombre: 'solicitar_prestamo',
      etiqueta: 'Solicitar préstamo',
      descripcion: 'Pedir préstamos a nombre del titular (requiere aprobación)',
    ),
    PrivilegioCatalogo(
      nombre: 'cerrar_cuenta',
      etiqueta: 'Cerrar cuenta',
      descripcion: 'Cerrar la cuenta y administrar accesos',
    ),
  ];

  /// Devuelve la etiqueta humanizada para un nombre de operacion.
  /// Si el nombre no esta en el catalogo, lo humaniza con una
  /// heuristica simple (snake_case -> palabras capitalizadas).
  static String etiquetaDe(String nombreOperacion) {
    for (final p in catalogoPrivilegios) {
      if (p.nombre == nombreOperacion) return p.etiqueta;
    }
    return _humanizar(nombreOperacion);
  }

  static String _humanizar(String s) {
    final partes = s.split('_');
    return partes
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  /// GET `/api/cuentas/<codigo>/usuarios`
  Future<UsuariosCuentaResponse> obtenerUsuariosCuenta(String codigo) async {
    final tok = await _token();
    final res = await _api.get(
      '/api/cuentas/${codigo.toUpperCase()}/usuarios',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return UsuariosCuentaResponse.fromJson(res);
  }

  /// POST `/api/cuentas/<codigo>/usuarios`
  Future<Map<String, dynamic>> compartirCuenta({
    required String codigoCuenta,
    required String curp,
    required List<String> privilegios,
  }) async {
    final tok = await _token();
    final res = await _api.post(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/usuarios',
      body: {
        'curp': curp.toUpperCase(),
        'privilegios': privilegios,
      },
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// PATCH `/api/cuentas/<codigo>/usuarios/<curp>`
  Future<Map<String, dynamic>> actualizarPrivilegiosUsuario({
    required String codigoCuenta,
    required String curp,
    required List<String> privilegios,
  }) async {
    final tok = await _token();
    final res = await _api.patch(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/usuarios/${curp.toUpperCase()}',
      body: {'privilegios': privilegios},
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// DELETE `/api/cuentas/<codigo>/usuarios/<curp>`
  Future<Map<String, dynamic>> quitarAccesoUsuario({
    required String codigoCuenta,
    required String curp,
  }) async {
    final tok = await _token();
    final res = await _api.delete(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/usuarios/${curp.toUpperCase()}',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// ──────────── Catalogo y domiciliaciones (pagos) ────────────

  /// GET `/api/catalogo-servicios` (publico, sin token)
  Future<CatalogoServiciosResponse> obtenerCatalogoServicios() async {
    final res = await _api.get('/api/catalogo-servicios');
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return CatalogoServiciosResponse.fromJson(res);
  }

  /// POST `/api/domiciliaciones`
  Future<Map<String, dynamic>> domiciliar({
    required String codigoCuenta,
    required int idCatalogoServicio,
  }) async {
    final tok = await _token();
    final res = await _api.post(
      '/api/domiciliaciones',
      body: {
        'codigo_cuenta': codigoCuenta.toUpperCase(),
        'id_catalogo_servicio': idCatalogoServicio,
      },
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// DELETE `/api/domiciliaciones/<id>` (solo empleado)
  Future<Map<String, dynamic>> darBajaDomiciliacion(int idDomiciliacion) async {
    final tok = await _token();
    final res = await _api.delete(
      '/api/domiciliaciones/$idDomiciliacion',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// PATCH `/api/cuentas/<codigo>/saldo` (solo empleado)
  Future<Map<String, dynamic>> asignarSaldo({
    required String codigoCuenta,
    required double monto,
    required String operacion, // 'sumar' o 'restar'
    String? motivo,
  }) async {
    final tok = await _token();
    final res = await _api.patch(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/saldo',
      body: {
        'monto': monto,
        'operacion': operacion,
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      },
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// GET `/api/cuentas/<codigo>/movimientos?limite=N&offset=N`
  /// Historial paginado, ordenado por fecha DESC.
  Future<MovimientosResponse> obtenerMovimientos(
    String codigoCuenta, {
    int limite = 20,
    int offset = 0,
  }) async {
    final tok = await _token();
    final res = await _api.get(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/movimientos'
      '?limite=$limite&offset=$offset',
      token: tok,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return MovimientosResponse.fromJson(res);
  }
}

/// ──────────── Modelos para acceso compartido ────────────

class PrivilegioCatalogo {
  const PrivilegioCatalogo({
    required this.nombre,
    required this.etiqueta,
    required this.descripcion,
  });
  final String nombre;

  /// Texto que se muestra al usuario. Es la versión humanizada
  /// (con espacios y "ñ") del nombre interno.
  final String etiqueta;
  final String descripcion;
}

class CuentaUsuario {
  const CuentaUsuario({
    required this.curp,
    required this.nombreCompleto,
    this.email,
    required this.activo,
    this.fechaAsignacion,
    required this.esDueno,
    required this.privilegios,
  });

  final String curp;
  final String nombreCompleto;
  final String? email;
  final bool activo;
  final DateTime? fechaAsignacion;
  final bool esDueno;
  final List<String> privilegios;

  bool tienePrivilegio(String nombre) => privilegios.contains(nombre);

  factory CuentaUsuario.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final list = (json['privilegios'] as List? ?? const [])
        .whereType<String>()
        .toList();

    return CuentaUsuario(
      curp: json['curp'] as String,
      nombreCompleto: (json['nombre_completo'] as String?) ?? '',
      email: json['email'] as String?,
      activo: json['activo'] as bool? ?? true,
      fechaAsignacion: parseDate(json['fecha_asignacion']),
      esDueno: json['es_dueno'] as bool? ?? false,
      privilegios: list,
    );
  }
}

class UsuariosCuentaResponse {
  const UsuariosCuentaResponse({
    required this.codigoCuenta,
    required this.total,
    required this.usuarios,
  });

  final String codigoCuenta;
  final int total;
  final List<CuentaUsuario> usuarios;

  /// Devuelve el usuario cuyo curp coincide (o null).
  CuentaUsuario? buscarPorCurp(String curp) {
    final up = curp.toUpperCase();
    for (final u in usuarios) {
      if (u.curp.toUpperCase() == up) return u;
    }
    return null;
  }

  /// Devuelve true si el curp actual tiene el privilegio `cerrar_cuenta`.
  bool esDueno(String curp) {
    final u = buscarPorCurp(curp);
    return u?.esDueno ?? false;
  }

  factory UsuariosCuentaResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['usuarios'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CuentaUsuario.fromJson)
        .toList();
    return UsuariosCuentaResponse(
      codigoCuenta: json['codigo_cuenta'] as String,
      total: json['total'] as int? ?? list.length,
      usuarios: list,
    );
  }
}