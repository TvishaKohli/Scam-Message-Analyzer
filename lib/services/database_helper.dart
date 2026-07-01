import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scam_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // bumped to 2 to clear stale mixed-user scan_history
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        // Enable foreign key enforcement (off by default in SQLite)
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Scan history table
    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        score INTEGER NOT NULL,
        level TEXT NOT NULL,
        reasons TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Scam patterns table (curated rules)
    await db.execute('''
      CREATE TABLE scam_patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT,
        risk_score INTEGER,
        type TEXT,
        statement TEXT,
        category TEXT,
        keywords TEXT,
        verified_count INTEGER DEFAULT 0,
        risk_level TEXT,
        source TEXT DEFAULT 'default'
      )
    ''');

    // Naive Bayes word frequency table
    // word_count: how many times this word appears in spam/ham messages
    // spam_count: times seen in spam
    // ham_count: times seen in ham
    await db.execute('''
      CREATE TABLE nb_word_freq (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT UNIQUE NOT NULL,
        spam_count INTEGER DEFAULT 0,
        ham_count INTEGER DEFAULT 0
      )
    ''');

    // Naive Bayes document totals
    await db.execute('''
      CREATE TABLE nb_totals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT UNIQUE NOT NULL,
        doc_count INTEGER DEFAULT 0,
        word_count INTEGER DEFAULT 0
      )
    ''');

    // Insert initial totals rows
    await db.insert('nb_totals', {'label': 'spam', 'doc_count': 0, 'word_count': 0});
    await db.insert('nb_totals', {'label': 'ham', 'doc_count': 0, 'word_count': 0});
  }

  // Called when DB bumps from version 1 → 2.
  // Drops & recreates scan_history to wipe any stale mixed-user records.
  // The users table is preserved so no accounts are lost.
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS scan_history');
      await db.execute('''
        CREATE TABLE scan_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          message TEXT NOT NULL,
          score INTEGER NOT NULL,
          level TEXT NOT NULL,
          reasons TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // ─── Naive Bayes operations ───────────────────────────────────────────────

  Future<void> upsertNBWord(String word, int spamDelta, int hamDelta) async {
    final db = await instance.database;
    await db.rawInsert('''
      INSERT INTO nb_word_freq (word, spam_count, ham_count)
      VALUES (?, ?, ?)
      ON CONFLICT(word) DO UPDATE SET
        spam_count = spam_count + excluded.spam_count,
        ham_count  = ham_count  + excluded.ham_count
    ''', [word, spamDelta, hamDelta]);
  }

  Future<void> incrementNBTotals(String label, int wordCount) async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE nb_totals SET doc_count = doc_count + 1, word_count = word_count + ?
      WHERE label = ?
    ''', [wordCount, label]);
  }

  Future<Map<String, int>> getNBTotals() async {
    final db = await instance.database;
    final rows = await db.query('nb_totals');
    Map<String, int> totals = {};
    for (var row in rows) {
      totals['${row['label']}_docs'] = row['doc_count'] as int;
      totals['${row['label']}_words'] = row['word_count'] as int;
    }
    return totals;
  }

  Future<Map<String, dynamic>?> getNBWordFreq(String word) async {
    final db = await instance.database;
    final rows = await db.query(
      'nb_word_freq',
      where: 'word = ?',
      whereArgs: [word],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> getNBVocabSize() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM nb_word_freq');
    return result.first['cnt'] as int;
  }

  Future<void> clearNBData() async {
    final db = await instance.database;
    await db.delete('nb_word_freq');
    await db.update('nb_totals', {'doc_count': 0, 'word_count': 0});
  }

  // ─── Pattern operations ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPatterns() async {
    final db = await instance.database;
    return await db.query('scam_patterns');
  }

  Future<int> insertScamPattern(Map<String, dynamic> pattern) async {
    final db = await instance.database;
    return await db.insert('scam_patterns', pattern);
  }

  Future<void> clearPatterns() async {
    final db = await instance.database;
    await db.delete('scam_patterns');
  }

  // ─── User operations ──────────────────────────────────────────────────────

  Future<int> insertUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return results.isNotEmpty ? User.fromMap(results.first) : null;
  }

  Future<User?> login(String email, String password) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return results.isNotEmpty ? User.fromMap(results.first) : null;
  }

  // ─── Scan history operations ──────────────────────────────────────────────

  Future<int> insertScanHistory(ScanHistory history) async {
    final db = await instance.database;
    // Build the map without the null 'id' key so SQLite AUTOINCREMENT
    // works correctly on every platform.
    final map = history.toMap();
    map.removeWhere((key, value) => key == 'id' && value == null);
    return await db.insert('scan_history', map);
  }

  Future<List<ScanHistory>> getScanHistory(int userId) async {
    final db = await instance.database;
    // Use rawQuery with explicit parametrized SQL to guarantee
    // the WHERE clause is always applied — no implicit fallback.
    final results = await db.rawQuery(
      'SELECT * FROM scan_history WHERE user_id = ? ORDER BY created_at DESC',
      [userId],
    );
    return results.map((map) => ScanHistory.fromMap(map)).toList();
  }

  // ─── Admin operations ─────────────────────────────────────────────────────

  /// Returns a single map with all data the admin dashboard needs.
  Future<Map<String, dynamic>> getAdminDashboardData() async {
    final db = await instance.database;

    // Totals
    final totalUsersResult  = await db.rawQuery('SELECT COUNT(*) AS cnt FROM users');
    final totalScansResult  = await db.rawQuery('SELECT COUNT(*) AS cnt FROM scan_history');
    final highRiskResult    = await db.rawQuery('SELECT COUNT(*) AS cnt FROM scan_history WHERE score >= 70');
    final safeResult        = await db.rawQuery('SELECT COUNT(*) AS cnt FROM scan_history WHERE score < 40');

    // Users with scan counts
    final users = await db.rawQuery('''
      SELECT u.id, u.name, u.email, u.created_at,
             COUNT(s.id) AS scan_count
      FROM users u
      LEFT JOIN scan_history s ON s.user_id = u.id
      GROUP BY u.id
      ORDER BY u.created_at DESC
    ''');

    // All scans with user name
    final allScans = await db.rawQuery('''
      SELECT s.id, s.user_id, s.message, s.score, s.level, s.reasons, s.created_at,
             u.name AS user_name
      FROM scan_history s
      LEFT JOIN users u ON u.id = s.user_id
      ORDER BY s.created_at DESC
    ''');

    return {
      'totalUsers':    totalUsersResult.first['cnt'] as int,
      'totalScans':    totalScansResult.first['cnt'] as int,
      'highRiskScans': highRiskResult.first['cnt'] as int,
      'safeScans':     safeResult.first['cnt'] as int,
      'users':         users,
      'allScans':      allScans,
    };
  }

  /// Deletes a user and cascades to their scan history (FK ON DELETE CASCADE).
  Future<void> deleteUser(int userId) async {
    final db = await instance.database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  /// Deletes a single scan record.
  Future<void> deleteScan(int scanId) async {
    final db = await instance.database;
    await db.delete('scan_history', where: 'id = ?', whereArgs: [scanId]);
  }
}
