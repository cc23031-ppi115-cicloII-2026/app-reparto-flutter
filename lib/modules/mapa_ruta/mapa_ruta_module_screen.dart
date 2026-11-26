import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class MapaRutaModuleScreen extends StatelessWidget {
  final List<Pedido> pedidos;
  final Ubicacion ubicacionActual;
  final bool optimizando;
  final Future<void> Function() onOptimizarRuta;

  const MapaRutaModuleScreen({
    super.key,
    required this.pedidos,
    required this.ubicacionActual,
    required this.optimizando,
    required this.onOptimizarRuta,
  });

  @override
  Widget build(BuildContext context) {
    final activos = pedidos.where((p) => p.estado != 'entregado').toList();
    final puntosRuta = <LatLng>[
      LatLng(ubicacionActual.lat, ubicacionActual.lng),
      ...activos.map((p) => LatLng(p.ubicacion.lat, p.ubicacion.lng)),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(ubicacionActual.lat, ubicacionActual.lng),
              initialZoom: 14.3,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ues.swoosh',
              ),
              if (puntosRuta.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: puntosRuta,
                      strokeWidth: 5.0,
                      color: SwooshColors.azulPrimario,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(ubicacionActual.lat, ubicacionActual.lng),
                    width: 44,
                    height: 44,
                    child: const CircleAvatar(
                      backgroundColor: SwooshColors.azulMarino,
                      child: Icon(Icons.delivery_dining, color: Colors.white),
                    ),
                  ),
                  ...pedidos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final entregado = p.estado == 'entregado';
                    return Marker(
                      point: LatLng(p.ubicacion.lat, p.ubicacion.lng),
                      width: 38,
                      height: 38,
                      child: CircleAvatar(
                        backgroundColor: entregado ? Colors.lightBlue : SwooshColors.azulAcento,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paradas activas en ruta: ${activos.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: SwooshColors.azulMarino,
                      ),
                    ),
                    Text(
                      'Total en curso: \$${activos.fold<double>(0, (s, p) => s + p.total).toStringAsFixed(2)}',
                      style: const TextStyle(color: SwooshColors.azulPrimario, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: optimizando ? null : onOptimizarRuta,
        backgroundColor: SwooshColors.azulPrimario,
        foregroundColor: Colors.white,
        icon: optimizando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.alt_route),
        label: const Text('Optimizar Ruta (2-opt)'),
      ),
    );
  }
}