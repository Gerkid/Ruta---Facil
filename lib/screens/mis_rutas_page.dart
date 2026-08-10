import 'package:flutter/material.dart';

import '../database/local_database.dart';
import 'ver_ruta_page.dart';

class MisRutasPage extends StatefulWidget {
  const MisRutasPage({super.key});

  @override
  State<MisRutasPage> createState() => _MisRutasPageState();
}

class _MisRutasPageState extends State<MisRutasPage> {
  final LocalDatabase _database = LocalDatabase.instance;

  late Future<List<RutaGuardada>> _futuroRutas;

  @override
  void initState() {
    super.initState();
    _futuroRutas = _database.obtenerRutas();
  }

  void _recargar() {
    setState(() {
      _futuroRutas = _database.obtenerRutas();
    });
  }

  Future<void> _eliminar(RutaGuardada ruta) async {
    await _database.eliminarRuta(ruta.id);
    _recargar();
  }

  Future<void> _abrirRuta(RutaGuardada ruta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerRutaPage(ruta: ruta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis rutas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<RutaGuardada>>(
        future: _futuroRutas,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final rutas = snapshot.data ?? [];

          if (rutas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no has guardado ninguna ruta.\n\n'
                  'Las rutas se guardan automáticamente '
                  'cada vez que optimizas una.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rutas.length,
            itemBuilder: (context, index) {
              final ruta = rutas[index];

              return Card(
                child: ListTile(
                  onTap: () => _abrirRuta(ruta),
                  leading: const CircleAvatar(
                    child: Icon(Icons.route_rounded),
                  ),
                  title: Text(ruta.nombre),
                  subtitle: Text(
                    '${ruta.cantidadParadas} paradas · '
                    '${ruta.duracionMinutos} min de recorrido',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                    onPressed: () => _eliminar(ruta),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}