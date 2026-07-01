import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scam.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scam_patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT,
        risk_score INTEGER,
        type TEXT
      )
    ''');

    await _insertDefaultPatterns(db);
  }

  Future<void> _insertDefaultPatterns(Database db) async {
    List<Map<String, dynamic>> patterns = [
      {"keyword": "urgent", "risk_score": 20, "type": "language"},
      {"keyword": "otp", "risk_score": 40, "type": "sensitive"},
      {"keyword": "click here", "risk_score": 30, "type": "link"},
      {"keyword": "verify", "risk_score": 15, "type": "action"},
      {"keyword": "bank", "risk_score": 10, "type": "context"},
      {"keyword": "account blocked", "risk_score": 30, "type": "threat"},
    ];

    for (var pattern in patterns) {
      await db.insert('scam_patterns', pattern);
    }
  }

  Future<List<Map<String, dynamic>>> getPatterns() async {
    final db = await instance.database;
    return await db.query('scam_patterns');
  }
}