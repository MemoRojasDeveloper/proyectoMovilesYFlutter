/// Pantalla "Inicio" del dashboard del cliente.
///
/// Muestra saludo, saldo total combinado y tarjetas con cada cuenta.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'cliente_cuenta_detalle_screen.dart';
import 'cliente_repository.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onAbrirCuentas,
    required this.onAbrirPrestamos,
  });

  final AuthResult user;
  final VoidCallback onLogout;
  final VoidCallback onAbrirCuentas;
  final VoidCallback onAbrirPrestamos;

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  final _repo = ClienteRepository();
  final _storage = AuthStorage();

  ClienteCuentasResponse? _data;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await _repo.obtenerCuentas(widget.user.curp ?? '');
      if (!mounted) return;
      setState(() {
        _data = r;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final saludo = widget.user.nombres ?? widget.user.email ?? 'Cliente';

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  saludo: saludo,
                  saldoTotal: _data?.saldoTotal,
                  totalCuentas: _data?.total,
                  tokens: tokens,
                  esOscuro: esOscuro,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: _buildLista(tokens, esOscuro),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLista(AppColors tokens, bool esOscuro) {
    if (_cargando) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: tokens.error, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final list = _data?.cuentas ?? const <ClienteCuenta>[];
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: SantanderColors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aun no tienes cuentas asignadas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Contacta a tu sucursal para abrir una.',
                style: TextStyle(color: tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _CuentaCard(
        cuenta: list[i],
        tokens: tokens,
        esOscuro: esOscuro,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClienteCuentaDetalleScreen(
                codigoCuenta: list[i].codigoCuenta,
                nombreCliente: widget.user.nombres ?? widget.user.email ?? '',
                userCurp: widget.user.curp,
              ),
            ),
          ).then((_) => _cargar());
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.saludo,
    required this.saldoTotal,
    required this.totalCuentas,
    required this.tokens,
    required this.esOscuro,
  });

  final String saludo;
  final double? saldoTotal;
  final int? totalCuentas;
  final AppColors tokens;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: esOscuro
              ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
              : [SantanderColors.red, SantanderColors.redDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, $saludo',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tu panel de cliente',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: esOscuro ? 0.10 : 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  saldoTotal == null
                      ? '—'
                      : '\$${saldoTotal!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalCuentas == null
                      ? '—'
                      : '${totalCuentas} cuenta(s) activa(s)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaCard extends StatelessWidget {
  const _CuentaCard({
    required this.cuenta,
    required this.tokens,
    required this.esOscuro,
    required this.onTap,
  });

  final ClienteCuenta cuenta;
  final AppColors tokens;
  final bool esOscuro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = esOscuro ? tokens.surface : Colors.white;
    return Material(
      color: cardColor,
      elevation: esOscuro ? 0 : 2,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: SantanderColors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta.codigoCuenta,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cuenta.nombreSucursal ?? cuenta.codigoSucursal,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${cuenta.saldo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: SantanderColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}