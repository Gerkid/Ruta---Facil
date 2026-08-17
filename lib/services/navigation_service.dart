import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  /// Abre Google Maps de forma 100% segura y nativa
  Future<bool> abrirGoogleMaps({
    required double latitud,
    required double longitud,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitud,$longitud&travelmode=driving',
    );

    try {
      final lanzado = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!lanzado) {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      return true;
    } catch (e) {
      debugPrint('🚨 Error abriendo Google Maps: $e');
      try {
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }

  /// Abre Waze de forma segura
  Future<bool> abrirWaze({
    required double latitud,
    required double longitud,
  }) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$latitud,$longitud&navigate=yes');

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('🚨 Error abriendo Waze: $e');
      return false;
    }
  }
}