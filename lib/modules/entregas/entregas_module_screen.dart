import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../control/geocoding_control.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class EntregasModuleScreen extends StatelessWidget {
  final List<Pedido> pedidos;
  final bool isOnline;
  final Ubicacion ubicacionActual;
  final bool puedeCrearPedidos;
  final Future<void> Function(Pedido pedido, String nuevoEstado) onCambiarEstado;
  final Future<void> Function(
    String cliente,
    String dir,
    Ubicacion ubi,
    double total,
  ) onCrearPedido;
  final Future<void> Function(Pedido pedidoCompleto)? onCrearPedidoCompleto;

  const EntregasModuleScreen({
    super.key,
    required this.pedidos,
    required this.isOnline,
    required this.ubicacionActual,
    this.puedeCrearPedidos = true,
    required this.onCambiarEstado,
    required this.onCrearPedido,
    this.onCrearPedidoCompleto,
  });

  void _abrirModalNuevoPedido(BuildContext context) {
    final clienteCtrl = TextEditingController();
    final tituloCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final pagaConCtrl = TextEditingController();

    LatLng punto = LatLng(
      ubicacionActual.lat + 0.002,
      ubicacionActual.lng + 0.002,
    );
    bool buscandoDireccion = false;
    bool tituloEditadoManual = false;
    String metodoPago = 'efectivo';
    String zonaDetectada = '';

    final referenciasRapidas = [
      'Portón negro',
      'Frente a tienda',
      'Casa esquina',
      '2da planta',
      'Portón rojo',
    ];

    Future<void> actualizarDireccionDesdeMapa(
      LatLng nuevoPunto,
      StateSetter setModal,
    ) async {
      setModal(() {
        punto = nuevoPunto;
        buscandoDireccion = true;
      });

      final res = await GeocodingControl().obtenerDireccionDesdePunto(
        nuevoPunto.latitude,
        nuevoPunto.longitude,
        isOnline: isOnline,
      );

      setModal(() {
        buscandoDireccion = false;
        dirCtrl.text = res.direccionCompleta;
        zonaDetectada = res.zonaCorta;

        if (!tituloEditadoManual) {
          final nombre = clienteCtrl.text.trim();
          tituloCtrl.text = nombre.isNotEmpty
              ? '$nombre · ${res.zonaCorta}'
              : 'Entrega · ${res.zonaCorta}';
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwooshColors.blanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        Future.microtask(() {
          if (dirCtrl.text.isEmpty && ctx.mounted) {
            actualizarDireccionDesdeMapa(punto, (fn) {
              if (ctx.mounted) (ctx as Element).markNeedsBuild();
              fn();
            });
          }
        });

        return StatefulBuilder(
          builder: (ctx, setModal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.add_location_alt,
                        color: SwooshColors.azulMarino,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Nueva Parada de Entrega',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SwooshColors.azulMarino,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          isOnline ? 'En línea' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: isOnline
                            ? SwooshColors.azulPrimario
                            : Colors.blueGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Toca el mapa para marcar el destino:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: SwooshColors.azulMarino,
                        ),
                      ),
                      if (buscandoDireccion)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 175,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: punto,
                              initialZoom: 15.0,
                              onTap: (_, latLng) =>
                                  actualizarDireccionDesdeMapa(latLng, setModal),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.ues.swoosh',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: punto,
                                    width: 46,
                                    height: 46,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.redAccent,
                                      size: 46,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: SwooshColors.azulMarino.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                buscandoDireccion
                                    ? 'Detectando calle y colonia...'
                                    : 'Pin: ${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dirCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Dirección detectada (editable)',
                      hintText: 'Se llena automáticamente al tocar el mapa',
                      prefixIcon: const Icon(
                        Icons.place,
                        color: SwooshColors.azulPrimario,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Actualizar dirección desde pin',
                        icon: const Icon(Icons.my_location),
                        onPressed: () =>
                            actualizarDireccionDesdeMapa(punto, setModal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: clienteCtrl,
                          onChanged: (val) {
                            if (!tituloEditadoManual) {
                              final z = zonaDetectada.isNotEmpty
                                  ? ' · $zonaDetectada'
                                  : '';
                              tituloCtrl.text = val.trim().isNotEmpty
                                  ? '${val.trim()}$z'
                                  : '';
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Cliente',
                            prefixIcon: Icon(
                              Icons.person,
                              color: SwooshColors.azulPrimario,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: tituloCtrl,
                          onChanged: (_) => tituloEditadoManual = true,
                          decoration: const InputDecoration(
                            labelText: 'Título de parada',
                            hintText: 'Ej. Casa Carlos · Col. IVU',
                            prefixIcon: Icon(
                              Icons.label_important_outline,
                              color: SwooshColors.azulPrimario,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Referencia visual para el repartidor',
                      hintText: 'Ej. Portón negro frente a tienda',
                      prefixIcon: Icon(
                        Icons.visibility_outlined,
                        color: SwooshColors.azulPrimario,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: referenciasRapidas.map((ref) {
                      return ActionChip(
                        label: Text(ref, style: const TextStyle(fontSize: 11.5)),
                        backgroundColor: SwooshColors.azulClaro.withValues(alpha: 0.5),
                        onPressed: () {
                          setModal(() {
                            refCtrl.text = ref;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: totalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Total (\$)',
                            prefixIcon: Icon(
                              Icons.attach_money,
                              color: SwooshColors.azulPrimario,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: metodoPago,
                          decoration: const InputDecoration(
                            labelText: 'Cobro',
                            prefixIcon: Icon(
                              Icons.payments_outlined,
                              color: SwooshColors.azulPrimario,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'efectivo',
                              child: Text('Efectivo'),
                            ),
                            DropdownMenuItem(
                              value: 'transferencia',
                              child: Text('Transferencia'),
                            ),
                            DropdownMenuItem(
                              value: 'pagado',
                              child: Text('Ya pagado'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setModal(() => metodoPago = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (metodoPago == 'efectivo') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: pagaConCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText:
                            'Cliente paga con (\$ opcional para calcular vuelto)',
                        hintText: 'Ej. 20.00',
                        prefixIcon: Icon(
                          Icons.point_of_sale,
                          color: SwooshColors.azulPrimario,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (clienteCtrl.text.trim().isEmpty) return;
                      final cliente = clienteCtrl.text.trim();
                      final direccion = dirCtrl.text.trim().isEmpty
                          ? 'Punto marcado (${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)})'
                          : dirCtrl.text.trim();
                      final total =
                          double.tryParse(totalCtrl.text.trim()) ?? 10.0;
                      final ubi = Ubicacion(
                        lat: punto.latitude,
                        lng: punto.longitude,
                      );

                      if (onCrearPedidoCompleto != null) {
                        final nuevo = Pedido(
                          id: 'pedido:${DateTime.now().microsecondsSinceEpoch}',
                          cliente: cliente,
                          tituloParada: tituloCtrl.text.trim().isNotEmpty
                              ? tituloCtrl.text.trim()
                              : 'Entrega · $cliente',
                          direccion: direccion,
                          referenciaVisual: refCtrl.text.trim().isNotEmpty
                              ? refCtrl.text.trim()
                              : null,
                          ubicacion: ubi,
                          total: total,
                          metodoPago: metodoPago,
                          pagaCon: double.tryParse(pagaConCtrl.text.trim()),
                          estado: 'pendiente',
                          creadoEn: DateTime.now().toUtc().toIso8601String(),
                          sincronizado: false,
                        );
                        await onCrearPedidoCompleto!(nuevo);
                      } else {
                        await onCrearPedido(cliente, direccion, ubi, total);
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.add_task),
                    label: const Text('Guardar Parada y Agregar a Ruta'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pedidos.isEmpty
          ? Center(
              child: Text(
                puedeCrearPedidos
                    ? 'No hay paradas registradas.\nPresiona "Nueva Parada" para marcar en el mapa.'
                    : 'No tienes entregas asignadas en este momento.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 85),
              itemCount: pedidos.length,
              itemBuilder: (context, index) {
                final p = pedidos[index];
                final completado = p.estado == 'entregado';
                final vuelto = p.vueltoCalculado;

                return Card(
                  color: completado
                      ? const Color(0xFFEFF5FB)
                      : SwooshColors.blanco,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: completado
                          ? Colors.transparent
                          : SwooshColors.azulClaro,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: completado
                                  ? Colors.lightBlue
                                  : SwooshColors.azulMarino,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.tituloParada,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: completado
                                          ? SwooshColors.textoSecundario
                                          : SwooshColors.azulMarino,
                                    ),
                                  ),
                                  Text(
                                    'Cliente: ${p.cliente}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: SwooshColors.textoSecundario,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              p.sincronizado
                                  ? Icons.cloud_done
                                  : Icons.cloud_upload_outlined,
                              size: 18,
                              color: p.sincronizado
                                  ? SwooshColors.azulPrimario
                                  : Colors.orange.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.place,
                              size: 16,
                              color: SwooshColors.azulPrimario,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p.direccion,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                        if (p.referenciaVisual != null &&
                            p.referenciaVisual!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'Ref: ${p.referenciaVisual}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cobrar: \$${p.total.toStringAsFixed(2)} (${p.metodoPago.toUpperCase()})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: SwooshColors.azulMarino,
                                  ),
                                ),
                                if (vuelto > 0)
                                  Text(
                                    'Llevar vuelto: \$${vuelto.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                            completado
                                ? const Chip(
                                    label: Text(
                                      'Entregado ✓',
                                      style: TextStyle(
                                        color: SwooshColors.azulMarino,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: SwooshColors.azulClaro,
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () =>
                                        onCambiarEstado(p, 'entregado'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: SwooshColors.azulPrimario,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Entregar'),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: puedeCrearPedidos
          ? FloatingActionButton.extended(
              onPressed: () => _abrirModalNuevoPedido(context),
              backgroundColor: SwooshColors.azulMarino,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Nueva Parada'),
            )
          : null,
    );
  }
}