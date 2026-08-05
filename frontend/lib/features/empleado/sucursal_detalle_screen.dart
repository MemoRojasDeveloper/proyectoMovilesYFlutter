/// Pantalla de detalle de una sucursal (solo lectura).
///
/// Botón "Editar" en la AppBar abre el formulario en modo edición.
/// Carga las cuentas corrientes asociadas y las muestra en una sección.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../historial/historial_cuenta_screen.dart';
import 'sucursal_form_screen.dart';
import 'sucursales_repository.dart';

class SucursalDetalleScreen extends StatefulWidget {
  const SucursalDetalleScreen({super.key, required this.sucursal});

  final Sucursal sucursal;

  @override
  State<SucursalDetalleScreen> createState() => _SucursalDetalleScreenState();
}

class _SucursalDetalleScreenState extends State<SucursalDetalleScreen> {
  final _repo = SucursalesRepository();

  CuentasSucursalResponse? _cuentas;
  List<Sucursal> _todasSucursales = const [];
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
    _cargarCatalogoSucursales();
  }

  Future<void> _cargarCuentas() async {
    try {
      final r = await _repo.obtenerCuentas(widget.sucursal.codigoSucursal);
      if (!mounted) return;
      setState(() {
        _cuentas = r;
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
        _error = 'Error al cargar cuentas: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _cargarCatalogoSucursales() async {
    try {
      final lista = await _repo.listar();
      if (!mounted) return;
      setState(() => _todasSucursales = lista);
    } catch (_) {
      // Silencioso: el menu se adapta si no hay catalogo.
    }
  }

  Future<void> _toggleActivo(CuentaCorriente cuenta) async {
    final nuevoEstado = !cuenta.activo;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nuevoEstado ? 'Reactivar cuenta' : 'Desactivar cuenta'),
        content: Text(
          nuevoEstado
              ? '¿Deseas reactivar la cuenta ${cuenta.codigoCuenta}?'
              : '¿Desactivar la cuenta ${cuenta.codigoCuenta}? '
                  'Esta accion solo aplica si el saldo es 0.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: nuevoEstado
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(nuevoEstado ? 'Reactivar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      final act = await _repo.toggleActivoCuenta(
        cuenta.codigoCuenta,
        nuevoEstado,
      );
      if (!mounted) return;
      _actualizarCuentaEnLista(act);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevoEstado
                ? 'Cuenta ${act.codigoCuenta} reactivada'
                : 'Cuenta ${act.codigoCuenta} desactivada',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _cambiarSucursal(CuentaCorriente cuenta) async {
    final candidatos = _todasSucursales
        .where((s) =>
            s.codigoSucursal != cuenta.codigoSucursal && s.activo)
        .toList();
    if (candidatos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay otras sucursales operativas disponibles'),
        ),
      );
      return;
    }

    Sucursal? seleccionada;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: const Text('Cambiar sucursal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta: ${cuenta.codigoCuenta}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                const Text('Sucursal destino:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<Sucursal>(
                  initialValue: seleccionada,
                  isExpanded: true,
                  items: candidatos
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.codigoSucursal} - ${s.nombreSucursal}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => seleccionada = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: seleccionada == null
                    ? null
                    : () => Navigator.of(ctx).pop(true),
                child: const Text('Mover'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true || seleccionada == null || !mounted) return;
    try {
      final act = await _repo.cambiarSucursalCuenta(
        cuenta.codigoCuenta,
        seleccionada!.codigoSucursal,
      );
      if (!mounted) return;
      // La cuenta deja de estar en esta sucursal; recargamos la lista.
      await _cargarCuentas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cuenta ${act.codigoCuenta} movida a ${act.codigoSucursal}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _actualizarCuentaEnLista(CuentaCorriente actualizada) {
    if (_cuentas == null) return;
    final nueva = _cuentas!.cuentas
        .map((c) => c.codigoCuenta == actualizada.codigoCuenta ? actualizada : c)
        .toList();
    setState(() {
      _cuentas = CuentasSucursalResponse(
        codigoSucursal: _cuentas!.codigoSucursal,
        totalCuentas: nueva.length,
        totalClientes: _cuentas!.totalClientes,
        cuentas: nueva,
      );
    });
  }

  Future<void> _asignarSaldo(CuentaCorriente c) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AsignarSaldoDialog(codigoCuenta: c.codigoCuenta),
    );
    if (resultado == null || !mounted) return;

    setState(() {}); // feedback visual mientras carga
    try {
      final res = await _repo.asignarSaldo(
        codigoCuenta: c.codigoCuenta,
        monto: resultado['monto'] as double,
        operacion: resultado['operacion'] as String,
        motivo: resultado['motivo'] as String?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje']?.toString() ?? 'Saldo actualizado'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _cargarCuentas();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _darBajaDomiciliacion(Map<String, dynamic> d) async {
    final id = d['id_domiciliacion'] as int;
    final servicio = d['servicio']?.toString() ?? 'servicio';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de baja'),
        content: Text(
          'Dar de baja la domiciliacion de "$servicio" '
          '(id $id)?\n\nEl cobro automatico dejara de aplicarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _repo.darBajaDomiciliacion(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Domiciliacion dada de baja'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _cargarCuentas();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _verHistorial(CuentaCorriente c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistorialCuentaScreen(
          codigoCuenta: c.codigoCuenta,
          nombreCuenta: '${c.codigoCuenta} - ${c.codigoSucursal}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sucursal;
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(s.nombreSucursal),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final actualizado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => SucursalFormScreen(sucursal: s),
                ),
              );
              if (actualizado == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarCuentas,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EstadoCard(activo: s.activo),
              const SizedBox(height: 20),
              _Seccion(
                titulo: 'Información básica',
                tokens: tokens,
                campos: [
                  _Campo('Código', s.codigoSucursal, copy: true),
                  _Campo('Nombre', s.nombreSucursal),
                  if (s.horarioLabel != null)
                    _Campo('Horario', s.horarioLabel!),
                  if (s.telefono != null)
                    _Campo('Teléfono', s.telefono!, copy: true),
                ],
              ),
              const SizedBox(height: 20),
              _Seccion(
                titulo: 'Dirección',
                tokens: tokens,
                campos: [
                  if (s.calle != null) _Campo('Calle', s.calle!),
                  if (s.numero != null) _Campo('Número', s.numero!),
                  if (s.colonia != null) _Campo('Colonia', s.colonia!),
                  if (s.ciudad != null) _Campo('Ciudad', s.ciudad!),
                  if (s.estado != null) _Campo('Estado', s.estado!),
                  if (s.codigoPostal != null)
                    _Campo('Código postal', s.codigoPostal!, copy: true),
                ],
              ),
              const SizedBox(height: 20),
              _SeccionCuentas(
                tokens: tokens,
                cargando: _cargando,
                error: _error,
                data: _cuentas,
                onToggleActivo: _toggleActivo,
                onCambiarSucursal: _cambiarSucursal,
                onAsignarSaldo: _asignarSaldo,
                onDarBajaDomiciliacion: _darBajaDomiciliacion,
                onVerHistorial: _verHistorial,
              ),
              const SizedBox(height: 24),
              _Metadata(sucursal: s, tokens: tokens),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoCard extends StatelessWidget {
  const _EstadoCard({required this.activo});
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.green.shade700 : Colors.grey.shade600;
    final icon = activo ? Icons.check_circle : Icons.cancel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estado',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                activo ? 'Operativa' : 'No operativa',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.tokens,
    required this.campos,
  });

  final String titulo;
  final AppColors tokens;
  final List<_Campo> campos;

  @override
  Widget build(BuildContext context) {
    if (campos.isEmpty) return const SizedBox.shrink();
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
        const SizedBox(height: 12),
        ...campos.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: c,
            )),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo(this.label, this.value, {this.copy = false});
  final String label;
  final String value;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        if (copy)
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiado')),
                );
              }
            },
          ),
      ],
    );
  }
}

