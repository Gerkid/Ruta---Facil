import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/configurar_ruta_page.dart';
import 'screens/mis_rutas_page.dart';

void main() async {
  // 1. Asegura que el motor de Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Escudo protector: Intenta cargar el .env, pero si falla, no congela la app
  try {
    await dotenv.load(fileName: ".env");
    print("✅ Bóveda .env cargada con éxito");
  } catch (e) {
    print("🚨 ERROR: No se pudo cargar el .env. Detalles: $e");
  }

  // 3. Arranca la aplicación sí o sí
  runApp(const RutaFacilApp());
}

class RutaFacilApp extends StatelessWidget {
  const RutaFacilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ruta Fácil',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
      ),
      home: const InicioPage(),
    );
  }
}

class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ruta Fácil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.local_shipping_rounded,
              size: 80,
            ),

            const SizedBox(height: 20),

            const Text(
              'Planifica tus rutas',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Organiza tus entregas de forma rápida y sencilla.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 50),

            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConfigurarRutaPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: Text(
                  'Nueva ruta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MisRutasPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.route_rounded,
              ),
              label: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: Text(
                  'Mis rutas',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}