import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  String? token;
  String? role;
  bool rememberMe = false;

  // ✅ عدد الإشعارات غير المقروءة
  int _unreadNotifications = 0;
  int get unreadNotifications => _unreadNotifications;
  Timer? _notificationTimer;

  void setUnreadCount(int count) {
    if (_unreadNotifications != count) {
      _unreadNotifications = count;
      notifyListeners();
    }
  }

  void startNotificationStream() {
    if (_notificationTimer != null) return;
    _pollUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollUnreadCount();
    });
  }

  void stopNotificationStream() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  Future<void> _pollUnreadCount() async {
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/alerts/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setUnreadCount(data['count'] ?? 0);
      }
    } catch (_) {
      // Ignore errors silently for background polling
    }
  }

  // ✅ Profile Cache
  Map<String, dynamic>? userProfile;

  Future<void> fetchProfileIfNeeded() async {
    if (userProfile != null) return; // Already cached
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        userProfile = data['data'];
        notifyListeners();
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    rememberMe = prefs.getBool('remember_me') ?? false;

    // ✅ لو remember me شغال، حمّل التوكن
    if (rememberMe) {
      token = prefs.getString('token');
      role = prefs.getString('role');
      if (token != null) {
        startNotificationStream();
      }
    }

    notifyListeners();
  }

  Future<void> login(String token, String role, {bool remember = false}) async {
    this.token = token;
    this.role = role;
    this.rememberMe = remember;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', remember);

    // ✅ احفظ بس لو remember me شغال
    if (remember) {
      await prefs.setString('token', token);
      await prefs.setString('role', role);
    } else {
      await prefs.remove('token');
      await prefs.remove('role');
    }

    startNotificationStream();

    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    role = null;
    rememberMe = false;
    _unreadNotifications = 0;
    userProfile = null;
    stopNotificationStream();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  bool get isHr => role == 'HR_manager';
  bool get isSupervisor => role == 'supervisor';
  bool get isLoggedIn => token != null;
}
