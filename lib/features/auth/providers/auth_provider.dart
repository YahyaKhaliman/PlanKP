import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';

class AuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String get jabatan => _user?['user_jabatan'] ?? '';

  Future<void> checkSession() async {
    final token = await _storage.read(key: StorageKeys.token);
    if (token == null) return;
    try {
      final res = await ApiClient.get(ApiConfig.me);
      _user = res['data'];
      notifyListeners();
    } catch (_) {
      await _storage.delete(key: StorageKeys.token);
    }
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.post(
        ApiConfig.login,
        {'user_name': username, 'password': password},
        auth: false,
      );
      final token = res['data']['token'] as String;
      _user = res['data']['user'];
      await _storage.write(key: StorageKeys.token, value: token);
      await _storage.write(key: StorageKeys.userData, value: jsonEncode(_user));
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    await _storage.deleteAll();
    notifyListeners();
  }
}
