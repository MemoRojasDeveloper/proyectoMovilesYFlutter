/// Pantalla que muestra el historial de movimientos de una cuenta.
///
/// Usada por:
///   - Clientes (desde detalle de cuenta)
///   - Empleados (desde detalle de sucursal)
///
/// Carga paginada de 20 movimientos, ordenados por fecha DESC.
/// Muestra icono + color segun tipo y signo (+/-) segun si fue
/// entrada o salida de dinero.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../cliente/cliente_repository.dart';

class HistorialCuentaScreen extends StatefulWidget {
  const HistorialCuentaScreen({
    super.key,
    required this.codigoCuenta,
    required this.nombreCuenta,
  });

  final String codigoCuenta;
  final String nombreCuenta;

  @override
  State<HistorialCuentaScreen> createState() => _HistorialCuentaScreenState();
}

class _HistorialCuentaScreenState extends State<HistorialCuentaScreen> {
  final _repo = ClienteRepository();
  final ScrollController _scroll = ScrollController();

  static const _pageSize = 20;

  final List<Movimiento> _items = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = true;
  String? _error;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _cargar(reset: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      // estamos cerca del final
      if (!_cargandoMas && _hayMas && !_cargando) {
        _cargar(reset: false);
      }
    }
  }

  Future<void> _cargar({required bool reset}) async {
    if (reset) {
      setState(() {
        _cargando = true;
        _error = null;
        _items.clear();
        _offset = 0;
        _hayMas = true;
      });
    } else {
      if (_cargandoMas || !_hayMas) return;
      setState(() => _cargandoMas = true);
    }
    try {
      final r = await _repo.obtenerMovimientos(
        widget.codigoCuenta,
        limite: _pageSize,
        offset: reset ? 0 : _offset,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(r.movimientos);
        _offset += r.movimientos.length;
        _hayMas = r.hayMas;
        _cargando = false;
        _cargandoMas = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
        _cargandoMas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _cargando = false;
        _cargandoMas = false;
      });
    }
  }

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'transferencia_enviada':
        return Icons.arrow_outward;
      case 'transferencia_recibida':
        return Icons.south_west;
      case 'pago_domiciliacion_manual':
      case 'cobro_domiciliacion_auto':
        return Icons.receipt_long;
      case 'cobro_domiciliacion_recargo':
        return Icons.warning_amber;
      case 'asignacion_empleado_suma':
        return Icons.add_circle_outline;
      case 'asignacion_empleado_resta':
        return Icons.remove_circle_outline;
      case 'pago_prestamo_cuota':
        return Icons.account_balance;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _color(String tipo) {
    switch (tipo) {
      case 'transferencia_recibida':
      case 'asignacion_empleado_suma':
        return Colors.green.shade700;
      case 'cobro_domiciliacion_recargo':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _fmtFecha(DateTime? f) {
    if (f == null) return '';
    final l = f.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(widget.nombreCuenta),
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargar(reset: true),
        child: _build(tokens),
      ),
    );
  }

  Widget _build(AppColors tokens) {
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
                onPressed: () => _cargar(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aun no hay movimientos en esta cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_hayMas ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final m = _items[i];
        final esSalida = m.esSalida;
        final color = _color(m.tipo);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icono(m.tipo), color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.etiquetaTipo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    if (m.concepto != null && m.concepto!.isNotEmpty)
                      Text(
                        m.concepto!,
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      _fmtFecha(m.fecha),
                      style: TextStyle(
                        fontSize: 10,
                        color: tokens.textSecondary,
                      ),
                    ),
                    if (m.actorNombre != null && m.actorNombre!.isNotEmpty)
                      Text(
                        'Por: ${m.actorNombre}',
                        style: TextStyle(
                          fontSize: 10,
                          color: tokens.textSecondary,
                        ),
                      ),
                    if (m.stripeReceiptUrl != null &&
                        m.stripeReceiptUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt,
                              size: 10,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Stripe',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${esSalida ? "-" : "+"}\$${m.monto.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: esSalida ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}