import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/parada.dart';
import '../services/navigation_service.dart';
import '../services/places_service.dart';
import '../services/route_service.dart';
import '../widgets/mapa_ruta.dart';

class NuevaRutaPage extends StatefulWidget {
  final Parada puntoInicio;
  final Parada? puntoFin;
  final int tiempoMaximoPorParadaMin;

  const NuevaRutaPage({
    super.key,
    required this.puntoInicio,
    required this.puntoFin,
    required this.tiempoMaximoPorParadaMin,
  });

  @override
  State<NuevaRutaPage> createState() => _NuevaRutaPageState();
}

class _NuevaRutaPageState extends State<NuevaRutaPage> {
  // Solo las entregas del medio; el inicio y el fin son fijos
  // y vienen de la pantalla de configuración.
  final List<Parada> entregas = [];

  final PlacesService _placesService = PlacesService();
  final NavigationService _navigationService = NavigationService();
  final RouteService _routeService = RouteService();
  final LocalDatabase _database = LocalDatabase.instance;

  bool optimizando = false;

  // Se llena después de optimizar, para mostrar el tiempo total
  // estimado del día (viaje + tiempo en cada parada).
  ResultadoOptimizacion? ultimoResultado;

  List<Parada> get todasLasParadas => [
        widget.puntoInicio,
        ...entregas,
        if (widget.puntoFin != null) widget.puntoFin!,
      ];

  void agregarParada(Parada parada) {
    setState(() {
      entregas.add(parada);
      ultimoResultado = null;
    });
  }

  void eliminarParada(int index) {
    setState(() {
      entregas.removeAt(index);
      ultimoResultado = null;
    });
  }

  bool _pareceCoordenadas(String texto) {
    final patron = RegExp(
      r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$',
    );

    return patron.hasMatch(texto.trim());
  }

