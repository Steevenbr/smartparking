import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

// Servicio de autenticación (RF-01).
// Guarda los usuarios y la sesión activa en el dispositivo con shared_preferences.
class AuthService {
  static const _usersKey = 'sp_users';
  static const _sessionKey = 'sp_session_email';

  Future<List<AppUser>> _getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => AppUser.fromJson(e)).toList();
  }

  Future<void> _saveUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(users.map((u) => u.toJson()).toList());
    await prefs.setString(_usersKey, raw);
  }

  // Registro de un nuevo usuario. Devuelve null si todo bien, o un mensaje de error.
  Future<String?> register(AppUser user) async {
    final users = await _getUsers();
    final existe = users.any((u) => u.email == user.email.toLowerCase());
    if (existe) return 'Ese correo ya está registrado.';
    user.email = user.email.toLowerCase();
    users.add(user);
    await _saveUsers(users);
    return null;
  }

  // Inicio de sesión. Devuelve el usuario si las credenciales son correctas.
  Future<AppUser?> login(String email, String password) async {
    final users = await _getUsers();
    final correo = email.toLowerCase();
    try {
      final user =
          users.firstWhere((u) => u.email == correo && u.password == password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, user.email);
      return user;
    } catch (_) {
      return null;
    }
  }

  // Usuario con sesión activa (si existe).
  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_sessionKey);
    if (email == null) return null;
    final users = await _getUsers();
    try {
      return users.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }

  // Cierre de sesión.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // Actualiza los datos de un usuario (lo usará el RF-11).
  Future<void> updateUser(AppUser updated) async {
    final users = await _getUsers();
    final i = users.indexWhere((u) => u.email == updated.email);
    if (i != -1) {
      users[i] = updated;
      await _saveUsers(users);
    }
  }
}