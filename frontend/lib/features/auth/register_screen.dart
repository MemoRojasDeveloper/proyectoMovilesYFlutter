/// Pantalla de registro de cliente.
///
/// Crea cliente + credencial en una sola transacción (backend).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bank_header.dart';
import 'auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.repository,
    this.onRegistered,
    this.themeController,
  });

  final AuthRepository repository;
  final ValueChanged<AuthResult>? onRegistered;

  /// Si se pasa, se muestra el botón de cambio de tema en el AppBar.
  final ThemeController? themeController;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _curpCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _apPatCtrl = TextEditingController();
  final _apMatCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _curpCtrl.dispose();
    _nombresCtrl.dispose();
    _apPatCtrl.dispose();
    _apMatCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    final telefonoNormalizado = Validators.normalizarTelefono(_telCtrl.text);

    setState(() => _loading = true);
    try {
      final result = await widget.repository.register(
        curp: _curpCtrl.text.trim().toUpperCase(),
        nombres: _nombresCtrl.text.trim(),
        apellidoPaterno: _apPatCtrl.text.trim(),
        apellidoMaterno: _apMatCtrl.text.trim().isEmpty
            ? null
            : _apMatCtrl.text.trim(),
        email: Validators.normalizeEmail(_emailCtrl.text),
        telefono: telefonoNormalizado,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      widget.onRegistered?.call(result);
      // Si no hay callback, hace pop
      if (widget.onRegistered == null) {
        Navigator.of(context).pop(result);
      }
    } on ApiException catch (e) {
      // Si el backend devuelve error por campo (p.ej. email duplicado)
      // se asigna al campo correspondiente.
      if (e.fieldErrors.isNotEmpty) {
        _formKey.currentState!.validate();
        setState(() => _serverError = e.message);
      } else {
        setState(() => _serverError = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        elevation: 0,
        actions: widget.themeController != null
            ? [ThemeToggleButton(controller: widget.themeController!)]
            : const <Widget>[],
      ),
      body: ListView(
        children: [
          BankHeader(
            title: 'Registro',
            subtitle: 'Crea tu cuenta de cliente',
            minHeight: 100,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('Datos personales'),
                  TextFormField(
                    controller: _curpCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(18),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CURP',
                      prefixIcon: Icon(Icons.badge_outlined),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombresCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombres',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        Validators.nombre(v, campo: 'Nombres'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _apPatCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Apellido paterno',
                          ),
                          validator: (v) => Validators.nombre(
                              v, campo: 'Apellido paterno'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _apMatCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Apellido materno',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            return Validators.nombre(
                                v, campo: 'Apellido materno');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section('Contacto'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText: '10 dígitos, opcional +52',
                    ),
                    validator: Validators.telefono,
                  ),
                  const SizedBox(height: 20),
                  _section('Contraseña'),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText:
                          'Mínimo 8 caracteres, una mayúscula y un dígito',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirma tu contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => Validators.confirmPassword(
                      v,
                      _passwordCtrl.text,
                    ),
                  ),
                  if (_serverError != null) ...[
                    const SizedBox(height: 16),
                    _ServerErrorCard(message: _serverError!),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Crear cuenta'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Ya tengo cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.of(context).primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ServerErrorCard extends StatelessWidget {
  const _ServerErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: tokens.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: tokens.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
