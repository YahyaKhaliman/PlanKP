class PabrikModel {
  final String pabKode;
  final String pabNama;
  final String? pabAlamat;
  final String? pabPabrik;

  const PabrikModel({
    required this.pabKode,
    required this.pabNama,
    this.pabAlamat,
    this.pabPabrik,
  });

  factory PabrikModel.fromJson(Map<String, dynamic> json) => PabrikModel(
        pabKode: (json['pab_kode'] ?? '').toString(),
        pabNama: (json['pab_nama'] ?? '').toString(),
        pabAlamat: json['pab_alamat']?.toString(),
        pabPabrik: json['pab_pabrik']?.toString(),
      );

  String get displayLabel {
    if (pabNama.trim().isEmpty) return pabKode;
    return '$pabKode - $pabNama';
  }
}
