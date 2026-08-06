/// Pantalla de registro de cliente.
///
/// Crea cliente + credencial + cuenta_corriente en una sola
/// transacción (backend). El usuario escoge la sucursal 'casa' en
/// un dropdown que se alimenta de /api/sucursales?activo=true.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bank_header.dart';
import '../empleado/sucursales_repository.dart';
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

  /// Estado del selector de sucursal
  List<Sucursal> _sucursalesDisponibles = [];
  bool _cargandoSucursales = false;
  String? _sucursalSeleccionadaCodigo;
  String? _errorSucursales;

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

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    setState(() {
      _cargandoSucursales = true;
      _errorSucursales = null;
    });
    final repo = SucursalesRepository();
    try {
      final list = await repo.listar(activo: true);
      if (!mounted) return;
      setState(() {
        _sucursalesDisponibles = list;
        _cargandoSucursales = false;
      });
      return;
    } on UnauthorizedApiException {
      // El backend devolvio 401 (token expirado o invalido en
      // SharedPreferences). Limpiamos el storage y reintentamos
      // SIN token (el endpoint con ?activo=true es publico).
      try {
        await AuthStorage().clear();
      } catch (_) {}
    } catch (_) {
      // Cualquier otro error cae al fallback final.
    }

    // Reintento sin token (o si fallo algo mas).
    try {
      // Forzamos peticion sin token mediante un repo con storage vacio.
      final repoSinSesion = SucursalesRepository(
        storage: AuthStorage.anonymous(),
      );
      final list = await repoSinSesion.listar(activo: true);
      if (!mounted) return;
      setState(() {
        _sucursalesDisponibles = list;
        _cargandoSucursales = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoSucursales = false;
        _errorSucursales = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoSucursales = false;
        _errorSucursales = 'No se pudieron cargar sucursales: $e';
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    final telefonoNormalizado = Validators.normalizarTelefono(_telCtrl.text);

    setState(() => _loading = true);
    try {
      if (_sucursalSeleccionadaCodigo == null) {
        setState(() {
          _loading = false;
          _serverError = 'Selecciona una sucursal';
        });
        return;
      }
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
        codigoSucursal: _sucursalSeleccionadaCodigo!,
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
                  _section('Sucursal'),
                  if (_cargandoSucursales)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorSucursales != null)
                    _ServerErrorCard(
                      message: _errorSucursales!,
                      onRetry: _cargarSucursales,
                    )
                  else if (_sucursalesDisponibles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No hay sucursales operativas disponibles. '
                        'Contacta al banco.',
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _sucursalSeleccionadaCodigo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sucursal',
                        prefixIcon: Icon(Icons.business_outlined),
                        helperText: 'Donde se te asignara tu cuenta',
                      ),
                      selectedItemBuilder: (context) => _sucursalesDisponibles
                          .map(
                            (s) => Text.rich(
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: s.nombreSucursal,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (s.codigoPostal != null) ...[
                                    const TextSpan(text: '  ·  CP '),
                                    TextSpan(
                                      text: s.codigoPostal,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.of(context)
                                            .textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      items: _sucursalesDisponibles
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s.codigoSucursal,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.business_outlined,
                                      size: 18,
                                      color: AppColors.of(context)
                                          .textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.nombreSucursal,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (s.ciudad != null ||
                                              s.codigoPostal != null)
                                            Text(
                                              [
                                                if (s.ciudad != null)
                                                  s.ciudad,
                                                if (s.codigoPostal != null)
                                                  'CP ${s.codigoPostal}',
                                              ].join(' · '),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.of(context)
                                                    .textSecondary,
                                              ),
                                            ),
                                          Text(
                                            s.codigoSucursal,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _sucursalSeleccionadaCodigo = v,
                      ),
                      validator: (v) =>
                          v == null ? 'Selecciona una sucursal' : null,
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
  const _ServerErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
