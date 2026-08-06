/// Pantalla "Préstamos" del dashboard del cliente.
///
/// Lista los préstamos del cliente, permite ver detalles/cuotas,
/// simular préstamos nuevos y pagarlos.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'cliente_prestamo_cuotas_screen.dart';
import 'cliente_prestamo_simulador_screen.dart';
import 'cliente_repository.dart';

class ClientePrestamosScreen extends StatefulWidget {
  const ClientePrestamosScreen({super.key, required this.user});

  final AuthResult user;

  @override
  State<ClientePrestamosScreen> createState() =>
      _ClientePrestamosScreenState();
}

class _ClientePrestamosScreenState extends State<ClientePrestamosScreen> {
  final _repo = ClienteRepository();
  List<Prestamo> _prestamos = [];
  List<ClienteCuenta> _cuentas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarCuentas();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final list = await _repo.obtenerPrestamos(widget.user.curp ?? '');
      if (!mounted) return;
      setState(() {
        _prestamos = list;
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

  Future<void> _cargarCuentas() async {
    try {
      final resp = await _repo.obtenerCuentas(widget.user.curp ?? '');
      if (!mounted) return;
      setState(() {
        _cuentas = resp.cuentas.where((c) => c.activo).toList();
      });
    } catch (_) {
      // No es crítico; si falla, no mostramos selector de cuenta.
    }
  }

  Future<void> _abrirSimulador({bool modoSolicitud = false}) async {
    final cuentasParaSimulador =
        modoSolicitud && _cuentas.isNotEmpty ? _cuentas : <ClienteCuenta>[];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientePrestamoSimuladorScreen(
          curp: widget.user.curp ?? '',
          cuentas: cuentasParaSimulador,
          onSolicitado: _cargar,
        ),
      ),
    );
  }

  Future<void> _cancelarSolicitud(Prestamo p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: Text(
          '¿Seguro que querés cancelar la solicitud #${p.idPrestamo} '
          'por \$${p.montoOtorgado.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repo.cancelarSolicitud(p.idPrestamo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud cancelada'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Préstamos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab-simular',
            onPressed: () => _abrirSimulador(),
            backgroundColor: Colors.white,
            foregroundColor: SantanderColors.red,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Simular'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab-solicitar',
            onPressed: _cuentas.isEmpty
                ? null
                : () => _abrirSimulador(modoSolicitud: true),
            backgroundColor: SantanderColors.red,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.send),
            label: const Text('Solicitar'),
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
    if (_prestamos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: SantanderColors.red,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sin préstamos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Usa el botón Simular para calcular una cuota antes de solicitarlo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _prestamos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PrestamoCard(
        prestamo: _prestamos[i],
        tokens: tokens,
        esOscuro: esOscuro,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientePrestamoCuotasScreen(
                idPrestamo: _prestamos[i].idPrestamo,
                prestamo: _prestamos[i],
              ),
            ),
          );
          _cargar();
        },
        onCancelar: _prestamos[i].estado == 'pendiente'
            ? () => _cancelarSolicitud(_prestamos[i])
            : null,
      ),
    );
  }
}

class _PrestamoCard extends StatelessWidget {
  const _PrestamoCard({
    required this.prestamo,
    required this.tokens,
    required this.esOscuro,
    required this.onTap,
    this.onCancelar,
  });

  final Prestamo prestamo;
  final AppColors tokens;
  final bool esOscuro;
  final VoidCallback onTap;
  final VoidCallback? onCancelar;

  String get _fechaStr {
    if (prestamo.fechaAprobacion == null) return '—';
    final d = prestamo.fechaAprobacion!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Color _colorEstado(AppColors tokens) {
    switch (prestamo.estado) {
      case 'aprobado':
        return const Color(0xFF2E7D32);
      case 'pendiente':
        return const Color(0xFFEF6C00);
      case 'rechazado':
        return tokens.error;
      case 'cancelado':
        return tokens.textSecondary;
      default:
        return tokens.textPrimary;
    }
  }

  String _etiquetaEstado() {
    switch (prestamo.estado) {
      case 'aprobado':
        return 'Aprobado';
      case 'pendiente':
        return 'Pendiente';
      case 'rechazado':
        return 'Rechazado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return prestamo.estado;
    }
  }

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, color: SantanderColors.red, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Préstamo #${prestamo.idPrestamo}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _colorEstado(tokens).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _etiquetaEstado(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _colorEstado(tokens),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                prestamo.estado == 'aprobado'
                    ? 'Aprobado: $_fechaStr · ${prestamo.plazoMeses} meses'
                    : 'Fecha: $_fechaStr · ${prestamo.plazoMeses} meses',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              if (prestamo.motivoSolicitud != null &&
                  prestamo.motivoSolicitud!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo: ${prestamo.motivoSolicitud}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      'Otorgado',
                      '\$${prestamo.montoOtorgado.toStringAsFixed(2)}',
                      tokens,
                    ),
                  ),
                  Expanded(
                    child: _stat(
                      'Cuota',
                      prestamo.cuotaMensual == null
                          ? '—'
                          : '\$${prestamo.cuotaMensual!.toStringAsFixed(2)}',
                      tokens,
                    ),
                  ),
                  Expanded(
                    child: _stat(
                      'Total',
                      prestamo.totalAPagar == null
                          ? '—'
                          : '\$${prestamo.totalAPagar!.toStringAsFixed(2)}',
                      tokens,
                    ),
                  ),
                ],
              ),
              if (prestamo.estado == 'rechazado') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cancel_outlined,
                          color: tokens.error, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          prestamo.estadoDetalle['motivo_rechazo']
                                  ?.toString() ??
                              'Sin motivo especificado',
                          style: TextStyle(
                            color: tokens.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (prestamo.estado == 'pendiente' && onCancelar != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCancelar,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancelar solicitud'),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, AppColors tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: tokens.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
          color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w700,
        )),
      ],
    );
  }
}