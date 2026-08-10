import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parada.dart';

/// Resultado de optimizar una ruta: las entregas reordenadas
/// (sin incluir el punto de inicio ni el de fin), más cuánto
/// tiempo tomaba el recorrido completo antes y cuánto toma ahora.
class ResultadoOptimizacion {
  final List<Parada> paradas;
  final double duracionOriginalSegundos;
  final double duracionOptimizadaSegundos;

  ResultadoOptimizacion({
    required this.paradas,
    required this.duracionOriginalSegundos,
    required this.duracionOptimizadaSegundos,
  });

  double get segundosAhorrados =>
      duracionOriginalSegundos - duracionOptimizadaSegundos;

  int get minutosAhorrados =>
      (segundosAhorrados / 60).round();

  /// Porcentaje de mejora (0-100). Si el original ya era el mejor
  /// orden posible, puede salir 0.
  double get porcentajeMejora {
    if (duracionOriginalSegundos <= 0) {
      return 0;
    }

    final porcentaje =
        (segundosAhorrados / duracionOriginalSegundos) * 100;

    return porcentaje < 0 ? 0 : porcentaje;
  }
}

/// Servicio de optimización de rutas.
///
/// Estrategia:
/// 1. Pedimos a OSRM (gratis, sin límite de paradas) la matriz de
///    tiempos de viaje entre TODAS las paradas (endpoint /table).
/// 2. Con esa matriz calculamos un orden inicial con el algoritmo
///    del "vecino más cercano".
/// 3. Mejoramos ese orden con 2-opt hasta que ya no se pueda
///    acortar más el tiempo total.
///
/// El punto de INICIO siempre es fijo (por ejemplo, tu almacén).
/// El punto de FIN es opcional: si lo das (por ejemplo, tu casa),
/// también queda fijo al final y las entregas se acomodan entre
/// ambos. Si no lo das, la ruta termina donde sea más rápido.
class RouteService {
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org';

  // Si el servidor de OSRM no responde en este tiempo, cancelamos
  // en vez de dejar la app esperando indefinidamente.
  static const Duration _timeoutRed = Duration(seconds: 20);

  Future<ResultadoOptimizacion> optimizarRuta(
    List<Parada> entregas, {
    required Parada inicio,
    Parada? fin,
  }) async {
    final finFijo = fin != null;

    final completa = [
      inicio,
      ...entregas,
      if (finFijo) fin,
    ];

    if (completa.length < 2) {
      return ResultadoOptimizacion(
        paradas: List.from(entregas),
        duracionOriginalSegundos: 0,
        duracionOptimizadaSegundos: 0,
      );
    }

    final matriz = await _obtenerMatrizDeTiempos(completa);

    final ordenOriginal = List.generate(
      completa.length,
      (i) => i,
    );

    final ordenInicial = _vecinoMasCercano(
      matriz,
      finFijo: finFijo,
    );

    final ordenOptimizado = _mejorarCon2Opt(
      ordenInicial,
      matriz,
      finFijo: finFijo,
    );

    final duracionOriginal = _costoDeRuta(
      ordenOriginal,
      matriz,
    );

    final duracionOptimizada = _costoDeRuta(
      ordenOptimizado,
      matriz,
    );

    final ultimoIndice = completa.length - 1;

    // Sacamos del resultado el inicio y el fin: solo devolvemos
    // las entregas del medio, ya reordenadas.
    final entregasOptimizadas = ordenOptimizado
        .where(
          (indice) =>
              indice != 0 &&
              !(finFijo && indice == ultimoIndice),
        )
        .map((indice) => completa[indice])
        .toList();

    return ResultadoOptimizacion(
      paradas: entregasOptimizadas,
      duracionOriginalSegundos: duracionOriginal,
      duracionOptimizadaSegundos: duracionOptimizada,
    );
  }

