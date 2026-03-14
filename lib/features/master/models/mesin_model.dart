import 'jenis_mesin_model.dart';

class MesinModel {
  final int mesinId;
  final String mesinNoInventaris;
  final String mesinNama;
  final int mesinJenisId;
  final String mesinLokasi;
  final int mesinIsActive;
  final String? mesinNotes;
  final JenisMesinModel? jenisMesin;

  MesinModel({
    required this.mesinId,
    required this.mesinNoInventaris,
    required this.mesinNama,
    required this.mesinJenisId,
    required this.mesinLokasi,
    required this.mesinIsActive,
    this.mesinNotes,
    this.jenisMesin,
  });

  bool get isActive => mesinIsActive == 1;

  factory MesinModel.fromJson(Map<String, dynamic> j) => MesinModel(
    mesinId:            j['mesin_id'],
    mesinNoInventaris:  j['mesin_no_inventaris'],
    mesinNama:          j['mesin_nama'],
    mesinJenisId:       j['mesin_jenis_id'],
    mesinLokasi:        j['mesin_lokasi'],
    mesinIsActive:      j['mesin_is_active'],
    mesinNotes:         j['mesin_notes'],
    jenisMesin: j['jenis_mesin'] != null ? JenisMesinModel.fromJson(j['jenis_mesin']) : null,
  );
}