class JadwalModel {
  final int jdwId;
  final String jdwJudul;
  final int jdwJenisId;
  final String? jdwInvJenis;
  final String jdwDivisi;
  final String jdwFrekuensi;
  final String jdwTglMulai;
  final String? jdwTglSelesai;
  final int? jdwWeekNumber;
  final int? jdwBulan;
  final int jdwTahun;
  final int? jdwAssignedTo;
  final String? jdwPabrikKode;
  final String jdwStatus;
  final int? jdwTarget;
  final int? jdwTotalUnit;
  final int? jdwSelesaiUnit;
  final bool jdwPeriodFulfilled;
  final String? jdwCurrentPeriodStart;
  final String? jdwNextDueDate;
  final int? jdwDaysRemaining;
  final String? jdwNotes;
  final Map<String, dynamic>? assignedUser;
  final Map<String, dynamic>? dibuatUser;

  JadwalModel({
    required this.jdwId,
    required this.jdwJudul,
    required this.jdwJenisId,
    this.jdwInvJenis,
    required this.jdwDivisi,
    required this.jdwFrekuensi,
    required this.jdwTglMulai,
    this.jdwTglSelesai,
    this.jdwWeekNumber,
    this.jdwBulan,
    required this.jdwTahun,
    this.jdwAssignedTo,
    this.jdwPabrikKode,
    required this.jdwStatus,
    this.jdwTarget,
    this.jdwTotalUnit,
    this.jdwSelesaiUnit,
    this.jdwPeriodFulfilled = false,
    this.jdwCurrentPeriodStart,
    this.jdwNextDueDate,
    this.jdwDaysRemaining,
    this.jdwNotes,
    this.assignedUser,
    this.dibuatUser,
  });

  factory JadwalModel.fromJson(Map<String, dynamic> j) => JadwalModel(
        jdwId: j['jdw_id'],
        jdwJudul: j['jdw_judul'] ?? '',
        jdwJenisId: j['jdw_jenis_id'] ?? j['jdw_inv_jenis'] ?? 0,
        jdwInvJenis: j['jdw_inv_jenis'],
        jdwDivisi: j['jdw_divisi'] ?? '',
        jdwFrekuensi: j['jdw_frekuensi'] ?? '',
        jdwTglMulai: j['jdw_tgl_mulai'] ?? '',
        jdwTglSelesai: j['jdw_tgl_selesai'],
        jdwWeekNumber: j['jdw_week_number'],
        jdwBulan: j['jdw_bulan'],
        jdwTahun: j['jdw_tahun'] ?? DateTime.now().year,
        jdwAssignedTo: j['jdw_assigned_to'],
        jdwPabrikKode: j['jdw_pabrik_kode']?.toString(),
        jdwStatus: j['jdw_status'] ?? 'Draft',
        jdwTarget: j['jdw_target'] is int
            ? j['jdw_target']
            : int.tryParse('${j['jdw_target'] ?? ''}'),
        jdwTotalUnit: j['jdw_total_unit'] is int
            ? j['jdw_total_unit']
            : int.tryParse('${j['jdw_total_unit'] ?? ''}'),
        jdwSelesaiUnit: j['jdw_selesai_unit'] is int
            ? j['jdw_selesai_unit']
            : int.tryParse('${j['jdw_selesai_unit'] ?? ''}'),
        jdwPeriodFulfilled: j['jdw_period_fulfilled'] == true,
        jdwCurrentPeriodStart: j['jdw_current_period_start'],
        jdwNextDueDate: j['jdw_next_due_date'],
        jdwDaysRemaining: j['jdw_days_remaining'] is int
            ? j['jdw_days_remaining']
            : int.tryParse('${j['jdw_days_remaining'] ?? ''}'),
        jdwNotes: j['jdw_notes'],
        assignedUser:
            (j['assigned_user'] ?? j['jdw_assigned_to_plan_user']) != null
                ? Map<String, dynamic>.from(
                    j['assigned_user'] ?? j['jdw_assigned_to_plan_user'])
                : null,
        dibuatUser: (j['dibuat_user'] ?? j['jdw_dibuat_oleh_plan_user']) != null
            ? Map<String, dynamic>.from(
                j['dibuat_user'] ?? j['jdw_dibuat_oleh_plan_user'])
            : null,
      );

  String get assignedNama => assignedUser?['user_nama'] ?? '-';
}
