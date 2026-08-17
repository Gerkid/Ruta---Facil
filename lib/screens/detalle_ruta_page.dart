import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../database/local_database.dart';
import '../models/parada.dart';
import '../services/navigation_service.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/places_service.dart';
import '../services/route_service.dart';
import '../widgets/mapa_ruta.dart';
import 'importar_paradas_page.dart';

class DetalleRutaPage extends StatefulWidget {
  final int rutaId;

  const DetalleRutaPage({super.key, required this.rutaId});

  @override
  State<DetalleRutaPage> createState() => _DetalleRutaPageState();
}

class _DetalleRutaPageState extends State<DetalleRutaPage> {
  final LocalDatabase _database = LocalDatabase.instance;
  final PlacesService _placesService = PlacesService();
  final NavigationService _navigationService = NavigationService();
  final RouteService _routeService = RouteService();
  final OcrService _ocrService = OcrService();
  final NotificationService _notifService = NotificationService.instance;

  final TextEditingController _buscarController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  RutaModel? ruta;
  List<Parada> paradas = [];
  List<LatLng> puntosPolilineaVial = [];
  List<PlaceSuggestion> sugerencias = [];
  bool buscandoSugerencias = false;
  int tabSeleccionado = 0; // 0 = Pendientes, 1 = Hecho
  bool optimizando = false;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _iniciarServicios();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _sheetController.dispose();
    _ocrService.dispose();
    _notifService.cancelarNotificacion();
    super.dispose();
  }

  Future<void> _iniciarServicios() async {
    await _notifService.inicializar(onAccion: (actionId, paradaId) async {
      if (actionId == 'accion_entregado') {
        await _database.actualizarEstadoParada(paradaId, 'entregado');
        await _cargarDatos(actualizarNotificacion: true);
      } else if (actionId == 'accion_ausente') {
        await _database.actualizarEstadoParada(paradaId, 'ausente');
        await _cargarDatos(actualizarNotificacion: true);
      } else if (actionId == 'accion_siguiente') {
        if (paradasPendientes.isNotEmpty) {
          _iniciarNavegacion(paradasPendientes.first);
        }
      }
    });
    await _cargarDatos();
  }

  Future<void> _cargarDatos({bool actualizarNotificacion = false}) async {
    final r = await _database.obtenerRutaPorId(widget.rutaId);
    final p = await _database.obtenerParadasDeRuta(widget.rutaId);

    List<LatLng> puntosGuardados = [];
    if (r?.polilineaCoords != null && r!.polilineaCoords!.isNotEmpty) {
      try {
        final List dec = jsonDecode(r.polilineaCoords!);
        puntosGuardados = dec.map((item) => LatLng((item[0] as num).toDouble(), (item as num).toDouble())).toList();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        ruta = r;
        paradas = p;
        if (puntosGuardados.isNotEmpty) {
          puntosPolilineaVial = puntosGuardados;
        }
        cargando = false;
      });

      if (actualizarNotificacion && paradasPendientes.isNotEmpty) {
        _notifService.mostrarNotificacionDespacho(
          parada: paradasPendientes.first,
          totalParadas: paradas.length,
          rutaId: widget.rutaId,
        );
      } else if (actualizarNotificacion && paradasPendientes.isEmpty) {
        _notifService.cancelarNotificacion();
      }
    }
  }

  List<Parada> get paradasPendientes => paradas.where((p) => p.estado == 'pendiente').toList();
  List<Parada> get paradasHechas => paradas.where((p) => p.estado != 'pendiente').toList();

  double get distanciaCalculadaKm {
    if (ruta != null && ruta!.distanciaKm > 0) return ruta!.distanciaKm;
    if (paradas.length < 2) return 0.0;

    double distanciaMetros = 0.0;
    for (var i = 0; i < paradas.length - 1; i++) {
      distanciaMetros += _haversine(
        paradas[i].latitud, paradas[i].longitud,
        paradas[i + 1].latitud, paradas[i + 1].longitud,
      );
    }
    return (distanciaMetros * 1.3) / 1000;
  }

  int get tiempoCalculadoMinutos {
    if (ruta != null && ruta!.duracionMinutos > 0) return ruta!.duracionMinutos;
    return (distanciaCalculadaKm * 2.8).round() + (paradas.length * 3);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _cambiarNombreRuta() async {
    final controller = TextEditingController(text: ruta?.nombre ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cambiar Nombre de Ruta', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.black87),
          decoration: const InputDecoration(labelText: 'Nombre de ruta', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
            onPressed: () async {
              final nuevo = controller.text.trim();
              if (nuevo.isNotEmpty) {
                Navigator.pop(ctx);
                await _database.actualizarNombreRuta(widget.rutaId, nuevo);
                _cargarDatos();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarParadaDirecta(Parada parada) async {
    await _database.agregarParadaARuta(widget.rutaId, parada);
    await _cargarDatos();
  }

  Future<void> _cambiarEstado(Parada p, String estado) async {
    if (p.id == null) return;
    await _database.actualizarEstadoParada(p.id!, estado);
    await _cargarDatos(actualizarNotificacion: true);
  }

  Future<void> _eliminarParada(Parada p) async {
    if (p.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('¿Eliminar parada?', style: TextStyle(color: Colors.black87)),
        content: Text('Se eliminará "${p.direccion}" de esta ruta.', style: const TextStyle(color: Colors.black54)),
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
      await _database.eliminarParada(p.id!);
      _cargarDatos();
    }
  }

  Future<void> _mostrarDialogoEditarParada(Parada p) async {
    if (p.id == null) return;

    final nombreCtrl = TextEditingController(text: p.direccion);
    final notaCtrl = TextEditingController(text: p.notas ?? '');
    final telCtrl = TextEditingController(text: p.telefono ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar detalles de parada', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Dirección o Nombre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notaCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Notas del paquete (ej: 883 o 956)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Teléfono del cliente', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _database.actualizarDetallesParada(
                paradaId: p.id!,
                direccion: nombreCtrl.text.trim().isNotEmpty ? nombreCtrl.text.trim() : p.direccion,
                notas: notaCtrl.text.trim().isNotEmpty ? notaCtrl.text.trim() : null,
                telefono: telCtrl.text.trim().isNotEmpty ? telCtrl.text.trim() : null,
              );
              _cargarDatos();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarResumenMetricas() {
    final total = paradas.length;
    final entregados = paradas.where((p) => p.estado == 'entregado').length;
    final ausentes = paradas.where((p) => p.estado == 'ausente').length;
    final pendientes = paradas.where((p) => p.estado == 'pendiente').length;
    final km = distanciaCalculadaKm;
    final minutos = tiempoCalculadoMinutos;
    final progreso = total > 0 ? (entregados / total) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFF6D00), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.speed, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Métricas: ${ruta?.nombre ?? "Ruta"}',
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _crearTarjetaMetrica('Distancia', '${km.toStringAsFixed(1)} km', Icons.directions_car, Colors.orange),
                _crearTarjetaMetrica('Tiempo Estimado', '$minutos min', Icons.timer_outlined, Colors.blue),
                _crearTarjetaMetrica('Entregas', '$entregados/$total', Icons.inventory_2_outlined, Colors.green),
              ],
            ),
            const SizedBox(height: 20),
            Text('Progreso: ${(progreso * 100).round()}% completado', style: const TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 10,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🟢 Entregados: $entregados', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text('🔴 Ausentes: $ausentes', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text('🔵 Pendientes: $pendientes', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _crearTarjetaMetrica(String label, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 6),
          Text(valor, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoConfirmarParada({
    required String direccion,
    required double lat,
    required double lng,
    String? placeId,
  }) async {
    final nombreCtrl = TextEditingController(text: direccion);
    final notaCtrl = TextEditingController();
    final telCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Añadir Parada a la Ruta', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Dirección *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notaCtrl,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Notas (ej. 818 o Paquete #12)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(labelText: 'Teléfono del cliente', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
            onPressed: () async {
              final nombreFinal = nombreCtrl.text.trim();
              if (nombreFinal.isEmpty) return;

              Navigator.pop(ctx);
              await _agregarParadaDirecta(
                Parada(
                  direccion: nombreFinal,
                  latitud: lat,
                  longitud: lng,
                  notas: notaCtrl.text.trim().isNotEmpty ? notaCtrl.text.trim() : null,
                  telefono: telCtrl.text.trim().isNotEmpty ? telCtrl.text.trim() : null,
                  placeId: placeId,
                ),
              );
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarNavegacion(Parada parada) async {
    await _notifService.mostrarNotificacionDespacho(
      parada: parada,
      totalParadas: paradas.length,
      rutaId: widget.rutaId,
    );

    await _navigationService.abrirGoogleMaps(
      latitud: parada.latitud,
      longitud: parada.longitud,
    );
  }

  void _mostrarMenuAgregarParada() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Añadir a la Ruta', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: Color(0xFF2962FF)),
              title: const Text('Importar paradas (Google Maps, CSV, JSON)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final List<Parada>? importadas = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportarParadasPage()),
                );
                if (importadas != null) {
                  for (final p in importadas) {
                    await _database.agregarParadaARuta(widget.rutaId, p);
                  }
                  _cargarDatos();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2962FF)),
              title: const Text('Escanear etiqueta Temu (Cámara OCR)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await _ocrService.escanearEtiquetaConCamara();
                if (res?.paradaGeocodificada != null) {
                  await _mostrarDialogoConfirmarParada(
                    direccion: res!.paradaGeocodificada!.direccion,
                    lat: res!.paradaGeocodificada!.latitud,
                    lng: res!.paradaGeocodificada!.longitud,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_drop_outlined, color: Color(0xFF2962FF)),
              title: const Text('Pegar Coordenadas (Lat, Lng)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarDialogoPegarCoordenadas();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoPegarCoordenadas() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pegar Coordenadas', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa la latitud y longitud separadas por coma:', style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(hintText: '-11.986123, -77.120169', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
            onPressed: () async {
              final partes = controller.text.split(',');
              if (partes.length == 2) {
                final lat = double.tryParse(partes.elementAt(0).trim());
                final lng = double.tryParse(partes.elementAt(1).trim());
                if (lat != null && lng != null) {
                  Navigator.pop(ctx);
                  await _mostrarDialogoConfirmarParada(direccion: 'Ubicación ($lat, $lng)', lat: lat, lng: lng);
                }
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _optimizarRuta() async {
    if (paradas.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos 2 paradas para optimizar')));
      return;
    }

    setState(() => optimizando = true);

    try {
      final inicio = Parada(
        direccion: ruta?.inicioDireccion ?? 'Inicio',
        latitud: ruta?.inicioLat ?? paradas.first.latitud,
        longitud: ruta?.inicioLng ?? paradas.first.longitud,
      );

      final fin = (ruta?.finLat != null && ruta?.finLng != null)
          ? Parada(
              direccion: ruta!.finDireccion ?? 'Fin',
              latitud: ruta!.finLat!,
              longitud: ruta!.finLng!,
            )
          : null;

      final res = await _routeService.optimizarRuta(paradas, inicio: inicio, fin: fin);
      await _database.actualizarOrdenParadas(widget.rutaId, res.paradas);

      final polilineaJson = jsonEncode(
        res.puntosPolilinea.map((latlng) => [latlng.latitude, latlng.longitude]).toList(),
      );

      await _database.actualizarMetricasYPoliLinea(
        widget.rutaId,
        duracionSegundos: res.duracionOptimizadaSegundos,
        distanciaMetros: res.distanciaMetros,
        polilineaCoords: polilineaJson,
      );

      if (mounted) {
        setState(() {
          puntosPolilineaVial = res.puntosPolilinea;
        });
      }

      await _cargarDatos();
      if (!mounted) return;
      setState(() => optimizando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('✅ Trazado vial completado: ${(res.distanciaMetros / 1000).toStringAsFixed(1)} km (Curvas trazadas)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => optimizando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al optimizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreRuta = ruta?.nombre ?? 'Ruta';
    final total = paradas.length;
    final hechas = paradasHechas.length;
    final listaMostrada = tabSeleccionado == 0 ? paradasPendientes : paradasHechas;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // 1. 🗺️ MAPA DE FONDO COMPLETO
            Positioned.fill(
              child: MapaRuta(
                paradas: paradas,
                puntosPolilinea: puntosPolilineaVial,
              ),
            ),

            // 2. BOTÓN DE REGRESO ARRIBA A LA IZQUIERDA
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: FloatingActionButton.small(
                heroTag: 'btn_back',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4,
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),

            // 3. 🚗 PÍLDORA ÚNICA DE MÉTRICAS EN LA ESQUINA SUPERIOR DERECHA
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: InkWell(
                onTap: _mostrarResumenMetricas,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${distanciaCalculadaKm.toStringAsFixed(1)} km · $tiempoCalculadoMinutos min',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. 📱 PANEL DESLIZABLE INFERIOR (DRAGGABLE SHEET LAZKAR)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.40,
              minChildSize: 0.20,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.20, 0.40, 0.92],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 2)],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),

                      // 🔍 BUSCADOR BLANCO CON BOTÓN (+)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: TextField(
                          controller: _buscarController,
                          style: const TextStyle(color: Colors.black87, fontSize: 15),
                          onTap: () {
                            // Sube automáticamente el panel para que el teclado no tape
                            _sheetController.animateTo(0.92, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          },
                          decoration: InputDecoration(
                            hintText: 'Añadir/Buscar paradas',
                            hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.black54),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (buscandoSugerencias)
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2962FF), size: 24),
                                  onPressed: _mostrarMenuAgregarParada,
                                ),
                              ],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (texto) async {
                            if (texto.trim().length >= 3) {
                              setState(() => buscandoSugerencias = true);
                              final items = await _placesService.buscarLugares(texto);
                              if (mounted) setState(() { sugerencias = items; buscandoSugerencias = false; });
                            } else {
                              if (sugerencias.isNotEmpty) setState(() => sugerencias = []);
                            }
                          },
                        ),
                      ),

                      if (sugerencias.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: sugerencias.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final s = sugerencias[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on, color: Color(0xFF2962FF), size: 20),
                                title: Text(s.descripcion, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                onTap: () async {
                                  setState(() { sugerencias = []; buscandoSugerencias = true; });
                                  final det = await _placesService.obtenerDetalles(s.placeId);
                                  if (det != null) {
                                    _buscarController.clear();
                                    await _mostrarDialogoConfirmarParada(
                                      direccion: det.nombre,
                                      lat: det.latitud,
                                      lng: det.longitud,
                                      placeId: det.placeId,
                                    );
                                  }
                                  if (mounted) setState(() => buscandoSugerencias = false);
                                },
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 14),

                      // ✏️ CABECERA CON LÁPIZ DE EDICIÓN FUNCIONAL
                      InkWell(
                        onTap: _cambiarNombreRuta,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Detalles de la ruta', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const Icon(Icons.edit_outlined, color: Color(0xFF2962FF), size: 18),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(nombreRuta, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text('Hoy', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      ruta?.inicioDireccion ?? 'Mi ubicación GPS',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 🔘 BOTONES [ Refinar / Optimizar ] [ Navegar 🧭 ]
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFF2962FF)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: optimizando ? null : _optimizarRuta,
                              child: optimizando
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Refinar / Optimizar', style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 6,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2962FF),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: paradasPendientes.isNotEmpty ? () => _iniciarNavegacion(paradasPendientes.first) : null,
                              icon: const Icon(Icons.navigation, color: Colors.white, size: 18),
                              label: const Text('Navegar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 28),

                      // 🔀 SELECTOR DE PESTAÑAS PENDIENTES VS ENTREGADOS
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF1F3F4), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => tabSeleccionado = 0),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: tabSeleccionado == 0 ? const Color(0xFF2962FF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Pendientes (${paradasPendientes.length})',
                                      style: TextStyle(
                                        color: tabSeleccionado == 0 ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => tabSeleccionado = 1),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: tabSeleccionado == 1 ? const Color(0xFF00C853) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Hecho ($hechas)',
                                      style: TextStyle(
                                        color: tabSeleccionado == 1 ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 📋 LISTA DE PARADAS
                      if (listaMostrada.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              tabSeleccionado == 0 ? 'No hay paradas pendientes.' : 'No hay entregas completadas.',
                              style: const TextStyle(color: Colors.black45),
                            ),
                          ),
                        )
                      else
                        ...List.generate(listaMostrada.length, (index) {
                          final p = listaMostrada[index];
                          final numeroEnRuta = p.orden > 0 ? p.orden : (index + 1);
                          final esEntregado = p.estado == 'entregado';
                          final esAusente = p.estado == 'ausente';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: esEntregado
                                          ? const Color(0xFF00C853)
                                          : (esAusente ? const Color(0xFFD50000) : const Color(0xFF2962FF)),
                                      child: Text(
                                        esEntregado ? '✓$numeroEnRuta' : '$numeroEnRuta',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        p.direccion,
                                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _eliminarParada(p),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // ✏️ CAJA DE NOTAS TOCABLE
                                InkWell(
                                  onTap: () => _mostrarDialogoEditarParada(p),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECEFF1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.notas ?? 'Toca para agregar/editar nota...',
                                            style: TextStyle(
                                              color: p.notas != null ? Colors.black87 : Colors.black38,
                                              fontSize: 13,
                                              fontWeight: p.notas != null ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text('ID $numeroEnRuta', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (p.telefono != null)
                                      Text('📞 ${p.telefono}', style: const TextStyle(color: Colors.black54, fontSize: 12))
                                    else
                                      const Text('Sin teléfono', style: TextStyle(color: Colors.black38, fontSize: 11)),
                                    if (tabSeleccionado == 0)
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                            tooltip: 'Ausente',
                                            onPressed: () => _cambiarEstado(p, 'ausente'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.check, color: Colors.green, size: 20),
                                            tooltip: 'Entregado',
                                            onPressed: () => _cambiarEstado(p, 'entregado'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.navigation, color: Color(0xFF2962FF), size: 20),
                                            tooltip: 'Navegar',
                                            onPressed: () => _iniciarNavegacion(p),
                                          ),
                                        ],
                                      )
                                    else
                                      TextButton(
                                        onPressed: () => _cambiarEstado(p, 'pendiente'),
                                        child: const Text('Deshacer', style: TextStyle(color: Color(0xFF2962FF))),
                                      ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}