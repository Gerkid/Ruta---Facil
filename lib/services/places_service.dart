import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../database/local_database.dart';
import '../models/parada.dart';

class PlaceSuggestion {
  final String placeId;
  final String descripcion;

  PlaceSuggestion({
    required this.placeId,
    required this.descripcion,
  });
}

class PlaceDetails {
  final String placeId;
  final String nombre;
  final double latitud;
  final double longitud;

  PlaceDetails({
    required this.placeId,
    required this.nombre,
    required this.latitud,
    required this.longitud,
  });
}

class PlacesService {
  // 🚨 CLAVE PROTEGIDA: Ahora se lee desde el archivo .env
  // Si el archivo falla, devolverá un string vacío para evitar que la app crashee.
  static String get apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  final LocalDatabase _database = LocalDatabase.instance;

Future<List<PlaceSuggestion>> buscarLugares(
    String texto,
  ) async {
    if (texto.trim().length < 3) {
      return [];
    }

    // 👇 1er CHIVATO: Verifica si la clave llega a la función
    print('🔍 TEST: Leyendo clave del .env -> "$apiKey"'); 

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(texto)}'
      '&language=es'
      '&components=country:pe'
      '&key=$apiKey',
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      // 👇 2do CHIVATO: Imprime la respuesta exacta de los servidores de Google
      print('📡 RESPUESTA GOOGLE: ${response.body}'); 

      if (response.statusCode != 200) {
        throw Exception('Error de conexión con Google Places');
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        // 👇 3er CHIVATO: Imprime si Google nos denegó el acceso
        print('🚨 ERROR DE GOOGLE PLACES: ${data['status']} - ${data['error_message']}');
        throw Exception('Google Places: ${data['status']}');
      }

      final predictions = data['predictions'] as List? ?? [];
      return predictions.map((item) {
        return PlaceSuggestion(
          placeId: item['place_id'],
          descripcion: item['description'],
        );
      }).toList();
    } catch (e) {
      print('🚨 EXCEPCIÓN EN BUSCAR LUGARES: $e');
      return [];
    }
  }

  Future<PlaceDetails?> obtenerDetalles(
    String placeId,
  ) async {
    final ubicacionGuardada =
        await _database.buscarUbicacionPorPlaceId(
      placeId,
    );

    if (ubicacionGuardada != null) {
      return PlaceDetails(
        placeId: ubicacionGuardada.placeId ?? placeId,
        nombre: ubicacionGuardada.nombre,
        latitud: ubicacionGuardada.latitud,
        longitud: ubicacionGuardada.longitud,
      );
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(placeId)}'
      '&fields=place_id,name,geometry'
      '&language=es'
      '&key=$apiKey',
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Error obteniendo los detalles del lugar',
      );
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception(
        'Google Places: ${data['status']}',
      );
    }

    final result = data['result'];

    if (result == null) {
      return null;
    }

    final location = result['geometry']['location'];

    final detalles = PlaceDetails(
      placeId: result['place_id'],
      nombre: result['name'] ?? 'Lugar sin nombre',
      latitud: (location['lat'] as num).toDouble(),
      longitud: (location['lng'] as num).toDouble(),
    );

    // Guardar la ubicación en nuestra base local.
    await _database.guardarUbicacion(
      Parada(
        nombre: detalles.nombre,
        latitud: detalles.latitud,
        longitud: detalles.longitud,
        placeId: detalles.placeId,
      ),
    );

    return detalles;
  }

  /// Reverse geocoding: convierte coordenadas en una dirección
  /// legible, usando el mismo Google Maps que ya usamos para
  /// buscar direcciones (mismo crédito, sin costo aparte).
  Future<PlaceDetails?> obtenerDireccionDesdeCoordenadas({
    required double latitud,
    required double longitud,
  }) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$latitud,$longitud'
      '&language=es'
      '&key=$apiKey',
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Error obteniendo la dirección de esas coordenadas',
      );
    }

    final data = jsonDecode(response.body);

    if (data['status'] == 'ZERO_RESULTS') {
      return null;
    }

    if (data['status'] != 'OK') {
      throw Exception(
        'Google Maps: ${data['status']}',
      );
    }

    final resultados = data['results'] as List? ?? [];

    if (resultados.isEmpty) {
      return null;
    }

    final primero = resultados.first;
    final location = primero['geometry']['location'];

    final detalles = PlaceDetails(
      placeId: primero['place_id'] ?? '',
      nombre: primero['formatted_address'] ??
          'Dirección encontrada',
      latitud: (location['lat'] as num).toDouble(),
      longitud: (location['lng'] as num).toDouble(),
    );

    // Guardamos también esta ubicación para no volver a
    // consultarla si se repite.
    if (detalles.placeId.isNotEmpty) {
      await _database.guardarUbicacion(
        Parada(
          nombre: detalles.nombre,
          latitud: detalles.latitud,
          longitud: detalles.longitud,
          placeId: detalles.placeId,
        ),
      );
    }

    return detalles;
  }
}