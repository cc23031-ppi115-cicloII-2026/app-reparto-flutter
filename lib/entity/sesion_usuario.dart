class SesionUsuario {
  final String usuario;
  final String rol; // 'negocio' | 'repartidor'
  final String nombre;
  final String? repartidorId;
  final String? negocioId;

  const SesionUsuario({
    required this.usuario,
    required this.rol,
    required this.nombre,
    this.repartidorId,
    this.negocioId,
  });

  bool get esNegocio =>
      rol.trim().toLowerCase() == 'negocio' ||
      rol.trim().toLowerCase() == 'negocio1';
  bool get esRepartidor =>
      rol.trim().toLowerCase() == 'repartidor' ||
      rol.trim().toLowerCase() == 'rep1';

  factory SesionUsuario.fromJson(Map<String, dynamic> json) {
    return SesionUsuario(
      usuario: (json['usuario'] ?? '').toString(),
      rol: (json['rol'] ?? 'repartidor').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      repartidorId: json['repartidor_id']?.toString(),
      negocioId: json['negocio_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario': usuario,
      'rol': rol,
      'nombre': nombre,
      'repartidor_id': repartidorId,
      'negocio_id': negocioId,
    };
  }
}
