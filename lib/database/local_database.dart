import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/parada.dart';

/// Resumen de una ruta guardada, para mostrar en la lista de
/// "Mis rutas" sin tener que cargar todas sus paradas.
class RutaGuardada {
  final int id;
  final String nombre;
  final DateTime fecha;
  final int cantidadParadas;
  final double duracionSegundos;

  RutaGuardada({
    required this.id,
    required this.nombre,
    required this.fecha,
    required this.cantidadParadas,
    required this.duracionSegundos,
  });

  int get duracionMinutos => (duracionSegundos / 60).round();
}

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._internal();

  static Database? _database;

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'ruta_facil.db',
    );

    return openDatabase(
      path,
      version: 2,
      onCreate: _crearBaseDatos,
      onUpgrade: _actualizarBaseDatos,
    );
  }

  Future<void> _crearBaseDatos(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE ubicaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        placeId TEXT,
        fechaCreacion TEXT NOT NULL
      )
    ''');

    await _crearTablasDeRutas(db);
  }

  Future<void> _actualizarBaseDatos(
    Database db,
    int versionAnterior,
    int versionNueva,
  ) async {
    if (versionAnterior < 2) {
      await _crearTablasDeRutas(db);
    }
  }

  Future<void> _crearTablasDeRutas(Database db) async {
    await db.execute('''
      CREATE TABLE rutas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        fecha TEXT NOT NULL,
        duracionSegundos REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ruta_paradas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rutaId INTEGER NOT NULL,
        orden INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        placeId TEXT,
        FOREIGN KEY (rutaId) REFERENCES rutas (id)
          ON DELETE CASCADE
      )
    ''');
  }

  // ============================================================
  // UBICACIONES (direcciones ya buscadas, para no repetir
  // llamadas a Google Places)
  // ============================================================

  Future<int> guardarUbicacion(Parada parada) async {
    final db = await database;

    // Si ya existe el mismo Place ID,
    // actualizamos sus datos en vez de crear un duplicado.
    if (parada.placeId != null &&
        parada.placeId!.isNotEmpty) {
      final existente = await buscarUbicacionPorPlaceId(
        parada.placeId!,
      );

      if (existente != null) {
        final ids = await db.update(
          'ubicaciones',
          {
            'nombre': parada.nombre,
            'latitud': parada.latitud,
            'longitud': parada.longitud,
          },
          where: 'placeId = ?',
          whereArgs: [parada.placeId],
        );

        return ids;
      }
    }

    return db.insert(
      'ubicaciones',
      {
        'nombre': parada.nombre,
        'latitud': parada.latitud,
        'longitud': parada.longitud,
        'placeId': parada.placeId,
        'fechaCreacion':
            DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Parada>> obtenerUbicaciones() async {
    final db = await database;

    final resultados = await db.query(
      'ubicaciones',
      orderBy: 'id DESC',
    );

    return resultados.map((map) {
      return Parada(
        nombre: map['nombre'] as String,
        latitud: (map['latitud'] as num).toDouble(),
        longitud: (map['longitud'] as num).toDouble(),
        placeId: map['placeId'] as String?,
      );
    }).toList();
  }

  Future<Parada?> buscarUbicacionPorPlaceId(
    String placeId,
  ) async {
    final db = await database;

    final resultados = await db.query(
      'ubicaciones',
      where: 'placeId = ?',
      whereArgs: [placeId],
      limit: 1,
    );

    if (resultados.isEmpty) {
      return null;
    }

    final map = resultados.first;

    return Parada(
      nombre: map['nombre'] as String,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      placeId: map['placeId'] as String?,
    );
  }

  Future<void> eliminarUbicacion(int id) async {
    final db = await database;

    await db.delete(
      'ubicaciones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // RUTAS (historial de rutas ya optimizadas)
  // ============================================================

  /// Guarda una ruta completa (ya optimizada) con el orden final
  /// de sus paradas, para poder consultarla después.
  Future<int> guardarRuta({
    required List<Parada> paradas,
    required double duracionSegundos,
    String? nombre,
  }) async {
    final db = await database;

    final fecha = DateTime.now();

    final nombreFinal = nombre ??
        'Ruta del ${fecha.day}/${fecha.month}/${fecha.year} '
            '${fecha.hour.toString().padLeft(2, '0')}:'
            '${fecha.minute.toString().padLeft(2, '0')}';

    final rutaId = await db.insert('rutas', {
      'nombre': nombreFinal,
      'fecha': fecha.toIso8601String(),
      'duracionSegundos': duracionSegundos,
    });

    final batch = db.batch();

    for (var i = 0; i < paradas.length; i++) {
      final parada = paradas[i];

      batch.insert('ruta_paradas', {
        'rutaId': rutaId,
        'orden': i,
        'nombre': parada.nombre,
        'latitud': parada.latitud,
        'longitud': parada.longitud,
        'placeId': parada.placeId,
      });
    }

    await batch.commit(noResult: true);

    return rutaId;
  }

  /// Devuelve el resumen de todas las rutas guardadas,
  /// de la más reciente a la más antigua.
  Future<List<RutaGuardada>> obtenerRutas() async {
    final db = await database;

    final resultados = await db.rawQuery('''
      SELECT
        rutas.id AS id,
        rutas.nombre AS nombre,
        rutas.fecha AS fecha,
        rutas.duracionSegundos AS duracionSegundos,
        COUNT(ruta_paradas.id) AS cantidadParadas
      FROM rutas
      LEFT JOIN ruta_paradas
        ON ruta_paradas.rutaId = rutas.id
      GROUP BY rutas.id
      ORDER BY rutas.fecha DESC
    ''');

    return resultados.map((map) {
      return RutaGuardada(
        id: map['id'] as int,
        nombre: map['nombre'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        cantidadParadas: (map['cantidadParadas'] as int?) ?? 0,
        duracionSegundos:
            (map['duracionSegundos'] as num).toDouble(),
      );
    }).toList();
  }

  /// Devuelve las paradas de una ruta guardada, en su orden
  /// original.
  Future<List<Parada>> obtenerParadasDeRuta(int rutaId) async {
    final db = await database;

    final resultados = await db.query(
      'ruta_paradas',
      where: 'rutaId = ?',
      whereArgs: [rutaId],
      orderBy: 'orden ASC',
    );

    return resultados.map((map) {
      return Parada(
        nombre: map['nombre'] as String,
        latitud: (map['latitud'] as num).toDouble(),
        longitud: (map['longitud'] as num).toDouble(),
        placeId: map['placeId'] as String?,
      );
    }).toList();
  }

  Future<void> eliminarRuta(int rutaId) async {
    final db = await database;

    await db.delete(
      'ruta_paradas',
      where: 'rutaId = ?',
      whereArgs: [rutaId],
    );

    await db.delete(
      'rutas',
      where: 'id = ?',
      whereArgs: [rutaId],
    );
  }

  // ============================================================
  // CERRAR BASE DE DATOS
  // ============================================================

  Future<void> cerrar() async {
    final db = await database;

    await db.close();

    _database = null;
  }
}