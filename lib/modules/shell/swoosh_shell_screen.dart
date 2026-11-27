import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../control/pedido_control.dart';
import '../../entity/pedido.dart';
import '../../entity/sesion_usuario.dart';
import '../../theme/swoosh_colors.dart';
import '../entregas/entregas_module_screen.dart';
import '../mapa_ruta/mapa_ruta_module_screen.dart';
import '../metricas/metricas_module_screen.dart';

class SwooshShellScreen extends StatefulWidget {
  final SesionUsuario sesion;
  final Future<void> Function() onCerrarSesion;
  final PedidoControl? pedidoControl;

  const SwooshShellScreen({
    super.key,
    required this.sesion,
    required this.onCerrarSesion,
    this.pedidoControl,
  });

  @override
  State<SwooshShellScreen> createState() => _SwooshShellScreenState();
}

class _SwooshShellScreenState extends State<SwooshShellScreen> {
  late final PedidoControl _pedidoControl;
  StreamSubscription<void>? _syncSubscription;

  int _tabIndex = 0;
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  bool _optimizando = false;
  bool _isOnline = false;
  int _pendientesSync = 0;
  int? _ultimoTsyncMs;
  String? _errorInicializacion;

  Ubicacion _ubicacionActual = Ubicacion(lat: 13.9942, lng: -89.5597);

  String get _repartidorActivoId =>
      widget.sesion.repartidorId ?? 'rep-1';

  String? get _filtroRepartidor =>
      widget.sesion.esNegocio ? null : _repartidorActivoId;

  @override
  void initState() {
    super.initState();
    _pedidoControl = widget.pedidoControl ?? PedidoControl();
    _syncSubscription = _pedidoControl.cambiosSync.listen((_) {
      unawaited(_refrescar());
    });
    _inicializar();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _pedidoControl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SwooshShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sesion.esNegocio != widget.sesion.esNegocio) {
      _tabIndex = 0;
    }
  }

  Future<void> _inicializar() async {
    try {
      await _pedidoControl.inicializar(repartidorId: _filtroRepartidor);
      await _obtenerGps();
      await _refrescar();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorInicializacion = 'No se pudo abrir el almacenamiento local: $error';
      });
    }
  }

  Future<void> _obtenerGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        _ubicacionActual = Ubicacion(lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _refrescar() async {
    final lista =
        await _pedidoControl.obtenerPedidos(repartidorId: _filtroRepartidor);
    final online = await _pedidoControl.hayConexion();
    final pend = await _pedidoControl.obtenerCantidadPendientes();
    final tsync = _pedidoControl.obtenerUltimoTsyncMs();

    if (!mounted) return;
    setState(() {
      _pedidos = lista;
      _isOnline = online;
      _pendientesSync = pend;
      _ultimoTsyncMs = tsync;
      _cargando = false;
    });
  }

  Future<void> _crearPedido(
      String cliente, String dir, Ubicacion ubi, double total) async {
    await _pedidoControl.crearPedido(
      cliente: cliente,
      direccion: dir,
      ubicacion: ubi,
      total: total,
      repartidorId: _repartidorActivoId,
    );
    await _refrescar();
  }

  Future<void> _crearPedidoCompleto(Pedido nuevo) async {
    final conRepartidor = nuevo.copyWith(
      repartidorId: nuevo.repartidorId ?? _repartidorActivoId,
      estado: 'asignado',
      sincronizado: _isOnline,
    );

    await _pedidoControl.crearPedidoCompleto(conRepartidor);
    await _refrescar();
  }

  Future<void> _cambiarEstado(Pedido pedido, String nuevoEstado) async {
    await _pedidoControl.actualizarEstadoPedido(
      pedidoId: pedido.id,
      nuevoEstado: nuevoEstado,
      repartidorId: pedido.repartidorId ?? _repartidorActivoId,
    );
    await _refrescar();
  }

  Future<void> _optimizarRuta() async {
    setState(() => _optimizando = true);
    await _obtenerGps();
    final ordenados = await _pedidoControl.obtenerRutaOptimizada(
      repartidorId: _repartidorActivoId,
      origenActual: _ubicacionActual,
    );
    if (!mounted) return;
    setState(() {
      if (ordenados.isNotEmpty) {
        final entregados =
            _pedidos.where((p) => p.estado == 'entregado').toList();
        _pedidos = [...ordenados, ...entregados];
      }
      _optimizando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final esNegocio = widget.sesion.esNegocio;

    final pantallas = esNegocio
        ? <Widget>[
            EntregasModuleScreen(
              pedidos: _pedidos,
              isOnline: _isOnline,
              ubicacionActual: _ubicacionActual,
              puedeCrearPedidos: true,
              onCambiarEstado: _cambiarEstado,
              onCrearPedido: _crearPedido,
              onCrearPedidoCompleto: _crearPedidoCompleto,
            ),
            MetricasModuleScreen(
              pedidos: _pedidos,
              ultimoTsyncMs: _ultimoTsyncMs,
              pendientesSync: _pendientesSync,
            ),
          ]
        : <Widget>[
            MapaRutaModuleScreen(
              pedidos: _pedidos,
              ubicacionActual: _ubicacionActual,
              optimizando: _optimizando,
              onOptimizarRuta: _optimizarRuta,
              onCambiarEstado: _cambiarEstado,
            ),
          ];

    final destinos = esNegocio
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(
                Icons.list_alt,
                color: SwooshColors.azulPrimario,
              ),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(
                Icons.analytics,
                color: SwooshColors.azulPrimario,
              ),
              label: 'Resumen',
            ),
          ]
        : const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: SwooshColors.azulPrimario),
              label: 'Mapa Ruta',
            ),
          ];

    final indiceSeguro = _tabIndex >= pantallas.length || _tabIndex < 0
        ? 0
        : _tabIndex;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.lightBlueAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SWOOSH', style: TextStyle(fontSize: 17)),
                  Text(
                    '${widget.sesion.nombre} · ${esNegocio ? 'Negocio' : 'Repartidor'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async => await widget.onCerrarSesion(),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorInicializacion != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorInicializacion!, textAlign: TextAlign.center),
                  ),
                )
          : pantallas[indiceSeguro],
      bottomNavigationBar: destinos.length == 1
          ? _barraDestinoUnico(context, destinos.single)
          : NavigationBar(
              selectedIndex: indiceSeguro,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: destinos,
            ),
    );
  }

  Widget _barraDestinoUnico(
    BuildContext context,
    NavigationDestination destino,
  ) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 80,
        child: Semantics(
          selected: true,
          label: destino.label,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              destino.selectedIcon ?? destino.icon,
              const SizedBox(height: 4),
              Text(destino.label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
