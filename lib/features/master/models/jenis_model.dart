class JenisModel {
  final int jenisId;
  final String jenisNama;
  final String jenisKategori;
  final int jenisGapHari;
  final bool jenisIsActive;

  JenisModel({
    required this.jenisId,
    required this.jenisNama,
    required this.jenisKategori,
    required this.jenisGapHari,
    required this.jenisIsActive,
  });

  factory JenisModel.fromJson(Map<String, dynamic> json) => JenisModel(
        jenisId: json['jenis_id'] ?? 0,
        jenisNama: json['jenis_nama'] ?? '-',
        jenisKategori: json['jenis_kategori'] ?? '-',
        jenisGapHari: json['jenis_gap_hari'] is int
            ? json['jenis_gap_hari']
            : int.tryParse('${json['jenis_gap_hari'] ?? 0}') ?? 0,
        jenisIsActive:
            json['jenis_is_active'] == 1 || json['jenis_is_active'] == true,
      );
}
