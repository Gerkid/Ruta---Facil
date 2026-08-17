import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static String get apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';
  final LocalDatabase _database = LocalDatabase.instance;

  /// Búsqueda predictiva de direcciones (Autocomplete)
  Future<List<PlaceSuggestion>> buscarLugares(String texto) async {
    if (texto.trim().length < 3) return [];
    if (apiKey.isEmpty) return [];

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(texto)}'
      '&language=es'
      '&components=country:pe'
      '&key=$apiKey',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return [];

      final predictions = data['predictions'] as List? ?? [];
      return predictions.map((item) {
        return PlaceSuggestion(
          placeId: item['place_id'],
          descripcion: item['description'],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene detalles de un lugar seleccionado
  Future<PlaceDetails?> obtenerDetalles(String placeId) async {
    final ubicacionGuardada = await _database.buscarUbicacionPorPlaceId(placeId);

    if (ubicacionGuardada != null) {
      return PlaceDetails(
        placeId: ubicacionGuardada.placeId ?? placeId,
        nombre: ubicacionGuardada.direccion,
        latitud: ubicacionGuardada.latitud,
        longitud: ubicacionGuardada.longitud,
      );
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(placeId)}'
      '&fields=place_id,name,geometry,formatted_address'
      '&language=es'
      '&key=$apiKey',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK' || data['result'] == null) return null;

      final result = data['result'];
      final location = result['geometry']['location'];

      final detalles = PlaceDetails(
        placeId: result['place_id'] ?? placeId,
        nombre: result['formatted_address'] ?? result['name'] ?? 'Lugar sin nombre',
        latitud: (location['lat'] as num).toDouble(),
        longitud: (location['lng'] as num).toDouble(),
      );

      await _database.guardarUbicacion(
        Parada(
          direccion: detalles.nombre,
          latitud: detalles.latitud,
          longitud: detalles.longitud,
          placeId: detalles.placeId,
        ),
      );

      return detalles;
    } catch (_) {
      return null;
    }
  }

  /// Geocodificación Inteligente con Doble Motor (Geocoding + Places Text Search)
  Future<PlaceDetails?> geocodificarTexto(String direccionTexto) async {
    final limpio = direccionTexto.trim();
    if (limpio.isEmpty) return null;

    // Asegurar contexto de Perú
    final direccionConsulta = limpio.toLowerCase().contains('peru') || limpio.toLowerCase().contains('perú')
        ? limpio
        : '$limpio, Perú';

    try {
      // 1. INTENTO PRIMARIO: Geocoding API tradicional
      final uriGeocode = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(direccionConsulta)}'
        '&components=country:pe'
        '&language=es'
        '&key=$apiKey',
      );

      final respGeocode = await http.get(uriGeocode).timeout(const Duration(seconds: 8));
      if (respGeocode.statusCode == 200) {
        final data = jsonDecode(respGeocode.body);
        final resultados = data['results'] as List? ?? [];

        if (data['status'] == 'OK' && resultados.isNotEmpty) {
          final primero = resultados.first;
          final location = primero['geometry']['location'];

          final detalles = PlaceDetails(
            placeId: primero['place_id'] ?? '',
            nombre: primero['formatted_address'] ?? limpio,
            latitud: (location['lat'] as num).toDouble(),
            longitud: (location['lng'] as num).toDouble(),
          );

          if (detalles.placeId.isNotEmpty) {
            await _database.guardarUbicacion(
              Parada(
                direccion: detalles.nombre,
                latitud: detalles.latitud,
                longitud: detalles.longitud,
                placeId: detalles.placeId,
              ),
            );
          }
          return detalles;
        }
      }

      // 2. FALLBACK SECUNDARIO: Google Places Text Search (Encuentra calles y avenidas aunque la numeración falle)
      final uriPlaces = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(direccionConsulta)}'
        '&language=es'
        '&key=$apiKey',
      );

      final respPlaces = await http.get(uriPlaces).timeout(const Duration(seconds: 8));
      if (respPlaces.statusCode == 200) {
        final dataPlaces = jsonDecode(respPlaces.body);
        final resultadosPlaces = dataPlaces['results'] as List? ?? [];

        if (dataPlaces['status'] == 'OK' && resultadosPlaces.isNotEmpty) {
          final primero = resultadosPlaces.first;
          final location = primero['geometry']['location'];

          final detalles = PlaceDetails(
            placeId: primero['place_id'] ?? '',
            nombre: primero['formatted_address'] ?? primero['name'] ?? limpio,
            latitud: (location['lat'] as num).toDouble(),
            longitud: (location['lng'] as num).toDouble(),
          );

          if (detalles.placeId.isNotEmpty) {
            await _database.guardarUbicacion(
              Parada(
                direccion: detalles.nombre,
                latitud: detalles.latitud,
                longitud: detalles.longitud,
                placeId: detalles.placeId,
              ),
            );
          }
          return detalles;
        }
      }
    } catch (e) {
      debugPrint('🚨 Error en geocodificación de $limpio: $e');
    }

    return null;
  }

  /// Reverse geocoding
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

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 'OK') return null;

      final resultados = data['results'] as List? ?? [];
      if (resultados.isEmpty) return null;

      final primero = resultados.first;
      final location = primero['geometry']['location'];

      return PlaceDetails(
        placeId: primero['place_id'] ?? '',
        nombre: primero['formatted_address'] ?? 'Ubicación actual',
        latitud: (location['lat'] as num).toDouble(),
        longitud: (location['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}