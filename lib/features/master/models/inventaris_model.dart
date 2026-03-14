class InventarisModel {
  final int    invId;
  final String invNo;
  final String invNama;
  final String invKategori;
  final String invJenis;
  final String? invLokasi;
  final String? invMerk;
  final String? invSerialNumber;
  final String? invTglBeli;
  final String invKondisi;
  final int    invIsActive;
  final String? invNotes;

  InventarisModel({
    required this.invId,
    required this.invNo,
    required this.invNama,
    required this.invKategori,
    required this.invJenis,
    this.invLokasi,
    this.invMerk,
    this.invSerialNumber,
    this.invTglBeli,
    required this.invKondisi,
    required this.invIsActive,
    this.invNotes,
  });

  factory InventarisModel.fromJson(Map<String, dynamic> j) => InventarisModel(
    invId:           j['inv_id'],
    invNo:           j['inv_no']       ?? '',
    invNama:         j['inv_nama']     ?? '',
    invKategori:     j['inv_kategori'] ?? '',
    invJenis:        j['inv_jenis']    ?? '',
    invLokasi:       j['inv_lokasi'],
    invMerk:         j['inv_merk'],
    invSerialNumber: j['inv_serial_number'],
    invTglBeli:      j['inv_tgl_beli'],
    invKondisi:      j['inv_kondisi']  ?? 'Baik',
    invIsActive:     j['inv_is_active'] ?? 1,
    invNotes:        j['inv_notes'],
  );

  bool get aktif => invIsActive == 1;
}
