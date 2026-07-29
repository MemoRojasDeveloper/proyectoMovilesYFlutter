/// Placeholder del dashboard post-login.
///
/// Muestra un saludo, los datos del usuario y un botón para cerrar
/// sesión. Será reemplazado en cuanto implementemos los dashboards
/// reales de cliente/empleado.
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../auth/auth_repository.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.onLogout,
  });

  final AuthResult user;
  final AuthRepository repository;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final saludo = user.nombres != null
        ? 'Hola, ${user.nombres}'
        : 'Hola, ${user.email ?? 'usuario'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await repository.logout();
              onLogout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              saludo,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Rol: ${user.rol}',
              style: TextStyle(color: tokens.textSecondary),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesión activa',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _kv('CURP', user.curp ?? '—'),
                    _kv('Email', user.email ?? '—'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tu dashboard completo se mostrará aquí en próximas '
              'iteraciones.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              onPressed: () async {
                await repository.logout();
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
