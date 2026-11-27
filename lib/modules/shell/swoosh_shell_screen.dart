import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../control/db_local_control.dart';
import '../../control/pedido_control.dart';
import '../../entity/pedido.dart';
import '../../entity/sesion_usuario.dart';
import '../../theme/swoosh_colors.dart';
import '../entregas/entregas_module_screen.dart';
import '../mapa_ruta/mapa_ruta_module_screen.dart';
import '../metricas/metricas_module_screen.dart';
import '../replicacion/replicacion_module_screen.dart';

class SwooshShellScreen extends StatefulWidget {
  final SesionUsuario sesion;
  final Future<void> Function() onCerrarSesion;

  const SwooshShellScreen({
    super.key,
    required this.sesion,
    required this.onCerrarSesion,
  });

  @override
  State<SwooshShellScreen> createState() => _SwooshShellScreenState();
}

class _SwooshShellScreenState extends State<SwooshShellScreen> {
  final PedidoControl _pedidoControl = PedidoControl();
  final Uuid _uuid = const Uuid();

  int _tabIndex = 0;
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  bool _optimizando = false;
  bool _isOnline = false;
  int _pendientesSync = 0;
  int? _ultimoTsyncMs;
  bool _modoWebDemo = false;

  Ubicacion _ubicacionActual = Ubicacion(lat: 13.9942, lng: -89.5597);

  String get _repartidorActivoId =>
      widget.sesion.repartidorId ?? 'rep-1';

  String? get _filtroRepartidor =>
      widget.sesion.esNegocio ? null : _repartidorActivoId;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      if (kIsWeb) throw UnsupportedError('sqflite en web');
      await _pedidoControl.inicializar();
      await _obtenerGps();
      await _refrescar();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _modoWebDemo = true;
        _isOnline = true;
        _ultimoTsyncMs = 68;
        _pedidos = [
          Pedido(
            id: 'demo-1',
            cliente: 'Comedor La Ceiba',
            tituloParada: 'Comedor La Ceiba · Centro',
            direccion: 'Av. Independencia Sur, Santa Ana',
            referenciaVisual: 'Portón negro frente a parqueo',
            ubicacion: Ubicacion(lat: 13.9942, lng: -89.5597),
            total: 14.50,
            subtotalProductos: 13.00,
            costoEnvio: 1.50,
            metodoPago: 'efectivo',
            pagaCon: 20.00,
            estado: 'asignado',
            repartidorId: _repartidorActivoId,
          ),
          Pedido(
            id: 'demo-2',
            cliente: 'Tienda El Progreso',
            tituloParada: 'Tienda El Progreso · Col. El Palmar',
            direccion: 'Calle Principal, Col. El Palmar, Santa Ana',
            referenciaVisual: 'Casa esquina rótulo azul',
            ubicacion: Ubicacion(lat: 13.9875, lng: -89.5640),
            total: 22.00,
            subtotalProductos: 20.00,
            costoEnvio: 2.00,
            metodoPago: 'transferencia',
            estado: 'pendiente',
            repartidorId: _repartidorActivoId,
          ),
          Pedido(
            id: 'demo-3',
            cliente: 'Pupusería Doña María',
            tituloParada: 'Pupusería Doña María · Barrio San Juan',
            direccion: '4a Calle Oriente, Barrio San Juan, Santa Ana',
            referenciaVisual: 'Frente a tienda',
            ubicacion: Ubicacion(lat: 13.9990, lng: -89.5521),
            total: 9.75,
            subtotalProductos: 8.50,
            costoEnvio: 1.25,
            metodoPago: 'efectivo',
            pagaCon: 10.00,
            estado: 'pendiente',
            repartidorId: _repartidorActivoId,
          ),
        ];
        _cargando = false;
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
    if (_modoWebDemo) {
      setState(() {
        _pedidos.insert(
          0,
          Pedido(
            id: _uuid.v4(),
            cliente: cliente,
            direccion: dir,
            ubicacion: ubi,
            total: total,
            estado: 'asignado',
            repartidorId: _repartidorActivoId,
            sincronizado: _isOnline,
          ),
        );
        if (!_isOnline) _pendientesSync++;
      });
      return;
    }

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

    if (_modoWebDemo) {
      setState(() {
        _pedidos.insert(0, conRepartidor);
        if (!_isOnline) _pendientesSync++;
      });
      return;
    }

