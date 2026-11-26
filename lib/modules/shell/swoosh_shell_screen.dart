import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../control/pedido_control.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';
import '../entregas/entregas_module_screen.dart';
import '../mapa_ruta/mapa_ruta_module_screen.dart';
import '../metricas/metricas_module_screen.dart';
import '../replicacion/replicacion_module_screen.dart';

class SwooshShellScreen extends StatefulWidget {
  const SwooshShellScreen({super.key});

  @override
  State<SwooshShellScreen> createState() => _SwooshShellScreenState();
}

class _SwooshShellScreenState extends State<SwooshShellScreen> {
  final PedidoControl _pedidoControl = PedidoControl();
  final String _repartidorId = 'rep-1';
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
            direccion: 'Av. Independencia Sur, Santa Ana',
            ubicacion: Ubicacion(lat: 13.9942, lng: -89.5597),
            total: 14.50,
            estado: 'asignado',
            repartidorId: _repartidorId,
          ),
          Pedido(
            id: 'demo-2',
            cliente: 'Tienda El Progreso',
            direccion: 'Col. El Palmar, Santa Ana',
            ubicacion: Ubicacion(lat: 13.9875, lng: -89.5640),
            total: 22.00,
            estado: 'pendiente',
            repartidorId: _repartidorId,
          ),
          Pedido(
            id: 'demo-3',
            cliente: 'Pupusería Doña María',
            direccion: 'Barrio San Juan, Santa Ana',
            ubicacion: Ubicacion(lat: 13.9990, lng: -89.5521),
            total: 9.75,
            estado: 'pendiente',
            repartidorId: _repartidorId,
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
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        _ubicacionActual = Ubicacion(lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _refrescar() async {
    final lista = await _pedidoControl.obtenerPedidos(repartidorId: _repartidorId);
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

  Future<void> _crearPedido(String cliente, String dir, Ubicacion ubi, double total) async {
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
            repartidorId: _repartidorId,
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
      repartidorId: _repartidorId,
    );
    await _refrescar();
  }

  Future<void> _cambiarEstado(Pedido pedido, String nuevoEstado) async {
    if (_modoWebDemo) {
      setState(() {
        final idx = _pedidos.indexWhere((p) => p.id == pedido.id);
        if (idx != -1) {
          _pedidos[idx] = pedido.copyWith(estado: nuevoEstado, sincronizado: _isOnline);
          if (!_isOnline) _pendientesSync++;
        }
      });
      return;
    }

    await _pedidoControl.actualizarEstadoPedido(
      pedidoId: pedido.id,
      nuevoEstado: nuevoEstado,
      repartidorId: _repartidorId,
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
        final entregados = _pedidos.where((p) => p.estado == 'entregado').toList();
        _pedidos = [...activos, ...entregados];
        _optimizando = false;
      });
      return;
    }

    await _obtenerGps();
    final ordenados = await _pedidoControl.obtenerRutaOptimizada(
      repartidorId: _repartidorId,
      origenActual: _ubicacionActual,
    );
    if (!mounted) return;
    setState(() {
      if (ordenados.isNotEmpty) {
        final entregados = _pedidos.where((p) => p.estado == 'entregado').toList();
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
    final pantallas = [
      EntregasModuleScreen(
        pedidos: _pedidos,
        isOnline: _isOnline,
        ubicacionActual: _ubicacionActual,
        onCambiarEstado: _cambiarEstado,
        onCrearPedido: _crearPedido,
      ),
      MapaRutaModuleScreen(
        pedidos: _pedidos,
        ubicacionActual: _ubicacionActual,
        optimizando: _optimizando,
        onOptimizarRuta: _optimizarRuta,
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
      MetricasModuleScreen(
        pedidos: _pedidos,
        ultimoTsyncMs: _ultimoTsyncMs,
        pendientesSync: _pendientesSync,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.lightBlueAccent),
            SizedBox(width: 6),
            Text('SWOOSH'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : pantallas[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt, color: SwooshColors.azulPrimario),
            label: 'Entregas',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: SwooshColors.azulPrimario),
            label: 'Mapa Ruta',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            selectedIcon: Icon(Icons.storage, color: SwooshColors.azulPrimario),
            label: 'Replicación',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: SwooshColors.azulPrimario),
            label: 'Métricas',
          ),
        ],
      ),
    );
  }
}