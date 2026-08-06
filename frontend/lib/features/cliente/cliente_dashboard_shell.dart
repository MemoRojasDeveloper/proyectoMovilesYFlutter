/// Shell del dashboard del cliente con bottom navigation bar.
///
/// Tabs:
///   0. Inicio
///   1. Cuentas
///   2. Préstamos
///   3. Cambiar cuenta (placeholder + accion via FAB del bottom nav)
///   4. Más
///
/// El destino 3 "Cambiar" abre un bottom sheet con la lista de cuentas
/// compartidas CON el usuario. Si no hay ninguna, muestra un SnackBar
/// con el mensaje correspondiente y cierra el sheet.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'cambiar_cuenta_sheet.dart';
import 'cliente_cuentas_screen.dart';
import 'cliente_home_screen.dart';
import 'cliente_mas_screen.dart';
import 'cliente_prestamos_screen.dart';

class ClienteDashboardShell extends StatefulWidget {
  const ClienteDashboardShell({
    super.key,
    required this.user,
    required this.onLogout,
    this.themeController,
  });

  final AuthResult user;
  final VoidCallback onLogout;
  final ThemeController? themeController;

  @override
  State<ClienteDashboardShell> createState() => _ClienteDashboardShellState();
}

class _ClienteDashboardShellState extends State<ClienteDashboardShell> {
  int _index = 0;

  Future<void> _abrirCambiarCuenta() async {
    final curp = widget.user.curp ?? '';
    final nombre = widget.user.nombres ?? widget.user.email ?? 'Cliente';
    await CambiarCuentaSheet.show(
      context: context,
      userCurp: curp,
      userNombre: nombre,
    );
    // Al volver, refrescamos para que vea cualquier cambio.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      ClienteHomeScreen(
        user: widget.user,
        onLogout: widget.onLogout,
        onAbrirCuentas: () => setState(() => _index = 1),
        onAbrirPrestamos: () => setState(() => _index = 2),
      ),
      ClienteCuentasScreen(user: widget.user),
      ClientePrestamosScreen(user: widget.user),
      // Slot reservado para "Cambiar cuenta": un placeholder
      // informativo. La accion real se dispara desde el bottom nav.
      const _CambiarCuentaPlaceholder(),
      ClienteMasScreen(
        user: widget.user,
        onLogout: widget.onLogout,
        themeController: widget.themeController,
      ),
    ];

    final scaffold = Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (i == 3) {
            // Al tocar "Cambiar", abrimos el sheet directamente
            // sin cambiar de tab.
            await _abrirCambiarCuenta();
            return;
          }
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: SantanderColors.red),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon:
                Icon(Icons.account_balance_wallet, color: SantanderColors.red),
            label: 'Cuentas',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon:
                Icon(Icons.account_balance, color: SantanderColors.red),
            label: 'Préstamos',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            selectedIcon:
                Icon(Icons.swap_horiz, color: SantanderColors.red),
            label: 'Cambiar',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_outlined),
            selectedIcon: Icon(Icons.menu, color: SantanderColors.red),
            label: 'Más',
          ),
        ],
      ),
    );
    return scaffold;
  }
}

class _CambiarCuentaPlaceholder extends StatelessWidget {
  const _CambiarCuentaPlaceholder();

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: const Text('Cambiar de cuenta')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swap_horiz,
                size: 64,
                color: tokens.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'Toca el boton "Cambiar" en la barra inferior para '
                'ver las cuentas que otros han compartido contigo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}