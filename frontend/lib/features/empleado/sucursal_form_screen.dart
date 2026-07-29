/// Formulario de sucursal (alta o edición).
///
/// Devuelve `true` vía `Navigator.pop(true)` cuando guarda con éxito.
/// La lista principal recarga al detectar este resultado.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'sucursales_repository.dart';

class SucursalFormScreen extends StatefulWidget {
  const SucursalFormScreen({super.key, this.sucursal});

  /// Si es null → modo creación.
  /// Si viene una Sucursal → modo edición.
  final Sucursal? sucursal;

  @override
  State<SucursalFormScreen> createState() => _SucursalFormScreenState();
}

class _SucursalFormScreenState extends State<SucursalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SucursalesRepository();

  late final TextEditingController _codigo;
  late final TextEditingController _nombre;
  late final TextEditingController _horario;
  late final TextEditingController _telefono;
  late final TextEditingController _calle;
  late final TextEditingController _numero;
  late final TextEditingController _colonia;
  late final TextEditingController _ciudad;
  late final TextEditingController _estado;
  late final TextEditingController _cp;
  late bool _activo;

  bool _guardando = false;

  bool get _esEdicion => widget.sucursal != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sucursal;
    _codigo = TextEditingController(text: s?.codigoSucursal ?? '');
    _nombre = TextEditingController(text: s?.nombreSucursal ?? '');
    _horario = TextEditingController(text: s?.horario ?? '');
    _telefono = TextEditingController(text: s?.telefono ?? '');
    _calle = TextEditingController(text: s?.calle ?? '');
    _numero = TextEditingController(text: s?.numero ?? '');
    _colonia = TextEditingController(text: s?.colonia ?? '');
    _ciudad = TextEditingController(text: s?.ciudad ?? '');
    _estado = TextEditingController(text: s?.estado ?? '');
    _cp = TextEditingController(text: s?.codigoPostal ?? '');
    _activo = s?.activo ?? true;
  }

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _horario.dispose();
    _telefono.dispose();
    _calle.dispose();
    _numero.dispose();
    _colonia.dispose();
    _ciudad.dispose();
    _estado.dispose();
    _cp.dispose();
    super.dispose();
  }

  String? _valCodigo(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (!_esEdicion) {
      if (t.isEmpty) return 'Código obligatorio';
      if (t.length < 3 || t.length > 20) {
        return '3 a 20 caracteres';
      }
      if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(t)) {
        return 'Solo A-Z, 0-9 y guion';
      }
    }
    return null;
  }

  String? _valNombre(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Nombre obligatorio';
    if ((v ?? '').trim().length > 100) return 'Máximo 100 caracteres';
    return null;
  }

  String? _valCp(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^[0-9]{5}$').hasMatch(t)) return '5 dígitos';
    return null;
  }

  String? _valTel(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^[0-9]{10}$').hasMatch(t)) return '10 dígitos';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final body = <String, dynamic>{
      'nombre_sucursal': _nombre.text.trim(),
      'calle': _calle.text.trim().isEmpty ? null : _calle.text.trim(),
      'numero': _numero.text.trim().isEmpty ? null : _numero.text.trim(),
      'colonia': _colonia.text.trim().isEmpty ? null : _colonia.text.trim(),
      'ciudad': _ciudad.text.trim().isEmpty ? null : _ciudad.text.trim(),
      'estado': _estado.text.trim().isEmpty ? null : _estado.text.trim(),
      'codigo_postal': _cp.text.trim().isEmpty ? null : _cp.text.trim(),
      'telefono': _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      'horario': _horario.text.trim().isEmpty ? null : _horario.text.trim(),
      'activo': _activo,
    };

    try {
      if (_esEdicion) {
        await _repo.actualizar(widget.sucursal!.codigoSucursal, body);
      } else {
        body['codigo_sucursal'] = _codigo.text.trim().toUpperCase();
        await _repo.crear(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _mostrarError(e.message);
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar sucursal' : 'Nueva sucursal'),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(
              _guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _SeccionTitulo(titulo: 'Datos básicos', tokens: tokens),
            const SizedBox(height: 12),
            if (!_esEdicion) ...[
              TextFormField(
                controller: _codigo,
                enabled: !_guardando,
                textCapitalization: TextCapitalization.characters,
                decoration: _dec(label: 'Código', hint: 'Ej. SUC-001'),
                validator: _valCodigo,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nombre,
              enabled: !_guardando,
              decoration: _dec(label: 'Nombre', hint: 'Sucursal Centro'),
              validator: _valNombre,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _horario,
              enabled: !_guardando,
              decoration: _dec(
                label: 'Horario',
                hint: 'L-V 9:00 a 17:00',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              enabled: !_guardando,
              keyboardType: TextInputType.phone,
              decoration: _dec(label: 'Teléfono', hint: '10 dígitos'),
              validator: _valTel,
            ),
            const SizedBox(height: 24),
            _SeccionTitulo(titulo: 'Dirección', tokens: tokens),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _calle,
                    enabled: !_guardando,
                    decoration: _dec(label: 'Calle', hint: 'Av. Reforma'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _numero,
                    enabled: !_guardando,
                    decoration: _dec(label: 'Número', hint: '123'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _colonia,
              enabled: !_guardando,
              decoration: _dec(label: 'Colonia', hint: 'Centro'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ciudad,
                    enabled: !_guardando,
                    decoration: _dec(label: 'Ciudad', hint: 'CDMX'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _estado,
                    enabled: !_guardando,
                    decoration: _dec(label: 'Estado', hint: 'CDMX'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cp,
              enabled: !_guardando,
              keyboardType: TextInputType.number,
              decoration: _dec(label: 'Código postal', hint: '06600'),
              validator: _valCp,
              maxLength: 5,
            ),
            const SizedBox(height: 16),
            _SeccionTitulo(titulo: 'Estado', tokens: tokens),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _activo,
              onChanged: _guardando ? null : (v) => setState(() => _activo = v),
              title: const Text('Sucursal operativa'),
              subtitle: Text(
                _activo
                    ? 'Aparece en listados de operativas'
                    : 'Marcada como no operativa',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              activeThumbColor: SantanderColors.red,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(
              _guardando
                  ? 'Guardando...'
                  : (_esEdicion ? 'Guardar cambios' : 'Crear sucursal'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SantanderColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo({required this.titulo, required this.tokens});
  final String titulo;
  final AppColors tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: tokens.border),
      ],
    );
  }
}