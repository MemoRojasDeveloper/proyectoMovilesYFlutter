/// Pantalla "Más": perfil, configuración, logout.
library;

import 'package:flutter/material.dart';

import '../../core/auth_storage.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';

class ClienteMasScreen extends StatelessWidget {
  const ClienteMasScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.themeController,
  });

  final AuthResult user;
  final VoidCallback onLogout;
  final ThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _PerfilCard(user: user, tokens: tokens, esOscuro: esOscuro),
          const SizedBox(height: 16),
          if (themeController != null)
            _ConfigItem(
              icon: Icons.brightness_auto_outlined,
              titulo: 'Tema',
              subtitulo: themeController!.mode.label,
              tokens: tokens,
              onTap: () => themeController!.cycle(),
            ),
          _ConfigItem(
            icon: Icons.smartphone_outlined,
            titulo: 'Banco Santander',
            subtitulo: 'App móvil · v1.0',
            tokens: tokens,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await AuthStorage().clear();
              if (context.mounted) onLogout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerfilCard extends StatelessWidget {
  const _PerfilCard({required this.user, required this.tokens, required this.esOscuro});
  final AuthResult user;
  final AppColors tokens;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: esOscuro
              ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
              : [SantanderColors.red, SantanderColors.redDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: const Icon(Icons.person, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nombres ?? 'Cliente',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (user.apellidoPaterno != null)
                      Text(
                        '${user.apellidoPaterno} ${user.email ?? ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kv('Email', user.email ?? '—'),
          _kv('CURP', user.curp ?? '—'),
          _kv('Rol', user.rol),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(k, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ),
          Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.tokens,
    required this.onTap,
  });
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final AppColors tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: tokens.textSecondary),
        title: Text(titulo, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo, style: TextStyle(color: tokens.textSecondary, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
        onTap: onTap,
      ),
    );
  }
}