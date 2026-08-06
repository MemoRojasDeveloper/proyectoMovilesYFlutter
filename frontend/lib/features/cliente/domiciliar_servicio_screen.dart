/// Pantalla para domiciliar un servicio del catalogo contra una cuenta.
///
/// Muestra los proveedores disponibles del catalogo (los que ya estan
/// activos en la cuenta se ocultan para evitar duplicados). Al
/// seleccionar uno, llama a `POST /api/domiciliaciones` y refresca.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'cliente_repository.dart';

class DomiciliarServicioScreen extends StatefulWidget {
  const DomiciliarServicioScreen({super.key, required this.codigoCuenta});
  final String codigoCuenta;

  @override
  State<DomiciliarServicioScreen> createState() =>
      _DomiciliarServicioScreenState();
}

class _DomiciliarServicioScreenState
    extends State<DomiciliarServicioScreen> {
  final _repo = ClienteRepository();

  List<CatalogoServicio> _catalogo = [];
  Set<int> _idsYaActivos = {};
  bool _cargando = true;
  String? _error;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.obtenerCatalogoServicios(),
        _repo.obtenerDomiciliaciones(widget.codigoCuenta),
      ]);
      if (!mounted) return;
      final cat = (results[0] as CatalogoServiciosResponse).servicios;
      final domis = results[1] as List<Domiciliacion>;
      setState(() {
        _catalogo = cat.where((s) => s.activo).toList();
        _idsYaActivos = {
          for (final d in domis.where((d) => d.activa))
            if (d.idCatalogoServicio != null) d.idCatalogoServicio!
        };
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
        _error = 'Error: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _domiciliar(CatalogoServicio s) async {
    setState(() => _procesando = true);
    try {
      await _repo.domiciliar(
        codigoCuenta: widget.codigoCuenta,
        idCatalogoServicio: s.idCatalogoServicio,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.nombreProveedor} domiciliado correctamente'),
          backgroundColor: Colors.green.shade700,
        ),
      );
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
      if (mounted) setState(() => _procesando = false);
    }
  }

  IconData _icono(String tipo) {
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

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'internet':
        return Colors.blue;
      case 'luz':
        return Colors.amber.shade700;
      case 'agua':
        return Colors.cyan.shade700;
      default:
        return Colors.grey;
    }
  }

  String _etiqueta(String tipo) {
    switch (tipo) {
      case 'internet':
        return 'Internet';
      case 'luz':
        return 'Luz';
      case 'agua':
        return 'Agua';
      default:
        return 'Otro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: const Text('Domiciliar servicio')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(mensaje: _error!, onRetry: _cargar)
              : _catalogo.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No hay servicios disponibles en el catalogo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _catalogo.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _catalogo[i];
                        final yaActivo = _idsYaActivos.contains(
                          s.idCatalogoServicio,
                        );
                        final color = _colorTipo(s.tipoServicio);
                        return Material(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: (_procesando || yaActivo)
                                ? null
                                : () => _domiciliar(s),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: yaActivo
                                      ? tokens.border
                                      : tokens.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _icono(s.tipoServicio),
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s.nombreProveedor,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: tokens.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _etiqueta(s.tipoServicio),
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (s.descripcion != null)
                                          Text(
                                            s.descripcion!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: tokens.textSecondary,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${s.monto.toStringAsFixed(2)} / hora',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    yaActivo
                                        ? Icons.check_circle
                                        : Icons.add_circle_outline,
                                    color: yaActivo
                                        ? Colors.grey
                                        : SantanderColors.red,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.mensaje, required this.onRetry});
  final String mensaje;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: tokens.error, size: 48),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}