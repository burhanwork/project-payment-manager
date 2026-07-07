import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static Database? _database;
  static const _dbName = 'payment_manager.db';
  static const _dbVersion = 1;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        clientName TEXT NOT NULL,
        totalCost REAL NOT NULL DEFAULT 0,
        totalPaid REAL NOT NULL DEFAULT 0,
        remainingBalance REAL NOT NULL DEFAULT 0,
        milestones TEXT NOT NULL DEFAULT '[]',
        completionPercentage REAL NOT NULL DEFAULT 0,
        startDate TEXT NOT NULL,
        expectedCompletionDate TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'planned',
        createdBy TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        title TEXT NOT NULL,
        module TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        method TEXT NOT NULL DEFAULT 'other',
        notes TEXT,
        proofPath TEXT,
        addedBy TEXT NOT NULL,
        addedByName TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'approved',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (projectId) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');

    // Seed the 3 default users
    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'uid': 'user_boss_001',
      'email': 'boss@example.com',
      'name': 'Boss',
      'password': _hashPassword('ChangeMe123!'),
      'role': 'boss',
      'createdAt': now,
    });
    await db.insert('users', {
      'uid': 'user_dev_001',
      'email': 'developer@example.com',
      'name': 'Developer',
      'password': _hashPassword('ChangeMe123!'),
      'role': 'developer',
      'createdAt': now,
    });
    await db.insert('users', {
      'uid': 'user_acc_001',
      'email': 'accountant@example.com',
      'name': 'Accountant',
      'password': _hashPassword('ChangeMe123!'),
      'role': 'accountant',
      'createdAt': now,
    });
  }

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ── User Operations ──

  static Future<Map<String, dynamic>?> authenticateUser(
      String email, String password) async {
    final db = await database;
    final hash = _hashPassword(password);
    final results = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email.toLowerCase().trim(), hash],
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    final db = await database;
    final results = await db.query('users', where: 'uid = ?', whereArgs: [uid]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<Map<String, dynamic>?> registerUser({
    required String uid,
    required String email,
    required String name,
    required String password,
    required String role,
  }) async {
    final db = await database;
    final existing = await db.query('users',
        where: 'email = ?', whereArgs: [email.toLowerCase().trim()]);
    if (existing.isNotEmpty) return null;

    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'uid': uid,
      'email': email.toLowerCase().trim(),
      'name': name.trim(),
      'password': _hashPassword(password),
      'role': role,
      'createdAt': now,
    });
    return (await getUserByUid(uid));
  }

  // ── Project Operations ──

  static Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await database;
    return db.query('projects', orderBy: 'createdAt DESC');
  }

  static Future<Map<String, dynamic>?> getProject(String id) async {
    final db = await database;
    final results =
        await db.query('projects', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<void> insertProject(Map<String, dynamic> project) async {
    final db = await database;
    await db.insert('projects', project,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateProject(
      String id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('projects', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('payments', where: 'projectId = ?', whereArgs: [id]);
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ── Payment Operations ──

  static Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await database;
    return db.query('payments', orderBy: 'createdAt DESC');
  }

  static Future<List<Map<String, dynamic>>> getPaymentsByProject(
      String projectId) async {
    final db = await database;
    return db.query('payments',
        where: 'projectId = ?',
        whereArgs: [projectId],
        orderBy: 'createdAt DESC');
  }

  static Future<void> insertPayment(Map<String, dynamic> payment) async {
    final db = await database;
    await db.insert('payments', payment,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deletePayment(String id) async {
    final db = await database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // ── Utility: Recalculate project totalPaid ──

  static Future<void> recalcProjectTotals(String projectId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE projectId = ?',
      [projectId],
    );
    final totalPaid = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    final project = await getProject(projectId);
    if (project != null) {
      final totalCost = (project['totalCost'] as num?)?.toDouble() ?? 0.0;
      await db.update(
        'projects',
        {
          'totalPaid': totalPaid,
          'remainingBalance': totalCost - totalPaid,
        },
        where: 'id = ?',
        whereArgs: [projectId],
      );
    }
  }
}
