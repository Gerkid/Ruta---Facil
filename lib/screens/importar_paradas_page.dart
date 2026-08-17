import 'package:flutter/material.dart';
import '../models/parada.dart';
import '../services/import_service.dart';

class ImportarParadasPage extends StatefulWidget {
  const ImportarParadasPage({super.key});

  @override
  State<ImportarParadasPage> createState() => _ImportarParadasPageState();
}

class _ImportarParadasPageState extends State<ImportarParadasPage> {
  final ImportService _importService = ImportService();
  final TextEditingController _textoController = TextEditingController();

  bool cargando = false;
  String? mensajeEstado;

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarArchivo() async {
    setState(() {
      cargando = true;
      mensajeEstado = 'Leyendo archivo...';
    });

    try {
      final paradas = await _importService.importarDesdeArchivo();
      if (!mounted) return;

      if (paradas.isEmpty) {
        setState(() {
          cargando = false;
          mensajeEstado = 'No se encontraron paradas válidas.';
        });
      } else {
        Navigator.pop(context, paradas);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          cargando = false;
          mensajeEstado = 'Error al importar: $e';
        });
      }
    }
  }

  Future<void> _procesarTexto() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      cargando = true;
      mensajeEstado = 'Procesando texto...';
    });

    try {
      final paradas = await _importService.importarDesdeTexto(texto);
      if (!mounted) return;

      if (paradas.isEmpty) {
        setState(() {
          cargando = false;
          mensajeEstado = 'No se detectaron coordenadas o direcciones.';
        });
      } else {
        Navigator.pop(context, paradas);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          cargando = false;
          mensajeEstado = 'Error al procesar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        title: const Text('Importar de Google Maps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Importar Lista de Google Maps con Notas',
                  style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  '1) Exporta tus listas guardadas desde Google Takeout en formato CSV o JSON.\n2) Selecciona el archivo o pega el texto aquí abajo.',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: cargando ? null : _seleccionarArchivo,
              icon: const Icon(Icons.folder_open),
              label: const Text('SELECCIONAR ARCHIVO (JSON / CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),

          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('O PEGA EL CONTENIDO AQUÍ', style: TextStyle(color: Colors.black45, fontSize: 12))),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _textoController,
            maxLines: 8,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Pega aquí el contenido JSON, CSV o lista de coordenadas de Google Maps...',
              hintStyle: const TextStyle(color: Colors.black38),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12)),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2962FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: cargando ? null : _procesarTexto,
              icon: const Icon(Icons.playlist_add_check, color: Color(0xFF2962FF)),
              label: const Text('Procesar Texto Pegado', style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold)),
            ),
          ),

          if (cargando) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(mensajeEstado ?? 'Cargando...', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}