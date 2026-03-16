import 'checklist_hasil_model.dart';

class RealisasiModel {
  final int     realId;
  final int     realJadwalId;
  final int     realInvId;
  final int     realTeknisiId;
  final String  realTgl;
  final String? realJamMulai;
  final String? realJamSelesai;
  final int     realWeekNumber;
  final int     realBulan;
  final int     realTahun;
  final String? realKondisiAkhir;
  final String? realKeterangan;
  final String  realStatus;
  final String? realTtdPicNama;
  final String? realTtdData;
  final String? realTtdAt;
  final int?    realApprovedBy;
  final String? realApprovedAt;
  final Map<String, dynamic>? jadwal;
  final Map<String, dynamic>? inventaris;
  final Map<String, dynamic>? teknisi;
  final List<ChecklistHasilModel> hasilChecklist;

  RealisasiModel({
    required this.realId,
    required this.realJadwalId,
    required this.realInvId,
    required this.realTeknisiId,
    required this.realTgl,
    this.realJamMulai,
    this.realJamSelesai,
    required this.realWeekNumber,
    required this.realBulan,
    required this.realTahun,
    this.realKondisiAkhir,
    this.realKeterangan,
    required this.realStatus,
    this.realTtdPicNama,
    this.realTtdData,
    this.realTtdAt,
    this.realApprovedBy,
    this.realApprovedAt,
    this.jadwal,
    this.inventaris,
    this.teknisi,
    this.hasilChecklist = const [],
  });

  factory RealisasiModel.fromJson(Map<String, dynamic> j) => RealisasiModel(
    realId:           j['real_id'],
    realJadwalId:     j['real_jadwal_id'],
    realInvId:        j['real_inv_id'],
    realTeknisiId:    j['real_teknisi_id'],
    realTgl:          j['real_tgl']           ?? '',
    realJamMulai:     j['real_jam_mulai'],
    realJamSelesai:   j['real_jam_selesai'],
    realWeekNumber:   j['real_week_number']   ?? 0,
    realBulan:        j['real_bulan']         ?? 0,
    realTahun:        j['real_tahun']         ?? DateTime.now().year,
    realKondisiAkhir: j['real_kondisi_akhir'],
    realKeterangan:   j['real_keterangan'],
    realStatus:       j['real_status']        ?? 'Draft',
    realTtdPicNama:   j['real_ttd_pic_nama'],
    realTtdData:      j['real_ttd_data'],
    realTtdAt:        j['real_ttd_at'],
    realApprovedBy:   j['real_approved_by'],
    realApprovedAt:   j['real_approved_at'],
    jadwal:           j['jadwal']     != null
        ? Map<String, dynamic>.from(j['jadwal'])     : null,
    inventaris:       j['inventaris'] != null
        ? Map<String, dynamic>.from(j['inventaris']) : null,
    teknisi:          j['teknisi']    != null
        ? Map<String, dynamic>.from(j['teknisi'])    : null,
    hasilChecklist:   j['hasil_checklist'] != null
        ? (j['hasil_checklist'] as List)
            .map((e) => ChecklistHasilModel.fromJson(e)).toList()
        : [],
  );

  bool get selesai  => realStatus == 'Selesai';
  bool get isDraft  => realStatus == 'Draft';
  String get invNama => inventaris?['inv_nama'] ?? '-';
  String get invNo   => inventaris?['inv_no']   ?? '-';
}
