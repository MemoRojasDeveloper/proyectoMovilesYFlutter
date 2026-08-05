/// Pantalla "simular y (opcional) solicitar" prestamo.
///
/// Tiene 2 modos:
///  - Si NO se pasa `cuentas`, solo simula (modo publico, sin auth).
///  - Si se pasa `cuentas`, muestra dropdown de cuenta + campo motivo,
///    y despues de simular ofrece "Enviar solicitud" que llama a
///    `POST /api/clientes/{curp}/prestamos/solicitar`.
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
    this.cuentas = const [],
    this.onSolicitado,
  });

  final String curp;
  final List<ClienteCuenta> cuentas;

  /// Callback que se invoca cuando se envía la solicitud con éxito.
  /// Sirve para que la pantalla de prestamos del cliente recargue.
  final VoidCallback? onSolicitado;

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
  final _motivoCtrl = TextEditingController();
  final _repo = ClienteRepository();

  SimulacionPrestamo? _resultado;
  bool _calculando = false;
  bool _enviando = false;
  String? _error;

  String? _cuentaSeleccionada;

  bool get _esSolicitud => widget.cuentas.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.cuentas.isNotEmpty) {
      _cuentaSeleccionada = widget.cuentas.first.codigoCuenta;
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _tasaCtrl.dispose();
    _plazoCtrl.dispose();
    _motivoCtrl.dispose();
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

  Future<void> _enviarSolicitud() async {
    if (_resultado == null) return;
    if (_esSolicitud) {
      final motivoOk = _motivoCtrl.text.trim();
      if (motivoOk.isEmpty) {
        setState(() => _error = 'Contanos para qué necesitás el préstamo');
        return;
      }
      if (_cuentaSeleccionada == null) {
        setState(() => _error = 'Elegí la cuenta donde aplicarlo');
        return;
      }
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    final monto = double.parse(_montoCtrl.text.trim());
    final tasa = double.parse(_tasaCtrl.text.trim());
    final plazo = int.parse(_plazoCtrl.text.trim());

    try {
      await _repo.solicitarPrestamo(
        curpTitular: widget.curp,
        codigoCuenta: _cuentaSeleccionada!,
        monto: monto,
        tasa: tasa,
        plazo: plazo,
        motivo: _motivoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada. Queda pendiente de aprobación.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      widget.onSolicitado?.call();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _enviando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo enviar: $e';
        _enviando = false;
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

            // Si el cliente tiene cuentas, mostramos selector + motivo
            // y, luego de simular, habilitamos la solicitud real.
            if (_esSolicitud) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Solicitar el préstamo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _cuentaSeleccionada,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Cuenta',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: widget.cuentas
                    .map((c) => DropdownMenuItem(
                          value: c.codigoCuenta,
                          child: Text(
                            '${c.codigoCuenta} · \$${c.saldo.toStringAsFixed(2)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _cuentaSeleccionada = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _motivoCtrl,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la solicitud',
                  hintText: 'Ej. Necesito cancelar la tarjeta de crédito',
                  prefixIcon: Icon(Icons.edit_note),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (_resultado == null) return null;
                  if (v == null || v.trim().isEmpty) {
                    return 'Contanos para qué necesitás el préstamo';
                  }
                  return null;
                },
              ),
            ],
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
            if (_resultado != null && _esSolicitud) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarSolicitud,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _enviando ? 'Enviando solicitud...' : 'Solicitar préstamo',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'La solicitud queda en revisión por un empleado. '
                'Te avisamos cuando se apruebe o rechace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                ),
              ),
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