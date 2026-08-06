/// Repositorio de sucursales (solo accesible por empleados).
///
/// Habla con `GET/POST/PUT/PATCH/DELETE /api/sucursales` del backend.
/// El token JWT se inyecta desde `AuthStorage` en cada llamada.
library;

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';

class Sucursal {
  const Sucursal({
    required this.codigoSucursal,
    required this.nombreSucursal,
    this.calle,
    this.numero,
    this.colonia,
    this.ciudad,
    this.estado,
    this.codigoPostal,
    this.telefono,
    this.diasSemana,
    this.horaApertura,
    this.horaCierre,
    this.activo = true,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String codigoSucursal;
  final String nombreSucursal;
  final String? calle;
  final String? numero;
  final String? colonia;
  final String? ciudad;
  final String? estado;
  final String? codigoPostal;
  final String? telefono;

  /// Días de apertura como enteros 1..7 (1=Lun ... 7=Dom).
  /// Null si la sucursal no tiene horario configurado.
  final List<int>? diasSemana;

  /// Hora de apertura en formato "HH:MM" (24h).
  final String? horaApertura;

  /// Hora de cierre en formato "HH:MM" (24h).
  final String? horaCierre;

  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  /// Etiqueta humana del horario, p.ej. "L-V 09:00–18:00" o "L,M,V 09:00–18:00".
  /// Null si no hay horario.
  String? get horarioLabel {
    if (diasSemana == null || diasSemana!.isEmpty) return null;
    if (horaApertura == null || horaCierre == null) return null;
    const diasCorto = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final sorted = [...diasSemana!]..sort();
    final rango = sorted.length > 1 &&
            sorted.last - sorted.first == sorted.length - 1
        ? '${diasCorto[sorted.first - 1]}-${diasCorto[sorted.last - 1]}'
        : sorted.map((d) => diasCorto[d - 1]).join(',');
    return '$rango $horaApertura–$horaCierre';
  }

  String get direccionCorta {
    final partes = <String>[];
    if (calle != null && calle!.isNotEmpty) {
      partes.add(numero != null && numero!.isNotEmpty
          ? '$calle $numero'
          : calle!);
    }
    if (colonia != null && colonia!.isNotEmpty) partes.add('col. $colonia');
    if (ciudad != null && ciudad!.isNotEmpty) partes.add(ciudad!);
    if (estado != null && estado!.isNotEmpty) partes.add(estado!);
    if (codigoPostal != null && codigoPostal!.isNotEmpty) {
      partes.add('C.P. $codigoPostal');
    }
    return partes.isEmpty ? 'Sin dirección registrada' : partes.join(', ');
  }

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    List<int>? parseDias(Object? v) {
      if (v is List) {
        return v
            .whereType<num>()
            .map((n) => n.toInt())
            .toList(growable: false);
      }
      return null;
    }

    return Sucursal(
      codigoSucursal: json['codigo_sucursal'] as String,
      nombreSucursal: json['nombre_sucursal'] as String,
      calle: json['calle'] as String?,
      numero: json['numero'] as String?,
      colonia: json['colonia'] as String?,
      ciudad: json['ciudad'] as String?,
      estado: json['estado'] as String?,
      codigoPostal: json['codigo_postal'] as String?,
      telefono: json['telefono'] as String?,
      diasSemana: parseDias(json['dias_semana']),
      horaApertura: json['hora_apertura'] as String?,
      horaCierre: json['hora_cierre'] as String?,
      activo: json['activo'] as bool? ?? true,
      creadoEn: parseDate(json['creado_en']),
      actualizadoEn: parseDate(json['actualizado_en']),
    );
  }
}

class SucursalesRepository {
  SucursalesRepository({ApiClient? api, AuthStorage? storage})
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

  /// Devuelve el token si existe, o null si no (sin lanzar excepcion).
  Future<String?> _tokenOpt() async {
    final t = await _storage.token;
    if (t == null || t.isEmpty) return null;
    return t;
  }

  Future<List<Sucursal>> listar({bool? activo}) async {
    // Solo exigimos token cuando NO hay filtro de 'activo'.
    // '?activo=true' es publico (necesario para el registro).
    final qs = activo == null ? '' : '?activo=${activo ? 'true' : 'false'}';
    final token = activo == null ? await _token() : await _tokenOpt();
    final res = await _api.get('/api/sucursales$qs', token: token);
    if (res is! List) {
      throw ServerApiException();
    }
    return res
        .whereType<Map<String, dynamic>>()
        .map(Sucursal.fromJson)
        .toList();
  }

