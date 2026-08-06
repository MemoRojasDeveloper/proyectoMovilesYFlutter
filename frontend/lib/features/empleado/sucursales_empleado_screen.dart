/// Dashboard principal del EMPLEADO: lista de sucursales.
///
/// Incluye:
///  - Buscador en vivo (filtra por nombre, código, ciudad, estado).
///  - Tarjetas modernas con elevation y badge de estado.
///  - Menú popup por tarjeta: Editar / Copiar dirección / Compartir.
///  - FAB para crear una nueva sucursal.
///  - Pull-to-refresh.
///  - Estado vacío amigable.
///  - Logout visible en el AppBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/auth_storage.dart';
import '../../core/theme.dart';
import '../auth/auth_repository.dart';
import 'prestamos_empleado_screen.dart';
import 'sucursal_detalle_screen.dart';
import 'sucursal_form_screen.dart';
import 'sucursales_repository.dart';

class SucursalesEmpleadoScreen extends StatefulWidget {
  const SucursalesEmpleadoScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.themeController,
  });

  final AuthResult user;
  final VoidCallback onLogout;
  final ThemeController? themeController;

  @override
  State<SucursalesEmpleadoScreen> createState() =>
      _SucursalesEmpleadoScreenState();
}

class _SucursalesEmpleadoScreenState extends State<SucursalesEmpleadoScreen> {
  final _repository = SucursalesRepository();
  final _searchController = TextEditingController();
  final _storage = AuthStorage();

  List<Sucursal> _todas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final list = await _repository.listar();
      if (!mounted) return;
      setState(() {
        _todas = list;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar la lista: $e';
      });
    }
  }

  List<Sucursal> get _filtradas {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _todas;
    return _todas.where((s) {
      return s.nombreSucursal.toLowerCase().contains(q) ||
          s.codigoSucursal.toLowerCase().contains(q) ||
          (s.ciudad ?? '').toLowerCase().contains(q) ||
          (s.estado ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _abrirFormulario({Sucursal? existente}) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SucursalFormScreen(sucursal: existente),
      ),
    );
    if (resultado == true) {
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existente == null
                  ? 'Sucursal creada con éxito'
                  : 'Sucursal actualizada con éxito',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    }
  }

  Future<void> _abrirDetalle(Sucursal s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SucursalDetalleScreen(sucursal: s)),
    );
  }

  Future<void> _copiarDireccion(Sucursal s) async {
    await Clipboard.setData(ClipboardData(text: s.direccionCorta));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dirección copiada al portapapeles')),
    );
  }

  Future<void> _compartir(Sucursal s) async {
    final texto =
        'Sucursal: ${s.nombreSucursal}\n'
        'Código: ${s.codigoSucursal}\n'
        'Dirección: ${s.direccionCorta}\n'
        'Teléfono: ${s.telefono ?? "—"}\n'
        'Horario: ${s.horarioLabel ?? "—"}';
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Información copiada al portapapeles')),
    );
  }

  Future<void> _toggleActivo(Sucursal s) async {
    final nuevo = !s.activo;
    try {
      await _repository.toggleActivo(s.codigoSucursal, nuevo);
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nuevo ? 'Sucursal marcada como operativa' : 'Sucursal marcada como no operativa',
          ),
          backgroundColor: nuevo ? Colors.green.shade700 : Colors.grey.shade700,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _logout() async {
    await _storage.clear();
    if (!mounted) return;
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Sucursales'),
        actions: [
          IconButton(
            tooltip: 'Solicitudes de préstamo',
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrestamosEmpleadoScreen(),
                ),
              );
            },
          ),
          if (widget.themeController != null) _ThemeToggleButton(
            controller: widget.themeController!,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header con saludo
            _SaludoHeader(
              nombre: widget.user.nombres ?? widget.user.email ?? 'Empleado',
              total: _todas.length,
              operativas: _todas.where((s) => s.activo).length,
              tokens: tokens,
              esOscuro: esOscuro,
            ),

            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, código o ciudad...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: tokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // Contenido
            Expanded(
              child: _buildContenido(tokens, esOscuro),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: SantanderColors.red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva sucursal'),
      ),
    );
  }

  Widget _buildContenido(AppColors tokens, bool esOscuro) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _EstadoError(
        mensaje: _error!,
        onRetry: _cargar,
        tokens: tokens,
      );
    }
    final list = _filtradas;
    if (list.isEmpty) {
      return _EstadoVacio(
        tokens: tokens,
        esOscuro: esOscuro,
        tieneFiltro: _searchController.text.isNotEmpty,
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _SucursalCard(
          sucursal: list[i],
          tokens: tokens,
          esOscuro: esOscuro,
          onTap: () => _abrirDetalle(list[i]),
          onEditar: () => _abrirFormulario(existente: list[i]),
          onCopiar: () => _copiarDireccion(list[i]),
          onCompartir: () => _compartir(list[i]),
          onToggleActivo: () => _toggleActivo(list[i]),
        ),
      ),
    );
  }
}

