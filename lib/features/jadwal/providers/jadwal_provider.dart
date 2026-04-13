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
  bool _loadingDetail = false;
  String? _error;
  bool _lastFetchDivisi = false;
  bool _lastFetchUser = false;
  String? _lastJadwalStatus;
  String? _lastJadwalJenis;
  int? _lastJadwalJenisId;
  bool get loading => _loading;
  bool get loadingDetail => _loadingDetail;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setLoadingDetail(bool v) {
    _loadingDetail = v;
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
    _lastFetchDivisi = false;
    _lastFetchUser = false;
    _lastJadwalStatus = status;
    _lastJadwalJenis = jenis;
    _lastJadwalJenisId = null;
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenis != null) 'jenis': jenis,
      };
      final res = await ApiClient.get(ApiConfig.jadwal, query: query);
      jadwalList = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalByDivisi({String? status, int? jenisId}) async {
    _setLoading(true);
    _lastFetchDivisi = true;
    _lastFetchUser = false;
    _lastJadwalStatus = status;
    _lastJadwalJenis = null;
    _lastJadwalJenisId = jenisId;
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenisId != null) 'jenis': jenisId,
      };
      final res =
          await ApiClient.get('${ApiConfig.jadwal}/divisi', query: query);
      jadwalList = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalByUser({String? status, int? jenisId}) async {
    _setLoading(true);
    _lastFetchUser = true;
    _lastFetchDivisi = false;
    _lastJadwalStatus = status;
    _lastJadwalJenis = null;
    _lastJadwalJenisId = jenisId;
    try {
      final query = <String, dynamic>{
        if (status != null) 'status': status,
        if (jenisId != null) 'jenis': jenisId,
      };
      final res =
          await ApiClient.get('${ApiConfig.jadwal}/assigned', query: query);
      jadwalList = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
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
      jadwalHariIni = ((res['data']['items'] ?? []) as List)
          .map((e) => JadwalModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJadwalDetail(int id,
      {bool affectGlobalLoading = true}) async {
    if (affectGlobalLoading) {
      _setLoading(true);
    } else {
      _setLoadingDetail(true);
    }
    try {
      final res = await ApiClient.get('${ApiConfig.jadwal}/$id');
      jadwalDetail = JadwalModel.fromJson(res['data']['jadwal']);
      inventarisByJenis = List.from(res['data']['inventaris']);
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (affectGlobalLoading) {
        _setLoading(false);
      } else {
        _setLoadingDetail(false);
      }
    }
  }

  Future<bool> saveJadwal(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.jadwal}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.jadwal, body);
      }
      if (_lastFetchUser) {
        await fetchJadwalByUser(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else if (_lastFetchDivisi) {
        await fetchJadwalByDivisi(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else {
        await fetchJadwal(status: _lastJadwalStatus, jenis: _lastJadwalJenis);
      }
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
      if (_lastFetchUser) {
        await fetchJadwalByUser(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else if (_lastFetchDivisi) {
        await fetchJadwalByDivisi(
          status: _lastJadwalStatus,
          jenisId: _lastJadwalJenisId,
        );
      } else {
        await fetchJadwal(status: _lastJadwalStatus, jenis: _lastJadwalJenis);
      }
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── REALISASI ──────────────────────────────────────────────
  Future<void> fetchRealisasi({
    int? jadwalId,
    String? status,
    bool byDivisi = false,
  }) async {
    _setLoading(true);
    try {
      final query = <String, dynamic>{
        if (jadwalId != null) 'jadwal_id': jadwalId,
        if (status != null) 'status': status,
        if (byDivisi) 'by_divisi': true,
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

  /// Fetch realisasi for a specific jadwal WITHOUT modifying [realisasiList].
  /// Use this when you only need the result temporarily (e.g. inventory picker)
  /// so that the dashboard's "remaining days" calculation is not disrupted.
  Future<List<RealisasiModel>> fetchRealisasiByJadwal(int jadwalId,
      {String? status}) async {
    try {
      final query = <String, dynamic>{
        'jadwal_id': jadwalId,
        if (status != null) 'status': status,
      };
      final res = await ApiClient.get(ApiConfig.realisasi, query: query);
      return (res['data'] as List)
          .map((e) => RealisasiModel.fromJson(e))
          .toList();
    } on ApiException {
      return [];
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
  Future<List<ChecklistInputModel>> fetchTemplate(int jenisId) async {
    try {
      final res =
          await ApiClient.get('${ApiConfig.realisasi}/template/$jenisId');
      _setError(null);
      return (res['data'] as List)
          .map((e) => ChecklistInputModel.fromTemplate(e))
          .toList();
    } on ApiException catch (e) {
      _setError(e.message);
      return [];
    }
  }
}
