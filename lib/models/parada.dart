import 'package:google_maps_flutter/google_maps_flutter.dart';

class Parada {
  final int? id;
  final int? rutaId;
  final String direccion;
  final double latitud;
  final double longitud;
  final int orden; // 1, 2, 3... 50 según la optimización
  final String estado; // 'pendiente', 'entregado', 'ausente', 'cancelado'
  final String? destinatario;
  final String? telefono;
  final String? trackingNumber; // Código de paquete Temu
  final String? notas;
  final String? placeId;
  final DateTime? fechaEntrega;

  Parada({
    this.id,
    this.rutaId,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    this.orden = 0,
    this.estado = 'pendiente',
    this.destinatario,
    this.telefono,
    this.trackingNumber,
    this.notas,
    this.placeId,
    this.fechaEntrega,
  });

  // Getter de conveniencia para Google Maps
  LatLng get latLng => LatLng(latitud, longitud);

  // Indica si ya fue gestionada
  bool get esCompletada => estado == 'entregado' || estado == 'ausente' || estado == 'cancelado';

  // Conversión a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ruta_id': rutaId,
      'direccion': direccion,
      'latitud': latitud,
      'longitud': longitud,
      'orden': orden,
      'estado': estado,
      'destinatario': destinatario,
      'telefono': telefono,
      'tracking_number': trackingNumber,
      'notas': notas,
      'place_id': placeId,
      'fecha_entrega': fechaEntrega?.toIso8601String(),
    };
  }

  // Creación de objeto desde Map de SQLite
  factory Parada.fromMap(Map<String, dynamic> map) {
    return Parada(
      id: map['id'] as int?,
      rutaId: map['ruta_id'] as int?,
      direccion: map['direccion'] as String? ?? map['nombre'] as String? ?? '',
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      orden: map['orden'] as int? ?? 0,
      estado: map['estado'] as String? ?? 'pendiente',
      destinatario: map['destinatario'] as String?,
      telefono: map['telefono'] as String?,
      trackingNumber: map['tracking_number'] as String?,
      notas: map['notas'] as String?,
      placeId: map['place_id'] as String? ?? map['placeId'] as String?,
      fechaEntrega: map['fecha_entrega'] != null
          ? DateTime.tryParse(map['fecha_entrega'] as String)
          : null,
    );
  }

  // Método inmutable para actualizar estados fácilmente
  Parada copyWith({
    int? id,
    int? rutaId,
    String? direccion,
    double? latitud,
    double? longitud,
    int? orden,
    String? estado,
    String? destinatario,
    String? telefono,
    String? trackingNumber,
    String? notas,
    String? placeId,
    DateTime? fechaEntrega,
  }) {
    return Parada(
      id: id ?? this.id,
      rutaId: rutaId ?? this.rutaId,
      direccion: direccion ?? this.direccion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      orden: orden ?? this.orden,
      estado: estado ?? this.estado,
      destinatario: destinatario ?? this.destinatario,
      telefono: telefono ?? this.telefono,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      notas: notas ?? this.notas,
      placeId: placeId ?? this.placeId,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
    );
  }
}