class JenisMesinModel {
  final int jmId;
  final String jmNama;
  final String? jmKeterangan;

  JenisMesinModel({required this.jmId, required this.jmNama, this.jmKeterangan});

  factory JenisMesinModel.fromJson(Map<String, dynamic> j) => JenisMesinModel(
    jmId:          j['jm_id'],
    jmNama:        j['jm_nama'],
    jmKeterangan:  j['jm_keterangan'],
  );

  Map<String, dynamic> toJson() => {'jm_nama': jmNama, 'jm_keterangan': jmKeterangan};
}