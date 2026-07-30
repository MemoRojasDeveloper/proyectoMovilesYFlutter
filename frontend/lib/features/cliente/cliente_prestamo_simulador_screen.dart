/// Pantalla de simulacion de prestamos.
///
/// Llama a /api/prestamos/simular (endpoint publico) y muestra el
/// resultado al instante. No persiste nada: solo calcula.
///
/// Si la tasa esta fuera del rango legal (9%-18%), el backend
/// rechaza y mostramos el error.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'cliente_repository.dart';

class ClientePrestamoSimuladorScreen extends StatefulWidget {
  const ClientePrestamoSimuladorScreen({
    super.key,
    required this.curp,
    this.onCreated,
  });

  final String curp;
  final VoidCallback? onCreated;

  @override
  State<ClientePrestamoSimuladorScreen> createState() =>
      _ClientePrestamoSimuladorScreenState();
}

class _ClientePrestamoSimuladorScreenState
    extends State<ClientePrestamoSimuladorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController(text: '15.0');
  final _plazoCtrl = TextEditingController(text: '12');
  final _repo = ClienteRepository();

  SimulacionPrestamo? _resultado;
  bool _calculando = false;
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _plazoCtrl.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _calculando = true;
      _error = null;
      _resultado = null;
    });
    final monto = double.parse(_montoCtrl.text.trim());
    final tasa = double.parse(_tasaCtrl.text.trim());
    final plazo = int.parse(_plazoCtrl.text.trim());
    try {
      final r = await _repo.simular(monto: monto, tasa: tasa, plazo: plazo);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _calculando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _calculando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _calculando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: const Text('Simular préstamo')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: tokens.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tasa legal: entre 9.0% y 18.0% anual. Fuera de ese rango el backend rechaza la solicitud.',
                      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto a solicitar',
                prefixIcon: Icon(Icons.attach_money),
                helperText: 'Ej. 10000',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obligatorio';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Monto invalido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tasaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Tasa de interes anual (%)',
                prefixIcon: Icon(Icons.percent),
                helperText: 'Entre 9.0 y 18.0',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obligatorio';
                final n = double.tryParse(v);
                if (n == null) return 'Tasa invalida';
                if (n < 9.0 || n > 18.0) return 'Fuera de rango legal (9%-18%)';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _plazoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Plazo (meses)',
                prefixIcon: Icon(Icons.calendar_month_outlined),
                helperText: 'Ej. 12, 24, 36',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obligatorio';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return 'Plazo invalido';
                if (n > 600) return 'Maximo 600 meses';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _calculando ? null : _calcular,
              icon: _calculando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: Text(_calculando ? 'Calculando...' : 'Calcular'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SantanderColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: tokens.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: tokens.error)),
                    ),
                  ],
                ),
              ),
            ],
            if (_resultado != null) ...[
              const SizedBox(height: 20),
              _ResultadoCard(r: _resultado!, tokens: tokens),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  const _ResultadoCard({required this.r, required this.tokens});
  final SimulacionPrestamo r;
  final AppColors tokens;

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
            'Resultado',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${r.cuotaMensual.toStringAsFixed(2)} / mes',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _kv('Plazo', '${r.plazoMeses} meses'),
          _kv('Tasa anual', '${r.tasaInteres.toStringAsFixed(1)}%'),
          _kv('Interés total', '\$${r.interesTotal.toStringAsFixed(2)}'),
          _kv('Total a pagar', '\$${r.totalAPagar.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
          ),
          Text(
            v,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}