  /// GET `/api/sucursales/<codigo>/cuentas`
  Future<CuentasSucursalResponse> obtenerCuentas(String codigo) async {
    final token = await _token();
    final res = await _api.get(
      '/api/sucursales/${codigo.toUpperCase()}/cuentas',
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final cuentas = (res['cuentas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CuentaCorriente.fromJson)
        .toList();
    return CuentasSucursalResponse(
      codigoSucursal: res['codigo_sucursal'] as String,
      totalCuentas: res['total_cuentas'] as int? ?? cuentas.length,
      totalClientes: res['total_clientes'] as int? ?? 0,
      cuentas: cuentas,
    );
  }

  Future<Sucursal> obtener(String codigo) async {
    final token = await _token();
    final res = await _api.get('/api/sucursales/$codigo', token: token);
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return Sucursal.fromJson(res);
  }

  Future<Sucursal> crear(Map<String, dynamic> body) async {
    final token = await _token();
    final res = await _api.post(
      '/api/sucursales',
      body: body,
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final suc = res['sucursal'];
    if (suc is Map<String, dynamic>) {
      return Sucursal.fromJson(suc);
    }
    return Sucursal.fromJson(res);
  }

  Future<Sucursal> actualizar(
    String codigo,
    Map<String, dynamic> body,
  ) async {
    final token = await _token();
    final res = await _api.put(
      '/api/sucursales/$codigo',
      body: body,
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final suc = res['sucursal'];
    if (suc is Map<String, dynamic>) {
      return Sucursal.fromJson(suc);
    }
    return Sucursal.fromJson(res);
  }

  Future<Sucursal> toggleActivo(String codigo, bool activo) async {
    final token = await _token();
    final res = await _api.patch(
      '/api/sucursales/$codigo/activo',
      body: {'activo': activo},
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final suc = res['sucursal'];
    if (suc is Map<String, dynamic>) {
      return Sucursal.fromJson(suc);
    }
    return Sucursal.fromJson(res);
  }

  /// PATCH `/api/cuentas/<codigo>/activo`
  Future<CuentaCorriente> toggleActivoCuenta(
    String codigoCuenta,
    bool activo,
  ) async {
    final token = await _token();
    final res = await _api.patch(
      '/api/cuentas/${Uri.encodeComponent(codigoCuenta)}/activo',
      body: {'activo': activo},
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final cuenta = res['cuenta'];
    if (cuenta is Map<String, dynamic>) {
      return CuentaCorriente.fromJson(cuenta);
    }
    throw ServerApiException();
  }

  /// PATCH `/api/cuentas/<codigo>/sucursal`
  Future<CuentaCorriente> cambiarSucursalCuenta(
    String codigoCuenta,
    String nuevaSucursalCodigo,
  ) async {
    final token = await _token();
    final res = await _api.patch(
      '/api/cuentas/${Uri.encodeComponent(codigoCuenta)}/sucursal',
      body: {'codigo_sucursal': nuevaSucursalCodigo.toUpperCase()},
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    final cuenta = res['cuenta'];
    if (cuenta is Map<String, dynamic>) {
      return CuentaCorriente.fromJson(cuenta);
    }
    throw ServerApiException();
  }

  /// PATCH `/api/cuentas/<codigo>/saldo` (solo empleado)
  Future<Map<String, dynamic>> asignarSaldo({
    required String codigoCuenta,
    required double monto,
    required String operacion, // 'sumar' o 'restar'
    String? motivo,
  }) async {
    final token = await _token();
    final res = await _api.patch(
      '/api/cuentas/${codigoCuenta.toUpperCase()}/saldo',
      body: {
        'monto': monto,
        'operacion': operacion,
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      },
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }

  /// DELETE `/api/domiciliaciones/<id>` (solo empleado)
  Future<Map<String, dynamic>> darBajaDomiciliacion(int idDomiciliacion) async {
    final token = await _token();
    final res = await _api.delete(
      '/api/domiciliaciones/$idDomiciliacion',
      token: token,
    );
    if (res is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return res;
  }
}

/// Cuenta corriente basica (modelo para vista).
class CuentaCorriente {
  const CuentaCorriente({
    required this.codigoCuenta,
    required this.codigoSucursal,
    required this.saldo,
    this.activo = true,
    this.fechaApertura,
    this.domiciliaciones = const [],
  });

  final String codigoCuenta;
  final String codigoSucursal;
  final double saldo;
  final bool activo;
  final DateTime? fechaApertura;

  /// Lista cruda de domiciliaciones (de SucursalDetalle). Se mantiene
  /// como Map para que el codigo del empleado no dependa del modelo
  /// del cliente_repository. Solo lectura.
  final List<Map<String, dynamic>> domiciliaciones;

  factory CuentaCorriente.fromJson(Map<String, dynamic> json) {
    double parseSaldo(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    DateTime? parseDate(Object? v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    final domis = (json['domiciliaciones'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return CuentaCorriente(
      codigoCuenta: json['codigo_cuenta'] as String,
      codigoSucursal: json['codigo_sucursal'] as String,
      saldo: parseSaldo(json['saldo']),
      activo: json['activo'] as bool? ?? true,
      fechaApertura: parseDate(json['fecha_apertura']),
      domiciliaciones: domis,
    );
  }
}

/// Respuesta de `GET /api/sucursales/<codigo>/cuentas`.
class CuentasSucursalResponse {
  const CuentasSucursalResponse({
    required this.codigoSucursal,
    required this.totalCuentas,
    required this.totalClientes,
    required this.cuentas,
  });

  final String codigoSucursal;
  final int totalCuentas;
  final int totalClientes;
  final List<CuentaCorriente> cuentas;
}