  /// Pide a OSRM la matriz de tiempos de viaje (en segundos)
  /// entre cada par de paradas.
  Future<List<List<double>>> _obtenerMatrizDeTiempos(
    List<Parada> paradas,
  ) async {
    final coordenadas = paradas
        .map(
          (parada) =>
              '${parada.longitud},${parada.latitud}',
        )
        .join(';');

    final url = Uri.parse(
      '$_osrmBaseUrl/table/v1/driving/'
      '$coordenadas'
      '?annotations=duration',
    );

    late final http.Response response;

    try {
      response = await http.get(url).timeout(_timeoutRed);
    } on Exception {
      throw Exception(
        'El servicio de rutas tardó demasiado en responder. '
        'Revisa tu conexión e inténtalo de nuevo.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'No se pudo conectar con el servicio de rutas.',
      );
    }

    final data = jsonDecode(response.body);

    if (data['code'] != 'Ok') {
      throw Exception(
        'El servicio de rutas no pudo calcular los tiempos '
        'entre las paradas.',
      );
    }

    final crudo = data['durations'] as List;

    final n = paradas.length;

    // Reemplazamos los pares sin conexión (null) por un valor
    // muy alto, para que el algoritmo evite usarlos pero el
    // programa no truene.
    const double sinConexion = 1e9;

    final matriz = List.generate(
      n,
      (i) => List.generate(
        n,
        (j) {
          if (i == j) {
            return 0.0;
          }

          final valor = crudo[i][j];

          if (valor == null) {
            return sinConexion;
          }

          return (valor as num).toDouble();
        },
      ),
    );

    return matriz;
  }

  /// Construye un orden inicial: desde el punto de inicio, siempre
  /// salta al punto no visitado más cercano en tiempo. Si hay un
  /// fin fijo, lo excluye de la búsqueda y lo agrega al final.
  List<int> _vecinoMasCercano(
    List<List<double>> matriz, {
    required bool finFijo,
  }) {
    final n = matriz.length;

    final visitado = List<bool>.filled(n, false);
    visitado[0] = true;

    if (finFijo) {
      visitado[n - 1] = true;
    }

    final orden = <int>[0];

    var actual = 0;

    final totalAVisitar = finFijo ? n - 1 : n;

    while (orden.length < totalAVisitar) {
      var mejorIndice = -1;
      var mejorTiempo = double.infinity;

      for (var candidato = 0; candidato < n; candidato++) {
        if (visitado[candidato]) {
          continue;
        }

        final tiempo = matriz[actual][candidato];

        if (tiempo < mejorTiempo) {
          mejorTiempo = tiempo;
          mejorIndice = candidato;
        }
      }

      orden.add(mejorIndice);
      visitado[mejorIndice] = true;
      actual = mejorIndice;
    }

    if (finFijo) {
      orden.add(n - 1);
    }

    return orden;
  }

  /// Mejora el orden con 2-opt. La posición 0 (inicio) nunca se
  /// mueve. Si hay fin fijo, la última posición tampoco se mueve.
  List<int> _mejorarCon2Opt(
    List<int> ordenInicial,
    List<List<double>> matriz, {
    required bool finFijo,
  }) {
    final orden = List<int>.from(ordenInicial);
    final n = orden.length;

    if (n < 4) {
      return orden;
    }

    // Índice más alto que SÍ se puede mover.
    final movibleHasta = finFijo ? n - 2 : n - 1;

    if (movibleHasta < 2) {
      return orden;
    }

    var mejorado = true;

    // Límite de seguridad para no colgar la app si algo raro pasa.
    var vueltasMaximas = 60;

    while (mejorado && vueltasMaximas > 0) {
      mejorado = false;
      vueltasMaximas--;

      for (var i = 1; i < movibleHasta; i++) {
        for (var k = i + 1; k <= movibleHasta; k++) {
          final kSiguiente = k + 1;
          final hayNodoSiguiente = kSiguiente < n;

          final costoActual = matriz[orden[i - 1]][orden[i]] +
              (hayNodoSiguiente
                  ? matriz[orden[k]][orden[kSiguiente]]
                  : 0.0);

          final costoNuevo = matriz[orden[i - 1]][orden[k]] +
              (hayNodoSiguiente
                  ? matriz[orden[i]][orden[kSiguiente]]
                  : 0.0);

          if (costoNuevo < costoActual - 1e-6) {
            _invertirSegmento(orden, i, k);
            mejorado = true;
          }
        }
      }
    }

    return orden;
  }

  double _costoDeRuta(
    List<int> orden,
    List<List<double>> matriz,
  ) {
    var total = 0.0;

    for (var i = 0; i < orden.length - 1; i++) {
      total += matriz[orden[i]][orden[i + 1]];
    }

    return total;
  }

  void _invertirSegmento(
    List<int> orden,
    int i,
    int k,
  ) {
    var izquierda = i;
    var derecha = k;

    while (izquierda < derecha) {
      final temporal = orden[izquierda];
      orden[izquierda] = orden[derecha];
      orden[derecha] = temporal;
      izquierda++;
      derecha--;
    }
  }
}