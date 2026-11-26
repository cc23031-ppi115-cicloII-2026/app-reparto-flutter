import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class MapaRutaModuleScreen extends StatefulWidget {
  final List<Pedido> pedidos;
  final Ubicacion ubicacionActual;
  final bool optimizando;
  final Future<void> Function() onOptimizarRuta;
  final Future<void> Function(Pedido pedido, String nuevoEstado)?
      onCambiarEstado;

  const MapaRutaModuleScreen({
    super.key,
    required this.pedidos,
    required this.ubicacionActual,
    required this.optimizando,
    required this.onOptimizarRuta,
    this.onCambiarEstado,
  });

  @override
  State<MapaRutaModuleScreen> createState() => _MapaRutaModuleScreenState();
}

class _MapaRutaModuleScreenState extends State<MapaRutaModuleScreen> {
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _indiceSeleccionado = 0;

  double _distanciaKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c * 1.3;
  }

  double _calcularDistanciaTotalRuta(List<Pedido> activos) {
    if (activos.isEmpty) return 0.0;
    double total = _distanciaKm(
      widget.ubicacionActual.lat,
      widget.ubicacionActual.lng,
      activos.first.ubicacion.lat,
      activos.first.ubicacion.lng,
    );
    for (int i = 0; i < activos.length - 1; i++) {
      total += _distanciaKm(
        activos[i].ubicacion.lat,
        activos[i].ubicacion.lng,
        activos[i + 1].ubicacion.lat,
        activos[i + 1].ubicacion.lng,
      );
    }
    return total;
  }

  void _enfocarParada(int index, Pedido p) {
    setState(() => _indiceSeleccionado = index);
    _mapController.move(LatLng(p.ubicacion.lat, p.ubicacion.lng), 15.6);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activos =
        widget.pedidos.where((p) => p.estado != 'entregado').toList();
    final entregadosCount =
        widget.pedidos.where((p) => p.estado == 'entregado').length;

    final puntosRuta = <LatLng>[
      LatLng(widget.ubicacionActual.lat, widget.ubicacionActual.lng),
      ...activos.map((p) => LatLng(p.ubicacion.lat, p.ubicacion.lng)),
    ];

    final distanciaTotalKm = _calcularDistanciaTotalRuta(activos);
    final montoPorCobrar = activos.fold<double>(0, (s, p) => s + p.total);

    if (_indiceSeleccionado >= activos.length && activos.isNotEmpty) {
      _indiceSeleccionado = 0;
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                widget.ubicacionActual.lat,
                widget.ubicacionActual.lng,
              ),
              initialZoom: 14.4,
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
                      strokeWidth: 6.0,
                      color: SwooshColors.azulMarino.withOpacity(0.25),
                    ),
                    Polyline(
                      points: puntosRuta,
                      strokeWidth: 4.0,
                      color: SwooshColors.azulPrimario,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      widget.ubicacionActual.lat,
                      widget.ubicacionActual.lng,
                    ),
                    width: 86,
                    height: 58,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SwooshColors.azulMarino,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Salida / Tú',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const CircleAvatar(
                          radius: 17,
                          backgroundColor: SwooshColors.azulMarino,
                          child: Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...activos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final esSeleccionada = idx == _indiceSeleccionado;
                    final esProxima = idx == 0;

                    return Marker(
                      point: LatLng(p.ubicacion.lat, p.ubicacion.lng),
                      width: 125,
                      height: 64,
                      child: GestureDetector(
                        onTap: () => _enfocarParada(idx, p),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: esProxima
                                    ? Colors.redAccent
                                    : (esSeleccionada
                                        ? SwooshColors.azulMarino
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: SwooshColors.azulMarino,
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Text(
                                '#${idx + 1} ${p.tituloParada}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: (esProxima || esSeleccionada)
                                      ? Colors.white
                                      : SwooshColors.azulMarino,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            CircleAvatar(
                              radius: esSeleccionada ? 18 : 15,
                              backgroundColor: esProxima
                                  ? Colors.redAccent
                                  : SwooshColors.azulPrimario,
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
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
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activos.isEmpty
                              ? 'Ruta completada ($entregadosCount entregas)'
                              : '${activos.length} paradas pendientes · ${distanciaTotalKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: SwooshColors.azulMarino,
                          ),
                        ),
                        Text(
                          'Por cobrar en ruta: \$${montoPorCobrar.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: SwooshColors.azulPrimario,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          widget.optimizando ? null : widget.onOptimizarRuta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwooshColors.azulPrimario,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      icon: widget.optimizando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.alt_route, size: 18),
                      label: const Text('Optimizar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: activos.isNotEmpty ? 205 : 24,
            child: FloatingActionButton.small(
              heroTag: 'centrar_origen',
              backgroundColor: Colors.white,
              foregroundColor: SwooshColors.azulMarino,
              onPressed: () => _mapController.move(
                LatLng(
                  widget.ubicacionActual.lat,
                  widget.ubicacionActual.lng,
                ),
                14.5,
              ),
              child: const Icon(Icons.my_location),
            ),
          ),
          if (activos.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              height: 182,
              child: PageView.builder(
                controller: _pageController,
                itemCount: activos.length,
                onPageChanged: (idx) {
                  setState(() => _indiceSeleccionado = idx);
                  final p = activos[idx];
                  _mapController.move(
                    LatLng(p.ubicacion.lat, p.ubicacion.lng),
                    15.4,
                  );
                },
                itemBuilder: (context, idx) {
                  final p = activos[idx];
                  final distTramo = idx == 0
                      ? _distanciaKm(
                          widget.ubicacionActual.lat,
                          widget.ubicacionActual.lng,
                          p.ubicacion.lat,
                          p.ubicacion.lng,
                        )
                      : _distanciaKm(
                          activos[idx - 1].ubicacion.lat,
                          activos[idx - 1].ubicacion.lng,
                          p.ubicacion.lat,
                          p.ubicacion.lng,
                        );
                  final vuelto = p.vueltoCalculado;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: idx == 0
                            ? Colors.redAccent
                            : SwooshColors.azulPrimario,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: idx == 0
                                      ? Colors.redAccent
                                      : SwooshColors.azulMarino,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  idx == 0
                                      ? 'SIGUIENTE · PARADA #1'
                                      : 'PARADA #${idx + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${distTramo.toStringAsFixed(1)} km tramo',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: SwooshColors.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.tituloParada,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: SwooshColors.azulMarino,
                            ),
                          ),
                          Text(
                            p.direccion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (p.referenciaVisual != null &&
                              p.referenciaVisual!.isNotEmpty)
                            Text(
                              'Ref: ${p.referenciaVisual}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${p.total.toStringAsFixed(2)} · ${p.metodoPago.toUpperCase()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: SwooshColors.azulMarino,
                                    ),
                                  ),
                                  if (vuelto > 0)
                                    Text(
                                      'Vuelto: \$${vuelto.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                ],
                              ),
                              if (widget.onCambiarEstado != null)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      widget.onCambiarEstado!(p, 'entregado'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.check_circle, size: 18),
                                  label: const Text('Entregado'),
                                ),
                            ],
                          ),
                        ],
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