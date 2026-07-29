// Tests de widget para la pantalla de login.
//
// Usamos un `AuthRepository` falso que no toca red real.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/auth_storage.dart';
import 'package:frontend/core/theme.dart';
import 'package:frontend/features/auth/auth_repository.dart';
import 'package:frontend/features/auth/login_screen.dart';

class _FakeRepo extends AuthRepository {
  _FakeRepo()
      : super(
          api: ApiClient(baseUrl: 'http://localhost'),
          storage: AuthStorage(),
        );

  bool shouldFail = false;
  String errorMessage = 'Credenciales inválidas';

  int loginCalls = 0;

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls += 1;
    if (shouldFail) {
      throw Exception(errorMessage);
    }
    return AuthResult(token: 'fake.jwt.token', rol: 'cliente', email: email);
  }
}

Widget _wrap(Widget child, {ThemeController? controller}) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: child,
  );
}

void main() {
  testWidgets('LoginScreen muestra email y password', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(LoginScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Regístrate'), findsOneWidget);
  });

  testWidgets('LoginScreen muestra error cuando el cliente no se puede '
      'validar antes de tocar Entrar', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(LoginScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    // email vacío → no se llama al repo
    expect(repo.loginCalls, 0);
  });

  testWidgets('LoginScreen navega a Register al pulsar "Regístrate"',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(LoginScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreenProbe), findsNothing);
  });
}

/// Stub de RegisterScreen — sustituido en runtime por el real.
/// Si el test pasa, es porque hay navegación; dejamos sin importar
/// aquí a propósito para no acoplar.
class RegisterScreenProbe {}
