/// Pantalla de detalle de una cuenta del cliente.
///
/// Carga: detalle de la cuenta, privilegios del cliente sobre la cuenta
/// y domiciliaciones. Tiene botones para transferir y pagar.
library;

import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../historial/historial_cuenta_screen.dart';
import 'cliente_repository.dart';
import 'cliente_transferir_screen.dart';
import 'compartir_cuenta_screen.dart';
import 'domiciliar_servicio_screen.dart';

class ClienteCuentaDetalleScreen extends StatefulWidget {
  const ClienteCuentaDetalleScreen({
    super.key,
    required this.codigoCuenta,
    required this.nombreCliente,
    this.userCurp,
  });

  final String codigoCuenta;
  final String nombreCliente;

  /// CURP del usuario actualmente logueado. Se usa para saber si
  /// tiene `cerrar_cuenta` sobre esta cuenta y, por tanto, puede
  /// administrar los accesos compartidos.
  final String? userCurp;

  @override
  State<ClienteCuentaDetalleScreen> createState() =>
      _ClienteCuentaDetalleScreenState();
}

class _ClienteCuentaDetalleScreenState
    extends State<ClienteCuentaDetalleScreen> {
  final _repo = ClienteRepository();

  ClienteCuenta? _cuenta;
  PrivilegiosResponse? _privilegios;
  List<Domiciliacion> _doms = [];
  UsuariosCuentaResponse? _accesos;
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
      final results = await Future.wait<dynamic>([
        _repo.obtenerDetalleCuenta(widget.codigoCuenta),
        _repo.obtenerPrivilegios(widget.codigoCuenta),
        _repo.obtenerDomiciliaciones(widget.codigoCuenta),
        _repo.obtenerUsuariosCuenta(widget.codigoCuenta),
      ]);
      if (!mounted) return;
      setState(() {
        _cuenta = results[0] as ClienteCuenta;
        _privilegios = results[1] as PrivilegiosResponse;
        _doms = results[2] as List<Domiciliacion>;
        _accesos = results[3] as UsuariosCuentaResponse;
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

  bool get _esDueno {
    final curp = widget.userCurp;
    final a = _accesos;
    if (curp == null || a == null) return false;
    return a.esDueno(curp);
  }

  Future<void> _abrirCompartir({CuentaUsuario? editar}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompartirCuentaScreen(
          codigoCuenta: widget.codigoCuenta,
          editarExistente: editar,
        ),
      ),
    );
    if (ok == true) {
      _cargar();
    }
  }

  Future<void> _quitarAcceso(CuentaUsuario u) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar acceso'),
        content: Text(
          '¿Quitar a ${u.nombreCompleto.isEmpty ? u.curp : u.nombreCompleto} '
          'el acceso a la cuenta ${widget.codigoCuenta}?\n\n'
          'Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await _repo.quitarAccesoUsuario(
        codigoCuenta: widget.codigoCuenta,
        curp: u.curp,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Acceso de ${u.curp} eliminado'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  bool _tienePrivilegio(String nombre) {
    if (_privilegios == null) return false;
    return _privilegios!.privilegios.any((p) => p.loTiene && p.nombreOperacion == nombre);
  }

  Future<void> _transferir() async {
    if (_cuenta == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClienteTransferirScreen(
          codigoCuentaOrigen: _cuenta!.codigoCuenta,
          saldoDisponible: _cuenta!.saldo,
        ),
      ),
    );
    if (ok == true) {
      _cargar();
    }
  }

  Future<void> _pagarDomiciliacion(Domiciliacion dom) async {
    final monto = dom.montoTotalACobrar ?? dom.montoAutorizado ?? 0;
    final recargo = dom.recargoAcumulado;
    final mensajeCuerpo = recargo > 0
        ? 'Vas a pagar \$${monto.toStringAsFixed(2)} de ${dom.servicio} '
            '(incluye \$${recargo.toStringAsFixed(2)} de recargo) '
            'desde tu cuenta ${_cuenta?.codigoCuenta}.'
        : 'Vas a pagar \$${monto.toStringAsFixed(2)} de ${dom.servicio} '
            'desde tu cuenta ${_cuenta?.codigoCuenta}.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(mensajeCuerpo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: SantanderColors.red),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await _repo.pagarDomiciliacion(
        codigoCuenta: _cuenta!.codigoCuenta,
        idDomiciliacion: dom.idDomiciliacion,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje']?.toString() ?? 'Pago realizado'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _abrirDomiciliar() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DomiciliarServicioScreen(
          codigoCuenta: widget.codigoCuenta,
        ),
      ),
    );
    if (ok == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(_cuenta?.codigoCuenta ?? 'Cuenta')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _cuenta == null
                    ? const Center(child: Text('Sin datos'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                        children: [
                          _SaldoCard(cuenta: _cuenta!),
                          const SizedBox(height: 16),
                          if (_tienePrivilegio('transferir'))
                            _Accion(
                              icon: Icons.swap_horiz,
                              label: 'Transferir',
                              onTap: _transferir,
                            ),
                          const SizedBox(height: 20),
                          _SeccionInfo(cuenta: _cuenta!),
                          const SizedBox(height: 20),
                          _SeccionDomiciliaciones(
                            doms: _doms,
                            tokens: tokens,
                            puedePagar: _tienePrivilegio('pagar_domiciliacion'),
                            onPagar: _pagarDomiciliacion,
                            onDomiciliar: _abrirDomiciliar,
                          ),
                          const SizedBox(height: 20),
                          _SeccionPrivilegios(privs: _privilegios?.privilegios ?? const []),
                          const SizedBox(height: 20),
                          _SeccionHistorial(
                            tokens: tokens,
                            onVerMas: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HistorialCuentaScreen(
                                    codigoCuenta: _cuenta!.codigoCuenta,
                                    nombreCuenta: _cuenta!.codigoCuenta,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          _SeccionAccesosCompartidos(
                            tokens: tokens,
                            accesos: _accesos,
                            esDueno: _esDueno,
                            userCurp: widget.userCurp,
                            onCompartir: () => _abrirCompartir(),
                            onEditar: (u) => _abrirCompartir(editar: u),
                            onQuitar: _quitarAcceso,
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.cuenta});
  final ClienteCuenta cuenta;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: esOscuro
              ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
              : [SantanderColors.red, SantanderColors.redDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo disponible',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${cuenta.saldo.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Codigo: ${cuenta.codigoCuenta}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: esOscuro ? tokens.surface : Colors.white,
      elevation: esOscuro ? 0 : 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: SantanderColors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeccionInfo extends StatelessWidget {
  const _SeccionInfo({required this.cuenta});
  final ClienteCuenta cuenta;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Informacion',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 8),
        Container(height: 1, color: tokens.border),
        const SizedBox(height: 8),
        _kv('Sucursal', cuenta.nombreSucursal ?? cuenta.codigoSucursal),
        if (cuenta.ciudad != null) _kv('Ciudad', cuenta.ciudad!),
        if (cuenta.fechaApertura != null)
          _kv('Apertura',
              '${cuenta.fechaApertura!.year}-${cuenta.fechaApertura!.month.toString().padLeft(2, '0')}-${cuenta.fechaApertura!.day.toString().padLeft(2, '0')}'),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _SeccionDomiciliaciones extends StatelessWidget {
  const _SeccionDomiciliaciones({
    required this.doms,
    required this.tokens,
    required this.puedePagar,
    required this.onPagar,
    required this.onDomiciliar,
  });

  final List<Domiciliacion> doms;
  final AppColors tokens;
  final bool puedePagar;
  final void Function(Domiciliacion) onPagar;
  final VoidCallback onDomiciliar;

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

  Color _color(String? tipo) {
    switch (tipo) {
      case 'internet':
        return Colors.blue;
      case 'luz':
        return Colors.amber.shade700;
      case 'agua':
        return Colors.cyan.shade700;
      default:
        return tokens.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar todas (activas + bajas) para que se vea historial
    final activas = doms.where((d) => d.activa).toList();
    final bajas = doms.where((d) => !d.activa).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Domiciliaciones',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onDomiciliar,
              style: TextButton.styleFrom(
                foregroundColor: SantanderColors.red,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Domiciliar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: tokens.border),
        const SizedBox(height: 8),
        if (activas.isEmpty && bajas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: tokens.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Aun no tienes servicios domiciliados',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          )
        else
          ...activas.map((d) => _DomiciliacionTile(
                dom: d,
                tokens: tokens,
                puedePagar: puedePagar,
                onPagar: () => onPagar(d),
                icono: _icono(d.catalogo?.tipoServicio),
                color: _color(d.catalogo?.tipoServicio),
              )),
        if (bajas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Historial (dadas de baja)',
            style: TextStyle(
              fontSize: 11,
              color: tokens.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          ...bajas.map((d) => _DomiciliacionTile(
                dom: d,
                tokens: tokens,
                puedePagar: false,
                onPagar: null,
                icono: _icono(d.catalogo?.tipoServicio),
                color: tokens.textSecondary,
                baja: true,
              )),
        ],
      ],
    );
  }
}

class _DomiciliacionTile extends StatelessWidget {
  const _DomiciliacionTile({
    required this.dom,
    required this.tokens,
    required this.puedePagar,
    required this.onPagar,
    required this.icono,
    required this.color,
    this.baja = false,
  });

  final Domiciliacion dom;
  final AppColors tokens;
  final bool puedePagar;
  final VoidCallback? onPagar;
  final IconData icono;
  final Color color;
  final bool baja;

  @override
  Widget build(BuildContext context) {
    final atrasada = !baja && dom.horasRetraso > 0;
    final recargo = dom.recargoAcumulado;
    final montoMostrar = dom.montoTotalACobrar ?? dom.montoAutorizado ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: atrasada ? Colors.red.shade300 : tokens.border,
          width: atrasada ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dom.servicio,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Cobro automatico cada hora',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${montoMostrar.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: atrasada ? Colors.red.shade700 : null,
                    ),
                  ),
                  if (baja)
                    const Text(
                      'Baja',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              if (onPagar != null && !baja)
                TextButton(
                  onPressed: onPagar,
                  child: const Text('Pagar'),
                ),
            ],
          ),
          if (atrasada) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estas atrasado con el pago. Si pasa la fecha '
                      'limite, se hara un cobro de 2% mas por cada '
                      'hora pasada al monto original '
                      '(${dom.horasRetraso}h atrasadas, '
                      '\$${recargo.toStringAsFixed(2)} recargo).',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeccionPrivilegios extends StatelessWidget {
  const _SeccionPrivilegios({required this.privs});
  final List<Privilegio> privs;

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privilegios',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 8),
        Container(height: 1, color: tokens.border),
        const SizedBox(height: 8),
        if (privs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin privilegios asignados',
                style: TextStyle(color: tokens.textSecondary)),
          )
        else
          ...privs.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      p.loTiene ? Icons.check_circle : Icons.cancel,
                      color: p.loTiene ? Colors.green.shade700 : Colors.grey.shade500,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ClienteRepository.etiquetaDe(p.nombreOperacion),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          if (p.descripcion != null)
                            Text(
                              p.descripcion!,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

class _SeccionAccesosCompartidos extends StatelessWidget {
  const _SeccionAccesosCompartidos({
    required this.tokens,
    required this.accesos,
    required this.esDueno,
    required this.userCurp,
    required this.onCompartir,
    required this.onEditar,
    required this.onQuitar,
  });

  final AppColors tokens;
  final UsuariosCuentaResponse? accesos;
  final bool esDueno;
  final String? userCurp;
  final VoidCallback onCompartir;
  final void Function(CuentaUsuario) onEditar;
  final void Function(CuentaUsuario) onQuitar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Accesos compartidos',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (accesos != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SantanderColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${accesos!.total}',
                  style: const TextStyle(
                    color: SantanderColors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: tokens.border),
        const SizedBox(height: 8),
        if (esDueno)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SantanderColors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SantanderColors.red.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: SantanderColors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Eres dueño de esta cuenta. Puedes compartirla y '
                      'personalizar los privilegios de cada usuario.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCompartir,
                    style: TextButton.styleFrom(
                      foregroundColor: SantanderColors.red,
                    ),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Compartir'),
                  ),
                ],
              ),
            ),
          ),
        if (accesos == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Cargando accesos...'),
          )
        else if (accesos!.usuarios.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nadie mas tiene acceso a esta cuenta.',
              style: TextStyle(color: tokens.textSecondary),
            ),
          )
        else
          ...accesos!.usuarios.map(
            (u) => _UsuarioTile(
              usuario: u,
              tokens: tokens,
              esDuenoActual: esDueno,
              esMiCuenta: u.curp.toUpperCase() ==
                  (userCurp ?? '').toUpperCase(),
              onEditar: () => onEditar(u),
              onQuitar: () => onQuitar(u),
            ),
          ),
      ],
    );
  }
}