  void mostrarAgregarParada() {
    final controller = TextEditingController();

    // Estas variables van AFUERA del builder de abajo a
    // propósito: si estuvieran adentro, Flutter las reiniciaría
    // en cada letra que escribas, antes de que las alcances a ver.
    double? latitud;
    double? longitud;
    bool convirtiendo = false;
    PlaceDetails? direccionEncontrada;
    bool intentoSinResultado = false;

    List<PlaceSuggestion> resultados = [];
    bool buscando = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void analizarTexto() {
              final texto = controller.text.trim();

              latitud = null;
              longitud = null;
              direccionEncontrada = null;
              intentoSinResultado = false;
              resultados = [];

              if (_pareceCoordenadas(texto)) {
                final partes = texto.split(',');

                final lat = double.tryParse(partes[0].trim());
                final lng = double.tryParse(partes[1].trim());

                if (lat != null &&
                    lng != null &&
                    lat >= -90 &&
                    lat <= 90 &&
                    lng >= -180 &&
                    lng <= 180) {
                  latitud = lat;
                  longitud = lng;
                }
              }
            }

            Future<void> convertirADireccion() async {
              if (latitud == null || longitud == null) {
                return;
              }

              setDialogState(() {
                convirtiendo = true;
              });

              try {
                final resultado = await _placesService
                    .obtenerDireccionDesdeCoordenadas(
                  latitud: latitud!,
                  longitud: longitud!,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  convirtiendo = false;
                  direccionEncontrada = resultado;
                  intentoSinResultado = resultado == null;
                });
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  convirtiendo = false;
                  intentoSinResultado = true;
                });
              }
            }

            Future<void> buscarDireccion() async {
              final texto = controller.text.trim();

              if (texto.length < 3) {
                setDialogState(() {
                  resultados = [];
                });
                return;
              }

              setDialogState(() {
                buscando = true;
              });

              try {
                final encontrados =
                    await _placesService.buscarLugares(texto);

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  resultados = encontrados;
                  buscando = false;
                });
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  resultados = [];
                  buscando = false;
                });
              }
            }

            final esCoordenadas = latitud != null;
            final textoActual = controller.text.trim();
            final modoDireccion =
                !esCoordenadas && textoActual.length >= 3;

            return AlertDialog(
              title: const Text('Agregar parada'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText:
                            'Busca una dirección o pega '
                            'coordenadas',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            setDialogState(analizarTexto);

                            if (latitud == null) {
                              buscarDireccion();
                            }
                          },
                        ),
                      ),
                      onChanged: (_) {
                        setDialogState(analizarTexto);
                      },
                      onSubmitted: (_) {
                        setDialogState(analizarTexto);

                        if (latitud == null) {
                          buscarDireccion();
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // ---- Resultado en modo coordenadas ----
                    if (esCoordenadas && convirtiendo)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),

                    if (esCoordenadas &&
                        !convirtiendo &&
                        direccionEncontrada != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                direccionEncontrada!.nombre,
                                style: const TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (esCoordenadas &&
                        !convirtiendo &&
                        intentoSinResultado &&
                        direccionEncontrada == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'No se encontró una dirección para '
                          'esas coordenadas. Se agregará solo '
                          'con el número.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                    if (esCoordenadas &&
                        !convirtiendo &&
                        direccionEncontrada == null &&
                        !intentoSinResultado)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: convertirADireccion,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text(
                            'Convertir a dirección con Google',
                          ),
                        ),
                      ),

                    // ---- Resultados en modo dirección ----
                    if (modoDireccion && buscando)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),

                    if (modoDireccion &&
                        !buscando &&
                        resultados.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: resultados.length,
                          itemBuilder: (context, index) {
                            final resultado =
                                resultados[index];

                            return ListTile(
                              leading: const Icon(
                                Icons.location_on_outlined,
                              ),
                              title:
                                  Text(resultado.descripcion),
                              onTap: () async {
                                final detalles =
                                    await _placesService
                                        .obtenerDetalles(
                                  resultado.placeId,
                                );

                                if (!dialogContext.mounted ||
                                    detalles == null) {
                                  return;
                                }

                                agregarParada(
                                  Parada(
                                    nombre: detalles.nombre,
                                    latitud: detalles.latitud,
                                    longitud:
                                        detalles.longitud,
                                    placeId: detalles.placeId,
                                  ),
                                );

                                Navigator.pop(dialogContext);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                if (esCoordenadas)
                  FilledButton(
                    onPressed: () {
                      agregarParada(
                        Parada(
                          nombre:
                              direccionEncontrada?.nombre ??
                                  'Ubicación por coordenadas',
                          latitud: latitud!,
                          longitud: longitud!,
                          placeId:
                              direccionEncontrada?.placeId,
                        ),
                      );

                      Navigator.pop(context);
                    },
                    child: const Text('Agregar'),
                  ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> optimizar() async {
    if (entregas.length < 2) {
      return;
    }

    setState(() {
      optimizando = true;
    });

    try {
      final resultado = await _routeService.optimizarRuta(
        entregas,
        inicio: widget.puntoInicio,
        fin: widget.puntoFin,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        entregas
          ..clear()
          ..addAll(resultado.paradas);
        ultimoResultado = resultado;
        optimizando = false;
      });

      // Guardamos la ruta completa (inicio + entregas + fin) en
      // el historial, para poder consultarla después.
      await _database.guardarRuta(
        paradas: todasLasParadas,
        duracionSegundos: resultado.duracionOptimizadaSegundos,
      );

      if (!mounted) {
        return;
      }

      final mensaje = resultado.minutosAhorrados > 0
          ? 'Ruta optimizada: ahorras '
              '${resultado.minutosAhorrados} min '
              '(${resultado.porcentajeMejora.round()}% menos '
              'tiempo de recorrido).'
          : 'Ruta procesada: el orden actual ya era el más '
              'rápido posible.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        optimizando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is Exception
                ? error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    )
                : 'No se pudo procesar la ruta.',
          ),
        ),
      );
    }
  }

  Future<void> navegar(Parada parada) async {
    await _navigationService.abrirGoogleMaps(
      latitud: parada.latitud,
      longitud: parada.longitud,
    );
  }

  String _formatearDuracion(double segundos) {
    final totalMinutos = (segundos / 60).round();
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;

    if (horas > 0) {
      return '$horas h $minutos min';
    }

    return '$minutos min';
  }

  @override
  Widget build(BuildContext context) {
    final resultado = ultimoResultado;

    // Tiempo total estimado del día: tiempo de viaje + tiempo
    // que planeas usar en cada parada.
    final tiempoTotalEstimado = resultado == null
        ? null
        : resultado.duracionOptimizadaSegundos +
            (entregas.length *
                widget.tiempoMaximoPorParadaMin *
                60);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nueva ruta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trip_origin_rounded,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Inicio: ${widget.puntoInicio.nombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (widget.puntoFin != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fin: ${widget.puntoFin!.nombre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            if (tiempoTotalEstimado != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tiempo total estimado del día: '
                          '${_formatearDuracion(tiempoTotalEstimado)} '
                          '(incluye ${widget.tiempoMaximoPorParadaMin} '
                          'min por parada)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapaRuta(paradas: todasLasParadas),
              ),
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Entregas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${entregas.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Expanded(
              child: entregas.isEmpty
                  ? const Center(
                      child: Text(
                        'Todavía no hay entregas.\n\n'
                        'Agrega una dirección o coordenadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: entregas.length,
                      itemBuilder: (context, index) {
                        final parada = entregas[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(parada.nombre),
                            subtitle: Text(
                              '${parada.latitud}, '
                              '${parada.longitud}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.navigation_rounded,
                                  ),
                                  onPressed: () =>
                                      navegar(parada),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons
                                        .delete_outline_rounded,
                                  ),
                                  onPressed: () =>
                                      eliminarParada(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            FilledButton.icon(
              onPressed: mostrarAgregarParada,
              icon: const Icon(Icons.add_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  'Agregar parada',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: entregas.length < 2 || optimizando
                  ? null
                  : optimizar,
              icon: optimizando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.route_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                child: Text(
                  optimizando ? 'Procesando...' : 'Optimizar ruta',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}