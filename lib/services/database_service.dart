import 'database_helper.dart';

class DatabaseService {
  static Future<void> initialize() async {
    // Initialize SQLite database
    await DatabaseHelper.database;
  }
}
