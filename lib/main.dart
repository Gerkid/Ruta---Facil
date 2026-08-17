import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'database/local_database.dart';
import 'screens/crear_ruta_page.dart';
import 'screens/detalle_ruta_page.dart';
import 'widgets/dialogo_parada_whatsapp.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  runApp(const RutaFacilApp());
}

class RutaFacilApp extends StatefulWidget {
  const RutaFacilApp({super.key});

  @override
  State<RutaFacilApp> createState() => _RutaFacilAppState();
}

class _RutaFacilAppState extends State<RutaFacilApp> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // Se ejecuta de forma segura en segundo plano sin retrasar el arranque visual
    Future.delayed(const Duration(milliseconds: 600), _iniciarManejadorDeEnlaces);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _iniciarManejadorDeEnlaces() async {
    try {
      _appLinks = AppLinks();

      final initialUri = await _appLinks?.getInitialLink();
      if (initialUri != null) {
        _procesarUri(initialUri);
      }

      _linkSubscription = _appLinks?.uriLinkStream.listen(
        (uri) => _procesarUri(uri),
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _procesarUri(Uri uri) {
    final uriStr = uri.toString();
    final coords = _extraerCoords(uriStr);

    if (coords != null) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          builder: (_) => DialogoParadaWhatsapp(latitud: coords.lat, longitud: coords.lng),
        );
      }
    }
  }

  ({double lat, double lng})? _extraerCoords(String texto) {
    try {
      final regex = RegExp(r'(-?\d{1,2}\.\d+)\s*(?:%2C|,)\s*(-?\d{1,3}\.\d+)');
      final match = regex.firstMatch(texto);
      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) return (lat: lat, lng: lng);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Ruta Fácil',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF3399FF)),
      ),
      home: const RutasActivasPage(),
    );
  }
}

class RutasActivasPage extends StatefulWidget {
  const RutasActivasPage({super.key});

  @override
  State<RutasActivasPage> createState() => _RutasActivasPageState();
}

class _RutasActivasPageState extends State<RutasActivasPage> {
  final LocalDatabase _database = LocalDatabase.instance;
  List<RutaModel> rutas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await _database.obtenerRutas();
      if (mounted) {
        setState(() {
          rutas = lista;
          cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _confirmarEliminarRuta(RutaModel ruta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('¿Eliminar ruta?', style: TextStyle(color: Colors.white)),
        content: Text('Se eliminará "${ruta.nombre}" y todas sus paradas.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _database.eliminarRuta(ruta.id);
      _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ Ruta "${ruta.nombre}" eliminada.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Rutas - Activo (${rutas.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF222222),
                    hintText: 'Filtrar rutas',
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                if (rutas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No tienes rutas activas.\nToca el botón (+) para crear tu ruta "TEMU".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                else
                  ...rutas.map((r) {
                    return Card(
                      color: const Color(0xFF222222),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetalleRutaPage(rutaId: r.id)),
                          );
                          _cargar();
                        },
                        leading: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 28),
                        title: Text(r.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(
                          'HOY · ${r.fecha.day}.${r.fecha.month}.${r.fecha.year} · Perú NUEVO',
                          style: const TextStyle(color: Colors.orange, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 13,
                              child: Text('${r.cantidadParadas}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                              tooltip: 'Eliminar ruta',
                              onPressed: () => _confirmarEliminarRuta(r),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF3399FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Crea una nueva ruta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearRutaPage()),
          );
          _cargar();
        },
      ),
    );
  }
}