import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/parada.dart';
import '../services/navigation_service.dart';
import '../widgets/mapa_ruta.dart';

class VerRutaPage extends StatefulWidget {
  final RutaGuardada ruta;

  const VerRutaPage({
    super.key,
    required this.ruta,
  });

  @override
  State<VerRutaPage> createState() => _VerRutaPageState();
}

class _VerRutaPageState extends State<VerRutaPage> {
  final LocalDatabase _database = LocalDatabase.instance;
  final NavigationService _navigationService = NavigationService();

  late Future<List<Parada>> _futuroParadas;

  @override
  void initState() {
    super.initState();
    _futuroParadas =
        _database.obtenerParadasDeRuta(widget.ruta.id);
  }

  Future<void> _navegar(Parada parada) async {
    await _navigationService.abrirGoogleMaps(
      latitud: parada.latitud,
      longitud: parada.longitud,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ruta.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Parada>>(
        future: _futuroParadas,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se pudo cargar la ruta.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final paradas = snapshot.data ?? [];

          if (paradas.isEmpty) {
            return const Center(
              child: Text('Esta ruta no tiene paradas.'),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  8,
                ),
                child: Text(
                  '${paradas.length} paradas · '
                  '${widget.ruta.duracionMinutos} min de recorrido',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
              ),

              SizedBox(
                height: 240,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MapaRuta(paradas: paradas),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: paradas.length,
                  itemBuilder: (context, index) {
                    final parada = paradas[index];

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
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.navigation_rounded,
                          ),
                          onPressed: () => _navegar(parada),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
