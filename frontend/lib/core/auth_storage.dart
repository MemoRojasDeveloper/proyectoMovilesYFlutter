/// Almacén del token JWT y datos básicos del usuario en
/// `SharedPreferences`.
///
/// El JWT y el `rol` / `curp` son opcionales (puede haber estado sin
/// sesión). Todo se expone vía getters nullable.
library;

import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _keyToken = 'jwt_token';
  static const _keyRol = 'auth_rol';
  static const _keyCurp = 'auth_curp';
  static const _keyEmail = 'auth_email';

  Future<void> save({
    required String token,
    required String rol,
    String? curp,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRol, rol);
    if (curp != null) await prefs.setString(_keyCurp, curp);
    if (email != null) await prefs.setString(_keyEmail, email);
  }

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<String?> get rol async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRol);
  }

  Future<String?> get curp async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurp);
  }

  Future<String?> get email async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  /// Devuelve true si hay token guardado (sesión activa).
  Future<bool> get isLoggedIn async {
    final t = await token;
    return t != null && t.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRol);
    await prefs.remove(_keyCurp);
    await prefs.remove(_keyEmail);
  }
}
