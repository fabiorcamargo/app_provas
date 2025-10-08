import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class Usuario {
  int? id;
  String uuid;
  String nome;
  String email;
  String telefone;
  String role;
  bool sincronizado;

  Usuario({
    this.id,
    required this.uuid,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.role,
    this.sincronizado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'role': role,
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      uuid: map['uuid'],
      nome: map['nome'],
      email: map['email'],
      telefone: map['telefone'],
      role: map['role'],
      sincronizado: map['sincronizado'] == 1,
    );
  }
}

class Cliente {
  int? id;
  String uuid;
  String acaoUuid;
  String nome;
  String telefone1;
  String telefone2;
  bool sincronizado;
  String? usuarioUuid;

  Cliente({
    this.id,
    required this.uuid,
    required this.acaoUuid,
    required this.nome,
    required this.telefone1,
    required this.telefone2,
    this.sincronizado = false,
    this.usuarioUuid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'acaoUuid': acaoUuid,
      'nome': nome,
      'telefone1': telefone1,
      'telefone2': telefone2,
      'sincronizado': sincronizado ? 1 : 0,
      'usuarioUuid': usuarioUuid,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      uuid: map['uuid'],
      acaoUuid: map['acaoUuid'],
      nome: map['nome'],
      telefone1: map['telefone1'],
      telefone2: map['telefone2'],
      sincronizado: map['sincronizado'] == 1,
      usuarioUuid: map['usuarioUuid'],
    );
  }
}

class Cidade {
  int? id;
  String uuid;
  String nome;
  bool sincronizado;
  String? usuarioUuid;

  Cidade({
    this.id,
    required this.uuid,
    required this.nome,
    this.sincronizado = false,
    this.usuarioUuid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nome': nome,
      'sincronizado': sincronizado ? 1 : 0,
      'usuarioUuid': usuarioUuid,
    };
  }

  factory Cidade.fromMap(Map<String, dynamic> map) {
    return Cidade(
      id: map['id'],
      uuid: map['uuid'],
      nome: map['nome'],
      sincronizado: map['sincronizado'] == 1,
      usuarioUuid: map['usuarioUuid'],
    );
  }
}

class Acao {
  int? id;
  String uuid;
  String cidadeUuid;
  String descricao;
  DateTime data;
  bool sincronizado;
  String? usuarioUuid;

  Acao({
    this.id,
    required this.uuid,
    required this.cidadeUuid,
    required this.descricao,
    required this.data,
    this.sincronizado = false,
    this.usuarioUuid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'cidadeUuid': cidadeUuid,
      'descricao': descricao,
      'data': data.toIso8601String(),
      'sincronizado': sincronizado ? 1 : 0,
      'usuarioUuid': usuarioUuid,
    };
  }

