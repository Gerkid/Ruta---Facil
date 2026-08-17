import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/parada.dart';
import 'places_service.dart';

class Coords {
  final double lat;
  final double lng;
  Coords(this.lat, this.lng);
}

class ImportService {
  final PlacesService _placesService = PlacesService();

  /// Abre el explorador de archivos para elegir JSON, CSV o TXT
  Future<List<Parada>> importarDesdeArchivo() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.isNotEmpty) {
        final path = result.first.path;
        if (path != null) {
          final file = File(path);
          final content = await file.readAsString();
          return await importarDesdeTexto(content);
        }
      }
    } catch (e) {
      debugPrint('Error leyendo archivo: $e');
    }
    return [];
  }

  /// Procesa texto crudo en formato JSON, CSV o lista de coordenadas/direcciones
  Future<List<Parada>> importarDesdeTexto(String texto) async {
    final trimText = texto.trim();
    if (trimText.isEmpty) return [];

    // 1. Intentar como JSON de Google Takeout
    if (trimText.startsWith('{') || trimText.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimText);
        final paradasJson = _procesarJsonGoogleMaps(decoded);
        if (paradasJson.isNotEmpty) return paradasJson;
      } catch (_) {}
    }

    // 2. Intentar como CSV o lista de líneas
    return await _procesarCsvOLineas(trimText);
  }

  List<Parada> _procesarJsonGoogleMaps(dynamic json) {
    final List<Parada> paradas = [];
    List items = [];

    if (json is List) {
      items = json;
    } else if (json is Map) {
      if (json['features'] is List) {
        items = json['features'];
      } else if (json['items'] is List) {
        items = json['items'];
      }
    }

    for (final item in items) {
      try {
        String direccion = 'Ubicación importada';
        double? lat;
        double? lng;
        String? notas;
        String? telefono;

        if (item is Map) {
          if (item.containsKey('geometry') && item['geometry'] is Map) {
            final geom = item['geometry'] as Map;
            if (geom['coordinates'] is List && (geom['coordinates'] as List).length >= 2) {
              lng = (geom['coordinates'][0] as num).toDouble();
              lat = (geom['coordinates'] as num).toDouble();
            }
          }

          final props = (item['properties'] is Map) ? (item['properties'] as Map) : item;
          if (props['title'] != null) direccion = props['title'].toString();
          if (props['name'] != null) direccion = props['name'].toString();
          if (props['address'] != null) direccion = props['address'].toString();
          if (props['note'] != null) notas = props['note'].toString();
          if (props['comment'] != null) notas = props['comment'].toString();
          if (props['phone'] != null) telefono = props['phone'].toString();

          if (lat == null && props['url'] != null) {
            final c = _extraerCoordsDeUrl(props['url'].toString());
            if (c != null) {
              lat = c.lat;
              lng = c.lng;
            }
          }
        }

        if (lat != null && lng != null) {
          paradas.add(Parada(
            direccion: direccion,
            latitud: lat,
            longitud: lng,
            notas: notas,
            telefono: telefono,
          ));
        }
      } catch (_) {}
    }

    return paradas;
  }

  Future<List<Parada>> _procesarCsvOLineas(String texto) async {
    final List<Parada> paradas = [];
    final lineas = texto.split(RegExp(r'\r?\n'));

    for (final linea in lineas) {
      final l = linea.trim();
      if (l.isEmpty) continue;

      if (l.toLowerCase().startsWith('title,') || l.toLowerCase().startsWith('nombre,')) continue;

      // 1. Coordenadas numéricas (-11.986123, -77.120169)
      final regexCoords = RegExp(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)');
      final matchCoords = regexCoords.firstMatch(l);

      if (matchCoords != null) {
        final lat = double.tryParse(matchCoords.group(1)!);
        final lng = double.tryParse(matchCoords.group(2)!);

        if (lat != null && lng != null) {
          String direccion = 'Ubicación ($lat, $lng)';
          String? nota;

          final partes = l.split(',');
          if (partes.length > 2) {
            final textoExtra = partes.where((p) => !regexCoords.hasMatch(p)).join(' ').trim();
            if (textoExtra.isNotEmpty) {
              nota = textoExtra;
            }
          }

          paradas.add(Parada(
            direccion: direccion,
            latitud: lat,
            longitud: lng,
            notas: nota,
          ));
          continue;
        }
      }

      // 2. Enlaces de Google Maps
      if (l.contains('google.com/maps') || l.contains('maps.app.goo.gl') || l.contains('geo:')) {
        final c = _extraerCoordsDeUrl(l);
        if (c != null) {
          paradas.add(Parada(
            direccion: 'Ubicación Maps',
            latitud: c.lat,
            longitud: c.lng,
          ));
          continue;
        }
      }

      // 3. Dirección de texto normal
      try {
        final lugares = await _placesService.buscarLugares(l);
        if (lugares.isNotEmpty) {
          final det = await _placesService.obtenerDetalles(lugares.first.placeId);
          if (det != null) {
            paradas.add(Parada(
              direccion: det.nombre,
              latitud: det.latitud,
              longitud: det.longitud,
              placeId: det.placeId,
            ));
          }
        }
      } catch (_) {}
    }

    return paradas;
  }

  Coords? _extraerCoordsDeUrl(String url) {
    try {
      final regex = RegExp(r'(-?\d{1,2}\.\d+)\s*(?:%2C|,)\s*(-?\d{1,3}\.\d+)');
      final match = regex.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) {
          return Coords(lat, lng);
        }
      }
    } catch (_) {}
    return null;
  }
}