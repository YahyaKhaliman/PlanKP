import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../models/checklist_hasil_model.dart';

class JadwalProvider extends ChangeNotifier {
  List<JadwalModel> jadwalList = [];
  List<JadwalModel> jadwalHariIni = [];
  List<RealisasiModel> realisasiList = [];
  RealisasiModel? realisasiDetail;
  JadwalModel? jadwalDetail;
  List<dynamic> inventarisByJenis = [];

  bool _loading = false;
  String? _error;
  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── JADWAL ─────────────────────────────────────────────────
  Future<void> fetchJadwal({String? status, String? jenis}) async {
    _setLoading(true);
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenis != null) 'jenis': jenis,
      };
      final res = await ApiClient.get(ApiConfig.jadwal, query: query);
      jadwalList =
          (res['data'] as List).map((e) => JadwalModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalHariIni() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.jadwal}/hari-ini');
      jadwalHariIni =
          (res['data'] as List).map((e) => JadwalModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalDetail(int id) async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.jadwal}/$id');
      jadwalDetail = JadwalModel.fromJson(res['data']['jadwal']);
      inventarisByJenis = List.from(res['data']['inventaris']);
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveJadwal(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('${ApiConfig.jadwal}/$id', body);
      else
        await ApiClient.post(ApiConfig.jadwal, body);
      await fetchJadwal();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> updateStatusJadwal(int id, String status) async {
    try {
      await ApiClient.patch(
          '${ApiConfig.jadwal}/$id/status', {'status': status});
      await fetchJadwal();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── REALISASI ──────────────────────────────────────────────
  Future<void> fetchRealisasi({int? jadwalId, String? status}) async {
    _setLoading(true);
    try {
      final query = <String, dynamic>{
        if (jadwalId != null) 'jadwal_id': jadwalId,
        if (status != null) 'status': status,
      };
      final res = await ApiClient.get(ApiConfig.realisasi, query: query);
      realisasiList =
          (res['data'] as List).map((e) => RealisasiModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchRealisasiDetail(int id) async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.realisasi}/$id');
      realisasiDetail = RealisasiModel.fromJson(res['data']);
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<RealisasiModel?> createRealisasi(Map<String, dynamic> body) async {
    try {
      final res = await ApiClient.post(ApiConfig.realisasi, body);
      return RealisasiModel.fromJson(res['data']);
    } on ApiException catch (e) {
      _setError(e.message);
      return null;
    }
  }

  Future<bool> saveChecklist(
      int realId, List<ChecklistInputModel> items) async {
    try {
      await ApiClient.post('${ApiConfig.realisasi}/$realId/checklist', {
        'hasil': items.map((e) => e.toJson()).toList(),
      });
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> saveTtd(int realId, String picNama, String ttdBase64) async {
    try {
      await ApiClient.post('${ApiConfig.realisasi}/$realId/ttd', {
        'real_ttd_pic_nama': picNama,
        'real_ttd_data': ttdBase64,
      });
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // Ambil template checklist untuk jenis inventaris tertentu
  Future<List<ChecklistInputModel>> fetchTemplate(String invJenis) async {
    try {
      final encoded = Uri.encodeComponent(invJenis);
      final res =
          await ApiClient.get('${ApiConfig.realisasi}/template/$encoded');
      return (res['data'] as List)
          .map((e) => ChecklistInputModel.fromTemplate(e))
          .toList();
    } on ApiException catch (_) {
      return [];
    }
  }
}
