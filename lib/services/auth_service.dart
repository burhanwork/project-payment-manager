import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'database_helper.dart';

class AuthService {
  AppUser? _cachedUser;
  static const _uidKey = 'logged_in_uid';

  Future<AppUser?> initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_uidKey);
    if (uid == null) return null;
    final row = await DatabaseHelper.getUserByUid(uid);
    if (row == null) return null;
    _cachedUser = AppUser(
      uid: row['uid'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => UserRole.boss,
      ),
      createdAt: DateTime.tryParse(row['createdAt'] as String) ?? DateTime.now(),
    );
    return _cachedUser;
  }

  AppUser? getCurrentUser() => _cachedUser;

  Future<AppUser?> signIn(String email, String password) async {
    final row = await DatabaseHelper.authenticateUser(email, password);
    if (row == null) return null;
    _cachedUser = AppUser(
      uid: row['uid'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => UserRole.boss,
      ),
      createdAt: DateTime.tryParse(row['createdAt'] as String) ?? DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, _cachedUser!.uid);
    return _cachedUser;
  }

  Future<AppUser?> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final row = await DatabaseHelper.registerUser(
      uid: uid,
      email: email,
      name: name,
      password: password,
      role: role.name,
    );
    if (row == null) return null;
    _cachedUser = AppUser(
      uid: row['uid'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => UserRole.boss,
      ),
      createdAt: DateTime.tryParse(row['createdAt'] as String) ?? DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, _cachedUser!.uid);
    return _cachedUser;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    _cachedUser = null;
  }

  bool get isLoggedIn => _cachedUser != null;
}
