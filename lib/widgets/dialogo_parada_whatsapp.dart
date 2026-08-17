import 'package:flutter/material.dart';
import '../database/local_database.dart';
import '../models/parada.dart';
import '../services/places_service.dart';
import '../screens/detalle_ruta_page.dart';

class DialogoParadaWhatsapp extends StatefulWidget {
  final double latitud;
  final double longitud;

  const DialogoParadaWhatsapp({
    super.key,
    required this.latitud,
    required this.longitud,
  });

  @override
  State<DialogoParadaWhatsapp> createState() => _DialogoParadaWhatsappState();
}

class _DialogoParadaWhatsappState extends State<DialogoParadaWhatsapp> {
  final PlacesService _placesService = PlacesService();
  final LocalDatabase _database = LocalDatabase.instance;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  bool cargandoDireccion = true;
  List<RutaModel> rutasDisponibles = [];
  int? rutaSeleccionadaId;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _notasController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    final detalles = await _placesService.obtenerDireccionDesdeCoordenadas(
      latitud: widget.latitud,
      longitud: widget.longitud,
    );

    if (mounted) {
      setState(() {
        _nombreController.text = detalles?.nombre ??
            'Ubicación (${widget.latitud.toStringAsFixed(4)}, ${widget.longitud.toStringAsFixed(4)})';
        cargandoDireccion = false;
      });
    }

    final rutas = await _database.obtenerRutas();
    if (mounted) {
      setState(() {
        rutasDisponibles = rutas;
        if (rutas.isNotEmpty) {
          rutaSeleccionadaId = rutas.first.id;
        }
      });
    }
  }

  Future<void> _crearRutaRapida() async {
    final controller = TextEditingController(text: 'TEMU');
    final nuevaId = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Nueva Ruta', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Nombre de ruta',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final id = await _database.crearRuta(nombre: controller.text.trim());
              Navigator.pop(ctx, id);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (nuevaId != null) {
      final rutas = await _database.obtenerRutas();
      setState(() {
        rutasDisponibles = rutas;
        rutaSeleccionadaId = nuevaId;
      });
    }
  }

  Future<void> _guardarParada() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre de parada')),
      );
      return;
    }

    // Si no hay ninguna ruta creada, creamos una por defecto
    if (rutaSeleccionadaId == null) {
      rutaSeleccionadaId = await _database.crearRuta(nombre: 'TEMU');
    }

    final parada = Parada(
      direccion: nombre,
      latitud: widget.latitud,
      longitud: widget.longitud,
      notas: _notasController.text.trim().isNotEmpty ? _notasController.text.trim() : null,
      telefono: _telefonoController.text.trim().isNotEmpty ? _telefonoController.text.trim() : null,
    );

    await _database.agregarParadaARuta(rutaSeleccionadaId!, parada);

    if (!mounted) return;
    Navigator.pop(context);

    // Abrimos el detalle de la ruta
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleRutaPage(rutaId: rutaSeleccionadaId!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'INFORMACIÓN DE PARADA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Latitud y Longitud
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Latitud', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          widget.latitud.toStringAsFixed(6),
                          style: const TextStyle(color: Color(0xFF33CCFF), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Longitud', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          widget.longitud.toStringAsFixed(6),
                          style: const TextStyle(color: Color(0xFF33CCFF), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                labelText: 'Nombre de parada *',
                labelStyle: const TextStyle(color: Colors.white70),
                suffixIcon: cargandoDireccion
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _notasController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                labelText: 'Notas (ej. Paquete #40)',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                labelText: 'Número de teléfono',
                labelStyle: const TextStyle(color: Colors.white70),
                suffixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF33CCFF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),

            // Selector de Ruta con botón '+' para crear nueva
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        dropdownColor: const Color(0xFF2C2C2C),
                        isExpanded: true,
                        value: rutaSeleccionadaId,
                        hint: const Text('Seleccionar Ruta', style: TextStyle(color: Colors.white70)),
                        items: rutasDisponibles.map((r) {
                          return DropdownMenuItem<int>(
                            value: r.id,
                            child: Text(
                              '${r.nombre} (${r.cantidadParadas})',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => rutaSeleccionadaId = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.green.shade600),
                  icon: const Icon(Icons.add),
                  tooltip: 'Crear nueva ruta',
                  onPressed: _crearRutaRapida,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCELAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3399FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _guardarParada,
                    child: const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}