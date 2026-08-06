/// Bottom sheet para cambiar rapido entre cuentas a las que el
/// usuario tiene acceso.
///
/// Comportamiento:
///   * Solo muestra las cuentas en las que el usuario NO es dueno
///     (es decir, cuentas compartidas CON el).
///   * Si la lista esta vacia, dispara un [SnackBar] con el mensaje
///     'No tienes cuentas compartidas' y cierra el sheet.
///   * Cada tile muestra el codigo de la cuenta, la sucursal y el
///     saldo. Tocar = empuja la pantalla de detalle de esa cuenta.
///
/// Las cuentas se cargan en el momento via `ClienteRepository`,
/// reutilizando la lista que ya devuelve `/api/clientes/<curp>/cuentas`.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import 'cliente_cuenta_detalle_screen.dart';
import 'cliente_repository.dart';

class CambiarCuentaSheet extends StatefulWidget {
  const CambiarCuentaSheet({
    super.key,
    required this.userCurp,
    required this.userNombre,
    this.cuentaActualCodigo,
  });

  /// CURP del usuario autenticado. Se usa para filtrar las cuentas
  /// donde NO es dueno.
  final String userCurp;

  /// Nombre para mostrar en el titulo del sheet.
  final String userNombre;

  /// Codigo de la cuenta que se esta viendo actualmente (se marca
  /// con un check y se deshabilita el tile).
  final String? cuentaActualCodigo;

  /// Abre el sheet desde cualquier sitio con un solo metodo estatico.
  /// Devuelve `true` si el usuario eligio una cuenta (y navego al
  /// detalle). Devuelve `false` si cancelo o no tenia cuentas
  /// compartidas.
  static Future<bool> show({
    required BuildContext context,
    required String userCurp,
    required String userNombre,
    String? cuentaActualCodigo,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CambiarCuentaSheet(
        userCurp: userCurp,
        userNombre: userNombre,
        cuentaActualCodigo: cuentaActualCodigo,
      ),
    );
    return result == true;
  }

  @override
  State<CambiarCuentaSheet> createState() => _CambiarCuentaSheetState();
}

class _CambiarCuentaSheetState extends State<CambiarCuentaSheet> {
  final _repo = ClienteRepository();

  ClienteCuentasResponse? _data;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await _repo.obtenerCuentas(widget.userCurp);
      if (!mounted) return;
      setState(() {
        _data = r;
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

  /// Devuelve las cuentas en las que el usuario actual NO es dueno.
  /// Como el backend no expone 'es_dueno' en este endpoint,
  /// usamos la heuristica: si la cuenta NO empieza por CTA-{curp[:6]}-
  /// entonces fue creada por otro cliente y, por tanto, es compartida
  /// con nosotros.
  List<ClienteCuenta> get _compartidas {
    final data = _data;
    if (data == null) return const [];
    final curp6 = widget.userCurp.toUpperCase().substring(
          0,
          widget.userCurp.length >= 6 ? 6 : widget.userCurp.length,
        );
    final propias = 'CTA-$curp6-';
    return data.cuentas
        .where((c) =>
            !c.codigoCuenta.toUpperCase().startsWith(propias.toUpperCase()))
        .toList();
  }

  Future<void> _elegir(ClienteCuenta c) async {
    Navigator.of(context).pop(true); // cerrar sheet
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClienteCuentaDetalleScreen(
          codigoCuenta: c.codigoCuenta,
          nombreCliente: widget.userNombre,
          userCurp: widget.userCurp,
        ),
      ),
    );
  }

  void _mostrarMensajeVacio() {
    // Cerramos el sheet y mostramos el mensaje fuera del modal.
    Navigator.of(context).pop(false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('No tienes cuentas compartidas'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.background,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            children: [
              // Handle para arrastrar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: tokens.textPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cambiar de cuenta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Solo se muestran las cuentas que otros han compartido contigo.',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Divider(height: 1, color: tokens.border),
              Expanded(
                child: _buildBody(tokens, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(AppColors tokens, ScrollController scrollController) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: tokens.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _cargando = true;
                  _error = null;
                });
                _cargar();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final compartidas = _compartidas;
    if (compartidas.isEmpty) {
      // Si no hay compartidas, mostramos un mini estado dentro del
      // sheet y dejamos que el usuario lo cierre; luego, como gesto
      // de UX, si estaba vacio por no tener compartidas (vs. por
      // error), no forzamos el snackbar. Aqui optamos por SI
      // mostrarlo, que es lo que pide el requerimiento.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarMensajeVacio();
      });
      return const SizedBox.shrink();
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: compartidas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = compartidas[i];
        final esActual = widget.cuentaActualCodigo != null &&
            c.codigoCuenta.toUpperCase() ==
                widget.cuentaActualCodigo!.toUpperCase();
        return _CuentaTile(
          cuenta: c,
          tokens: tokens,
          esActual: esActual,
          onTap: esActual ? null : () => _elegir(c),
        );
      },
    );
  }
}

class _CuentaTile extends StatelessWidget {
  const _CuentaTile({
    required this.cuenta,
    required this.tokens,
    required this.esActual,
    required this.onTap,
  });

  final ClienteCuenta cuenta;
  final AppColors tokens;
  final bool esActual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: esActual
                  ? SantanderColors.red.withValues(alpha: 0.5)
                  : tokens.border,
              width: esActual ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: esActual
                    ? SantanderColors.red
                    : SantanderColors.red.withValues(alpha: 0.10),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: esActual ? Colors.white : SantanderColors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta.codigoCuenta,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cuenta.nombreSucursal ?? "Sucursal"} · '
                      '${cuenta.ciudad ?? "—"}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${cuenta.saldo.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (esActual)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Actual',
                        style: TextStyle(
                          color: SantanderColors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                esActual ? Icons.check : Icons.chevron_right,
                color: esActual
                    ? SantanderColors.red
                    : tokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}