// ───────────────────── Header saludo ─────────────────────

class _SaludoHeader extends StatelessWidget {
  const _SaludoHeader({
    required this.nombre,
    required this.total,
    required this.operativas,
    required this.tokens,
    required this.esOscuro,
  });

  final String nombre;
  final int total;
  final int operativas;
  final AppColors tokens;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: esOscuro
              ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
              : [SantanderColors.red, SantanderColors.redDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, $nombre',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Panel de empleados · Sucursales',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(label: 'Total', value: '$total', esOscuro: esOscuro),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Operativas',
                value: '$operativas',
                esOscuro: esOscuro,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Inactivas',
                value: '${total - operativas}',
                esOscuro: esOscuro,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.esOscuro,
  });

  final String label;
  final String value;
  final bool esOscuro;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: esOscuro ? 0.10 : 0.20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── Tarjeta de sucursal ─────────────────────

class _SucursalCard extends StatelessWidget {
  const _SucursalCard({
    required this.sucursal,
    required this.tokens,
    required this.esOscuro,
    required this.onTap,
    required this.onEditar,
    required this.onCopiar,
    required this.onCompartir,
    required this.onToggleActivo,
  });

  final Sucursal sucursal;
  final AppColors tokens;
  final bool esOscuro;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onCopiar;
  final VoidCallback onCompartir;
  final VoidCallback onToggleActivo;

  @override
  Widget build(BuildContext context) {
    final cardColor = esOscuro ? tokens.surface : Colors.white;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: esOscuro ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business,
                  color: SantanderColors.red,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sucursal.nombreSucursal,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _EstadoBadge(activo: sucursal.activo),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sucursal.codigoSucursal} · ${sucursal.direccionCorta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (sucursal.telefono != null || sucursal.horarioLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (sucursal.telefono != null) ...[
                              Icon(Icons.phone, size: 12, color: tokens.textSecondary),
                              const SizedBox(width: 3),
                              Text(
                                sucursal.telefono!,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (sucursal.horarioLabel != null) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.access_time, size: 12, color: tokens.textSecondary),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  sucursal.horarioLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: tokens.textSecondary),
                onSelected: (v) {
                  switch (v) {
                    case 'editar':
                      onEditar();
                      break;
                    case 'copiar':
                      onCopiar();
                      break;
                    case 'compartir':
                      onCompartir();
                      break;
                    case 'toggle':
                      onToggleActivo();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit, size: 20),
                      title: Text('Editar'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copiar',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy, size: 20),
                      title: Text('Copiar dirección'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'compartir',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.share, size: 20),
                      title: Text('Compartir'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        sucursal.activo ? Icons.toggle_off : Icons.toggle_on,
                        size: 20,
                      ),
                      title: Text(
                        sucursal.activo
                            ? 'Marcar no operativa'
                            : 'Marcar operativa',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.activo});
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.green.shade700 : Colors.grey.shade600;
    final icon = activo ? Icons.check_circle : Icons.cancel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text(
            activo ? 'Operativa' : 'Inactiva',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Estados especiales ─────────────────────

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({
    required this.tokens,
    required this.esOscuro,
    required this.tieneFiltro,
  });

  final AppColors tokens;
  final bool esOscuro;
  final bool tieneFiltro;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: SantanderColors.red.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tieneFiltro ? Icons.search_off : Icons.business_outlined,
                size: 44,
                color: SantanderColors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tieneFiltro
                  ? 'Sin resultados'
                  : 'Aún no hay sucursales',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tieneFiltro
                  ? 'Intenta con otro nombre o código'
                  : 'Crea la primera sucursal tocando el botón +',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({
    required this.mensaje,
    required this.onRetry,
    required this.tokens,
  });

  final String mensaje;
  final VoidCallback onRetry;
  final AppColors tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

// ───────────────────── Toggle de tema (mini) ─────────────────────

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: controller.mode.label,
      icon: Icon(controller.mode.icon),
      onPressed: () => controller.cycle(),
    );
  }
}