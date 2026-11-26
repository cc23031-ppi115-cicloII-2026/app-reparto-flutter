import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class EntregasModuleScreen extends StatelessWidget {
  final List<Pedido> pedidos;
  final bool isOnline;
  final Ubicacion ubicacionActual;
  final Future<void> Function(Pedido pedido, String nuevoEstado) onCambiarEstado;
  final Future<void> Function(String cliente, String dir, Ubicacion ubi, double total) onCrearPedido;

  const EntregasModuleScreen({
    super.key,
    required this.pedidos,
    required this.isOnline,
    required this.ubicacionActual,
    required this.onCambiarEstado,
    required this.onCrearPedido,
  });

  void _abrirModalNuevoPedido(BuildContext context) {
    final clienteCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    LatLng punto = LatLng(ubicacionActual.lat + 0.002, ubicacionActual.lng + 0.002);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwooshColors.blanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping, color: SwooshColors.azulMarino),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Nuevo Pedido Swoosh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: SwooshColors.azulMarino,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        isOnline ? 'En línea' : 'Modo Offline',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: isOnline ? SwooshColors.azulPrimario : Colors.blueGrey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clienteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cliente / Comercio',
                    prefixIcon: Icon(Icons.store, color: SwooshColors.azulPrimario),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de entrega',
                    prefixIcon: Icon(Icons.place, color: SwooshColors.azulPrimario),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: totalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto (\$)',
                    prefixIcon: Icon(Icons.attach_money, color: SwooshColors.azulPrimario),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Toca el mapa para fijar coordenadas del destino:',
                  style: TextStyle(fontWeight: FontWeight.w600, color: SwooshColors.azulMarino),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: punto,
                        initialZoom: 14.5,
                        onTap: (_, latLng) => setModal(() => punto = latLng),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.ues.swoosh',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: punto,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: SwooshColors.azulMarino,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (clienteCtrl.text.trim().isEmpty) return;
                    await onCrearPedido(
                      clienteCtrl.text.trim(),
                      dirCtrl.text.trim().isEmpty ? 'Santa Ana, El Salvador' : dirCtrl.text.trim(),
                      Ubicacion(lat: punto.latitude, lng: punto.longitude),
                      double.tryParse(totalCtrl.text.trim()) ?? 10.0,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.add_task),
                  label: const Text('Registrar Pedido y Agregar a Ruta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pedidos.isEmpty
          ? const Center(child: Text('No hay pedidos registrados'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: pedidos.length,
              itemBuilder: (context, index) {
                final p = pedidos[index];
                final completado = p.estado == 'entregado';

                return Card(
                  color: completado ? const Color(0xFFEFF5FB) : SwooshColors.blanco,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: completado ? Colors.lightBlue : SwooshColors.azulPrimario,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.cliente,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: completado ? SwooshColors.textoSecundario : SwooshColors.azulMarino,
                            ),
                          ),
                        ),
                        Icon(
                          p.sincronizado ? Icons.cloud_done : Icons.cloud_upload_outlined,
                          size: 18,
                          color: p.sincronizado ? SwooshColors.azulPrimario : Colors.orange.shade700,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${p.direccion}\nTotal: \$${p.total.toStringAsFixed(2)} • ${p.sincronizado ? "En CouchDB" : "Pendiente Sync"}',
                    ),
                    isThreeLine: true,
                    trailing: completado
                        ? const Chip(
                            label: Text('Completado', style: TextStyle(color: SwooshColors.azulMarino)),
                            backgroundColor: SwooshColors.azulClaro,
                          )
                        : ElevatedButton.icon(
                            onPressed: () => onCambiarEstado(p, 'entregado'),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Entregar'),
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModalNuevoPedido(context),
        backgroundColor: SwooshColors.azulMarino,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Pedido'),
      ),
    );
  }
}