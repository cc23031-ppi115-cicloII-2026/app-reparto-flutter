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
    final db = await database;
    final maps = await db.query('sesion_activa', where: 'id = 1', limit: 1);
    if (maps.isEmpty) return null;
    return SesionUsuario.fromJson(maps.first);
  }

  Future<SesionUsuario?> autenticarOfflineCache(String usuario, String password) async {
    final key = usuario.trim().toLowerCase();
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
    final db = await database;
    await db.delete('sesion_activa');
  }

  // --- Operaciones sobre pedidos_local ---

  Future<void> guardarPedidos(List<Pedido> pedidos) async {
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
    final db = await database;
    await db.insert(
      'pedidos_local',
      pedido.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> guardarPedidoYEncolarOperaciones(
    Pedido pedido,
    List<OperacionOffline> operaciones,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'pedidos_local',
        pedido.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final maximos = await txn.rawQuery(
        'SELECT MAX(creado_en_ms) AS ultimo FROM cola_operaciones',
      );
      final ultimo = (maximos.first['ultimo'] as num?)?.toInt();
      var creadoEnMs = DateTime.now().millisecondsSinceEpoch;
      if (ultimo != null && creadoEnMs <= ultimo) creadoEnMs = ultimo + 1;

      for (final operacion in operaciones) {
        final datos = operacion.toMap()..['creado_en_ms'] = creadoEnMs++;
        await txn.insert(
          'cola_operaciones',
          datos,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Pedido>> obtenerPedidos({String? repartidorId}) async {
    final db = await database;
    final maps = (repartidorId != null && repartidorId.isNotEmpty)
        ? await db.query(
            'pedidos_local',
            where: 'repartidor_id = ?',
            whereArgs: [repartidorId],
            orderBy: 'creado_en DESC',
          )
        : await db.query('pedidos_local', orderBy: 'creado_en DESC');
    return maps.map((m) => Pedido.fromMap(m)).toList();
  }

  Future<void> eliminarPedidosDePruebaConocidos() async {
    final db = await database;
    const demoPedido =
        '(cliente = ? AND direccion = ? AND total = ? AND lat = ? AND lng = ? '
        'AND repartidor_id = ? AND rev IS NULL)';
    final where = "id LIKE 'offline-%' OR id LIKE 'transicion-%' "
        'OR cliente = ? OR $demoPedido OR $demoPedido OR $demoPedido';
    final args = [
      'Pedido creado offline',
      'Comedor La Ceiba',
      'Av. Independencia Sur, Santa Ana',
      14.5,
      13.9942,
      -89.5597,
      'rep-1',
      'Tienda El Progreso',
      'Col. El Palmar, Santa Ana',
      22.0,
      13.9875,
      -89.564,
      'rep-1',
      'Pupusería Doña María',
      'Barrio San Juan, Santa Ana',
      9.75,
      13.999,
      -89.5521,
      'rep-1',
    ];
    final rows = await db.query(
      'pedidos_local',
      columns: ['id'],
      where: where,
      whereArgs: args,
    );
    if (rows.isEmpty) return;

    final ids = rows.map((row) => row['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.transaction((txn) async {
      await txn.delete(
        'cola_operaciones',
        where: 'pedido_id IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.delete(
        'pedidos_local',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    });
  }

  Future<Pedido?> obtenerPedidoPorId(String id) async {
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
    final db = await database;
    await db.delete('pedidos_local', where: 'id = ?', whereArgs: [id]);
  }

  // --- Operaciones sobre cola_operaciones ---

  Future<void> encolarOperacion(OperacionOffline op) async {
    final db = await database;
    await db.insert(
      'cola_operaciones',
      op.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OperacionOffline>> obtenerOperacionesPendientes() async {
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
    final db = await database;
    final maps = await db.query(
      'cola_operaciones',
      columns: ['pedido_id'],
      where: 'estado_sync IN (?, ?)',
      whereArgs: ['PENDIENTE', 'CONFLICTO'],
    );
    return maps.map((map) => map['pedido_id'] as String).toSet();
  }

  Future<int> contarPendientes() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as total FROM cola_operaciones WHERE estado_sync = 'PENDIENTE'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> marcarOperacionEstado(String opId, String estadoSync) async {
    final db = await database;
    await db.update(
      'cola_operaciones',
      {'estado_sync': estadoSync},
      where: 'op_id = ?',
      whereArgs: [opId],
    );
  }

  Future<void> marcarOperacionesPendientesDelPedidoComoConflicto(
    String pedidoId,
  ) async {
    final db = await database;
    await db.update(
      'cola_operaciones',
      {'estado_sync': 'CONFLICTO'},
      where: 'pedido_id = ? AND estado_sync = ?',
      whereArgs: [pedidoId, 'PENDIENTE'],
    );
  }

  Future<void> incrementarIntento(String opId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE cola_operaciones SET intentos = intentos + 1 WHERE op_id = ?',
      [opId],
    );
  }
}