import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../entity/operacion_offline.dart';
import '../entity/pedido.dart';

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
    final path = join(dbPath, 'reparto_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pedidos_local (
            id TEXT PRIMARY KEY,
            rev TEXT,
            cliente TEXT NOT NULL,
            direccion TEXT NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            total REAL NOT NULL,
            estado TEXT NOT NULL,
            repartidor_id TEXT,
            creado_en TEXT,
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
      },
    );
  }

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

  Future<List<Pedido>> obtenerPedidos({String? repartidorId}) async {
    final db = await database;
    final maps = repartidorId != null
        ? await db.query(
            'pedidos_local',
            where: 'repartidor_id = ?',
            whereArgs: [repartidorId],
          )
        : await db.query('pedidos_local');
    return maps.map((m) => Pedido.fromMap(m)).toList();
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

  Future<void> incrementarIntento(String opId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE cola_operaciones SET intentos = intentos + 1 WHERE op_id = ?',
      [opId],
    );
  }
}