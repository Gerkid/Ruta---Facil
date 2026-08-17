import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/local_database.dart';
import '../models/parada.dart';

// 🚀 DISPARADOR EN SEGUNDO PLANO BLINDADO CON INICIALIZACIÓN DE BINDINGS
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (response.actionId == null || response.payload == null) return;

  try {
    final Map<String, dynamic> data = jsonDecode(response.payload!);
    final int paradaId = data['paradaId'] ?? 0;
    final int rutaId = data['rutaId'] ?? 0;
    final db = LocalDatabase.instance;

    if (response.actionId == 'accion_entregado') {
      await db.actualizarEstadoParada(paradaId, 'entregado');
      await NotificationService.instance.actualizarSiguienteParada(rutaId);
    } else if (response.actionId == 'accion_ausente') {
      await db.actualizarEstadoParada(paradaId, 'ausente');
      await NotificationService.instance.actualizarSiguienteParada(rutaId);
    } else if (response.actionId == 'accion_siguiente') {
      await NotificationService.instance.navegarASiguiente(rutaId);
    }
  } catch (e) {
    debugPrint('Error en background action: $e');
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> inicializar({Function(String actionId, int paradaId)? onAccion}) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId != null && response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            final paradaId = data['paradaId'] ?? 0;
            final rutaId = data['rutaId'] ?? 0;

            if (response.actionId == 'accion_entregado') {
              await LocalDatabase.instance.actualizarEstadoParada(paradaId, 'entregado');
              await actualizarSiguienteParada(rutaId);
            } else if (response.actionId == 'accion_ausente') {
              await LocalDatabase.instance.actualizarEstadoParada(paradaId, 'ausente');
              await actualizarSiguienteParada(rutaId);
            } else if (response.actionId == 'accion_siguiente') {
              await navegarASiguiente(rutaId);
            }

            if (onAccion != null) onAccion(response.actionId!, paradaId);
          } catch (_) {}
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> mostrarNotificacionDespacho({
    required Parada parada,
    required int totalParadas,
    required int rutaId,
  }) async {
    final numero = parada.orden > 0 ? parada.orden : 1;
    final notaTexto = parada.notas != null ? '📝 ${parada.notas}' : 'Sin notas';
    final telTexto = parada.telefono != null ? ' · 📞 ${parada.telefono}' : '';

    final payloadStr = jsonEncode({
      'paradaId': parada.id ?? 0,
      'rutaId': rutaId,
      'lat': parada.latitud,
      'lng': parada.longitud,
    });

    final androidDetails = AndroidNotificationDetails(
      'despacho_ruta_facil_live',
      'Despacho en Ruta (Now Bar)',
      channelDescription: 'Controles de entrega en barra de estado y Samsung Now Bar',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.navigation,
      visibility: NotificationVisibility.public,
      color: const Color(0xFF00E676),
      colorized: true,
      ongoing: true,
      autoCancel: false,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accion_entregado',
          '✅ Entregado',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'accion_ausente',
          '❌ Ausente',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'accion_siguiente',
          '⏭️ Siguiente',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );

    await _notificationsPlugin.show(
      888,
      '📦 Parada #$numero de $totalParadas: ${parada.direccion}',
      '$notaTexto$telTexto',
      NotificationDetails(android: androidDetails),
      payload: payloadStr,
    );
  }

  Future<void> actualizarSiguienteParada(int rutaId) async {
    final paradas = await LocalDatabase.instance.obtenerParadasDeRuta(rutaId);
    final pendientes = paradas.where((p) => p.estado == 'pendiente').toList();

    if (pendientes.isNotEmpty) {
      final siguiente = pendientes.first;
      await mostrarNotificacionDespacho(parada: siguiente, totalParadas: paradas.length, rutaId: rutaId);

      // Salta a la siguiente parada directamente en Google Maps
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${siguiente.latitud},${siguiente.longitud}&travelmode=driving',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await cancelarNotificacion();
    }
  }

  Future<void> navegarASiguiente(int rutaId) async {
    final paradas = await LocalDatabase.instance.obtenerParadasDeRuta(rutaId);
    final pendientes = paradas.where((p) => p.estado == 'pendiente').toList();
    if (pendientes.isNotEmpty) {
      final siguiente = pendientes.first;
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${siguiente.latitud},${siguiente.longitud}&travelmode=driving',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> cancelarNotificacion() async {
    await _notificationsPlugin.cancel(888);
  }
}