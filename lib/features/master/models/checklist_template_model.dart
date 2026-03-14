class ChecklistTemplateModel {
  final int    ctId;
  final String ctInvJenis;
  final String ctItem;
  final String? ctKeterangan;
  final int    ctUrutan;
  final int    ctIsActive;

  ChecklistTemplateModel({
    required this.ctId,
    required this.ctInvJenis,
    required this.ctItem,
    this.ctKeterangan,
    required this.ctUrutan,
    required this.ctIsActive,
  });

  factory ChecklistTemplateModel.fromJson(Map<String, dynamic> j) => ChecklistTemplateModel(
    ctId:          j['ct_id'],
    ctInvJenis:    j['ct_inv_jenis'] ?? '',
    ctItem:        j['ct_item']      ?? '',
    ctKeterangan:  j['ct_keterangan'],
    ctUrutan:      j['ct_urutan']    ?? 1,
    ctIsActive:    j['ct_is_active'] ?? 1,
  );
}
