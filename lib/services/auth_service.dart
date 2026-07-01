import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_helper.dart';

class AuthService {
  static const String _userIdKey    = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey  = 'user_name';
  static const String _isAdminKey   = 'is_admin';

  // Hard-coded admin credentials (no DB row needed)
  static const String adminEmail    = 'admin@scam.ai';
  static const String adminPassword = 'admin123';
  static const int    adminId       = -1; // sentinel – not a real DB user

  // Save user session
  static Future<void> saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, user.id!);
    await prefs.setString(_userEmailKey, user.email);
    await prefs.setString(_userNameKey, user.name);
    await prefs.setBool(_isAdminKey, false);
  }

  // Get current user session
  static Future<Map<String, String>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_userIdKey);
    final email  = prefs.getString(_userEmailKey);
    final name   = prefs.getString(_userNameKey);

    if (userId != null && email != null) {
      return {
        'id':    userId.toString(),
        'email': email,
        'name':  name ?? '',
      };
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  // Clear user session (logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_isAdminKey);
  }

  // Login user
  static Future<User?> login(String email, String password) async {
    final user = await DatabaseHelper.instance.login(email, password);
    if (user != null) {
      await saveUserSession(user);
    }
    return user;
  }

  // Register new user
  static Future<bool> signup(String name, String email, String password) async {
    // Check if user already exists
    final existingUser = await DatabaseHelper.instance.getUserByEmail(email);
    if (existingUser != null) {
      return false; // User already exists
    }

    // Create new user
    final newUser = User(
      email: email,
      password: password, // In real app, hash this password
      name: name,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertUser(newUser);
    return true;
  }

  // ─── Admin helpers ────────────────────────────────────────────────────────

  static bool checkAdminCredentials(String email, String password) =>
      email.trim().toLowerCase() == adminEmail && password == adminPassword;

  /// Saves a synthetic admin session (no DB row needed).
  static Future<void> saveAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, adminId);
    await prefs.setString(_userEmailKey, adminEmail);
    await prefs.setString(_userNameKey, 'Admin');
    await prefs.setBool(_isAdminKey, true);
  }

  /// Returns true when the current session belongs to the admin.
  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAdminKey) ?? false;
  }
}
