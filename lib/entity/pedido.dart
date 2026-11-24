class Ubicacion {
  final double lat;
  final double lng;

  Ubicacion({required this.lat, required this.lng});

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
  final String direccion;
  final Ubicacion ubicacion;
  final double total;
  final String estado; // pendiente, asignado, en_ruta, entregado, cancelado
  final String? repartidorId;
  final String? creadoEn;
  final String? entregadoEn;
  final bool sincronizado;

  Pedido({
    required this.id,
    this.rev,
    required this.cliente,
    required this.direccion,
    required this.ubicacion,
    required this.total,
    required this.estado,
    this.repartidorId,
    this.creadoEn,
    this.entregadoEn,
    this.sincronizado = true,
  });

  Pedido copyWith({
    String? rev,
    String? estado,
    String? repartidorId,
    String? entregadoEn,
    bool? sincronizado,
  }) {
    return Pedido(
      id: id,
      rev: rev ?? this.rev,
      cliente: cliente,
      direccion: direccion,
      ubicacion: ubicacion,
      total: total,
      estado: estado ?? this.estado,
      repartidorId: repartidorId ?? this.repartidorId,
      creadoEn: creadoEn,
      entregadoEn: entregadoEn ?? this.entregadoEn,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: (json['_id'] ?? json['id']).toString(),
      rev: json['_rev']?.toString(),
      cliente: json['cliente'] ?? 'Sin nombre',
      direccion: json['direccion'] ?? '',
      ubicacion: json['ubicacion'] != null
          ? Ubicacion.fromJson(json['ubicacion'])
          : Ubicacion(
              lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
              lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
            ),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado'] ?? 'pendiente',
      repartidorId: json['repartidor_id']?.toString(),
      creadoEn: json['creado_en']?.toString(),
      entregadoEn: json['entregado_en']?.toString(),
      sincronizado: true,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      if (rev != null) '_rev': rev,
      'cliente': cliente,
      'direccion': direccion,
      'ubicacion': ubicacion.toJson(),
      'total': total,
      'estado': estado,
      if (repartidorId != null) 'repartidor_id': repartidorId,
      if (creadoEn != null) 'creado_en': creadoEn,
      if (entregadoEn != null) 'entregado_en': entregadoEn,
    };
  }

  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] as String,
      rev: map['rev'] as String?,
      cliente: map['cliente'] as String,
      direccion: map['direccion'] as String,
      ubicacion: Ubicacion(
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
      ),
      total: (map['total'] as num).toDouble(),
      estado: map['estado'] as String,
      repartidorId: map['repartidor_id'] as String?,
      creadoEn: map['creado_en'] as String?,
      entregadoEn: map['entregado_en'] as String?,
      sincronizado: (map['sincronizado'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rev': rev,
      'cliente': cliente,
      'direccion': direccion,
      'lat': ubicacion.lat,
      'lng': ubicacion.lng,
      'total': total,
      'estado': estado,
      'repartidor_id': repartidorId,
      'creado_en': creadoEn,
      'entregado_en': entregadoEn,
      'sincronizado': sincronizado ? 1 : 0,
    };
  }
}