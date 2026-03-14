class UserModel {
  final int    userId;
  final String userNama;
  final String userNik;
  final String userJabatan;
  final String? userCabang;
  final int    userIsActive;

  UserModel({
    required this.userId,
    required this.userNama,
    required this.userNik,
    required this.userJabatan,
    this.userCabang,
    required this.userIsActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    userId:       j['user_id'],
    userNama:     j['user_nama']      ?? '',
    userNik:      j['user_nik']       ?? '',
    userJabatan:  j['user_jabatan']   ?? '',
    userCabang:   j['user_cabang'],
    userIsActive: j['user_is_active'] ?? 1,
  );

  bool get aktif => userIsActive == 1;

  String get jabatanLabel {
    switch (userJabatan) {
      case 'admin':      return 'Admin';
      case 'teknisi':    return 'Teknisi';
      case 'it_support': return 'IT Support';
      default:           return userJabatan;
    }
  }
}
