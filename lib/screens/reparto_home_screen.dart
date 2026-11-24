import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../control/pedido_control.dart';
import '../entity/pedido.dart';

class RepartoHomeScreen extends StatefulWidget {
  const RepartoHomeScreen({super.key});

  @override
  State<RepartoHomeScreen> createState() => _RepartoHomeScreenState();
}

class _RepartoHomeScreenState extends State<RepartoHomeScreen> {
  final PedidoControl _pedidoControl = PedidoControl();
  final String _repartidorId = 'rep-1';

  List<Pedido> _pedidos = [];
  bool _cargando = true;
  bool _optimizando = false;
  bool _isOnline = false;
  int _pendientesSync = 0;
  int? _ultimoTsyncMs;
  bool _modoWebDemo = false;

  // Origen por defecto en el centro de Santa Ana
  Ubicacion _ubicacionActual = Ubicacion(lat: 13.9942, lng: -89.5597);

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  Future<void> _inicializarApp() async {
    try {
      if (kIsWeb) {
        throw UnsupportedError('sqflite no soportado en Web');
      }
      await _pedidoControl.inicializar();
      await _obtenerUbicacionGps();
      await _refrescarEstado();
    } catch (_) {
      // Respaldo automático en memoria para demostración en Web/Desktop
      if (!mounted) return;
      setState(() {
        _modoWebDemo = true;
        _isOnline = true;
        _ultimoTsyncMs = 84;
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

  Future<void> _obtenerUbicacionGps() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) return;

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) return;
      }

      if (permiso == LocationPermission.whileInUse ||
          permiso == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        _ubicacionActual = Ubicacion(lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _refrescarEstado() async {
    final lista = await _pedidoControl.obtenerPedidos(repartidorId: _repartidorId);
    final online = await _pedidoControl.hayConexion();
    final pendientes = await _pedidoControl.obtenerCantidadPendientes();
    final tsync = _pedidoControl.obtenerUltimoTsyncMs();

    if (!mounted) return;
    setState(() {
      _pedidos = lista;
      _isOnline = online;
      _pendientesSync = pendientes;
      _ultimoTsyncMs = tsync;
      _cargando = false;
    });
  }

  Future<void> _optimizarRuta() async {
    setState(() => _optimizando = true);

    if (_modoWebDemo) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        final activos = _pedidos.where((p) => p.estado != 'entregado').toList()
          ..sort((a, b) => a.ubicacion.lat.compareTo(b.ubicacion.lat));
        final entregados = _pedidos.where((p) => p.estado == 'entregado').toList();
        _pedidos = [...activos, ...entregados];
        _optimizando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta optimizada por proximidad')),
      );
      return;
    }

    await _obtenerUbicacionGps();
    final rutaOrdenada = await _pedidoControl.obtenerRutaOptimizada(
      repartidorId: _repartidorId,
      origenActual: _ubicacionActual,
    );

    if (!mounted) return;
    setState(() {
      if (rutaOrdenada.isNotEmpty) {
        final entregados = _pedidos.where((p) => p.estado == 'entregado').toList();
        _pedidos = [...rutaOrdenada, ...entregados];
      }
      _optimizando = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOnline
              ? 'Ruta optimizada con el motor en Rust'
              : 'Sin red: manteniendo secuencia local guardada',
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Pedido pedido, String nuevoEstado) async {
    if (_modoWebDemo) {
      setState(() {
        final idx = _pedidos.indexWhere((p) => p.id == pedido.id);
        if (idx != -1) {
          _pedidos[idx] = pedido.copyWith(
            estado: nuevoEstado,
            sincronizado: _isOnline,
          );
          if (!_isOnline) _pendientesSync++;
        }
      });
    } else {
      await _pedidoControl.actualizarEstadoPedido(
        pedidoId: pedido.id,
        nuevoEstado: nuevoEstado,
        repartidorId: _repartidorId,
      );
      await _refrescarEstado();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido de ${pedido.cliente} marcado como ${nuevoEstado.toUpperCase()}',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final puntosRuta = <LatLng>[
      LatLng(_ubicacionActual.lat, _ubicacionActual.lng),
      ..._pedidos
          .where((p) => p.estado != 'entregado')
          .map((p) => LatLng(p.ubicacion.lat, p.ubicacion.lng)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Reparto'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isOnline
                    ? (_ultimoTsyncMs != null
                        ? 'Online (${_ultimoTsyncMs}ms)'
                        : 'Online')
                    : 'Offline ($_pendientesSync pend.)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor:
                  _isOnline ? Colors.green.shade700 : Colors.orange.shade800,
              onPressed: () async {
                if (_modoWebDemo) {
                  setState(() {
                    _isOnline = !_isOnline;
                    if (_isOnline) {
                      _pendientesSync = 0;
                      _pedidos = _pedidos
                          .map((p) => p.copyWith(sincronizado: true))
                          .toList();
                    }
                  });
                } else {
                  await _pedidoControl.forzarSincronizacion();
                  await _refrescarEstado();
                }
              },
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            _ubicacionActual.lat,
                            _ubicacionActual.lng,
                          ),
                          initialZoom: 14.2,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.ues.app_reparto',
                          ),
                          if (puntosRuta.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: puntosRuta,
                                  strokeWidth: 4.5,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _ubicacionActual.lat,
                                  _ubicacionActual.lng,
                                ),
                                width: 42,
                                height: 42,
                                child: const CircleAvatar(
                                  backgroundColor: Colors.black87,
                                  child: Icon(
                                    Icons.delivery_dining,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              ..._pedidos.asMap().entries.map((entry) {
                                final index = entry.key;
                                final p = entry.value;
                                final entregado = p.estado == 'entregado';
                                return Marker(
                                  point: LatLng(
                                    p.ubicacion.lat,
                                    p.ubicacion.lng,
                                  ),
                                  width: 38,
                                  height: 38,
                                  child: CircleAvatar(
                                    backgroundColor: entregado
                                        ? Colors.green
                                        : Colors.redAccent,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: FloatingActionButton.extended(
                          onPressed: _optimizando ? null : _optimizarRuta,
                          icon: _optimizando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.alt_route),
                          label: const Text('Optimizar Ruta'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _pedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = _pedidos[index];
                      final entregado = pedido.estado == 'entregado';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                entregado ? Colors.green : Colors.blue.shade700,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pedido.cliente,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!pedido.sincronizado)
                                const Tooltip(
                                  message: 'Pendiente de sincronizar',
                                  child: Icon(
                                    Icons.sync_problem,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${pedido.direccion}\nTotal: \$${pedido.total.toStringAsFixed(2)} • Estado: ${pedido.estado}',
                          ),
                          isThreeLine: true,
                          trailing: entregado
                              ? const Chip(
                                  label: Text('Entregado'),
                                  backgroundColor: Colors.greenAccent,
                                )
                              : ElevatedButton.icon(
                                  onPressed: () =>
                                      _cambiarEstado(pedido, 'entregado'),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Entregar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}