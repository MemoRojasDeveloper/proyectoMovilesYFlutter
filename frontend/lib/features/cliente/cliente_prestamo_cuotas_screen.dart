/// Pantalla de cuotas de un prestamo: lista todas las cuotas y permite
/// marcar como pagada cada una (best-effort, sin Stripe todavia).
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'cliente_repository.dart';

class ClientePrestamoCuotasScreen extends StatefulWidget {
  const ClientePrestamoCuotasScreen({
    super.key,
    required this.idPrestamo,
    required this.prestamo,
  });

  final int idPrestamo;
  final Prestamo prestamo;

  @override
  State<ClientePrestamoCuotasScreen> createState() =>
      _ClientePrestamoCuotasScreenState();
}

class _ClientePrestamoCuotasScreenState
    extends State<ClientePrestamoCuotasScreen> {
  final _repo = ClienteRepository();
  CuotasResponse? _data;
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
      final r = await _repo.obtenerCuotas(widget.idPrestamo);
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

  Future<void> _pagarCuota(Cuota c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          'Vas a pagar la cuota #${c.numero} por \$${c.montoCuota.toStringAsFixed(2)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: SantanderColors.red),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.pagarCuota(c.idCuota);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cuota #${c.numero} pagada'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text('Préstamo #${widget.idPrestamo}')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _data == null
                    ? const Center(child: Text('Sin datos'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          _ResumenCard(prestamo: widget.prestamo, data: _data!),
                          const SizedBox(height: 16),
                          ..._data!.cuotas.map(
                            (c) => _CuotaTile(
                              cuota: c,
                              tokens: tokens,
                              esOscuro: esOscuro,
                              onPagar: () => _pagarCuota(c),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({required this.prestamo, required this.data});
  final Prestamo prestamo;
  final CuotasResponse data;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            'Otorgado: \$${prestamo.montoOtorgado.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${prestamo.cuotaMensual?.toStringAsFixed(2) ?? "—"}/mes · ${prestamo.tasaInteres.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniStat('Pagadas', '${data.pagadas}/${data.total}'),
              ),
              Expanded(
                child: _miniStat('Saldo', '\$${data.saldoPendiente.toStringAsFixed(2)}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CuotaTile extends StatelessWidget {
  const _CuotaTile({
    required this.cuota,
    required this.tokens,
    required this.esOscuro,
    required this.onPagar,
  });
  final Cuota cuota;
  final AppColors tokens;
  final bool esOscuro;
  final VoidCallback onPagar;

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = esOscuro ? tokens.surface : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(
            cuota.pagada ? Icons.check_circle : Icons.pending_outlined,
            color: cuota.pagada ? Colors.green.shade700 : Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuota #${cuota.numero}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  cuota.pagada
                      ? 'Pagada${cuota.fechaPago == null ? "" : " el ${_fmt(cuota.fechaPago)}"}'
                      : 'Vence: ${_fmt(cuota.fechaVencimiento)}',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '\$${cuota.montoCuota.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (!cuota.pagada)
            TextButton(
              onPressed: onPagar,
              child: const Text('Pagar'),
            ),
        ],
      ),
    );
  }
}