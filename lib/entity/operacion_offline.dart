class OperacionOffline {
  final String opId;
  final String pedidoId;
  final String tipoOperacion; // CREAR_PEDIDO | ACTUALIZAR_ESTADO
  final String payloadJson;
  final int creadoEnMs;
  final int intentos;
  final String estadoSync; // PENDIENTE | ENVIADA | CONFLICTO

  const OperacionOffline({
    required this.opId,
    required this.pedidoId,
    required this.tipoOperacion,
    required this.payloadJson,
    required this.creadoEnMs,
    this.intentos = 0,
    this.estadoSync = 'PENDIENTE',
  });

  OperacionOffline copyWith({
    int? intentos,
    String? estadoSync,
  }) {
    return OperacionOffline(
      opId: opId,
      pedidoId: pedidoId,
      tipoOperacion: tipoOperacion,
      payloadJson: payloadJson,
      creadoEnMs: creadoEnMs,
      intentos: intentos ?? this.intentos,
      estadoSync: estadoSync ?? this.estadoSync,
    );
  }

  factory OperacionOffline.fromMap(Map<String, dynamic> map) {
    return OperacionOffline(
      opId: map['op_id'] as String,
      pedidoId: map['pedido_id'] as String,
      tipoOperacion: map['tipo_operacion'] as String,
      payloadJson: map['payload_json'] as String,
      creadoEnMs: map['creado_en_ms'] as int,
      intentos: map['intentos'] as int? ?? 0,
      estadoSync: map['estado_sync'] as String? ?? 'PENDIENTE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'op_id': opId,
      'pedido_id': pedidoId,
      'tipo_operacion': tipoOperacion,
      'payload_json': payloadJson,
      'creado_en_ms': creadoEnMs,
      'intentos': intentos,
      'estado_sync': estadoSync,
    };
  }
}