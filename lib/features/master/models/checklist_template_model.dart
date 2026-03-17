class ChecklistTemplateModel {
  final int ctId;
  final String ctInvJenis;
  final String? ctDivisi;
  final String ctItem;
  final String? ctKeterangan;
  final int ctUrutan;
  final bool ctIsActive;

  ChecklistTemplateModel({
    required this.ctId,
    required this.ctInvJenis,
    this.ctDivisi,
    required this.ctItem,
    this.ctKeterangan,
    required this.ctUrutan,
    required this.ctIsActive,
  });

  factory ChecklistTemplateModel.fromJson(Map<String, dynamic> j) =>
      ChecklistTemplateModel(
        ctId: j['ct_id'],
        ctInvJenis: j['ct_inv_jenis'] ?? '',
        ctDivisi: j['ct_divisi'],
        ctItem: j['ct_item'] ?? '',
        ctKeterangan: j['ct_keterangan'],
        ctUrutan: j['ct_urutan'] ?? 1,
        ctIsActive: _mapBool(j['ct_is_active']),
      );

  static bool _mapBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return true;
  }
}
