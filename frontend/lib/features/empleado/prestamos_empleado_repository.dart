/// Repositorio de prestamos para el dashboard del empleado.
///
/// Cola de pendientes, aprobar, rechazar, ver historial.
library;

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';

class PrestamoEmpleado {
  const PrestamoEmpleado({
    required this.idPrestamo,
    required this.curp,
    this.curpSolicitante,
    required this.montoOtorgado,
    required this.tasaInteres,
    required this.plazoMeses,
    this.fechaAprobacion,
    this.estado = 'pendiente',
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
  final String estado;
  final String? motivoSolicitud;
  final Map<String, dynamic> estadoDetalle;

  factory PrestamoEmpleado.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double parseMonto(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final detalle = json['estado_detalle'];
    Map<String, dynamic> detalleMap = const {};
    if (detalle is Map<String, dynamic>) detalleMap = detalle;

    return PrestamoEmpleado(
      idPrestamo: json['id_prestamo'] as int,
      curp: json['curp'] as String,
      curpSolicitante: json['curp_solicitante'] as String?,
      montoOtorgado: parseMonto(json['monto_otorgado']),
      tasaInteres: parseMonto(json['tasa_interes']),
      plazoMeses: json['plazo_meses'] as int,
      fechaAprobacion: parseDate(json['fecha_aprobacion']),
      estado: json['estado'] as String? ?? 'pendiente',
      motivoSolicitud: json['motivo_solicitud'] as String?,
      estadoDetalle: detalleMap,
    );
  }
}

class PrestamosEmpleadoRepository {
  PrestamosEmpleadoRepository({ApiClient? api, AuthStorage? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? AuthStorage();

  final ApiClient _api;
  final AuthStorage _storage;

  Future<String?> _token() => _storage.token;

  /// GET /api/prestamos/pendientes
  Future<List<PrestamoEmpleado>> listarPendientes() async {
    final tok = await _token();
    final res = await _api.get('/api/prestamos/pendientes', token: tok);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return (res['prestamos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PrestamoEmpleado.fromJson)
        .toList();
  }

  /// GET /api/prestamos/<id>/eventos
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

  /// PATCH /api/prestamos/<id>/aprobar
  Future<PrestamoEmpleado> aprobar(int idPrestamo, String motivo) async {
    final tok = await _token();
    final res = await _api.patch(
      '/api/prestamos/$idPrestamo/aprobar',
      body: {'motivo': motivo},
      token: tok,
    );
    if (res is! Map<String, dynamic> || res['prestamo'] is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return PrestamoEmpleado.fromJson(
      res['prestamo'] as Map<String, dynamic>,
    );
  }

  /// PATCH /api/prestamos/<id>/rechazar
  Future<PrestamoEmpleado> rechazar(int idPrestamo, String motivo) async {
    final tok = await _token();
    final res = await _api.patch(
      '/api/prestamos/$idPrestamo/rechazar',
      body: {'motivo': motivo},
      token: tok,
    );
    if (res is! Map<String, dynamic> || res['prestamo'] is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return PrestamoEmpleado.fromJson(
      res['prestamo'] as Map<String, dynamic>,
    );
  }
}
