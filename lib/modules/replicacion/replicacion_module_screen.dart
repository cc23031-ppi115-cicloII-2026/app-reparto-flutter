import 'package:flutter/material.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class ReplicacionModuleScreen extends StatelessWidget {
  final bool isOnline;
  final int pendientesSync;
  final int? ultimoTsyncMs;
  final List<Pedido> pedidos;
  final Future<void> Function() onForzarSync;
  final VoidCallback? onToggleSimulacionRed;

  const ReplicacionModuleScreen({
    super.key,
    required this.isOnline,
    required this.pendientesSync,
    required this.ultimoTsyncMs,
    required this.pedidos,
    required this.onForzarSync,
    this.onToggleSimulacionRed,
  });

  @override
  Widget build(BuildContext context) {
    final sincronizados = pedidos.where((p) => p.sincronizado).length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arquitectura de Persistencia y Replicación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: SwooshColors.azulMarino,
                  ),
                ),
                const SizedBox(height: 12),
                _nodoEstado(
                  icono: Icons.phone_android,
                  titulo: '1. Almacenamiento Local (SQLite / Offline)',
                  detalle: '${pedidos.length} registros persistidos • $pendientesSync en cola de envío',
                  activo: true,
                ),
                const Divider(),
                _nodoEstado(
                  icono: Icons.storage,
                  titulo: '2. CouchDB Base Principal (API Rust)',
                  detalle: isOnline
                      ? 'Conectada • $sincronizados documentos sincronizados'
                      : 'Desconectada (operando en cola local)',
                  activo: isOnline,
                ),
                const Divider(),
                _nodoEstado(
                  icono: Icons.backup_table,
                  titulo: '3. CouchDB Base Paralela (Replicación Continua)',
                  detalle: isOnline
                      ? 'Réplica activa y espejada en tiempo real'
                      : 'En espera de reconexión de red',
                  activo: isOnline,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onForzarSync,
          icon: const Icon(Icons.sync),
          label: Text(
            ultimoTsyncMs != null
                ? 'Sincronizar Ahora (Último Tsync: ${ultimoTsyncMs}ms)'
                : 'Sincronizar Cola con API Rust',
          ),
        ),
        if (onToggleSimulacionRed != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onToggleSimulacionRed,
            icon: Icon(isOnline ? Icons.wifi_off : Icons.wifi),
            label: Text(isOnline ? 'Simular Caída de Red (Offline)' : 'Restaurar Conexión (Online)'),
          ),
        ],
      ],
    );
  }

  Widget _nodoEstado({
    required IconData icono,
    required String titulo,
    required String detalle,
    required bool activo,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: activo ? SwooshColors.azulClaro : Colors.grey.shade200,
          child: Icon(icono, color: activo ? SwooshColors.azulMarino : Colors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: SwooshColors.textoOscuro)),
              Text(detalle, style: const TextStyle(fontSize: 12, color: SwooshColors.textoSecundario)),
            ],
          ),
        ),
        Icon(
          activo ? Icons.check_circle : Icons.pause_circle_filled,
          color: activo ? SwooshColors.azulPrimario : Colors.orange,
        ),
      ],
    );
  }
}