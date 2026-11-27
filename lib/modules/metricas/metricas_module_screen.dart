import 'package:flutter/material.dart';
import '../../entity/pedido.dart';
import '../../theme/swoosh_colors.dart';

class MetricasModuleScreen extends StatefulWidget {
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
  State<MetricasModuleScreen> createState() => _MetricasModuleScreenState();
}

class _MetricasModuleScreenState extends State<MetricasModuleScreen> {
  String? _filtroEstado = 'todos'; // todos, entregado, activos
  String? _filtroPago = 'todos'; // todos, efectivo, transferencia
  bool _verDiagnostico = false;

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.pedidos.where((p) {
      final pasaEstado = switch (_filtroEstado) {
        null => p.estado != 'cancelado',
        'entregado' => p.estado == 'entregado',
        'activos' => p.estado != 'entregado' && p.estado != 'cancelado',
        _ => p.estado != 'cancelado',
      };
      final pasaPago = switch (_filtroPago) {
        null => true,
        'efectivo' => p.metodoPago == 'efectivo',
        'transferencia' => p.metodoPago != 'efectivo',
        _ => true,
      };
      return pasaEstado && pasaPago;
    }).toList();

    final entregados =
        widget.pedidos.where((p) => p.estado == 'entregado').toList();
    final todos = widget.pedidos.where((p) => p.estado != 'cancelado').toList();
    final activos = widget.pedidos
        .where((p) => p.estado != 'entregado' && p.estado != 'cancelado')
        .toList();

    final ventasTotales = filtrados.fold<double>(0, (s, p) => s + p.total);
    final totalProductos =
        filtrados.fold<double>(0, (s, p) => s + p.subtotalProductos);
    final totalEnvios = filtrados.fold<double>(0, (s, p) => s + p.costoEnvio);

    final efectivoCobrado = entregados
        .where((p) => p.metodoPago == 'efectivo')
        .fold<double>(0, (s, p) => s + p.total);
    final digitalCobrado = entregados
        .where((p) => p.metodoPago != 'efectivo')
        .fold<double>(0, (s, p) => s + p.total);
    final efectivoPorCobrar = activos
        .where((p) => p.metodoPago == 'efectivo')
        .fold<double>(0, (s, p) => s + p.total);

    final ticketPromedio =
        filtrados.isEmpty ? 0.0 : ventasTotales / filtrados.length;
    final tasaExito = widget.pedidos.isEmpty
        ? 0.0
        : (entregados.length / widget.pedidos.length) * 100;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        // Encabezado + Switch discreto de Diagnóstico Técnico
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen Financiero y Ruta',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: SwooshColors.azulMarino,
                  ),
                ),
                Text(
                  'Control de ventas, cobros y arqueo de repartidor',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SwooshColors.textoSecundario,
                  ),
                ),
              ],
            ),
            FilterChip(
              label: const Text('Técnico', style: TextStyle(fontSize: 11.5)),
              selected: _verDiagnostico,
              onSelected: (v) => setState(() => _verDiagnostico = v),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filtros Dinámicos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipFiltro('Todos (${todos.length})', 'todos',
                  _filtroEstado, (v) => setState(() => _filtroEstado = v)),
              const SizedBox(width: 6),
              _chipFiltro('Entregados (${entregados.length})', 'entregado',
                  _filtroEstado, (v) => setState(() => _filtroEstado = v)),
              const SizedBox(width: 6),
              _chipFiltro('En Ruta (${activos.length})', 'activos',
                  _filtroEstado, (v) => setState(() => _filtroEstado = v)),
              const SizedBox(width: 12),
              _chipFiltro('Solo Efectivo', 'efectivo', _filtroPago,
                  (v) => setState(() => _filtroPago = v)),
              const SizedBox(width: 6),
              _chipFiltro('Transferencia/Pagado', 'transferencia', _filtroPago,
                  (v) => setState(() => _filtroPago = v)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tarjeta Principal de Ingresos Desglosados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SwooshColors.azulMarino, SwooshColors.azulPrimario],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INGRESO TOTAL FILTRADO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${ventasTotales.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'Ticket prom: \$${ticketPromedio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _datoBlanco('Productos', '\$${totalProductos.toStringAsFixed(2)}'),
                  _datoBlanco('Tarifas Envío', '\$${totalEnvios.toStringAsFixed(2)}'),
                  _datoBlanco('Efectividad', '${tasaExito.toStringAsFixed(0)}%'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bloque de Arqueo de Caja del Repartidor
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: SwooshColors.azulClaro),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.point_of_sale, color: SwooshColors.azulMarino),
                    SizedBox(width: 8),
                    Text(
                      'Arqueo de Caja · Repartidor Actual',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: SwooshColors.azulMarino,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _filaArqueo(
                  'Efectivo cobrado (a entregar en caja)',
                  '\$${efectivoCobrado.toStringAsFixed(2)}',
                  Colors.green.shade800,
                  negrita: true,
                ),
                const SizedBox(height: 6),
                _filaArqueo(
                  'Cobrado por transferencia / ya pagado',
                  '\$${digitalCobrado.toStringAsFixed(2)}',
                  SwooshColors.azulPrimario,
                ),
                const SizedBox(height: 6),
                _filaArqueo(
                  'Efectivo pendiente por cobrar en calle',
                  '\$${efectivoPorCobrar.toStringAsFixed(2)}',
                  Colors.orange.shade800,
                ),
              ],
            ),
          ),
        ),

        // Panel Técnico Opcional (Laboratorio / Tesis)
        if (_verDiagnostico) ...[
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFF3F6FA),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telemetría de Arquitectura Offline-First',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: SwooshColors.azulMarino,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniMetric(
                        'Tsync',
                        widget.ultimoTsyncMs != null
                            ? '${widget.ultimoTsyncMs} ms'
                            : 'N/A',
                      ),
                      _miniMetric('Cola Offline', '${widget.pendientesSync} ops'),
                      _miniMetric('Persistencia', 'SQLite + CouchDB'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Text(
          'Detalle de Movimientos (${filtrados.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: SwooshColors.azulMarino,
          ),
        ),
        const SizedBox(height: 8),
        if (filtrados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No hay pedidos que coincidan con el filtro'),
            ),
          )
        else
          ...filtrados.map((p) {
            final entregado = p.estado == 'entregado';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                leading: Icon(
                  entregado ? Icons.check_circle : Icons.schedule,
                  color: entregado ? Colors.green.shade700 : Colors.orange,
                ),
                title: Text(
                  p.tituloParada,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${p.metodoPago.toUpperCase()} • ${entregado ? "Cobrado" : "Pendiente"}',
                ),
                trailing: Text(
                  '\$${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: SwooshColors.azulMarino,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _chipFiltro(
    String label,
    String valor,
    String? actual,
    ValueChanged<String?> onSelect,
  ) {
    final seleccionado = valor == actual;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: seleccionado ? Colors.white : SwooshColors.azulMarino,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: seleccionado,
      selectedColor: SwooshColors.azulPrimario,
      onSelected: (seleccionar) => onSelect(seleccionar ? valor : null),
    );
  }

  Widget _datoBlanco(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }

  Widget _filaArqueo(String texto, String monto, Color color,
      {bool negrita = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          monto,
          style: TextStyle(
            fontSize: negrita ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String val) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: SwooshColors.azulMarino,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: SwooshColors.textoSecundario,
          ),
        ),
      ],
    );
  }
}