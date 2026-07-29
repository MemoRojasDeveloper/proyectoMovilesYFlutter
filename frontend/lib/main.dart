import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/empleado/sucursales_empleado_screen.dart';
import 'features/home/home_placeholder_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeController = ThemeController();
  await themeController.load();

  final auth = AuthRepository(themeController: themeController);

  runApp(BancoSantanderApp(
    themeController: themeController,
    authRepository: auth,
  ));
}

class BancoSantanderApp extends StatefulWidget {
  const BancoSantanderApp({
    super.key,
    required this.themeController,
    required this.authRepository,
  });

  final ThemeController themeController;
  final AuthRepository authRepository;

  @override
  State<BancoSantanderApp> createState() => _BancoSantanderAppState();
}

class _BancoSantanderAppState extends State<BancoSantanderApp> {
  bool _hasSession = false;
  AuthResult? _currentUser;

  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_onThemeChanged);
    _checkSession();
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkSession() async {
    final logged = await widget.authRepository.hasSession();
    if (logged && mounted) {
      final rol = await widget.authRepository.storedRol();
      setState(() {
        _hasSession = true;
        _currentUser = AuthResult(
          token: '',
          rol: rol ?? 'cliente',
        );
      });
    }
  }

  void _onSignedIn(AuthResult result) {
    setState(() {
      _hasSession = true;
      _currentUser = result;
    });
  }

  void _onLogout() {
    setState(() {
      _hasSession = false;
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banco Santander',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: widget.themeController.materialThemeMode,
      home: _hasSession && _currentUser != null
          ? _routerPostLogin(_currentUser!)
          : LoginScreen(
              repository: widget.authRepository,
              onSignedIn: _onSignedIn,
              themeController: widget.themeController,
            ),
    );
  }

  Widget _routerPostLogin(AuthResult user) {
    if (user.isEmpleado) {
      return SucursalesEmpleadoScreen(
        user: user,
        onLogout: _onLogout,
        themeController: widget.themeController,
      );
    }
    return HomePlaceholderScreen(
      user: user,
      repository: widget.authRepository,
      onLogout: _onLogout,
    );
  }
}
