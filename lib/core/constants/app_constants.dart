class ApiConfig {
  static const String baseUrl =
      'http://103.94.238.252:3007/api'; // Production server
  // static const String baseUrl =
  // 'http://localhost:3003/api'; // Local development
  // static const String baseUrl = 'http://10.0.2.2:3003/api'; // Android emulator
  // static const String baseUrl = 'http://127.0.0.1:3003/api';  // iOS simulator

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String changePass = '/auth/change-password';
  static const String checklistTemplate = '/master/checklist-template';
  static const String inventaris = '/master/inv';
  static const String divisi = '/master/divisi';
  static const String users = '/master/users';
  static const String jadwal = '/master/jadwal';
  static const String realisasi = '/master/realisasi';
  static const String jenis = '/master/jenis';
  static const String pabrik = '/master/pabrik';
  static const String metadata = '/master/metadata';
  static const String dashboardSummary = '/master/dashboard/summary';
}

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String register = '/register';
  static const String jadwalDetail = '/jadwal/detail';
  static const String realisasiForm = '/jadwal/realisasi-form';
}

class StorageKeys {
  static const String token = 'auth_token';
  static const String userData = 'user_data';
}
