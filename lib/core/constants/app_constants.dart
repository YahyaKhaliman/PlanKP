class ApiConfig {
  static const String baseUrl = 'http://localhost:3003/api';
  // Ganti IP sesuai environment:
  // Android emulator : 10.0.2.2
  // iOS simulator    : 127.0.0.1
  // Device fisik     : IP mesin dev, misal 192.168.1.x

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String changePass = '/auth/change-password';
}

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String register = '/register';
}

class StorageKeys {
  static const String token = 'auth_token';
  static const String userData = 'user_data';
}
