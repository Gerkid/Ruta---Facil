class Parada {
  final String nombre;
  final double latitud;
  final double longitud;
  final String? placeId;

  Parada({
    required this.nombre,
    required this.latitud,
    required this.longitud,
    this.placeId,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'latitud': latitud,
      'longitud': longitud,
      'placeId': placeId,
    };
  }

  factory Parada.fromMap(Map<String, dynamic> map) {
    return Parada(
      nombre: map['nombre'] as String,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      placeId: map['placeId'] as String?,
    );
  }
} 