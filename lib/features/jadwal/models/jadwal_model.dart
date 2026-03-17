class JadwalModel {
  final int jdwId;
  final String jdwJudul;
  final String jdwInvJenis;
  final String jdwDivisi;
  final String jdwFrekuensi;
  final String jdwTglMulai;
  final String? jdwTglSelesai;
  final int? jdwWeekNumber;
  final int? jdwBulan;
  final int jdwTahun;
  final int? jdwAssignedTo;
  final String jdwStatus;
  final String? jdwNotes;
  final Map<String, dynamic>? assignedUser;
  final Map<String, dynamic>? dibuatUser;

  JadwalModel({
    required this.jdwId,
    required this.jdwJudul,
    required this.jdwInvJenis,
    required this.jdwDivisi,
    required this.jdwFrekuensi,
    required this.jdwTglMulai,
    this.jdwTglSelesai,
    this.jdwWeekNumber,
    this.jdwBulan,
    required this.jdwTahun,
    this.jdwAssignedTo,
    required this.jdwStatus,
    this.jdwNotes,
    this.assignedUser,
    this.dibuatUser,
  });

  factory JadwalModel.fromJson(Map<String, dynamic> j) => JadwalModel(
        jdwId: j['jdw_id'],
        jdwJudul: j['jdw_judul'] ?? '',
        jdwInvJenis: j['jdw_inv_jenis'] ?? '',
        jdwDivisi: j['jdw_divisi'] ?? '',
        jdwFrekuensi: j['jdw_frekuensi'] ?? '',
        jdwTglMulai: j['jdw_tgl_mulai'] ?? '',
        jdwTglSelesai: j['jdw_tgl_selesai'],
        jdwWeekNumber: j['jdw_week_number'],
        jdwBulan: j['jdw_bulan'],
        jdwTahun: j['jdw_tahun'] ?? DateTime.now().year,
        jdwAssignedTo: j['jdw_assigned_to'],
        jdwStatus: j['jdw_status'] ?? 'Draft',
        jdwNotes: j['jdw_notes'],
        assignedUser: j['assigned_user'] != null
            ? Map<String, dynamic>.from(j['assigned_user'])
            : null,
        dibuatUser: j['dibuat_user'] != null
            ? Map<String, dynamic>.from(j['dibuat_user'])
            : null,
      );

  String get assignedNama => assignedUser?['user_nama'] ?? '-';
}