class _SeccionCuentas extends StatelessWidget {
  const _SeccionCuentas({
    required this.tokens,
    required this.cargando,
    required this.error,
    required this.data,
    required this.onToggleActivo,
    required this.onCambiarSucursal,
    required this.onAsignarSaldo,
    required this.onDarBajaDomiciliacion,
    required this.onVerHistorial,
  });

  final AppColors tokens;
  final bool cargando;
  final String? error;
  final CuentasSucursalResponse? data;
  final Future<void> Function(CuentaCorriente) onToggleActivo;
  final Future<void> Function(CuentaCorriente) onCambiarSucursal;
  final Future<void> Function(CuentaCorriente) onAsignarSaldo;
  final Future<void> Function(Map<String, dynamic>) onDarBajaDomiciliacion;
  final void Function(CuentaCorriente) onVerHistorial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Cuentas corrientes',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            if (data != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data!.totalCuentas}',
                  style: const TextStyle(
                    color: SantanderColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: tokens.border),
        const SizedBox(height: 12),
        if (cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error!,
              style: TextStyle(color: tokens.error, fontSize: 12),
            ),
          )
        else if (data == null || data!.cuentas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: tokens.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Sin cuentas asociadas',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
              ],
            ),
          )
        else
          Column(
            children: data!.cuentas.map((c) {
              final estadoColor = c.activo
                  ? Colors.green.shade700
                  : Colors.grey.shade600;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.codigoCuenta,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: estadoColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c.activo ? 'Activa' : 'Baja',
                                  style: TextStyle(
                                    color: estadoColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (c.fechaApertura != null)
                            Text(
                              'Apertura: ${c.fechaApertura!.toIso8601String().substring(0, 10)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${c.saldo.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Acciones',
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (op) {
                        switch (op) {
                          case 'cambiar':
                            onCambiarSucursal(c);
                            break;
                          case 'toggle':
                            onToggleActivo(c);
                            break;
                          case 'asignar':
                            onAsignarSaldo(c);
                            break;
                          case 'historial':
                            onVerHistorial(c);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'historial',
                          child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text('Ver historial'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'asignar',
                          child: ListTile(
                            leading: Icon(Icons.attach_money),
                            title: Text('Asignar saldo'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'cambiar',
                          child: ListTile(
                            leading: Icon(Icons.swap_horiz),
                            title: Text('Cambiar sucursal'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: ListTile(
                            leading: Icon(
                              c.activo
                                  ? Icons.block
                                  : Icons.check_circle_outline,
                              color: c.activo ? Colors.red : Colors.green,
                            ),
                            title: Text(
                              c.activo ? 'Desactivar' : 'Reactivar',
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        // Sub-lista de domiciliaciones por cuenta (solo si hay)
        if (data != null &&
            data!.cuentas.any((c) => c.domiciliaciones.isNotEmpty))
          ...data!.cuentas
              .where((c) => c.domiciliaciones.isNotEmpty)
              .map((c) => _DomiciliacionesEmpleado(
                    codigoCuenta: c.codigoCuenta,
                    domiciliaciones: c.domiciliaciones,
                    tokens: tokens,
                    onDarBaja: onDarBajaDomiciliacion,
                  )),
        if (data != null && data!.totalClientes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${data!.totalClientes} cliente(s) registrados',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.sucursal, required this.tokens});
  final Sucursal sucursal;
  final AppColors tokens;

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creado: ${_fmt(sucursal.creadoEn)}',
            style: TextStyle(color: tokens.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Actualizado: ${_fmt(sucursal.actualizadoEn)}',
            style: TextStyle(color: tokens.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Sub-lista de domiciliaciones activas por cuenta, con accion
/// "Dar de baja" visible para el empleado.
class _DomiciliacionesEmpleado extends StatelessWidget {
  const _DomiciliacionesEmpleado({
    required this.codigoCuenta,
    required this.domiciliaciones,
    required this.tokens,
    required this.onDarBaja,
  });

  final String codigoCuenta;
  final List<Map<String, dynamic>> domiciliaciones;
  final AppColors tokens;
  final void Function(Map<String, dynamic>) onDarBaja;

  IconData _icono(String? tipo) {
    switch (tipo) {
      case 'internet':
        return Icons.wifi;
      case 'luz':
        return Icons.bolt;
      case 'agua':
        return Icons.water_drop;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activas = domiciliaciones
        .where((d) => (d['estado'] ?? 'activa') == 'activa')
        .toList();
    if (activas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Domiciliaciones de $codigoCuenta',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tokens.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          ...activas.map((d) {
            final cat = d['catalogo'] as Map<String, dynamic>?;
            final tipo = cat?['tipo_servicio'] as String?;
            final montoTotal = (d['monto_total_a_cobrar'] as num?)?.toDouble()
                ?? (d['monto_autorizado'] as num?)?.toDouble()
                ?? 0;
            final atraso = (d['horas_retraso'] as int?) ?? 0;
            final recargo = (d['recargo_acumulado'] as num?)?.toDouble() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: atraso > 0 ? Colors.red.shade300 : tokens.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(_icono(tipo), size: 18, color: tokens.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['servicio']?.toString() ?? 'Servicio',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          atraso > 0
                              ? 'Atraso ${atraso}h · recargo \$${recargo.toStringAsFixed(2)}'
                              : 'Cobro cada hora',
                          style: TextStyle(
                            fontSize: 10,
                            color: atraso > 0
                                ? Colors.red
                                : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${montoTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: atraso > 0 ? Colors.red.shade700 : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dar de baja',
                    icon: const Icon(Icons.block, color: Colors.red, size: 18),
                    onPressed: () => onDarBaja(d),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Dialogo modal para que el empleado sume/reste saldo a una cuenta
/// (util para pruebas).
class _AsignarSaldoDialog extends StatefulWidget {
  const _AsignarSaldoDialog({required this.codigoCuenta});
  final String codigoCuenta;

  @override
  State<_AsignarSaldoDialog> createState() => _AsignarSaldoDialogState();
}

class _AsignarSaldoDialogState extends State<_AsignarSaldoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  String _operacion = 'sumar';

  @override
  void dispose() {
    _montoCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  String? _validar(String? v) {
    if (v == null || v.trim().isEmpty) return 'Monto obligatorio';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Numero invalido';
    if (n <= 0) return 'Debe ser > 0';
    if (n > 1000000) return 'Maximo \$1,000,000';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'monto': double.parse(_montoCtrl.text.trim()),
      'operacion': _operacion,
      'motivo': _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar saldo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.codigoCuenta,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'sumar',
                  icon: Icon(Icons.add),
                  label: Text('Sumar'),
                ),
                ButtonSegment(
                  value: 'restar',
                  icon: Icon(Icons.remove),
                  label: Text('Restar'),
                ),
              ],
              selected: {_operacion},
              onSelectionChanged: (s) =>
                  setState(() => _operacion = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              validator: _validar,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}