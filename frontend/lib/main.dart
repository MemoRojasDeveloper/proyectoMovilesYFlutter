import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
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
    _checkSession();
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
          ? HomePlaceholderScreen(
              user: _currentUser!,
              repository: widget.authRepository,
              onLogout: _onLogout,
            )
          : LoginScreen(
              repository: widget.authRepository,
              onSignedIn: _onSignedIn,
              themeController: widget.themeController,
            ),
    );
  }
}
