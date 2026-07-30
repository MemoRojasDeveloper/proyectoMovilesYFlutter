/// Pantalla para compartir una cuenta con otro usuario.
///
/// Se reutiliza en dos modos:
///   - crear: `editarExistente == null`. El usuario escribe una CURP
///     y marca los privilegios que quiere darle.
///   - editar: `editarExistente != null`. La CURP viene bloqueada
///     (no se puede cambiar a quien ya se le dio acceso) y los
///     checkboxes arrancan con los privilegios actuales.
///
/// Al pulsar "Guardar" se llama a:
///   - POST `/api/cuentas/<codigo>/usuarios`        (modo crear)
///   - PATCH `/api/cuentas/<codigo>/usuarios/<curp>` (modo editar)
///
/// La pantalla SIEMPRE cierra con `Navigator.pop(context, true)`
/// cuando la operacion es exitosa; los errores se muestran con
/// un SnackBar rojo y la pantalla permanece abierta para que el
/// usuario pueda corregir.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'cliente_repository.dart';

class CompartirCuentaScreen extends StatefulWidget {
  const CompartirCuentaScreen({
    super.key,
    required this.codigoCuenta,
    this.editarExistente,
  });

  final String codigoCuenta;

  /// Si es null, la pantalla esta en modo "crear". Si trae un
  /// `CuentaUsuario`, estamos editando los privilegios de ese
  /// usuario sobre la cuenta.
  final CuentaUsuario? editarExistente;

  @override
  State<CompartirCuentaScreen> createState() => _CompartirCuentaScreenState();
}

class _CompartirCuentaScreenState extends State<CompartirCuentaScreen> {
  final _repo = ClienteRepository();
  final _curpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Conjunto de nombres de privilegios seleccionados.
  late Set<String> _seleccion;

  bool _cargando = false;

  bool get _esEdicion => widget.editarExistente != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _curpCtrl.text = widget.editarExistente!.curp;
      _seleccion = widget.editarExistente!.privilegios.toSet();
    } else {
      _seleccion = {};
    }
  }

  @override
  void dispose() {
    _curpCtrl.dispose();
    super.dispose();
  }

  String? _validarCurp(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    if (s.isEmpty) return 'CURP obligatoria';
    if (s.length != 18) return 'CURP debe tener 18 caracteres';
    final r = RegExp(r'^[A-Z]{4}\d{6}[A-Z]{6}[0-9A-Z]\d$');
    if (!r.hasMatch(s)) return 'Formato de CURP invalido';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seleccion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un privilegio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _cargando = true);
    final curp = _curpCtrl.text.trim().toUpperCase();
    final privilegios = _seleccion.toList();
    try {
      if (_esEdicion) {
        await _repo.actualizarPrivilegiosUsuario(
          codigoCuenta: widget.codigoCuenta,
          curp: curp,
          privilegios: privilegios,
        );
      } else {
        await _repo.compartirCuenta(
          codigoCuenta: widget.codigoCuenta,
          curp: curp,
          privilegios: privilegios,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final editar = widget.editarExistente;
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar acceso' : 'Compartir acceso'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _CuentaBadge(codigo: widget.codigoCuenta),
              const SizedBox(height: 24),
              Text(
                'CURP del usuario',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _curpCtrl,
                textCapitalization: TextCapitalization.characters,
                enabled: !_esEdicion,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(18),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Za-z0-9]'),
                  ),
                ],
                decoration: InputDecoration(
                  hintText: '18 caracteres',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: tokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 1.0,
                ),
                validator: _validarCurp,
                onChanged: (_) {
                  if (_esEdicion) return;
                  _curpCtrl.value = TextEditingValue(
                    text: _curpCtrl.text.toUpperCase(),
                    selection: _curpCtrl.selection,
                  );
                },
              ),
              if (_esEdicion && editar != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    editar.nombreCompleto.isEmpty
                        ? editar.curp
                        : '${editar.nombreCompleto} · ${editar.email ?? ''}',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Privilegios que tendra el usuario',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _esEdicion
                    ? 'Marca o desmarca las acciones que podra realizar.'
                    : 'Marca las acciones que el usuario podra realizar.',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ...ClienteRepository.catalogoPrivilegios.map(
                (p) => _PrivilegioCheck(
                  priv: p,
                  seleccionado: _seleccion.contains(p.nombre),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _seleccion.add(p.nombre);
                      } else {
                        _seleccion.remove(p.nombre);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _cargando ? null : _guardar,
                style: FilledButton.styleFrom(
                  backgroundColor: SantanderColors.red,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _cargando
                      ? 'Guardando...'
                      : (_esEdicion ? 'Guardar cambios' : 'Compartir acceso'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivilegioCheck extends StatelessWidget {
  const _PrivilegioCheck({
    required this.priv,
    required this.seleccionado,
    required this.onChanged,
  });

  final PrivilegioCatalogo priv;
  final bool seleccionado;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: seleccionado
              ? SantanderColors.red.withValues(alpha: 0.5)
              : tokens.border,
          width: seleccionado ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: seleccionado,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: SantanderColors.red,
        title: Text(
          priv.etiqueta,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
            fontSize: 13,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            priv.descripcion,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CuentaBadge extends StatelessWidget {
  const _CuentaBadge({required this.codigo});
  final String codigo;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SantanderColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: SantanderColors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  codigo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
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