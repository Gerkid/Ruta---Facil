import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> obtenerUbicacionActual() async {
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();

    if (!servicioActivo) {
      return null;
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}