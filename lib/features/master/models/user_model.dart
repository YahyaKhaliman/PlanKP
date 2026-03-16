class UserModel {
  final int userId;
  final String userNama;
  final String userNik;
  final String userJabatan;
  final String userDivisi;
  final String? userCabang;
  final bool userIsActive;

  UserModel({
    required this.userId,
    required this.userNama,
    required this.userNik,
    required this.userJabatan,
    required this.userDivisi,
    this.userCabang,
    required this.userIsActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        userId: j['user_id'],
        userNama: j['user_nama'] ?? '',
        userNik: j['user_nik'] ?? '',
        userJabatan: j['user_jabatan'] ?? '',
        userDivisi: j['user_divisi'] ?? '',
        userCabang: j['user_cabang'],
        userIsActive: _mapActive(j['user_is_active']),
      );

  static bool _mapActive(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return true;
  }

  bool get aktif => userIsActive;

  static const List<String> divisiList = [
    'Teknisi Jahit',
    'Teknisi Umum',
    'IT Support',
    'Satpam',
    'Kebersihan',
  ];

  static const Map<String, List<String>> kategoriToDivisi = {
    'Mesin Jahit': ['Teknisi Jahit'],
    'Mesin Umum': ['Teknisi Umum'],
    'Hardware': ['IT Support'],
    'APAR': ['Teknisi Jahit', 'Teknisi Umum', 'IT Support', 'Satpam'],
    'Lainnya': divisiList,
  };

  String get jabatanLabel {
    switch (userJabatan) {
      case 'admin':
        return 'Admin';
      case 'teknisi':
        return 'Teknisi';
      case 'it_support':
        return 'IT Support';
      default:
        return userJabatan;
    }
  }
}
