import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/parada.dart';

class MapaRuta extends StatelessWidget {
  final List<Parada> paradas;

  const MapaRuta({
    super.key,
    required this.paradas,
  });

  @override
  Widget build(BuildContext context) {
    if (paradas.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Text(
            'Agrega una parada para verla en el mapa',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final primeraParada = paradas.first;

    final puntos = paradas
        .map(
          (parada) => LatLng(
            parada.latitud,
            parada.longitud,
          ),
        )
        .toList();

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          primeraParada.latitud,
          primeraParada.longitud,
        ),
        zoom: 13,
      ),

      // Línea azul conectando las paradas en el orden actual.
      polylines: puntos.length > 1
          ? {
              Polyline(
                polylineId: const PolylineId('ruta'),
                points: puntos,
                width: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            }
          : {},

      markers: {
        for (int i = 0; i < paradas.length; i++)
          Marker(
            markerId: MarkerId('parada_$i'),
            position: LatLng(
              paradas[i].latitud,
              paradas[i].longitud,
            ),
            infoWindow: InfoWindow(
              title: '${i + 1}. ${paradas[i].nombre}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
      },
    );
  }
}