    await _pedidoControl.crearPedido(
      cliente: conRepartidor.cliente,
      direccion: conRepartidor.direccion,
      ubicacion: conRepartidor.ubicacion,
      total: conRepartidor.total,
      repartidorId: conRepartidor.repartidorId,
    );
    await DbLocalControl().guardarPedido(conRepartidor);
    await _refrescar();
  }

  Future<void> _cambiarEstado(Pedido pedido, String nuevoEstado) async {
    if (_modoWebDemo) {
      setState(() {
        final idx = _pedidos.indexWhere((p) => p.id == pedido.id);
        if (idx != -1) {
          _pedidos[idx] = pedido.copyWith(
            estado: nuevoEstado,
            entregadoEn: nuevoEstado == 'entregado'
                ? DateTime.now().toUtc().toIso8601String()
                : pedido.entregadoEn,
            sincronizado: _isOnline,
          );
          if (!_isOnline) _pendientesSync++;
        }
      });
      return;
    }

    await _pedidoControl.actualizarEstadoPedido(
      pedidoId: pedido.id,
      nuevoEstado: nuevoEstado,
      repartidorId: pedido.repartidorId ?? _repartidorActivoId,
    );
    await _refrescar();
  }

  Future<void> _optimizarRuta() async {
    setState(() => _optimizando = true);
    if (_modoWebDemo) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        final activos = _pedidos.where((p) => p.estado != 'entregado').toList()
          ..sort((a, b) => a.ubicacion.lat.compareTo(b.ubicacion.lat));
        final entregados =
            _pedidos.where((p) => p.estado == 'entregado').toList();
        _pedidos = [...activos, ...entregados];
        _optimizando = false;
      });
      return;
    }

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

  Future<void> _forzarSync() async {
    if (_modoWebDemo) {
      setState(() {
        _isOnline = true;
        _pendientesSync = 0;
        _pedidos = _pedidos.map((p) => p.copyWith(sincronizado: true)).toList();
      });
      return;
    }
    await _pedidoControl.forzarSincronizacion();
    await _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final esNegocio = widget.sesion.esNegocio;

    final pantallas = <Widget>[
      EntregasModuleScreen(
        pedidos: _pedidos,
        isOnline: _isOnline,
        ubicacionActual: _ubicacionActual,
        puedeCrearPedidos: esNegocio,
        onCambiarEstado: _cambiarEstado,
        onCrearPedido: _crearPedido,
        onCrearPedidoCompleto: _crearPedidoCompleto,
      ),
      MapaRutaModuleScreen(
        pedidos: _pedidos,
        ubicacionActual: _ubicacionActual,
        optimizando: _optimizando,
        onOptimizarRuta: _optimizarRuta,
        onCambiarEstado: _cambiarEstado,
      ),
      ReplicacionModuleScreen(
        isOnline: _isOnline,
        pendientesSync: _pendientesSync,
        ultimoTsyncMs: _ultimoTsyncMs,
        pedidos: _pedidos,
        onForzarSync: _forzarSync,
        onToggleSimulacionRed: _modoWebDemo
            ? () => setState(() => _isOnline = !_isOnline)
            : null,
      ),
      if (esNegocio)
        MetricasModuleScreen(
          pedidos: _pedidos,
          ultimoTsyncMs: _ultimoTsyncMs,
          pendientesSync: _pendientesSync,
        ),
    ];

    final destinos = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.list_alt_outlined),
        selectedIcon:
            const Icon(Icons.list_alt, color: SwooshColors.azulPrimario),
        label: esNegocio ? 'Pedidos' : 'Mis Entregas',
      ),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map, color: SwooshColors.azulPrimario),
        label: 'Mapa Ruta',
      ),
      const NavigationDestination(
        icon: Icon(Icons.storage_outlined),
        selectedIcon: Icon(Icons.storage, color: SwooshColors.azulPrimario),
        label: 'Replicación',
      ),
      if (esNegocio)
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics, color: SwooshColors.azulPrimario),
          label: 'Resumen',
        ),
    ];

    final indiceSeguro = _tabIndex >= pantallas.length ? 0 : _tabIndex;

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
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: SwooshColors.azulMarino,
                size: 18,
              ),
              label: Text(
                _isOnline ? 'Online' : 'Offline ($_pendientesSync)',
                style: const TextStyle(
                  color: SwooshColors.azulMarino,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: SwooshColors.azulClaro,
              onPressed: _forzarSync,
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async => await widget.onCerrarSesion(),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : pantallas[indiceSeguro],
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceSeguro,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: destinos,
      ),
    );
  }
}