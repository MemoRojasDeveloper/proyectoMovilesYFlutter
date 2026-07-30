/// Pantalla de transferencia entre cuentas (CURP destino + monto + concepto).
///
/// Devuelve `true` al Navigator cuando la transferencia fue exitosa,
/// para que el detalle de la cuenta refresque el saldo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import 'cliente_repository.dart';

class ClienteTransferirScreen extends StatefulWidget {
  const ClienteTransferirScreen({
    super.key,
    required this.codigoCuentaOrigen,
    required this.saldoDisponible,
  });

  final String codigoCuentaOrigen;
  final double saldoDisponible;

  @override
  State<ClienteTransferirScreen> createState() =>
      _ClienteTransferirScreenState();
}

class _ClienteTransferirScreenState extends State<ClienteTransferirScreen> {
  final _formKey = GlobalKey<FormState>();
  final _curpCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  final _repo = ClienteRepository();

  bool _enviando = false;
  String? _serverError;

  @override
  void dispose() {
    _curpCtrl.dispose();
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarYEnviar() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.tryParse(_montoCtrl.text.trim());
    if (monto == null || monto <= 0) {
      setState(() => _serverError = 'Monto invalido');
      return;
    }
    if (monto > widget.saldoDisponible) {
      setState(() => _serverError =
          'Saldo insuficiente (disponible: \$${widget.saldoDisponible.toStringAsFixed(2)})');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar transferencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CURP destino: ${_curpCtrl.text.trim().toUpperCase()}'),
            const SizedBox(height: 8),
            Text('Monto: \$${monto.toStringAsFixed(2)}'),
            if (_conceptoCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Concepto: ${_conceptoCtrl.text.trim()}'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Esta operacion no se puede deshacer.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: SantanderColors.red),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _enviando = true;
      _serverError = null;
    });

    try {
      final res = await _repo.transferir(
        codigoCuenta: widget.codigoCuentaOrigen,
        curpDestino: _curpCtrl.text.trim(),
        monto: monto,
        concepto: _conceptoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje']?.toString() ?? 'Transferencia exitosa'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError = e.message;
        _enviando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverError = 'No se pudo transferir: $e';
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Transferir'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Origen: ${widget.codigoCuentaOrigen}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Saldo: \$${widget.saldoDisponible.toStringAsFixed(2)}',
                          style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _curpCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                LengthLimitingTextInputFormatter(18),
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'CURP destino',
                prefixIcon: Icon(Icons.person_outline),
                helperText: '18 caracteres',
              ),
              validator: Validators.curp,
              onChanged: (v) {
                final up = Validators.normalizeCurp(v);
                if (up != v) {
                  _curpCtrl.value = _curpCtrl.value.copyWith(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixIcon: const Icon(Icons.attach_money),
                helperText: 'Maximo: \$${widget.saldoDisponible.toStringAsFixed(2)}',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Monto obligatorio';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Monto invalido';
                if (n > widget.saldoDisponible) return 'Saldo insuficiente';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _conceptoCtrl,
              decoration: const InputDecoration(
                labelText: 'Concepto (opcional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 12),
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
                      child: Text(
                        _serverError!,
                        style: TextStyle(color: tokens.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _enviando ? null : _confirmarYEnviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.swap_horiz),
              label: Text(_enviando ? 'Enviando...' : 'Continuar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SantanderColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}