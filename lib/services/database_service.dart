import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  
  final _changeController = StreamController<void>.broadcast();
  Stream<void> get onChange => _changeController.stream;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'auto_mail_ai.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE config (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE emails (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recipient TEXT,
            subject TEXT,
            body TEXT,
            resume_path TEXT,
            status TEXT, -- pending, sending, sent, failed, archived
            retries INTEGER DEFAULT 0,
            error_message TEXT,
            created_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE emails ADD COLUMN resume_path TEXT');
        }
      },
    );
  }

  // Config Methods
  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert(
      'config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changeController.add(null);
  }

  Future<String?> getConfig(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // Email Methods
  Future<int> insertEmail(Map<String, dynamic> email) async {
    final db = await database;
    email['created_at'] = DateTime.now().toIso8601String();
    final id = await db.insert('emails', email);
    _changeController.add(null);
    return id;
  }

  Future<List<Map<String, dynamic>>> getEmails({String? status}) async {
    final db = await database;
    if (status != null) {
      return await db.query('emails', where: 'status = ?', whereArgs: [status], orderBy: 'created_at DESC');
    }
    return await db.query('emails', where: 'status != ?', whereArgs: ['deleted'], orderBy: 'created_at DESC');
  }

  Future<void> updateEmailStatus(int id, String status, {String? errorMessage, int? retries}) async {
    final db = await database;
    Map<String, dynamic> values = {'status': status};
    if (errorMessage != null) values['error_message'] = errorMessage;
    if (retries != null) values['retries'] = retries;
    
    await db.update('emails', values, where: 'id = ?', whereArgs: [id]);
    _changeController.add(null);
  }

  Future<void> deleteEmail(int id) async {
    final db = await database;
    await db.delete('emails', where: 'id = ?', whereArgs: [id]);
    _changeController.add(null);
  }
}
