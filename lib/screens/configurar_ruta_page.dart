import 'package:flutter/material.dart';

import '../models/parada.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import 'nueva_ruta_page.dart';

class ConfigurarRutaPage extends StatefulWidget {
  const ConfigurarRutaPage({super.key});

  @override
  State<ConfigurarRutaPage> createState() =>
      _ConfigurarRutaPageState();
}

class _ConfigurarRutaPageState extends State<ConfigurarRutaPage> {
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService();

  final TextEditingController _tiempoController =
      TextEditingController(text: '5');

  // Punto de inicio: por defecto, mi ubicación actual.
  bool _inicioEsUbicacionActual = true;
  Parada? _inicioBuscado;

  // Punto de fin: opcional.
  bool _finTieneDireccion = false;
  Parada? _finBuscado;

  bool _cargando = false;

  @override
  void dispose() {
    _tiempoController.dispose();
    super.dispose();
  }

  bool _pareceCoordenadas(String texto) {
    final patron = RegExp(
      r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$',
    );

    return patron.hasMatch(texto.trim());
  }

  Future<void> _buscarDireccion({
    required void Function(Parada) alEncontrar,
  }) async {
    final controller = TextEditingController();

    List<PlaceSuggestion> resultados = [];
    bool buscando = false;

    // Modo "coordenadas". Van AFUERA del builder de abajo a
    // propósito: si estuvieran adentro, Flutter las reiniciaría
    // en cada letra que escribas, antes de que las alcances a ver.
    double? latitud;
    double? longitud;
    bool convirtiendo = false;
    PlaceDetails? direccionEncontrada;
    bool intentoSinResultado = false;

    await showDialog(
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

            Future<void> buscar() async {
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
              title: const Text('Buscar dirección'),
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
                            'Ej. Mi casa, o pega coordenadas',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            setDialogState(analizarTexto);

                            if (latitud == null) {
                              buscar();
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
                          buscar();
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // ---- Modo coordenadas ----
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
                          'esas coordenadas. Se usará solo '
                          'el número.',
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

                    if (esCoordenadas)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding:
                              const EdgeInsets.only(top: 10),
                          child: FilledButton(
                            onPressed: () {
                              alEncontrar(
                                Parada(
                                  nombre: direccionEncontrada
                                          ?.nombre ??
                                      'Ubicación por '
                                          'coordenadas',
                                  latitud: latitud!,
                                  longitud: longitud!,
                                  placeId: direccionEncontrada
                                      ?.placeId,
                                ),
                              );

                              Navigator.pop(dialogContext);
                            },
                            child: const Text('Usar esta ubicación'),
                          ),
                        ),
                      ),

                    // ---- Modo dirección ----
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

                                alEncontrar(
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _continuar() async {
    final minutos = int.tryParse(_tiempoController.text.trim());

    if (minutos == null || minutos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa un tiempo válido por parada.',
          ),
        ),
      );
      return;
    }

    Parada? inicio;

    if (_inicioEsUbicacionActual) {
      setState(() {
        _cargando = true;
      });

      final posicion =
          await _locationService.obtenerUbicacionActual();

      if (!mounted) {
        return;
      }

      setState(() {
        _cargando = false;
      });

      if (posicion == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener tu ubicación actual.',
            ),
          ),
        );
        return;
      }

      inicio = Parada(
        nombre: 'Punto de partida (mi ubicación)',
        latitud: posicion.latitude,
        longitud: posicion.longitude,
      );
    } else {
      inicio = _inicioBuscado;
    }

    if (inicio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Elige una dirección de inicio.',
          ),
        ),
      );
      return;
    }

    if (_finTieneDireccion && _finBuscado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Elige una dirección de fin, o desactiva esa opción.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaRutaPage(
          puntoInicio: inicio!,
          puntoFin:
              _finTieneDireccion ? _finBuscado : null,
          tiempoMaximoPorParadaMin: minutos,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nueva ruta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tiempo máximo por parada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Se usa para estimar cuánto durará todo el día.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tiempoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixText: 'minutos',
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Punto de inicio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Por ejemplo, el almacén donde armas la ruta.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            value: true,
            groupValue: _inicioEsUbicacionActual,
            title: const Text('Usar mi ubicación actual'),
            onChanged: (valor) {
              setState(() {
                _inicioEsUbicacionActual = true;
              });
            },
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            value: false,
            groupValue: _inicioEsUbicacionActual,
            title: const Text('Buscar una dirección'),
            onChanged: (valor) {
              setState(() {
                _inicioEsUbicacionActual = false;
              });
            },
          ),
          if (!_inicioEsUbicacionActual)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: Text(
                  _inicioBuscado?.nombre ??
                      'Elegir dirección de inicio',
                ),
                onPressed: () {
                  _buscarDireccion(
                    alEncontrar: (parada) {
                      setState(() {
                        _inicioBuscado = parada;
                      });
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 28),

          const Text(
            'Punto de fin (opcional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Por ejemplo, tu casa. La última entrega quedará '
            'cerca de esta dirección.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _finTieneDireccion,
            title: const Text('Terminar en una dirección fija'),
            onChanged: (valor) {
              setState(() {
                _finTieneDireccion = valor;
              });
            },
          ),
          if (_finTieneDireccion)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: Text(
                  _finBuscado?.nombre ??
                      'Elegir dirección de fin',
                ),
                onPressed: () {
                  _buscarDireccion(
                    alEncontrar: (parada) {
                      setState(() {
                        _finBuscado = parada;
                      });
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 32),

          FilledButton(
            onPressed: _cargando ? null : _continuar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Continuar',
                      style: TextStyle(fontSize: 17),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}