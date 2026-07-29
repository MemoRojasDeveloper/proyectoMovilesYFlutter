/// Widget reutilizable con la franja corporativa roja, el logo "flame"
/// estilizado y el título opcional.
///
/// Se usa como cabecera dentro del `Scaffold`, **debajo de** la
/// `AppBar` (si la hay) o como cuerpo en pantallas tipo login.
///
/// La altura NO es fija: se adapta al contenido con `IntrinsicHeight`
/// y `mainAxisSize.min`, por lo que es seguro dentro de cualquier
/// `Column` sin provocar overflow. Para forzar una altura mínima
/// cuando no hay título, pasa `minHeight`.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class BankHeader extends StatelessWidget {
  const BankHeader({
    super.key,
    this.title,
    this.subtitle,
    this.minHeight = 140,
    this.showLogo = true,
    this.actions = const <Widget>[],
  });

  /// Título principal (blanco, bold). Si es null, no se renderiza.
  final String? title;
  final String? subtitle;

  /// Altura mínima cuando hay poco contenido (header "compacto").
  final double minHeight;
  final bool showLogo;

  /// Widgets opcionales en la esquina superior derecha (p.ej. el
  /// `ThemeToggleButton`). Se renderizan sobre el `SafeArea` con su
  /// padding propio.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tokens = dark ? AppColors.dark : AppColors.light;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.primary,
            tokens.primaryDark,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showLogo) ...[
                    const _BankLogo(),
                    const SizedBox(height: 12),
                  ],
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: 0.3,
                      ),
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Logo minimalista del banco — una llama estilizada en blanco.
/// Sustituible por un SVG o imagen cuando esté disponible.
class _BankLogo extends StatelessWidget {
  const _BankLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              'S',
              style: TextStyle(
                color: SantanderColors.red,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Banco Santander',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
