/// Pantalla de detalle de una sucursal (solo lectura).
///
/// Botón "Editar" en la AppBar abre el formulario en modo edición.
/// Sin DELETE: para inactivar, hay que volver a la lista y usar el
/// menú popup de la tarjeta.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'sucursal_form_screen.dart';
import 'sucursales_repository.dart';

class SucursalDetalleScreen extends StatelessWidget {
  const SucursalDetalleScreen({super.key, required this.sucursal});

  final Sucursal sucursal;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(sucursal.nombreSucursal),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final actualizado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => SucursalFormScreen(sucursal: sucursal),
                ),
              );
              if (actualizado == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EstadoCard(activo: sucursal.activo),
            const SizedBox(height: 20),
            _Seccion(
              titulo: 'Información básica',
              tokens: tokens,
              campos: [
                _Campo('Código', sucursal.codigoSucursal, copy: true),
                _Campo('Nombre', sucursal.nombreSucursal),
                if (sucursal.horario != null) _Campo('Horario', sucursal.horario!),
                if (sucursal.telefono != null)
                  _Campo('Teléfono', sucursal.telefono!, copy: true),
              ],
            ),
            const SizedBox(height: 20),
            _Seccion(
              titulo: 'Dirección',
              tokens: tokens,
              campos: [
                if (sucursal.calle != null) _Campo('Calle', sucursal.calle!),
                if (sucursal.numero != null) _Campo('Número', sucursal.numero!),
                if (sucursal.colonia != null) _Campo('Colonia', sucursal.colonia!),
                if (sucursal.ciudad != null) _Campo('Ciudad', sucursal.ciudad!),
                if (sucursal.estado != null) _Campo('Estado', sucursal.estado!),
                if (sucursal.codigoPostal != null)
                  _Campo('Código postal', sucursal.codigoPostal!, copy: true),
              ],
            ),
            const SizedBox(height: 24),
            _Metadata(sucursal: sucursal, tokens: tokens),
          ],
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