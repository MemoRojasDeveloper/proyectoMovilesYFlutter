/// Pantalla del empleado: cola de solicitudes de préstamo.
///
/// Lista los préstamos en estado 'pendiente'. Permite ver el motivo,
/// aprobar o rechazar (con motivo obligatorio) y ver el historial.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'prestamos_empleado_repository.dart';

class PrestamosEmpleadoScreen extends StatefulWidget {
  const PrestamosEmpleadoScreen({super.key});

  @override
  State<PrestamosEmpleadoScreen> createState() =>
      _PrestamosEmpleadoScreenState();
}

class _PrestamosEmpleadoScreenState extends State<PrestamosEmpleadoScreen> {
  final _repo = PrestamosEmpleadoRepository();
  List<PrestamoEmpleado> _pendientes = [];
  bool _cargando = true;
  String? _error;

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
      final list = await _repo.listarPendientes();
      if (!mounted) return;
      setState(() {
        _pendientes = list;
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

  Future<void> _aprobar(PrestamoEmpleado p) async {
    final motivo = await _pedirMotivo(
      titulo: 'Aprobar solicitud #${p.idPrestamo}',
      mensaje: 'Dejá un comentario para que el cliente entienda la decisión.',
      confirmar: 'Aprobar',
      iconoConfirmar: Icons.check_circle_outline,
    );
    if (motivo == null) return;

    try {
      await _repo.aprobar(p.idPrestamo, motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud #${p.idPrestamo} aprobada'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aprobar: $e')),
      );
    }
  }

  Future<void> _rechazar(PrestamoEmpleado p) async {
    final motivo = await _pedirMotivo(
      titulo: 'Rechazar solicitud #${p.idPrestamo}',
      mensaje: 'El motivo es obligatorio y se le muestra al cliente.',
      confirmar: 'Rechazar',
      iconoConfirmar: Icons.cancel_outlined,
    );
    if (motivo == null) return;

    try {
      await _repo.rechazar(p.idPrestamo, motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud #${p.idPrestamo} rechazada'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo rechazar: $e')),
      );
    }
  }

  Future<String?> _pedirMotivo({
    required String titulo,
    required String mensaje,
    required String confirmar,
    required IconData iconoConfirmar,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(titulo),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensaje,
                    style: TextStyle(
                      color: AppColors.of(ctx).textSecondary,
                      fontSize: 13,
                    )),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 500,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    hintText: 'Ej. El monto supera el límite permitido',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Motivo obligatorio';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              icon: Icon(iconoConfirmar),
              label: Text(confirmar),
              style: ElevatedButton.styleFrom(
                backgroundColor: SantanderColors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verHistorial(PrestamoEmpleado p) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _HistorialSheet(
        repo: _repo,
        idPrestamo: p.idPrestamo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Solicitudes de préstamo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _build(tokens),
      ),
    );
  }

  Widget _build(AppColors tokens) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: tokens.error, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_pendientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF2E7D32),
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sin solicitudes pendientes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'No hay solicitudes de préstamo para revisar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _pendientes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _SolicitudCard(
        prestamo: _pendientes[i],
        tokens: tokens,
        onAprobar: () => _aprobar(_pendientes[i]),
        onRechazar: () => _rechazar(_pendientes[i]),
        onHistorial: () => _verHistorial(_pendientes[i]),
      ),
    );
  }
}

class _SolicitudCard extends StatelessWidget {
  const _SolicitudCard({
    required this.prestamo,
    required this.tokens,
    required this.onAprobar,
    required this.onRechazar,
    required this.onHistorial,
  });

  final PrestamoEmpleado prestamo;
  final AppColors tokens;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;
  final VoidCallback onHistorial;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final cardColor = esOscuro ? tokens.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: esOscuro ? 0 : 2,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Titular: ${prestamo.curp}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                if (prestamo.curpSolicitante != null &&
                    prestamo.curpSolicitante != prestamo.curp)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Solicitada por tercero',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Préstamo #${prestamo.idPrestamo}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Chip(
                  icon: Icons.attach_money,
                  label: 'Monto: \$${prestamo.montoOtorgado.toStringAsFixed(2)}',
                ),
                _Chip(
                  icon: Icons.percent,
                  label: 'Tasa: ${prestamo.tasaInteres.toStringAsFixed(1)}%',
                ),
                _Chip(
                  icon: Icons.calendar_month,
                  label: 'Plazo: ${prestamo.plazoMeses} meses',
                ),
              ],
            ),
            if (prestamo.motivoSolicitud != null &&
                prestamo.motivoSolicitud!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motivo de la solicitud',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prestamo.motivoSolicitud!,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onHistorial,
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Historial'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRechazar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.error,
                      side: BorderSide(color: tokens.error),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAprobar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HistorialSheet extends StatefulWidget {
  const _HistorialSheet({
    required this.repo,
    required this.idPrestamo,
  });

  final PrestamosEmpleadoRepository repo;
  final int idPrestamo;

  @override
  State<_HistorialSheet> createState() => _HistorialSheetState();
}

class _HistorialSheetState extends State<_HistorialSheet> {
  List<dynamic>? _eventos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final eventos = await widget.repo.obtenerEventos(widget.idPrestamo);
      if (!mounted) return;
      setState(() => _eventos = eventos);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error: $e');
    }
  }

  String _etiquetaTipo(String t) {
    switch (t) {
      case 'solicitud':
        return 'Solicitud';
      case 'aprobacion':
        return 'Aprobación';
      case 'rechazo':
        return 'Rechazo';
      case 'cancelacion':
        return 'Cancelación';
      case 'pago_cuota':
        return 'Pago de cuota';
      default:
        return t;
    }
  }

  IconData _iconoTipo(String t) {
    switch (t) {
      case 'solicitud':
        return Icons.send_outlined;
      case 'aprobacion':
        return Icons.check_circle_outline;
      case 'rechazo':
        return Icons.cancel_outlined;
      case 'cancelacion':
        return Icons.do_disturb_alt_outlined;
      case 'pago_cuota':
        return Icons.payments_outlined;
      default:
        return Icons.event_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Historial del préstamo #${widget.idPrestamo}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_eventos == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: tokens.error),
              ),
            if (_eventos != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _eventos!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final ev = _eventos![i] as Map<String, dynamic>;
                    final tipo = ev['tipo'] as String? ?? '';
                    final fecha = ev['fecha'] as String? ?? '';
                    final motivo = ev['motivo'] as String?;
                    final actor = ev['curp_actor'] as String?;
                    final estado = ev['estado_nuevo'] as String?;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _iconoTipo(tipo),
                                size: 16,
                                color: tokens.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _etiquetaTipo(tipo),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if (estado != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    estado,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fecha,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                          if (actor != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Por: $actor',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                          if (motivo != null && motivo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              motivo,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
