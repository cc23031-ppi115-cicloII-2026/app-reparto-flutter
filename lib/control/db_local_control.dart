import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../entity/operacion_offline.dart';
import '../entity/pedido.dart';
import '../entity/sesion_usuario.dart';

class DbLocalControl {
  static final DbLocalControl _instance = DbLocalControl._internal();
  factory DbLocalControl() => _instance;
  DbLocalControl._internal();

  Database? _db;

  // Almacenamiento fallback en memoria para compilación Web (kIsWeb)
  final Map<String, Pedido> _webPedidos = {};
  final Map<String, OperacionOffline> _webCola = {};
  SesionUsuario? _webSesionActiva;
  final Map<String, Map<String, dynamic>> _webUsuariosCache = {};

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'swoosh_offline.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pedidos_local (
            id TEXT PRIMARY KEY,
            rev TEXT,
            cliente TEXT NOT NULL,
            titulo_parada TEXT,
            direccion TEXT NOT NULL,
            referencia_visual TEXT,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            total REAL NOT NULL,
            subtotal_productos REAL,
            costo_envio REAL DEFAULT 0.0,
            metodo_pago TEXT DEFAULT 'efectivo',
            paga_con REAL,
            orden_en_ruta INTEGER,
            estado TEXT NOT NULL,
            repartidor_id TEXT,
            creado_en TEXT,
            inicio_ruta_en TEXT,
            entregado_en TEXT,
            sincronizado INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE cola_operaciones (
            op_id TEXT PRIMARY KEY,
            pedido_id TEXT NOT NULL,
            tipo_operacion TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            creado_en_ms INTEGER NOT NULL,
            intentos INTEGER NOT NULL DEFAULT 0,
            estado_sync TEXT NOT NULL DEFAULT 'PENDIENTE'
          )
        ''');

        await _crearTablasAuth(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final nuevasColumnas = [
            'ALTER TABLE pedidos_local ADD COLUMN titulo_parada TEXT',
            'ALTER TABLE pedidos_local ADD COLUMN referencia_visual TEXT',
            'ALTER TABLE pedidos_local ADD COLUMN subtotal_productos REAL',
            'ALTER TABLE pedidos_local ADD COLUMN costo_envio REAL DEFAULT 0.0',
            "ALTER TABLE pedidos_local ADD COLUMN metodo_pago TEXT DEFAULT 'efectivo'",
            'ALTER TABLE pedidos_local ADD COLUMN paga_con REAL',
            'ALTER TABLE pedidos_local ADD COLUMN orden_en_ruta INTEGER',
            'ALTER TABLE pedidos_local ADD COLUMN inicio_ruta_en TEXT',
          ];
          for (final sql in nuevasColumnas) {
            try {
              await db.execute(sql);
            } catch (_) {}
          }
        }
        if (oldVersion < 3) {
          await _crearTablasAuth(db);
        }
      },
    );
  }

  Future<void> _crearTablasAuth(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sesion_activa (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        usuario TEXT NOT NULL,
        rol TEXT NOT NULL,
        nombre TEXT NOT NULL,
        repartidor_id TEXT,
        negocio_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios_cache (
        usuario TEXT PRIMARY KEY,
        password TEXT NOT NULL,
        rol TEXT NOT NULL,
        nombre TEXT NOT NULL,
        repartidor_id TEXT,
        negocio_id TEXT
      )
    ''');
  }

  // --- Operaciones de Sesión y Caché Offline de Usuarios ---

  Future<void> guardarSesionActiva(SesionUsuario sesion, {String? password}) async {
    if (kIsWeb) {
      _webSesionActiva = sesion;
      if (password != null && password.isNotEmpty) {
        _webUsuariosCache[sesion.usuario.toLowerCase()] = {
          ...sesion.toJson(),
          'password': password,
        };
      }
      return;
    }

    final db = await database;
    await db.insert(
      'sesion_activa',
      {
        'id': 1,
        'usuario': sesion.usuario,
        'rol': sesion.rol,
        'nombre': sesion.nombre,
        'repartidor_id': sesion.repartidorId,
        'negocio_id': sesion.negocioId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (password != null && password.isNotEmpty) {
      await db.insert(
        'usuarios_cache',
        {
          'usuario': sesion.usuario.toLowerCase(),
          'password': password,
          'rol': sesion.rol,
          'nombre': sesion.nombre,
          'repartidor_id': sesion.repartidorId,
          'negocio_id': sesion.negocioId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<SesionUsuario?> obtenerSesionActiva() async {
    if (kIsWeb) return _webSesionActiva;

    final db = await database;
    final maps = await db.query('sesion_activa', where: 'id = 1', limit: 1);
    if (maps.isEmpty) return null;
    return SesionUsuario.fromJson(maps.first);
  }

  Future<SesionUsuario?> autenticarOfflineCache(String usuario, String password) async {
    final key = usuario.trim().toLowerCase();
    if (kIsWeb) {
      final cached = _webUsuariosCache[key];
      if (cached != null && cached['password'] == password) {
        final sesion = SesionUsuario.fromJson(cached);
        _webSesionActiva = sesion;
        return sesion;
      }
      return null;
    }

    final db = await database;
    final maps = await db.query(
      'usuarios_cache',
      where: 'usuario = ? AND password = ?',
      whereArgs: [key, password],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final sesion = SesionUsuario.fromJson(maps.first);
    await guardarSesionActiva(sesion);
    return sesion;
  }

  Future<void> cerrarSesionLocal() async {
    if (kIsWeb) {
      _webSesionActiva = null;
      return;
    }

    final db = await database;
    await db.delete('sesion_activa');
  }

  // --- Operaciones sobre pedidos_local ---

  Future<void> guardarPedidos(List<Pedido> pedidos) async {
    if (kIsWeb) {
      for (final p in pedidos) {
        _webPedidos[p.id] = p;
      }
      return;
    }

    final db = await database;
    final batch = db.batch();
    for (final p in pedidos) {
      batch.insert(
        'pedidos_local',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> guardarPedido(Pedido pedido) async {
    if (kIsWeb) {
      _webPedidos[pedido.id] = pedido;
      return;
    }

    final db = await database;
    await db.insert(
      'pedidos_local',
      pedido.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Pedido>> obtenerPedidos({String? repartidorId}) async {
    if (kIsWeb) {
      final lista = _webPedidos.values.toList();
      if (repartidorId == null || repartidorId.isEmpty) return lista;
      return lista.where((p) => p.repartidorId == repartidorId).toList();
    }

    final db = await database;
    final maps = (repartidorId != null && repartidorId.isNotEmpty)
        ? await db.query(
            'pedidos_local',
            where: 'repartidor_id = ?',
            whereArgs: [repartidorId],
          )
        : await db.query('pedidos_local');
    return maps.map((m) => Pedido.fromMap(m)).toList();
  }

  Future<Pedido?> obtenerPedidoPorId(String id) async {
    if (kIsWeb) {
      return _webPedidos[id];
    }

    final db = await database;
    final maps = await db.query(
      'pedidos_local',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Pedido.fromMap(maps.first);
  }

  Future<void> eliminarPedidoLocal(String id) async {
    if (kIsWeb) {
      _webPedidos.remove(id);
      return;
    }

    final db = await database;
    await db.delete('pedidos_local', where: 'id = ?', whereArgs: [id]);
  }

  // --- Operaciones sobre cola_operaciones ---

  Future<void> encolarOperacion(OperacionOffline op) async {
    if (kIsWeb) {
      _webCola[op.opId] = op;
      return;
    }

    final db = await database;
    await db.insert(
      'cola_operaciones',
      op.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OperacionOffline>> obtenerOperacionesPendientes() async {
    if (kIsWeb) {
      final pendientes = _webCola.values
          .where((op) => op.estadoSync == 'PENDIENTE')
          .toList()
        ..sort((a, b) => a.creadoEnMs.compareTo(b.creadoEnMs));
      return pendientes;
    }

    final db = await database;
    final maps = await db.query(
      'cola_operaciones',
      where: 'estado_sync = ?',
      whereArgs: ['PENDIENTE'],
      orderBy: 'creado_en_ms ASC',
    );
    return maps.map((m) => OperacionOffline.fromMap(m)).toList();
  }

  Future<Set<String>> obtenerPedidoIdsConPendientes() async {
    final ops = await obtenerOperacionesPendientes();
    return ops.map((op) => op.pedidoId).toSet();
  }

  Future<int> contarPendientes() async {
    if (kIsWeb) {
      return _webCola.values.where((op) => op.estadoSync == 'PENDIENTE').length;
    }

    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as total FROM cola_operaciones WHERE estado_sync = 'PENDIENTE'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> marcarOperacionEstado(String opId, String estadoSync) async {
    if (kIsWeb) {
      final actual = _webCola[opId];
      if (actual != null) {
        _webCola[opId] = actual.copyWith(estadoSync: estadoSync);
      }
      return;
    }

    final db = await database;
    await db.update(
      'cola_operaciones',
      {'estado_sync': estadoSync},
      where: 'op_id = ?',
      whereArgs: [opId],
    );
  }

  Future<void> incrementarIntento(String opId) async {
    if (kIsWeb) {
      final actual = _webCola[opId];
      if (actual != null) {
        _webCola[opId] = actual.copyWith(intentos: actual.intentos + 1);
      }
      return;
    }

    final db = await database;
    await db.rawUpdate(
      'UPDATE cola_operaciones SET intentos = intentos + 1 WHERE op_id = ?',
      [opId],
    );
  }
}