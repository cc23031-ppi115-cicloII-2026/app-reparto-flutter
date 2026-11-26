class Ubicacion {
  final double lat;
  final double lng;

  const Ubicacion({required this.lat, required this.lng});

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class Pedido {
  final String id;
  final String? rev;
  final String cliente;
  final String tituloParada;
  final String direccion;
  final String? referenciaVisual;
  final Ubicacion ubicacion;
  final double total;
  final double subtotalProductos;
  final double costoEnvio;
  final String metodoPago; // efectivo, transferencia, pos, pagado
  final double? pagaCon;
  final int? ordenEnRuta;
  final String estado; // pendiente, asignado, en_ruta, entregado, cancelado
  final String? repartidorId;
  final String? creadoEn;
  final String? inicioRutaEn;
  final String? entregadoEn;
  final bool sincronizado;

  const Pedido({
    required this.id,
    this.rev,
    required this.cliente,
    String? tituloParada,
    required this.direccion,
    this.referenciaVisual,
    required this.ubicacion,
    required this.total,
    double? subtotalProductos,
    this.costoEnvio = 0.0,
    this.metodoPago = 'efectivo',
    this.pagaCon,
    this.ordenEnRuta,
    required this.estado,
    this.repartidorId,
    this.creadoEn,
    this.inicioRutaEn,
    this.entregadoEn,
    this.sincronizado = true,
  })  : tituloParada = tituloParada ?? 'Entrega · $cliente',
        subtotalProductos = subtotalProductos ?? total;

  double get vueltoCalculado {
    if (metodoPago != 'efectivo' || pagaCon == null) return 0.0;
    final diff = pagaCon! - total;
    return diff > 0 ? diff : 0.0;
  }

  Pedido copyWith({
    String? id,
    String? rev,
    String? cliente,
    String? tituloParada,
    String? direccion,
    String? referenciaVisual,
    Ubicacion? ubicacion,
    double? total,
    double? subtotalProductos,
    double? costoEnvio,
    String? metodoPago,
    double? pagaCon,
    int? ordenEnRuta,
    String? estado,
    String? repartidorId,
    String? creadoEn,
    String? inicioRutaEn,
    String? entregadoEn,
    bool? sincronizado,
  }) {
    return Pedido(
      id: id ?? this.id,
      rev: rev ?? this.rev,
      cliente: cliente ?? this.cliente,
      tituloParada: tituloParada ?? this.tituloParada,
      direccion: direccion ?? this.direccion,
      referenciaVisual: referenciaVisual ?? this.referenciaVisual,
      ubicacion: ubicacion ?? this.ubicacion,
      total: total ?? this.total,
      subtotalProductos: subtotalProductos ?? this.subtotalProductos,
      costoEnvio: costoEnvio ?? this.costoEnvio,
      metodoPago: metodoPago ?? this.metodoPago,
      pagaCon: pagaCon ?? this.pagaCon,
      ordenEnRuta: ordenEnRuta ?? this.ordenEnRuta,
      estado: estado ?? this.estado,
      repartidorId: repartidorId ?? this.repartidorId,
      creadoEn: creadoEn ?? this.creadoEn,
      inicioRutaEn: inicioRutaEn ?? this.inicioRutaEn,
      entregadoEn: entregadoEn ?? this.entregadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  factory Pedido.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente']?.toString() ?? 'Sin nombre';
    final total = (json['total'] as num?)?.toDouble() ?? 0.0;
    final envio = (json['costo_envio'] as num?)?.toDouble() ?? 0.0;
    return Pedido(
      id: (json['_id'] ?? json['id']).toString(),
      rev: json['_rev']?.toString(),
      cliente: cliente,
      tituloParada: json['titulo_parada']?.toString().trim().isNotEmpty == true
          ? json['titulo_parada'].toString()
          : 'Entrega · $cliente',
      direccion: json['direccion']?.toString() ?? '',
      referenciaVisual: json['referencia_visual']?.toString(),
      ubicacion: json['ubicacion'] is Map<String, dynamic>
          ? Ubicacion.fromJson(json['ubicacion'] as Map<String, dynamic>)
          : Ubicacion(
              lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
              lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
            ),
      total: total,
      subtotalProductos:
          (json['subtotal_productos'] as num?)?.toDouble() ?? (total - envio),
      costoEnvio: envio,
      metodoPago: json['metodo_pago']?.toString() ?? 'efectivo',
      pagaCon: (json['paga_con'] as num?)?.toDouble(),
      ordenEnRuta: (json['orden_en_ruta'] as num?)?.toInt(),
      estado: json['estado']?.toString() ?? 'pendiente',
      repartidorId: json['repartidor_id']?.toString(),
      creadoEn: json['creado_en']?.toString(),
      inicioRutaEn: json['inicio_ruta_en']?.toString(),
      entregadoEn: json['entregado_en']?.toString(),
      sincronizado: true,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      'cliente': cliente,
      'titulo_parada': tituloParada,
      'direccion': direccion,
      if (referenciaVisual != null && referenciaVisual!.isNotEmpty)
        'referencia_visual': referenciaVisual,
      'ubicacion': ubicacion.toJson(),
      'total': total,
      'subtotal_productos': subtotalProductos,
      'costo_envio': costoEnvio,
      'metodo_pago': metodoPago,
      if (pagaCon != null) 'paga_con': pagaCon,
      'estado': estado,
      if (rev != null) '_rev': rev,
      if (repartidorId != null) 'repartidor_id': repartidorId,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (entregadoEn != null) 'entregado_en': entregadoEn,
    };
  }

  factory Pedido.fromMap(Map<String, dynamic> map) {
    final cliente = map['cliente'] as String;
    final total = (map['total'] as num).toDouble();
    final envio = (map['costo_envio'] as num?)?.toDouble() ?? 0.0;
    return Pedido(
      id: map['id'] as String,
      rev: map['rev'] as String?,
      cliente: cliente,
      tituloParada: (map['titulo_parada'] as String?)?.isNotEmpty == true
          ? map['titulo_parada'] as String
          : 'Entrega · $cliente',
      direccion: map['direccion'] as String,
      referenciaVisual: map['referencia_visual'] as String?,
      ubicacion: Ubicacion(
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      ),
      total: total,
      subtotalProductos:
          (map['subtotal_productos'] as num?)?.toDouble() ?? (total - envio),
      costoEnvio: envio,
      metodoPago: (map['metodo_pago'] as String?) ?? 'efectivo',
      pagaCon: (map['paga_con'] as num?)?.toDouble(),
      ordenEnRuta: (map['orden_en_ruta'] as num?)?.toInt(),
      estado: map['estado'] as String,
      repartidorId: map['repartidor_id'] as String?,
      creadoEn: map['creado_en'] as String?,
      inicioRutaEn: map['inicio_ruta_en'] as String?,
      entregadoEn: map['entregado_en'] as String?,
      sincronizado: (map['sincronizado'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rev': rev,
      'cliente': cliente,
      'titulo_parada': tituloParada,
      'direccion': direccion,
      'referencia_visual': referenciaVisual,
      'lat': ubicacion.lat,
      'lng': ubicacion.lng,
      'total': total,
      'subtotal_productos': subtotalProductos,
      'costo_envio': costoEnvio,
      'metodo_pago': metodoPago,
      'paga_con': pagaCon,
      'orden_en_ruta': ordenEnRuta,
      'estado': estado,
      'repartidor_id': repartidorId,
      'creado_en': creadoEn,
      'inicio_ruta_en': inicioRutaEn,
      'entregado_en': entregadoEn,
      'sincronizado': sincronizado ? 1 : 0,
    };
  }
}