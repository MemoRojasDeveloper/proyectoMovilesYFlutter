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
    this.horario,
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
  final String? horario;
  final bool activo;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

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
      horario: json['horario'] as String?,
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

  /// GET /api/sucursales/<codigo>/cuentas
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
}

/// Cuenta corriente basica (modelo para vista).
class CuentaCorriente {
  const CuentaCorriente({
    required this.codigoCuenta,
    required this.codigoSucursal,
    required this.saldo,
    this.fechaApertura,
  });

  final String codigoCuenta;
  final String codigoSucursal;
  final double saldo;
  final DateTime? fechaApertura;

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

    return CuentaCorriente(
      codigoCuenta: json['codigo_cuenta'] as String,
      codigoSucursal: json['codigo_sucursal'] as String,
      saldo: parseSaldo(json['saldo']),
      fechaApertura: parseDate(json['fecha_apertura']),
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