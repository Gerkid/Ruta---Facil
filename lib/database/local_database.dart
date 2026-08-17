import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/parada.dart';

class RutaModel {
  final int id;
  final String nombre;
  final DateTime fecha;
  final int cantidadParadas;
  final int entregadas;
  final double duracionSegundos;
  final double distanciaMetros;
  final double? inicioLat;
  final double? inicioLng;
  final String? inicioDireccion;
  final double? finLat;
  final double? finLng;
  final String? finDireccion;
  final String? polilineaCoords;

  RutaModel({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.cantidadParadas = 0,
    this.entregadas = 0,
    this.duracionSegundos = 0.0,
    this.distanciaMetros = 0.0,
    this.inicioLat,
    this.inicioLng,
    this.inicioDireccion,
    this.finLat,
    this.finLng,
    this.finDireccion,
    this.polilineaCoords,
  });

  int get duracionMinutos => (duracionSegundos / 60).round();
  double get distanciaKm => (distanciaMetros / 1000);
}

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._internal();
  static Database? _database;

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'ruta_facil_master_v6.db');

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE rutas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            fecha TEXT NOT NULL,
            duracionSegundos REAL DEFAULT 0,
            distanciaMetros REAL DEFAULT 0,
            inicioLat REAL,
            inicioLng REAL,
            inicioDireccion TEXT,
            finLat REAL,
            finLng REAL,
            finDireccion TEXT,
            polilineaCoords TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE ruta_paradas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rutaId INTEGER NOT NULL,
            orden INTEGER NOT NULL,
            direccion TEXT NOT NULL,
            latitud REAL NOT NULL,
            longitud REAL NOT NULL,
            estado TEXT NOT NULL DEFAULT 'pendiente',
            destinatario TEXT,
            telefono TEXT,
            tracking_number TEXT,
            notas TEXT,
            place_id TEXT,
            fecha_entrega TEXT,
            FOREIGN KEY (rutaId) REFERENCES rutas (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE ubicaciones_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            latitud REAL NOT NULL,
            longitud REAL NOT NULL,
            placeId TEXT
          )
        ''');
      },
    );

    await _migrarBasesDeDatosAntiguas(db);
    return db;
  }

  Future<void> _migrarBasesDeDatosAntiguas(Database dbNueva) async {
    final databasePath = await getDatabasesPath();
    final nombresViejos = ['ruta_facil_v5.db', 'ruta_facil_master.db', 'ruta_facil_v4.db', 'ruta_facil_v3.db'];

    for (final nombreViejo in nombresViejos) {
      final pathViejo = join(databasePath, nombreViejo);
      final archivoViejo = File(pathViejo);
      if (await archivoViejo.exists()) {
        try {
          final dbVieja = await openDatabase(pathViejo);
          final rutasViejas = await dbVieja.query('rutas');

          for (final r in rutasViejas) {
            final nombreRuta = r['nombre'] as String? ?? 'Ruta';
            final fechaRuta = r['fecha'] as String? ?? DateTime.now().toIso8601String();
            final idViejo = r['id'] as int;

            final existe = await dbNueva.query('rutas', where: 'nombre = ?', whereArgs: [nombreRuta]);
            if (existe.isEmpty) {
              final nuevoId = await dbNueva.insert('rutas', {
                'nombre': nombreRuta,
                'fecha': fechaRuta,
                'duracionSegundos': (r['duracionSegundos'] as num?)?.toDouble() ?? 0.0,
                'distanciaMetros': (r['distanciaMetros'] as num?)?.toDouble() ?? 0.0,
                'inicioLat': (r['inicioLat'] as num?)?.toDouble(),
                'inicioLng': (r['inicioLng'] as num?)?.toDouble(),
                'inicioDireccion': r['inicioDireccion'] as String?,
                'finLat': (r['finLat'] as num?)?.toDouble(),
                'finLng': (r['finLng'] as num?)?.toDouble(),
                'finDireccion': r['finDireccion'] as String?,
                'polilineaCoords': r['polilineaCoords'] as String?,
              });

              final paradasViejas = await dbVieja.query('ruta_paradas', where: 'rutaId = ?', whereArgs: [idViejo]);
              for (final p in paradasViejas) {
                await dbNueva.insert('ruta_paradas', {
                  'rutaId': nuevoId,
                  'orden': p['orden'] as int? ?? 1,
                  'direccion': p['direccion'] as String? ?? p['nombre'] as String? ?? '',
                  'latitud': (p['latitud'] as num).toDouble(),
                  'longitud': (p['longitud'] as num).toDouble(),
                  'estado': p['estado'] as String? ?? 'pendiente',
                  'destinatario': p['destinatario'] as String?,
                  'telefono': p['telefono'] as String?,
                  'tracking_number': p['tracking_number'] as String?,
                  'notas': p['notas'] as String?,
                  'place_id': p['place_id'] as String?,
                  'fecha_entrega': p['fecha_entrega'] as String?,
                });
              }
            }
          }
          await dbVieja.close();
        } catch (e) {
          debugPrint('Migración: $e');
        }
      }
    }
  }

  Future<int> guardarUbicacion(Parada parada) async {
    final db = await database;
    return await db.insert('ubicaciones_cache', {
      'nombre': parada.direccion,
      'latitud': parada.latitud,
      'longitud': parada.longitud,
      'placeId': parada.placeId,
    });
  }

  Future<Parada?> buscarUbicacionPorPlaceId(String placeId) async {
    final db = await database;
    final resultados = await db.query('ubicaciones_cache', where: 'placeId = ?', whereArgs: [placeId], limit: 1);
    if (resultados.isEmpty) return null;
    final map = resultados.first;
    return Parada(
      direccion: map['nombre'] as String,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      placeId: map['placeId'] as String?,
    );
  }

  Future<int> crearRuta({
    required String nombre,
    DateTime? fecha,
    double? inicioLat,
    double? inicioLng,
    String? inicioDireccion,
    double? finLat,
    double? finLng,
    String? finDireccion,
  }) async {
    final db = await database;
    final f = fecha ?? DateTime.now();
    return await db.insert('rutas', {
      'nombre': nombre.isNotEmpty ? nombre : 'TEMU',
      'fecha': f.toIso8601String(),
      'duracionSegundos': 0.0,
      'distanciaMetros': 0.0,
      'inicioLat': inicioLat,
      'inicioLng': inicioLng,
      'inicioDireccion': inicioDireccion,
      'finLat': finLat,
      'finLng': finLng,
      'finDireccion': finDireccion,
    });
  }

  Future<void> actualizarNombreRuta(int rutaId, String nuevoNombre) async {
    final db = await database;
    await db.update('rutas', {'nombre': nuevoNombre}, where: 'id = ?', whereArgs: [rutaId]);
  }

  Future<void> actualizarMetricasYPoliLinea(
    int rutaId, {
    required double duracionSegundos,
    required double distanciaMetros,
    required String polilineaCoords,
  }) async {
    final db = await database;
    await db.update(
      'rutas',
      {
        'duracionSegundos': duracionSegundos,
        'distanciaMetros': distanciaMetros,
        'polilineaCoords': polilineaCoords,
      },
      where: 'id = ?',
      whereArgs: [rutaId],
    );
  }

  Future<void> actualizarDetallesParada({
    required int paradaId,
    required String direccion,
    String? notas,
    String? telefono,
  }) async {
    final db = await database;
    await db.update(
      'ruta_paradas',
      {
        'direccion': direccion,
        'notas': notas,
        'telefono': telefono,
      },
      where: 'id = ?',
      whereArgs: [paradaId],
    );
  }

  Future<List<RutaModel>> obtenerRutas() async {
    final db = await database;
    final resultados = await db.rawQuery('''
      SELECT
        rutas.id AS id,
        rutas.nombre AS nombre,
        rutas.fecha AS fecha,
        rutas.duracionSegundos AS duracionSegundos,
        rutas.distanciaMetros AS distanciaMetros,
        rutas.inicioLat AS inicioLat,
        rutas.inicioLng AS inicioLng,
        rutas.inicioDireccion AS inicioDireccion,
        rutas.finLat AS finLat,
        rutas.finLng AS finLng,
        rutas.finDireccion AS finDireccion,
        rutas.polilineaCoords AS polilineaCoords,
        COUNT(ruta_paradas.id) AS cantidadParadas,
        SUM(CASE WHEN ruta_paradas.estado = 'entregado' THEN 1 ELSE 0 END) AS entregadas
      FROM rutas
      LEFT JOIN ruta_paradas ON ruta_paradas.rutaId = rutas.id
      GROUP BY rutas.id
      ORDER BY rutas.id DESC
    ''');

    return resultados.map((map) {
      return RutaModel(
        id: map['id'] as int,
        nombre: map['nombre'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        cantidadParadas: (map['cantidadParadas'] as int?) ?? 0,
        entregadas: (map['entregadas'] as int?) ?? 0,
        duracionSegundos: (map['duracionSegundos'] as num).toDouble(),
        distanciaMetros: ((map['distanciaMetros'] as num?) ?? 0.0).toDouble(),
        inicioLat: (map['inicioLat'] as num?)?.toDouble(),
        inicioLng: (map['inicioLng'] as num?)?.toDouble(),
        inicioDireccion: map['inicioDireccion'] as String?,
        finLat: (map['finLat'] as num?)?.toDouble(),
        finLng: (map['finLng'] as num?)?.toDouble(),
        finDireccion: map['finDireccion'] as String?,
        polilineaCoords: map['polilineaCoords'] as String?,
      );
    }).toList();
  }

  Future<RutaModel?> obtenerRutaPorId(int rutaId) async {
    final db = await database;
    final resultados = await db.query('rutas', where: 'id = ?', whereArgs: [rutaId], limit: 1);
    if (resultados.isEmpty) return null;
    final map = resultados.first;
    return RutaModel(
      id: map['id'] as int,
      nombre: map['nombre'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      duracionSegundos: (map['duracionSegundos'] as num).toDouble(),
      distanciaMetros: ((map['distanciaMetros'] as num?) ?? 0.0).toDouble(),
      inicioLat: (map['inicioLat'] as num?)?.toDouble(),
      inicioLng: (map['inicioLng'] as num?)?.toDouble(),
      inicioDireccion: map['inicioDireccion'] as String?,
      finLat: (map['finLat'] as num?)?.toDouble(),
      finLng: (map['finLng'] as num?)?.toDouble(),
      finDireccion: map['finDireccion'] as String?,
      polilineaCoords: map['polilineaCoords'] as String?,
    );
  }

  Future<void> eliminarRuta(int rutaId) async {
    final db = await database;
    await db.delete('ruta_paradas', where: 'rutaId = ?', whereArgs: [rutaId]);
    await db.delete('rutas', where: 'id = ?', whereArgs: [rutaId]);
  }

  Future<int> agregarParadaARuta(int rutaId, Parada parada) async {
    final db = await database;
    final paradasExistentes = await obtenerParadasDeRuta(rutaId);
    final nuevoOrden = paradasExistentes.length + 1;

    return await db.insert('ruta_paradas', {
      'rutaId': rutaId,
      'orden': nuevoOrden,
      'direccion': parada.direccion,
      'latitud': parada.latitud,
      'longitud': parada.longitud,
      'estado': parada.estado,
      'destinatario': parada.destinatario,
      'telefono': parada.telefono,
      'tracking_number': parada.trackingNumber,
      'notas': parada.notas,
      'place_id': parada.placeId,
    });
  }

  Future<List<Parada>> obtenerParadasDeRuta(int rutaId) async {
    final db = await database;
    final resultados = await db.query(
      'ruta_paradas',
      where: 'rutaId = ?',
      whereArgs: [rutaId],
      orderBy: 'orden ASC',
    );
    return resultados.map((map) => Parada.fromMap(map)).toList();
  }

  Future<void> actualizarEstadoParada(int paradaId, String nuevoEstado) async {
    final db = await database;
    await db.update(
      'ruta_paradas',
      {
        'estado': nuevoEstado,
        'fecha_entrega': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [paradaId],
    );
  }

  Future<void> actualizarOrdenParadas(int rutaId, List<Parada> paradas) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < paradas.length; i++) {
      final p = paradas[i];
      if (p.id != null) {
        batch.update(
          'ruta_paradas',
          {'orden': i + 1},
          where: 'id = ? AND rutaId = ?',
          whereArgs: [p.id, rutaId],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> eliminarParada(int paradaId) async {
    final db = await database;
    await db.delete('ruta_paradas', where: 'id = ?', whereArgs: [paradaId]);
  }
}