/// Cliente HTTP minimalista para hablar con el backend Flask.
///
/// - La URL base se resuelve **una vez** desde la constante
///   `API_BASE_URL` (definida con `--dart-define API_BASE_URL=...` cuando
///   se compila la app).
/// - En desarrollo local con emulador Android usa `10.0.2.2:5000`
///   (el emulador ve `10.0.2.2` como el host del desarrollador).
/// - En web y otros destinos, `API_BASE_URL` se debe pasar en build.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// URL base del backend. Se define al compilar:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
///
/// Si no se define, se usa un fallback seguro para emulador.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

/// Timeout por defecto para todas las llamadas.
const Duration _defaultTimeout = Duration(seconds: 15);

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// GET con JWT opcional (sin prefijo `Bearer`).
  Future<dynamic> get(
    String path, {
    String? token,
    Duration timeout = _defaultTimeout,
  }) {
    return _send('GET', path, token: token, timeout: timeout);
  }

  /// POST con body JSON.
  Future<dynamic> post(
    String path, {
    Object? body,
    String? token,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      'POST',
      path,
      body: body ?? const <String, dynamic>{},
      token: token,
      timeout: timeout,
    );
  }

  /// PUT con body JSON.
  Future<dynamic> put(
    String path, {
    Object? body,
    String? token,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      'PUT',
      path,
      body: body ?? const <String, dynamic>{},
      token: token,
      timeout: timeout,
    );
  }

  /// PATCH con body JSON.
  Future<dynamic> patch(
    String path, {
    Object? body,
    String? token,
    Duration timeout = _defaultTimeout,
  }) {
    return _send(
      'PATCH',
      path,
      body: body ?? const <String, dynamic>{},
      token: token,
      timeout: timeout,
    );
  }

  /// DELETE sin body.
  Future<dynamic> delete(
    String path, {
    String? token,
    Duration timeout = _defaultTimeout,
  }) {
    return _send('DELETE', path, token: token, timeout: timeout);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    String? token,
    Duration timeout = _defaultTimeout,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(timeout);
          break;
        default:
          throw ApiException(
            statusCode: 0,
            message: 'Método HTTP no soportado: $method',
          );
      }
      return _decode(response);
    } on SocketException {
      throw NetworkApiException();
    } on TimeoutException {
      throw NetworkApiException(message: 'Tiempo de espera agotado');
    } on http.ClientException {
      throw NetworkApiException();
    }
  }

  /// Decodifica la respuesta y mapea errores a `ApiException`.
  dynamic _decode(http.Response response) {
    final int status = response.statusCode;
    final bool hasBody = response.body.isNotEmpty;
    Map<String, dynamic>? json;
    dynamic decoded; // admitimos tanto Map como List en respuestas 2xx
    if (hasBody) {
      try {
        decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {
        // body no era JSON, lo dejamos así
      }
    }

    if (status >= 200 && status < 300) {
      // Devuelve lo decodificado tal cual: puede ser Map (objeto) o List (array).
      // Si el body no era JSON válido, devolvemos el string crudo como fallback.
      return decoded ?? (hasBody ? response.body : null);
    }

    final String message =
        (json?['error'] as String?) ?? (json?['mensaje'] as String?) ?? _default(status);

    final Map<String, String> fieldErrors = _extractFieldErrors(json);

    switch (status) {
      case 400:
        return throw ValidationApiException(
          message: message,
          fieldErrors: fieldErrors,
        );
      case 401:
        return throw UnauthorizedApiException(message: message);
      case 404:
        return throw NotFoundApiException(message: message);
      case 409:
        return throw ConflictApiException(message: message);
      default:
        if (status >= 500) {
          return throw ServerApiException(message: message, code: status);
        }
        return throw ApiException(
          statusCode: status,
          message: message,
          fieldErrors: fieldErrors,
        );
    }
  }

  String _default(int status) {
    switch (status) {
      case 400:
        return 'Datos inválidos';
      case 401:
        return 'No autorizado';
      case 404:
        return 'No encontrado';
      case 409:
        return 'Conflicto';
      default:
        return status >= 500 ? 'Error del servidor' : 'Error $status';
    }
  }

  Map<String, String> _extractFieldErrors(Map<String, dynamic>? json) {
    if (json == null) return const {};
    final Map<String, String> out = {};
    json.forEach((key, value) {
      if (value is String &&
          key != 'error' &&
          key != 'mensaje' &&
          key != 'access_token' &&
          key != 'rol') {
        out[key] = value;
      }
    });
    return out;
  }

  void dispose() {
    _client.close();
  }
}
