/// Repositorio de autenticación: orquesta cliente HTTP + storage local.
///
/// Devuelve un `AuthResult` con el token, rol y datos del usuario
/// cuando la operación es exitosa; deja que las `ApiException`
/// se propaguen para que las pantallas las manejen.
library;

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';
import '../../core/theme.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? api,
    AuthStorage? storage,
    ThemeController? themeController,
  })  : _api = api ?? ApiClient(),
        _storage = storage ?? AuthStorage(),
        themeController = themeController;

  final ApiClient _api;
  final AuthStorage _storage;

  /// Controlador de tema inyectado para que las pantallas puedan
  /// mostrar el botón de cambio de tema sin imports circulares.
  final ThemeController? themeController;

  /// POST /api/auth/register
  Future<AuthResult> register({
    required String curp,
    required String nombres,
    required String apellidoPaterno,
    String? apellidoMaterno,
    required String email,
    String? telefono,
    required String password,
    required String codigoSucursal,
  }) async {
    final body = {
      'curp': curp,
      'nombres': nombres,
      'apellido_paterno': apellidoPaterno,
      if (apellidoMaterno != null && apellidoMaterno.isNotEmpty)
        'apellido_materno': apellidoMaterno,
      'email': email,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      'password': password,
      'codigo_sucursal': codigoSucursal,
    };

    final response = await _api.post('/api/auth/register', body: body);
    if (response is! Map<String, dynamic>) {
      throw ServerApiException();
    }

    final token = response['access_token'] as String? ?? '';
    final rol = response['rol'] as String? ?? 'cliente';

    if (token.isEmpty) {
      throw ServerApiException(message: 'El servidor no devolvió un token');
    }

    await _storage.save(
      token: token,
      rol: rol,
      curp: curp,
      email: email,
    );

    return AuthResult.fromJson(response, token: token, rol: rol);
  }

  /// POST /api/auth/login
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    });

    if (response is! Map<String, dynamic>) {
      throw ServerApiException();
    }

    final token = response['access_token'] as String? ?? '';
    final rol = response['rol'] as String? ?? 'cliente';
    if (token.isEmpty) {
      throw ServerApiException(message: 'El servidor no devolvió un token');
    }

    await _storage.save(
      token: token,
      rol: rol,
      curp: response['perfil'] is Map ? response['perfil']['curp'] as String? : null,
      email: email,
    );

    return AuthResult.fromJson(response, token: token, rol: rol);
  }

  /// GET /api/auth/me — útil para pantallas tras login.
  Future<AuthResult> me() async {
    final token = await _storage.token;
    if (token == null) {
      throw UnauthorizedApiException(message: 'No hay sesión activa');
    }
    final response = await _api.get('/api/auth/me', token: token);
    if (response is! Map<String, dynamic>) {
      throw ServerApiException();
    }
    return AuthResult.fromJson(
      response,
      token: token,
      rol: response['rol'] as String? ?? 'cliente',
    );
  }

  Future<void> logout() => _storage.clear();

  /// Devuelve true si hay un JWT guardado.
  Future<bool> hasSession() => _storage.isLoggedIn;

  Future<String?> storedRol() => _storage.rol;
}

/// Modelo del resultado de autenticación.
class AuthResult {
  AuthResult({
    required this.token,
    required this.rol,
    this.email,
    this.curp,
    this.nombres,
    this.apellidoPaterno,
    this.mensaje,
  });

  final String token;
  final String rol;
  final String? email;
  final String? curp;
  final String? nombres;
  final String? apellidoPaterno;
  final String? mensaje;

  bool get isEmpleado => rol == 'empleado';
  bool get isCliente => rol == 'cliente';

  factory AuthResult.fromJson(
    Map<String, dynamic> json, {
    required String token,
    required String rol,
  }) {
    final perfil = json['perfil'];
    return AuthResult(
      token: token,
      rol: rol,
      email: json['email'] as String?,
      curp: json['curp'] as String? ??
          (perfil is Map ? perfil['curp'] as String? : null),
      nombres: json['nombres'] as String? ??
          (perfil is Map ? perfil['nombres'] as String? : null),
      apellidoPaterno: json['apellido_paterno'] as String? ??
          (perfil is Map ? perfil['apellido_paterno'] as String? : null),
      mensaje: json['mensaje'] as String?,
    );
  }
}
