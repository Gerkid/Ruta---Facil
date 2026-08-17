import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'places_service.dart';
import '../models/parada.dart';

class DatosEtiquetaExtraidos {
  final String direccionSugerida;
  final String? telefono;
  final String? trackingNumber;
  final String? destinatario;
  final String textoCompleto;
  final Parada? paradaGeocodificada;

  DatosEtiquetaExtraidos({
    required this.direccionSugerida,
    this.telefono,
    this.trackingNumber,
    this.destinatario,
    required this.textoCompleto,
    this.paradaGeocodificada,
  });
}

class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final PlacesService _placesService = PlacesService();

  /// Captura foto con la cámara y procesa la etiqueta del paquete
  Future<DatosEtiquetaExtraidos?> escanearEtiquetaConCamara() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Optimiza velocidad de procesamiento
      );

      if (imagen == null) return null;

      return await procesarImagenEtiqueta(File(imagen.path));
    } catch (e) {
      debugPrint('🚨 Error al abrir la cámara OCR: $e');
      return null;
    }
  }

  /// Procesa una imagen de etiqueta y extrae datos estructurados
  Future<DatosEtiquetaExtraidos> procesarImagenEtiqueta(File archivoImagen) async {
    final inputImage = InputImage.fromFile(archivoImagen);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    final lineas = recognizedText.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    String? telefonoExtraido;
    String? trackingExtraido;
    String? destinatarioExtraido;
    final lineasDireccion = <String>[];

    // Regex para teléfonos peruanos (9 dígitos iniciando en 9)
    final regexTelefono = RegExp(r'(?:\+?51\s*)?(9\d{8})');
    // Regex para códigos de tracking típicos (alfanuméricos de 8 a 22 dígitos)
    final regexTracking = RegExp(r'\b[A-Z0-9]{10,22}\b');

    for (final linea in lineas) {
      final lineaUpper = linea.toUpperCase();

      // 1. Extraer Teléfono
      if (telefonoExtraido == null && regexTelefono.hasMatch(linea)) {
        final match = regexTelefono.firstMatch(linea);
        telefonoExtraido = match?.group(1) ?? match?.group(0);
        continue;
      }

      // 2. Extraer Código de Envío / Tracking
      if (trackingExtraido == null &&
          (lineaUpper.contains('TRACKING') ||
              lineaUpper.contains('GUIA') ||
              lineaUpper.contains('PKG') ||
              regexTracking.hasMatch(linea))) {
        final match = regexTracking.firstMatch(linea);
        if (match != null) {
          trackingExtraido = match.group(0);
        }
      }

      // 3. Filtrar palabras comunes de etiquetas que no son dirección
      if (lineaUpper.contains('TEMU') ||
          lineaUpper.contains('DESTINATARIO') ||
          lineaUpper.contains('REMITENTE') ||
          lineaUpper.contains('EXPRESS') ||
          lineaUpper.contains('STANDARD') ||
          lineaUpper.contains('PAQUETE') ||
          lineaUpper.contains('CLIENTE') ||
          lineaUpper.contains('ENVIO') ||
          linea.length < 4) {
        continue;
      }

      // 4. Si la línea parece ser un nombre (ej: "Juan Pérez")
      if (destinatarioExtraido == null &&
          linea.split(' ').length >= 2 &&
          linea.split(' ').length <= 4 &&
          !linea.contains(RegExp(r'\d'))) {
        destinatarioExtraido = linea;
        continue;
      }

      // 5. Acumular líneas candidatas a dirección
      lineasDireccion.add(linea);
    }

    // Unir las mejores líneas para formar la dirección de búsqueda
    final direccionFinal = lineasDireccion.take(2).join(', ');

    // Geocodificar automáticamente la dirección extraída
    Parada? parada;
    if (direccionFinal.isNotEmpty) {
      final detalles = await _placesService.geocodificarTexto(direccionFinal);
      if (detalles != null) {
        parada = Parada(
          direccion: detalles.nombre,
          latitud: detalles.latitud,
          longitud: detalles.longitud,
          destinatario: destinatarioExtraido,
          telefono: telefonoExtraido,
          trackingNumber: trackingExtraido,
          placeId: detalles.placeId,
        );
      }
    }

    return DatosEtiquetaExtraidos(
      direccionSugerida: direccionFinal,
      telefono: telefonoExtraido,
      trackingNumber: trackingExtraido,
      destinatario: destinatarioExtraido,
      textoCompleto: recognizedText.text,
      paradaGeocodificada: parada,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}