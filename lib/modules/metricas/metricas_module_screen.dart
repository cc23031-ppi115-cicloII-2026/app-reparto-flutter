import 'package:flutter/material.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class MetricasModuleScreen extends StatelessWidget {
  final List<Pedido> pedidos;
  final int? ultimoTsyncMs;
  final int pendientesSync;

  const MetricasModuleScreen({
    super.key,
    required this.pedidos,
    required this.ultimoTsyncMs,
    required this.pendientesSync,
  });

  @override
  Widget build(BuildContext context) {
    final totalPedidos = pedidos.length;
    final entregados = pedidos.where((p) => p.estado == 'entregado').length;
    final montoTotal = pedidos.fold<double>(0, (s, p) => s + p.total);
    final tasaEntrega = totalPedidos == 0 ? 0.0 : (entregados / totalPedidos) * 100;

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(14),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _kpiCard('Entregas Completadas', '$entregados / $totalPedidos', Icons.check_circle_outline),
        _kpiCard('Efectividad de Ruta', '${tasaEntrega.toStringAsFixed(0)}%', Icons.trending_up),
        _kpiCard('Tiempo Sync (Tsync)', ultimoTsyncMs != null ? '$ultimoTsyncMs ms' : 'N/A', Icons.speed),
        _kpiCard('Monto Gestionado', '\$${montoTotal.toStringAsFixed(2)}', Icons.payments_outlined),
        _kpiCard('Cola Offline Pendiente', '$pendientesSync ops', Icons.cloud_queue),
        _kpiCard('Disponibilidad Local', '100% SQLite', Icons.verified_user_outlined),
      ],
    );
  }

  Widget _kpiCard(String titulo, String valor, IconData icono) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 32, color: SwooshColors.azulPrimario),
            const SizedBox(height: 8),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: SwooshColors.azulMarino,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: SwooshColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}