import 'dart:convert';
import 'package:http/http.dart' as http;

class ResultadoGeocoding {
  final String direccionCompleta;
  final String zonaCorta;
  final bool desdeRed;

  const ResultadoGeocoding({
    required this.direccionCompleta,
    required this.zonaCorta,
    required this.desdeRed,
  });
}

class GeocodingControl {
  static final GeocodingControl _instance = GeocodingControl._internal();
  factory GeocodingControl() => _instance;
  GeocodingControl._internal();

  final Map<String, ResultadoGeocoding> _cache = {};

  String _clave(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// Convierte coordenadas marcadas en el mapa en una dirección legible para el input.
  /// Si no hay red o excede el timeout, devuelve una etiqueta limpia con coordenadas.
  Future<ResultadoGeocoding> obtenerDireccionDesdePunto(
    double lat,
    double lng, {
    required bool isOnline,
  }) async {
    final key = _clave(lat, lng);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final fallback = ResultadoGeocoding(
      direccionCompleta:
          'Punto en mapa (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})',
      zonaCorta: 'Zona marcada',
      desdeRed: false,
    );

    if (!isOnline) {
      return fallback;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=es',
      );
      final resp = await http.get(
        uri,
        headers: {'User-Agent': 'SwooshDeliveryUES/1.0'},
      ).timeout(const Duration(milliseconds: 2200));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final calle = (address['road'] ??
                  address['pedestrian'] ??
                  address['residential'] ??
                  '')
              .toString();
          final barrio = (address['neighbourhood'] ??
                  address['suburb'] ??
                  address['quarter'] ??
                  address['city_district'] ??
                  '')
              .toString();
          final ciudad = (address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['municipality'] ??
                  'Santa Ana')
              .toString();

          final partes = [
            if (calle.isNotEmpty) calle,
            if (barrio.isNotEmpty) barrio,
            if (ciudad.isNotEmpty) ciudad,
          ];

          final direccion = partes.isNotEmpty
              ? partes.join(', ')
              : (data['display_name']?.toString() ?? fallback.direccionCompleta);

          final zona = barrio.isNotEmpty
              ? barrio
              : (calle.isNotEmpty ? calle : ciudad);

          final resultado = ResultadoGeocoding(
            direccionCompleta: direccion,
            zonaCorta: zona,
            desdeRed: true,
          );
          _cache[key] = resultado;
          return resultado;
        }
      }
    } catch (_) {
      // Ante caída de red o timeout, usar respaldo limpio sin bloquear la UI
    }

    return fallback;
  }
}