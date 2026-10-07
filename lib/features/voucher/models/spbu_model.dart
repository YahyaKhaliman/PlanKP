class SpbuModel {
  final int spbuId;
  final String spbuNama;
  final String? spbuAlamat;
  final bool spbuIsActive;

  SpbuModel({
    required this.spbuId,
    required this.spbuNama,
    this.spbuAlamat,
    required this.spbuIsActive,
  });

  factory SpbuModel.fromJson(Map<String, dynamic> json) {
    return SpbuModel(
      spbuId: json['spbu_id'] is int ? json['spbu_id'] : int.tryParse('${json['spbu_id']}') ?? 0,
      spbuNama: json['spbu_nama'] ?? '',
      spbuAlamat: json['spbu_alamat'],
      spbuIsActive: json['spbu_is_active'] == true || json['spbu_is_active'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spbu_id': spbuId,
      'spbu_nama': spbuNama,
      'spbu_alamat': spbuAlamat,
      'spbu_is_active': spbuIsActive,
    };
  }
}
