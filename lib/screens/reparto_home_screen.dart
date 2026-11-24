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

  // Origen por defecto en el centro de Santa Ana si el GPS no responde en emulador
  Ubicacion _ubicacionActual = Ubicacion(lat: 13.9942, lng: -89.5597);

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  Future<void> _inicializarApp() async {
    await _pedidoControl.inicializar();
    await _obtenerUbicacionGps();
    await _refrescarEstado();
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
    } catch (_) {
      // Mantiene coordenada base de Santa Ana en caso de correr en escritorio/emulador sin GPS
    }
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
    await _obtenerUbicacionGps();

    final rutaOrdenada = await _pedidoControl.obtenerRutaOptimizada(
      repartidorId: _repartidorId,
      origenActual: _ubicacionActual,
    );

    if (!mounted) return;
    setState(() {
      if (rutaOrdenada.isNotEmpty) {
        // Mantiene los entregados al final y ordena los activos según el backend Rust
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
    await _pedidoControl.actualizarEstadoPedido(
      pedidoId: pedido.id,
      nuevoEstado: nuevoEstado,
      repartidorId: _repartidorId,
    );
    await _refrescarEstado();

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
          // Indicador de estado Offline-First y métricas de sincronización (Tsync)
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
                await _pedidoControl.forzarSincronizacion();
                await _refrescarEstado();
              },
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Mapa OpenStreetMap con origen, paradas y polilínea de ruta
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
                              // Marcador del repartidor (Origen)
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
                              // Marcadores de paradas
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
                      // Botón flotante para optimizar secuencia
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

                // 2. Lista secuenciada de entregas con confirmación en un toque
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