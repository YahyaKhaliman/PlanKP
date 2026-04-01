class ChecklistHasilModel {
  final int hcId;
  final int hcRealId;
  final int hcCtId;
  final String hcHasil;
  final String? hcKondisi;
  final String? hcKeterangan;
  final Map<String, dynamic>? templateItem;

  ChecklistHasilModel({
    required this.hcId,
    required this.hcRealId,
    required this.hcCtId,
    required this.hcHasil,
    this.hcKondisi,
    this.hcKeterangan,
    this.templateItem,
  });

  factory ChecklistHasilModel.fromJson(Map<String, dynamic> j) =>
      ChecklistHasilModel(
        hcId: j['hc_id'],
        hcRealId: j['hc_real_id'],
        hcCtId: j['hc_ct_id'],
        hcHasil: j['hc_hasil'] ?? 'N/A',
        hcKondisi: j['hc_kondisi'],
        hcKeterangan: j['hc_keterangan'],
        templateItem: (j['template_item'] ?? j['hc_ct']) != null
            ? Map<String, dynamic>.from(j['template_item'] ?? j['hc_ct'])
            : null,
      );

  String get itemNama => templateItem?['ct_item'] ?? '-';
  int get urutan => templateItem?['ct_urutan'] ?? 0;
}

// Model untuk state pengisian checklist (sebelum disimpan)
class ChecklistInputModel {
  final int ctId;
  final String ctItem;
  final String? ctKeterangan;
  final int ctUrutan;
  String hasil = '';
  String? kondisi;
  String? keterangan;

  ChecklistInputModel({
    required this.ctId,
    required this.ctItem,
    this.ctKeterangan,
    required this.ctUrutan,
  });

  factory ChecklistInputModel.fromTemplate(Map<String, dynamic> j) =>
      ChecklistInputModel(
        ctId: j['ct_id'],
        ctItem: j['ct_item'] ?? '',
        ctKeterangan: j['ct_keterangan'],
        ctUrutan: j['ct_urutan'] ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'hc_ct_id': ctId,
        'hc_hasil': hasil,
        'hc_kondisi': kondisi,
        'hc_keterangan': keterangan,
      };
}