  factory Acao.fromMap(Map<String, dynamic> map) {
    return Acao(
      id: map['id'],
      uuid: map['uuid'],
      cidadeUuid: map['cidadeUuid'],
      descricao: map['descricao'],
      data: DateTime.parse(map['data']),
      sincronizado: map['sincronizado'] == 1,
      usuarioUuid: map['usuarioUuid'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // No Web usamos apenas um nome de arquivo; no mobile usamos o caminho padrão
    final String dbFilePath;
    if (kIsWeb) {
      dbFilePath = 'cidades.db';
    } else {
      final dbPath = await getDatabasesPath();
      dbFilePath = join(dbPath, 'cidades.db');
    }
    return await openDatabase(
      dbFilePath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE acoes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cidadeId INTEGER NOT NULL,
          descricao TEXT NOT NULL,
          data TEXT NOT NULL,
          FOREIGN KEY (cidadeId) REFERENCES cidades(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE clientes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          acaoId INTEGER NOT NULL,
          nome TEXT NOT NULL,
          telefone1 TEXT,
          telefone2 TEXT,
          FOREIGN KEY (acaoId) REFERENCES acoes(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        nome TEXT NOT NULL,
        email TEXT NOT NULL,
        telefone TEXT,
        role TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE cidades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        nome TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        usuarioUuid TEXT,
        FOREIGN KEY (usuarioUuid) REFERENCES usuarios(uuid)
      )
    ''');
    await db.execute('''
      CREATE TABLE acoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        cidadeUuid TEXT NOT NULL,
        descricao TEXT NOT NULL,
        data TEXT NOT NULL,
        usuarioUuid TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cidadeUuid) REFERENCES cidades(uuid),
        FOREIGN KEY (usuarioUuid) REFERENCES usuarios(uuid)
      )
    ''');
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        acaoUuid TEXT NOT NULL,
        nome TEXT NOT NULL,
        telefone1 TEXT,
        telefone2 TEXT,
        usuarioUuid TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (acaoUuid) REFERENCES acoes(uuid),
        FOREIGN KEY (usuarioUuid) REFERENCES usuarios(uuid)
      )
    ''');
  }

  // CRUD Usuario
  Future<int> insertUsuario(Usuario usuario) async {
    final database = await db;
    // Garante apenas um usuário no app: limpa usuários existentes
    await database.delete('usuarios');
    if (usuario.uuid.isEmpty) {
      usuario.uuid = const Uuid().v4();
    }
    usuario.sincronizado = false;
    return await database.insert('usuarios', usuario.toMap());
  }

  Future<void> clearUsuarios() async {
    final database = await db;
    await database.delete('usuarios');
  }

  Future<Usuario?> getUsuarioById(int id) async {
    final database = await db;
    final maps = await database.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Usuario>> getUsuarios() async {
    final database = await db;
    final maps = await database.query('usuarios');
    return maps.map((m) => Usuario.fromMap(m)).toList();
  }

  Future<int> updateUsuario(Usuario usuario) async {
    final database = await db;
    return await database.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<int> deleteUsuario(int id) async {
    final database = await db;
    return await database.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Cliente
  Future<int> insertCliente(Cliente cliente) async {
    final database = await db;
    final prefs = await SharedPreferences.getInstance();
    final usuarioUuid = prefs.getString('usuarioUuid');
    if (cliente.uuid.isEmpty) {
      cliente.uuid = const Uuid().v4();
    }
    cliente.sincronizado = false;
    final map = cliente.toMap();
    if (usuarioUuid != null) map['usuarioUuid'] = usuarioUuid;
    return await database.insert('clientes', map);
  }

  Future<List<Cliente>> getClientesByAcao(String acaoUuid) async {
    final database = await db;
    final maps = await database.query(
      'clientes',
      where: 'acaoUuid = ?',
      whereArgs: [acaoUuid],
      orderBy: 'id DESC', // mais recentes primeiro
    );
    return maps.map((map) => Cliente.fromMap(map)).toList();
  }

  Future<int> updateCliente(Cliente cliente) async {
    final database = await db;
    return await database.update(
      'clientes',
      cliente.toMap(),
      where: 'uuid = ?',
      whereArgs: [cliente.uuid],
    );
  }

  Future<int> deleteCliente(String uuid) async {
    final database = await db;
    return await database.delete(
      'clientes',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // CRUD Cidade
  Future<int> insertCidade(Cidade cidade) async {
    final database = await db;
    final prefs = await SharedPreferences.getInstance();
    final usuarioUuid = prefs.getString('usuarioUuid');
    if (cidade.uuid.isEmpty) {
      cidade.uuid = const Uuid().v4();
    }
    cidade.sincronizado = false;
    final map = cidade.toMap();
    if (usuarioUuid != null) map['usuarioUuid'] = usuarioUuid;
    return await database.insert('cidades', map);
  }

  Future<List<Cidade>> getCidades() async {
    final database = await db;
    final maps = await database.query('cidades');
    return maps.map((map) => Cidade.fromMap(map)).toList();
  }

  Future<Cidade?> getCidadeByNome(String nome) async {
    final database = await db;
    final maps = await database.query(
      'cidades',
      where: 'nome = ?',
      whereArgs: [nome],
    );
    if (maps.isNotEmpty) {
      return Cidade.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCidade(Cidade cidade) async {
    final database = await db;
    return await database.update(
      'cidades',
      cidade.toMap(),
      where: 'uuid = ?',
      whereArgs: [cidade.uuid],
    );
  }

  Future<int> deleteCidade(String uuid) async {
    final database = await db;
    return await database.delete(
      'cidades',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // CRUD Ação
  Future<int> insertAcao(Acao acao) async {
    final database = await db;
    final prefs = await SharedPreferences.getInstance();
    final usuarioUuid = prefs.getString('usuarioUuid');
    if (acao.uuid.isEmpty) {
      acao.uuid = const Uuid().v4();
    }
    acao.sincronizado = false;
    final map = acao.toMap();
    if (usuarioUuid != null) map['usuarioUuid'] = usuarioUuid;
    return await database.insert('acoes', map);
  }

  Future<List<Acao>> getAcoesByCidade(String cidadeUuid) async {
    final database = await db;
    final maps = await database.query(
      'acoes',
      where: 'cidadeUuid = ?',
      whereArgs: [cidadeUuid],
    );
    return maps.map((map) => Acao.fromMap(map)).toList();
  }

  Future<int> updateAcao(Acao acao) async {
    final database = await db;
    return await database.update(
      'acoes',
      acao.toMap(),
      where: 'uuid = ?',
      whereArgs: [acao.uuid],
    );
  }

  Future<int> deleteAcao(String uuid) async {
    final database = await db;
    return await database.delete('acoes', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // Helpers: marcar registros específicos como sincronizados
  Future<int> markUsuarioSynced(String uuid) async {
    final database = await db;
    return await database.update(
      'usuarios',
      {'sincronizado': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markCidadeSynced(String uuid) async {
    final database = await db;
    return await database.update(
      'cidades',
      {'sincronizado': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markAcaoSynced(String uuid) async {
    final database = await db;
    return await database.update(
      'acoes',
      {'sincronizado': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> markClienteSynced(String uuid) async {
    final database = await db;
    return await database.update(
      'clientes',
      {'sincronizado': 1},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // Verifica se existem pendências de sincronização em qualquer tabela
  Future<bool> hasPendingSync() async {
    final database = await db;
    final results = await Future.wait<int>([
      _countPending(database, 'usuarios'),
      _countPending(database, 'cidades'),
      _countPending(database, 'acoes'),
      _countPending(database, 'clientes'),
    ]);
    return results.any((c) => c > 0);
  }

  Future<int> _countPending(Database database, String table) async {
    final res = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM ' + table + ' WHERE sincronizado = 0',
    );
    final cnt = Sqflite.firstIntValue(res) ?? 0;
    return cnt;
  }

  // Pendências por cidade: ações não sincronizadas ou clientes das ações da cidade não sincronizados
  Future<bool> hasPendingForCidade(String cidadeUuid) async {
    final database = await db;
    final acaoCountRes = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM acoes WHERE cidadeUuid = ? AND sincronizado = 0',
      [cidadeUuid],
    );
    final acaoCnt = Sqflite.firstIntValue(acaoCountRes) ?? 0;
    if (acaoCnt > 0) return true;
    final clienteCountRes = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM clientes WHERE acaoUuid IN (SELECT uuid FROM acoes WHERE cidadeUuid = ?) AND sincronizado = 0',
      [cidadeUuid],
    );
    final clienteCnt = Sqflite.firstIntValue(clienteCountRes) ?? 0;
    return clienteCnt > 0;
  }

  // Pendências por ação: a própria ação não sincronizada ou clientes da ação
  Future<bool> hasPendingClientsForAcao(String acaoUuid) async {
    final database = await db;
    final acaoRes = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM acoes WHERE uuid = ? AND sincronizado = 0',
      [acaoUuid],
    );
    final acaoCnt = Sqflite.firstIntValue(acaoRes) ?? 0;
    if (acaoCnt > 0) return true;
    final clienteRes = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM clientes WHERE acaoUuid = ? AND sincronizado = 0',
      [acaoUuid],
    );
    final clienteCnt = Sqflite.firstIntValue(clienteRes) ?? 0;
    return clienteCnt > 0;
  }
}
