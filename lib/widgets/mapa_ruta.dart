import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/parada.dart';

class MapaRuta extends StatefulWidget {
  final List<Parada> paradas;
  final List<LatLng> puntosPolilinea;

  const MapaRuta({
    super.key,
    required this.paradas,
    this.puntosPolilinea = const [],
  });

  @override
  State<MapaRuta> createState() => _MapaRutaState();
}

class _MapaRutaState extends State<MapaRuta> {
  GoogleMapController? _mapController;
  Map<String, Marker> _marcadores = {};

  static const String _estiloMapaPlateado = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f5f5f5"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#dadada"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
    {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"color": "#e5e5e5"}]},
    {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c9c9c9"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _generarMarcadoresNumerados();
  }

  @override
  void didUpdateWidget(covariant MapaRuta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paradas != oldWidget.paradas || widget.puntosPolilinea != oldWidget.puntosPolilinea) {
      _generarMarcadoresNumerados();
      _ajustarCamara();
    }
  }

  Future<void> _generarMarcadoresNumerados() async {
    final Map<String, Marker> nuevosMarcadores = {};

    for (var i = 0; i < widget.paradas.length; i++) {
      final p = widget.paradas[i];
      final numero = p.orden > 0 ? p.orden : (i + 1);
      final icon = await _crearIconoNumerado(numero: numero, estado: p.estado, esInicio: i == 0);

      nuevosMarcadores['parada_${p.id ?? i}'] = Marker(
        markerId: MarkerId('parada_${p.id ?? i}'),
        position: p.latLng,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: '#$numero - ${p.direccion}',
          snippet: p.notas != null ? '📝 ${p.notas}' : 'Estado: ${p.estado.toUpperCase()}',
        ),
      );
    }

    if (mounted) {
      setState(() {
        _marcadores = nuevosMarcadores;
      });
    }
  }

  Future<BitmapDescriptor> _crearIconoNumerado({
    required int numero,
    required String estado,
    bool esInicio = false,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double size = 60.0;

    final Paint circlePaint = Paint()..isAntiAlias = true;

    if (esInicio) {
      circlePaint.color = const Color(0xFF1E88E5);
    } else if (estado == 'entregado') {
      circlePaint.color = const Color(0xFF00C853);
    } else if (estado == 'ausente') {
      circlePaint.color = const Color(0xFFD50000);
    } else {
      circlePaint.color = const Color(0xFF2962FF);
    }

    canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) - 2, circlePaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), (size / 2) - 2, borderPaint);

    final String texto = esInicio ? '🏁' : (estado == 'entregado' ? '✓$numero' : '$numero');
    final double fontSize = esInicio ? 18 : (texto.length > 2 ? 16 : 20);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final ui.Image img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List(), imagePixelRatio: 2.2);
  }

  void _ajustarCamara() {
    if (_mapController == null || widget.paradas.isEmpty) return;

    if (widget.paradas.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(widget.paradas.first.latLng, 14));
      return;
    }

    double minLat = widget.paradas.first.latitud;
    double maxLat = widget.paradas.first.latitud;
    double minLng = widget.paradas.first.longitud;
    double maxLng = widget.paradas.first.longitud;

    for (final p in widget.paradas) {
      if (p.latitud < minLat) minLat = p.latitud;
      if (p.latitud > maxLat) maxLat = p.latitud;
      if (p.longitud < minLng) minLng = p.longitud;
      if (p.longitud > maxLng) maxLng = p.longitud;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paradas.isEmpty) {
      return Container(
        color: const Color(0xFFE0E0E0),
        child: const Center(
          child: Text('Agrega paradas para ver la ruta en el mapa', style: TextStyle(color: Colors.black54)),
        ),
      );
    }

    final puntosTrazado = widget.puntosPolilinea.isNotEmpty
        ? widget.puntosPolilinea
        : widget.paradas.map((p) => p.latLng).toList();

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.paradas.first.latLng, zoom: 13),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (c) {
        _mapController = c;
        _mapController?.setMapStyle(_estiloMapaPlateado);
        Future.delayed(const Duration(milliseconds: 300), _ajustarCamara);
      },
      polylines: puntosTrazado.length > 1
          ? {
              Polyline(
                polylineId: const PolylineId('linea_vial_calles'),
                points: puntosTrazado,
                width: 5,
                color: const Color(0xFF2962FF),
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            }
          : {},
      markers: Set<Marker>.of(_marcadores.values),
    );
  }
}