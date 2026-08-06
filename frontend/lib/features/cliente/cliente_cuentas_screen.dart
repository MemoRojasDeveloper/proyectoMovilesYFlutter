/// Pantalla "Cuentas" del dashboard: lista todas las cuentas del cliente.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'cliente_cuenta_detalle_screen.dart';
import 'cliente_repository.dart';

class ClienteCuentasScreen extends StatefulWidget {
  const ClienteCuentasScreen({super.key, required this.user});

  final AuthResult user;

  @override
  State<ClienteCuentasScreen> createState() => _ClienteCuentasScreenState();
}

class _ClienteCuentasScreenState extends State<ClienteCuentasScreen> {
  final _repo = ClienteRepository();
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

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Mis cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _build(tokens, esOscuro),
      ),
    );
  }

  Widget _build(AppColors tokens, bool esOscuro) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
      return const Center(child: Text('No tienes cuentas'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final c = list[i];
        return _CuentaTile(
          cuenta: c,
          tokens: tokens,
          esOscuro: esOscuro,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClienteCuentaDetalleScreen(
                  codigoCuenta: c.codigoCuenta,
                  nombreCliente: widget.user.nombres ?? widget.user.email ?? '',
                  userCurp: widget.user.curp,
                ),
              ),
            );
            _cargar();
          },
        );
      },
    );
  }
}

class _CuentaTile extends StatelessWidget {
  const _CuentaTile({
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
      elevation: esOscuro ? 0 : 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: SantanderColors.red.withValues(alpha: 0.10),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: SantanderColors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta.codigoCuenta,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cuenta.nombreSucursal ?? "Sucursal"} · ${cuenta.ciudad ?? "—"}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${cuenta.saldo.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: tokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}