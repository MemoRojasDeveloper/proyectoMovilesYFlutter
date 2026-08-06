/// Validadores regex compartidos cliente ↔ backend.
///
/// ESTAS REGLAS SON LA FUENTE DE VERDAD. El backend Flask vive en
/// `app/utils/validation.py` y debe usar exactamente estas mismas
/// regex. Si cambias una, cambia la otra.
///
/// Mantén los mensajes cortos y claros: el usuario los ve bajo cada
/// campo. Sin jerga técnica.
library;

class Validators {
  Validators._();

  /// CURP oficial mexicana — 18 caracteres con estructura validada.
  static final RegExp _curp = RegExp(
    r'^[A-Z]{4}\d{6}[HM][A-Z]{2}[BCDFGHJKLMNPQRSTVWXYZ]{3}[A-Z0-9]\d$',
  );

  /// RFC 5322 simplificado — cubre el 99% de emails reales.
  static final RegExp _email =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  /// Mínimo 8 chars, 1 minúscula + 1 mayúscula + 1 dígito.
  static final RegExp _password = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$',
  );

  /// 10 dígitos; prefijo +52 opcional. Acepta espacios/guiones.
  static final RegExp _telefono = RegExp(r'^(\+?52\s?)?\d{10}$');

  /// Letras Unicode (con acentos y ñ), espacios, apóstrofes y guiones.
  static final RegExp _nombre = RegExp(
    r"^[A-Za-z"
    r"\u00C0-\u00D6"
    r"\u00D8-\u00F6"
    r"\u00F8-\u02FF"
    r"\u1E00-\u1EFF"
    r"'\- ]{2,100}$",
  );

  /// ─────────────────────────────────────────────────────────────────
  /// Validadores que devuelven `null` si OK, o un mensaje de error.
  /// Ideales para `TextFormField.validator`.
  /// ─────────────────────────────────────────────────────────────────

  static String? curp(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'CURP es obligatorio';
    if (v.length != 18) return 'CURP debe tener 18 caracteres';
    if (!_curp.hasMatch(v)) return 'CURP con formato inválido';
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Email es obligatorio';
    if (v.length > 120) return 'Email demasiado largo';
    if (!_email.hasMatch(v)) return 'Email con formato inválido';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Contraseña es obligatoria';
    if (!_password.hasMatch(v)) {
      return 'Mínimo 8 caracteres con mayúscula, minúscula y un dígito';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? telefono(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (v.isEmpty) return null; // opcional
    if (!_telefono.hasMatch(v)) {
      return 'Teléfono inválido (10 dígitos, opcional +52)';
    }
    return null;
  }

  static String? nombre(String? value, {String campo = 'Este campo'}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '$campo es obligatorio';
    if (!_nombre.hasMatch(v)) {
      return '$campo contiene caracteres no permitidos';
    }
    return null;
  }

  /// Normaliza un teléfono quitando espacios/guiones. Devuelve null si
  /// no es válido.
  static String? normalizarTelefono(String? value) {
    if (value == null) return null;
    final limpio = value.replaceAll(RegExp(r'[\s-]'), '');
    if (limpio.isEmpty) return null;
    return _telefono.hasMatch(limpio) ? limpio : null;
  }

  /// Convierte el CURP a mayúsculas en el acto (atajo para
  /// `onChanged` en el `TextFormField`).
  static String normalizeCurp(String value) => value.toUpperCase();

  /// Normaliza el email a minúsculas + trim.
  static String normalizeEmail(String value) => value.trim().toLowerCase();
}
