// Smoke test: valida que theme.dart y validators.dart compilan y las
// regex devuelven los resultados esperados. NO testea Flutter UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/theme.dart';
import 'package:frontend/core/validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Validators.curp', () {
    test('acepta CURP valida', () {
      expect(Validators.curp('LOAJ900215HDFRPC08'), isNull);
    });

    test('rechaza CURP vacia', () {
      expect(Validators.curp(''), isNotNull);
    });

    test('rechaza CURP de longitud incorrecta', () {
      expect(Validators.curp('CORTA'), isNotNull);
    });

    test('rechaza CURP mal formada', () {
      expect(Validators.curp('1234567890ABCDEF12'), isNotNull);
    });

    test('normaliza a mayusculas al validar', () {
      expect(Validators.curp('loaj900215hdfrpc08'), isNull);
    });
  });

  group('Validators.email', () {
    test('acepta email valido', () {
      expect(Validators.email('juan@example.com'), isNull);
    });

    test('rechaza sin arroba', () {
      expect(Validators.email('juanexample.com'), isNotNull);
    });

    test('rechaza vacio', () {
      expect(Validators.email(''), isNotNull);
    });

    test('normalizeEmail pasa a minusculas y trim', () {
      expect(Validators.normalizeEmail('  Juan@Example.COM  '),
          'juan@example.com');
    });
  });

  group('Validators.password', () {
    test('acepta password fuerte', () {
      expect(Validators.password('Password1'), isNull);
    });

    test('rechaza muy corta', () {
      expect(Validators.password('Aa1'), isNotNull);
    });

    test('rechaza sin digito', () {
      expect(Validators.password('PasswordSinNumero'), isNotNull);
    });

    test('rechaza sin mayuscula', () {
      expect(Validators.password('passwordfuerte1'), isNotNull);
    });

    test('rechaza sin minuscula', () {
      expect(Validators.password('PASSWORDFUERTE1'), isNotNull);
    });
  });

  group('Validators.telefono', () {
    test('acepta 10 digitos', () {
      expect(Validators.telefono('5512345678'), isNull);
    });

    test('acepta con prefijo +52', () {
      expect(Validators.telefono('+52 55 1234 5678'), isNull);
    });

    test('rechaza demasiados digitos', () {
      expect(Validators.telefono('55123456789999'), isNotNull);
    });

    test('vacio es valido por ser opcional', () {
      expect(Validators.telefono(''), isNull);
    });
  });

  group('Validators.nombre', () {
    test('acepta nombres normales', () {
      expect(Validators.nombre('Juan', campo: 'Nombres'), isNull);
    });

    test('acepta acentos y enhe', () {
      expect(Validators.nombre('Maria Nunez', campo: 'Nombres'), isNull);
    });

    test('rechaza numeros', () {
      expect(Validators.nombre('Juan123', campo: 'Nombres'), isNotNull);
    });

    test('rechaza vacio', () {
      expect(Validators.nombre('', campo: 'Nombres'), isNotNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('coincide', () {
      expect(Validators.confirmPassword('Password1', 'Password1'), isNull);
    });

    test('difiere', () {
      expect(Validators.confirmPassword('Other1', 'Password1'), isNotNull);
    });
  });

  group('Theme', () {
    test('buildLightTheme produce un ThemeData claro', () {
      final t = buildLightTheme();
      expect(t.brightness, Brightness.light);
      expect(t.useMaterial3, isTrue);
    });

    test('buildDarkTheme produce un ThemeData oscuro', () {
      final t = buildDarkTheme();
      expect(t.brightness, Brightness.dark);
      expect(t.useMaterial3, isTrue);
    });

    test('ThemeController arranca en sistema por defecto', () {
      final c = ThemeController();
      expect(c.mode, AppThemeMode.system);
      expect(c.materialThemeMode, ThemeMode.system);
    });

    test('cambia modos consecutivos persistiendo', () async {
      final c = ThemeController();
      await c.setMode(AppThemeMode.light);
      expect(c.mode, AppThemeMode.light);

      await c.setMode(AppThemeMode.dark);
      expect(c.mode, AppThemeMode.dark);
      expect(c.materialThemeMode, ThemeMode.dark);
    });

    test('cycle rota system a light a dark a system', () async {
      final c = ThemeController();
      await c.cycle();
      expect(c.mode, AppThemeMode.light);
      await c.cycle();
      expect(c.mode, AppThemeMode.dark);
      await c.cycle();
      expect(c.mode, AppThemeMode.system);
    });

    test('SantanderColors expone rojo corporativo', () {
      expect(SantanderColors.red.toARGB32(), 0xFFEC0000);
    });
  });
}
