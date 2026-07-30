/// Pantalla de detalle de una sucursal (solo lectura).
///
/// Botón "Editar" en la AppBar abre el formulario en modo edición.
/// Carga las cuentas corrientes asociadas y las muestra en una sección.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
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
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
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
                  if (s.horario != null) _Campo('Horario', s.horario!),
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
  });

  final AppColors tokens;
  final bool cargando;
  final String? error;
  final CuentasSucursalResponse? data;

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
                          Text(
                            c.codigoCuenta,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
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
                    Text(
                      '\$${c.saldo.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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