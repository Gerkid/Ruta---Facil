import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  Future<bool> abrirGoogleMaps({
    required double latitud,
    required double longitud,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitud,$longitud'
      '&travelmode=driving',
    );

    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> abrirWaze({
    required double latitud,
    required double longitud,
  }) async {
    final uri = Uri.parse(
      'https://waze.com/ul?ll=$latitud,$longitud&navigate=yes',
    );

    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}