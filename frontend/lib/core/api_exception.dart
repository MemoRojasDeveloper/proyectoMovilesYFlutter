/// Excepciones específicas de la capa de red.
///
/// El backend Flask devuelve errores en formato `{ "error": "..." }` o
/// `{ "mensaje": "..." }`. Esta jerarquía encapsula todo lo que puede
/// pasar en una llamada HTTP para que las pantallas reaccionen con
/// mensajes en español.
library;

/// Errores que el backend reporta con su `status_code` HTTP.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String message;

  /// Cuando el backend puede asociar el error a un campo concreto
  /// (p.ej. `{"email": "Ya registrado"}`), se mapea aquí para que la
  /// UI lo muestre bajo el `TextFormField` correspondiente.
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ─────────────────────────────────────────────────────────────────
// 400 — datos inválidos
// ─────────────────────────────────────────────────────────────────
class ValidationApiException extends ApiException {
  ValidationApiException({
    required super.message,
    super.fieldErrors,
  }) : super(statusCode: 400);
}

// ─────────────────────────────────────────────────────────────────
// 401 — credenciales
// ─────────────────────────────────────────────────────────────────
class UnauthorizedApiException extends ApiException {
  UnauthorizedApiException({String message = 'Credenciales inválidas'})
      : super(statusCode: 401, message: message);
}

// ─────────────────────────────────────────────────────────────────
// 404 — no encontrado
// ─────────────────────────────────────────────────────────────────
class NotFoundApiException extends ApiException {
  NotFoundApiException({String message = 'Recurso no encontrado'})
      : super(statusCode: 404, message: message);
}

// ─────────────────────────────────────────────────────────────────
// 409 — conflicto (curp o email duplicados)
// ─────────────────────────────────────────────────────────────────
class ConflictApiException extends ApiException {
  ConflictApiException({String message = 'Conflicto'})
      : super(statusCode: 409, message: message);
}

// ─────────────────────────────────────────────────────────────────
// 5xx — server
// ─────────────────────────────────────────────────────────────────
class ServerApiException extends ApiException {
  ServerApiException({String message = 'Error del servidor', int? code})
      : super(statusCode: code ?? 500, message: message);
}

// ─────────────────────────────────────────────────────────────────
// red / timeout / sin conexión
// ─────────────────────────────────────────────────────────────────
class NetworkApiException extends ApiException {
  NetworkApiException({String message = 'Sin conexión con el servidor'})
      : super(statusCode: 0, message: message);
}
