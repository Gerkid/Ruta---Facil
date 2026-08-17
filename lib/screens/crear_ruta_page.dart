import 'package:flutter/material.dart';
import '../database/local_database.dart';
import '../models/parada.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import 'detalle_ruta_page.dart';

class CrearRutaPage extends StatefulWidget {
  const CrearRutaPage({super.key});

  @override
  State<CrearRutaPage> createState() => _CrearRutaPageState();
}

class _CrearRutaPageState extends State<CrearRutaPage> {
  final LocalDatabase _database = LocalDatabase.instance;
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService();

  final TextEditingController _nombreController = TextEditingController(text: 'TEMU');
  
  DateTime fechaSeleccionada = DateTime.now();
  String inicioNombre = 'Mi ubicación';
  double? inicioLat;
  double? inicioLng;

  String finNombre = 'Selección automática';
  double? finLat;
  double? finLng;

  bool cargando = false;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActualGPS();
  }

  Future<void> _obtenerUbicacionActualGPS() async {
    final pos = await _locationService.obtenerUbicacionActual();
    if (pos != null && mounted) {
      setState(() {
        inicioLat = pos.latitude;
        inicioLng = pos.longitude;
      });
    }
  }

  // 📅 SELECCIONAR FECHA
  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF3399FF), surface: Color(0xFF222222)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => fechaSeleccionada = picked);
    }
  }

  // 🔍 DIÁLOGO PARA BUSCAR DIRECCIÓN DE INICIO O FIN (TU CASA / ALMACÉN)
  Future<void> _buscarDireccionPersonalizada({required bool esInicio}) async {
    final controller = TextEditingController();
    List<PlaceSuggestion> sugerencias = [];
    bool buscando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> buscar(String q) async {
            if (q.trim().length < 3) return;
            setDialogState(() => buscando = true);
            final items = await _placesService.buscarLugares(q);
            if (ctx.mounted) {
              setDialogState(() {
                sugerencias = items;
                buscando = false;
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: Text(
              esInicio ? 'Elegir Punto de Salida' : 'Elegir Punto Final (Tu Casa)',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: esInicio ? 'Ej: Almacén Callao...' : 'Ej: Mi casa / Los Olivos...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF333333),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.white54), onPressed: () => buscar(controller.text)),
                    ),
                    onChanged: (val) {
                      if (val.length >= 3) buscar(val);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (buscando)
                    const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Color(0xFF3399FF)))
                  else if (sugerencias.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sugerencias.length,
                        itemBuilder: (context, i) {
                          final s = sugerencias[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined, color: Color(0xFF33CCFF)),
                            title: Text(s.descripcion, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            onTap: () async {
                              final det = await _placesService.obtenerDetalles(s.placeId);
                              if (det != null) {
                                Navigator.pop(ctx);
                                setState(() {
                                  if (esInicio) {
                                    inicioNombre = det.nombre;
                                    inicioLat = det.latitud;
                                    inicioLng = det.longitud;
                                  } else {
                                    finNombre = det.nombre;
                                    finLat = det.latitud;
                                    finLng = det.longitud;
                                  }
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ],
          );
        },
      ),
    );
  }

  // 📍 MENÚ DE INICIO
  void _mostrarOpcionesInicio() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('UBICACIÓN DE INICIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.my_location, color: Color(0xFF33CCFF)),
              title: const Text('Mi ubicación GPS actual', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await _obtenerUbicacionActualGPS();
                setState(() => inicioNombre = 'Mi ubicación');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store_mall_directory_outlined, color: Colors.white),
              title: const Text('Buscar dirección (Almacén / Depósito)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _buscarDireccionPersonalizada(esInicio: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🏁 MENÚ DE FINALIZACIÓN (DONDE ACABAR / TU CASA)
  void _mostrarOpcionesFin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('UBICACIÓN DE FINALIZACIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.auto_mode_rounded, color: Color(0xFF33CCFF)),
              title: const Text('Selección automática (La parada más óptima)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  finNombre = 'Selección automática';
                  finLat = null;
                  finLng = null;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: Colors.greenAccent),
              title: const Text('Terminar cerca de mi casa (Dirección fija)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('La última entrega se ubicará cerca de tu casa', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _buscarDireccionPersonalizada(esInicio: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.replay_rounded, color: Colors.orangeAccent),
              title: const Text('Terminar en el punto de inicio (Regreso al almacén)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  finNombre = 'Regreso al inicio ($inicioNombre)';
                  finLat = inicioLat;
                  finLng = inicioLng;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearRuta() async {
    setState(() => cargando = true);

    final id = await _database.crearRuta(
      nombre: _nombreController.text.trim().isNotEmpty ? _nombreController.text.trim() : 'TEMU',
      fecha: fechaSeleccionada,
      inicioLat: inicioLat,
      inicioLng: inicioLng,
      inicioDireccion: inicioNombre,
      finLat: finLat,
      finLng: finLng,
      finDireccion: finNombre,
    );

    if (!mounted) return;
    setState(() => cargando = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DetalleRutaPage(rutaId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = '${fechaSeleccionada.day.toString().padLeft(2, '0')}.${fechaSeleccionada.month.toString().padLeft(2, '0')}.${fechaSeleccionada.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: const Text('Crea una nueva ruta', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Nombre de ruta', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _nombreController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF2C2C2C),
              hintText: 'TEMU',
              hintStyle: const TextStyle(color: Colors.white30),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // FECHA (TOCA PARA CAMBIAR)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _seleccionarFecha,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fecha', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fechaStr, style: const TextStyle(color: Color(0xFF33CCFF), fontWeight: FontWeight.bold)),
                            const Icon(Icons.calendar_today_outlined, color: Color(0xFF33CCFF), size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('País / Región', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Perú', style: TextStyle(color: Color(0xFF33CCFF), fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // INICIO (TOCA PARA CAMBIAR)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _mostrarOpcionesInicio,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ubicación de inicio de ruta', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          inicioNombre,
                          style: const TextStyle(color: Color(0xFF33CCFF), fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // FIN / TU CASA (TOCA PARA CAMBIAR)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _mostrarOpcionesFin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ubicación de finalización de ruta', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          finNombre,
                          style: TextStyle(
                            color: finLat != null ? Colors.greenAccent : const Color(0xFF33CCFF),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3399FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: cargando ? null : _crearRuta,
              child: cargando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('CREAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}