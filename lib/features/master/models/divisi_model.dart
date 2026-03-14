class DivisiModel {
  final int divisiId;
  final String divisiKode;
  final String divisiNama;

  DivisiModel({required this.divisiId, required this.divisiKode, required this.divisiNama});

  factory DivisiModel.fromJson(Map<String, dynamic> j) => DivisiModel(
    divisiId:   j['divisi_id'],
    divisiKode: j['divisi_kode'],
    divisiNama: j['divisi_nama'],
  );

  Map<String, dynamic> toJson() => {'divisi_kode': divisiKode, 'divisi_nama': divisiNama};
}