class _UsuarioTile extends StatelessWidget {
  const _UsuarioTile({
    required this.usuario,
    required this.tokens,
    required this.esDuenoActual,
    required this.esMiCuenta,
    required this.onEditar,
    required this.onQuitar,
  });

  final CuentaUsuario usuario;
  final AppColors tokens;
  final bool esDuenoActual;
  final bool esMiCuenta;
  final VoidCallback onEditar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    SantanderColors.red.withValues(alpha: 0.10),
                child: Text(
                  _iniciales(usuario.nombreCompleto),
                  style: const TextStyle(
                    color: SantanderColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            usuario.nombreCompleto.isEmpty
                                ? usuario.curp
                                : usuario.nombreCompleto,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (usuario.esDueno)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Dueño',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.brown,
                              ),
                            ),
                          )
                        else if (esMiCuenta)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Tu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${usuario.curp}${usuario.email != null ? " · ${usuario.email}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (esDuenoActual && !esMiCuenta)
                PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (op) {
                    if (op == 'editar') onEditar();
                    if (op == 'quitar') onQuitar();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        leading: Icon(Icons.edit, size: 18),
                        title: Text('Editar privilegios'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'quitar',
                      child: ListTile(
                        leading: Icon(Icons.block, size: 18, color: Colors.red),
                        title: Text('Quitar acceso',
                            style: TextStyle(color: Colors.red)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: usuario.privilegios.map((p) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ClienteRepository.etiquetaDe(p),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Resumen rapido de "Movimientos recientes" + boton para ver
/// el historial completo en una pantalla aparte.
class _SeccionHistorial extends StatelessWidget {
  const _SeccionHistorial({
    required this.tokens,
    required this.onVerMas,
  });

  final AppColors tokens;
  final VoidCallback onVerMas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Historial',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onVerMas,
              style: TextButton.styleFrom(
                foregroundColor: SantanderColors.red,
              ),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Ver historial completo'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: tokens.border),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Consulta todos los movimientos de la cuenta: '
                  'transferencias, pagos de servicios y cobros '
                  'automaticos, depositos y retiros del empleado.',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}