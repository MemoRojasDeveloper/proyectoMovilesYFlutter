/// Formulario de sucursal (alta o edición).
///
/// Devuelve `true` vía `Navigator.pop(true)` cuando guarda con éxito.
/// La lista principal recarga al detectar este resultado.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/estados_mexico.dart';
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

  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _calle;
  late final TextEditingController _numero;
  late final TextEditingController _colonia;
  late final TextEditingController _ciudad;
  late final TextEditingController _estado;
  late final TextEditingController _cp;
  late bool _activo;

  // Horario: dias (1=L ... 7=D) + hora 24h apertura/cierre.
  final Set<int> _diasSeleccionados = <int>{};
  TimeOfDay? _horaApertura;
  TimeOfDay? _horaCierre;

  bool _guardando = false;

  bool get _esEdicion => widget.sucursal != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sucursal;
    _nombre = TextEditingController(text: s?.nombreSucursal ?? '');
    _telefono = TextEditingController(text: s?.telefono ?? '');
    _calle = TextEditingController(text: s?.calle ?? '');
    _numero = TextEditingController(text: s?.numero ?? '');
    _colonia = TextEditingController(text: s?.colonia ?? '');
    _ciudad = TextEditingController(text: s?.ciudad ?? '');
    _estado = TextEditingController(text: s?.estado ?? '');
    _cp = TextEditingController(text: s?.codigoPostal ?? '');
    _activo = s?.activo ?? true;

    // Horario viene del backend ya tipado (dias_semana, hora_apertura, hora_cierre).
    if (s?.diasSemana != null) {
      _diasSeleccionados.addAll(s!.diasSemana!);
    }
    if (s?.horaApertura != null) {
      final parts = s!.horaApertura!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          _horaApertura = TimeOfDay(hour: h, minute: m);
        }
      }
    }
    if (s?.horaCierre != null) {
      final parts = s!.horaCierre!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          _horaCierre = TimeOfDay(hour: h, minute: m);
        }
      }
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _calle.dispose();
    _numero.dispose();
    _colonia.dispose();
    _ciudad.dispose();
    _estado.dispose();
    _cp.dispose();
    super.dispose();
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

  // ── Horario: helpers ──────────────────────────────────────────
  static const List<String> _diasCorto = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  /// Devuelve un dict con los 3 campos del horario para el backend.
  /// Si el usuario no configuró los 3 (días + apertura + cierre),
  /// devuelve los 3 en null (horario no configurado).
  String _fmtHhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _serializarHorario() {
    final completo = _diasSeleccionados.isNotEmpty &&
        _horaApertura != null &&
        _horaCierre != null;
    if (!completo) {
      return {
        'dias_semana': null,
        'hora_apertura': null,
        'hora_cierre': null,
      };
    }
    return {
      'dias_semana': (_diasSeleccionados.toList()..sort()),
      'hora_apertura': _fmtHhmm(_horaApertura!),
      'hora_cierre': _fmtHhmm(_horaCierre!),
    };
  }

  Future<void> _pickHora(BuildContext context, bool esApertura) async {
    final inicial = (esApertura ? _horaApertura : _horaCierre) ??
        TimeOfDay(hour: esApertura ? 9 : 18, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (esApertura) {
          _horaApertura = picked;
        } else {
          _horaCierre = picked;
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final horario = _serializarHorario();

    final body = <String, dynamic>{
      'nombre_sucursal': _nombre.text.trim(),
      'calle': _calle.text.trim().isEmpty ? null : _calle.text.trim(),
      'numero': _numero.text.trim().isEmpty ? null : _numero.text.trim(),
      'colonia': _colonia.text.trim().isEmpty ? null : _colonia.text.trim(),
      'ciudad': _ciudad.text.trim().isEmpty ? null : _ciudad.text.trim(),
      'estado': _estado.text.trim().isEmpty ? null : _estado.text.trim(),
      'codigo_postal': _cp.text.trim().isEmpty ? null : _cp.text.trim(),
      'telefono': _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      'dias_semana':   horario['dias_semana'],
      'hora_apertura': horario['hora_apertura'],
      'hora_cierre':   horario['hora_cierre'],
      'activo': _activo,
    };

    try {
      if (_esEdicion) {
        await _repo.actualizar(widget.sucursal!.codigoSucursal, body);
      } else {
        // El codigo_sucursal lo genera el servidor; NO se manda en body.
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
              // Aviso: el código se autogenera en el servidor.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tag, size: 18, color: tokens.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El código se asignará automáticamente '
                        '(SUC-001, SUC-002, ...)',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
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

            // ── Horario: días de apertura + hora 24h ──
            Text(
              'Horario',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final dia = i + 1; // 1=L ... 7=D
                final seleccionado = _diasSeleccionados.contains(dia);
                return FilterChip(
                  label: Text(_diasCorto[i]),
                  selected: seleccionado,
                  onSelected: _guardando
                      ? null
                      : (_) => setState(() {
                            if (seleccionado) {
                              _diasSeleccionados.remove(dia);
                            } else {
                              _diasSeleccionados.add(dia);
                            }
                          }),
                  selectedColor: SantanderColors.red,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: seleccionado ? Colors.white : tokens.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: seleccionado
                          ? SantanderColors.red
                          : tokens.border,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => _pickHora(context, true),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _horaApertura == null
                          ? 'Hora apertura'
                          : 'Apertura: ${_fmtHhmm(_horaApertura!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: tokens.border),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _guardando
                        ? null
                        : () => _pickHora(context, false),
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(
                      _horaCierre == null
                          ? 'Hora cierre'
                          : 'Cierre: ${_fmtHhmm(_horaCierre!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: tokens.border),
                    ),
                  ),
                ),
              ],
            ),
            if (_diasSeleccionados.isNotEmpty &&
                (_horaApertura == null || _horaCierre == null))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selecciona también la hora de apertura y cierre',
                  style: TextStyle(
                    color: tokens.error,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              enabled: !_guardando,
              keyboardType: TextInputType.number,
              decoration: _dec(label: 'Teléfono', hint: '10 dígitos'),
              validator: _valTel,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
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
                    inputFormatters: [
                      // Permitimos dígitos, letras (ej. "123-A"),
                      // guion, slash, y el simbolo de grado.
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9A-Za-z\-/° ]'),
                      ),
                      LengthLimitingTextInputFormatter(10),
                    ],
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
                  child: DropdownButtonFormField<String>(
                    initialValue: kEstadosMexico.contains(_estado.text)
                        ? _estado.text
                        : null,
                    decoration: _dec(label: 'Estado'),
                    isExpanded: true,
                    items: kEstadosMexico
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() => _estado.text = v ?? ''),
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