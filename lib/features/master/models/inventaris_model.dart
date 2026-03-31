class InventarisModel {
  final int invId;
  final String invNo;
  final String invNama;
  final String invKategori;
  final int invJenisId;
  final String? invPabrikKode;
  final String? invMerk;
  final String? invSerialNumber;
  final String? invPic;
  final String? invTglBeli;
  final String invKondisi;
  final bool invIsActive;
  final String? invNotes;

  InventarisModel({
    required this.invId,
    required this.invNo,
    required this.invNama,
    required this.invKategori,
    required this.invJenisId,
    this.invPabrikKode,
    this.invMerk,
    this.invSerialNumber,
    this.invPic,
    this.invTglBeli,
    required this.invKondisi,
    required this.invIsActive,
    this.invNotes,
  });

  factory InventarisModel.fromJson(Map<String, dynamic> j) => InventarisModel(
        invId: j['inv_id'],
        invNo: j['inv_no'] ?? '',
        invNama: j['inv_nama'] ?? '',
        invKategori: j['inv_kategori'] ?? j['jenis']?['jenis_kategori'] ?? '',
        invJenisId: j['inv_jenis_id'] ?? 0,
        invPabrikKode: j['inv_pabrik_kode'] ?? j['inv_lokasi'],
        invMerk: j['inv_merk'],
        invSerialNumber: j['inv_serial_number'],
        invPic: j['inv_pic'],
        invTglBeli: j['inv_tgl_beli'],
        invKondisi: j['inv_kondisi'] ?? 'Baik',
        invIsActive: j['inv_is_active'] == true || j['inv_is_active'] == 1,
        invNotes: j['inv_notes'],
      );

  bool get aktif => invIsActive;
  String? get invLokasi => invPabrikKode;
}
