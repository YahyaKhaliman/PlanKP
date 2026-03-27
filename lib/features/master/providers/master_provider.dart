import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../models/checklist_template_model.dart';
import '../models/divisi_model.dart';
import '../models/inventaris_model.dart';
import '../models/jenis_model.dart';
import '../models/user_model.dart';

class MasterProvider extends ChangeNotifier {
  List<InventarisModel> inventarisList = [];
  List<ChecklistTemplateModel> checklistList = [];
  List<UserModel> userList = [];
  List<DivisiModel> divisiList = [];
  List<JenisModel> jenisMaster = [];
  final Map<int, String> _jenisKategoriMap = {};
  Set<int> _jenisWithInventarisIds = {};

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

  // ── INVENTARIS ─────────────────────────────────────────────────
  String? kategoriByJenisId(int jenisId) => _jenisKategoriMap[jenisId];
  bool hasInventarisForJenis(int jenisId) =>
      _jenisWithInventarisIds.contains(jenisId);

  List<JenisModel> jenisAvailableForJadwal({int? includeJenisId}) {
    final includeId = includeJenisId;
    return jenisMaster.where((j) {
      if (includeId != null && j.jenisId == includeId) return true;
      return hasInventarisForJenis(j.jenisId);
    }).toList();
  }

  JenisModel? jenisById(int jenisId) {
    try {
      return jenisMaster.firstWhere((j) => j.jenisId == jenisId);
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchInventaris(
      {String? kategori,
      String? jenis,
      String? q,
      bool showLoading = true,
      bool updateKategoriMap = true}) async {
    if (showLoading) _setLoading(true);
    try {
      final query = {
        if (kategori != null) 'kategori': kategori,
        if (jenis != null) 'jenis': jenis,
        if (q != null) 'q': q,
      };
      final res = await ApiClient.get(ApiConfig.inventaris, query: query);
      inventarisList = (res['data'] as List)
          .map((e) => InventarisModel.fromJson(e))
          .toList();
      if (updateKategoriMap && jenisMaster.isNotEmpty) {
        _jenisKategoriMap
          ..clear()
          ..addEntries(
            jenisMaster.map((j) => MapEntry(j.jenisId, j.jenisKategori)),
          );
      }
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  Future<bool> saveInventaris(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('${ApiConfig.inventaris}/$id', body);
      else
        await ApiClient.post(ApiConfig.inventaris, body);
      await fetchInventaris();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleInventarisAktif(int id) async {
    try {
      await ApiClient.patch('${ApiConfig.inventaris}/$id/aktif', {});
      await fetchInventaris();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── DIVISI ──────────────────────────────────────────────────
  Future<void> fetchDivisi({bool showLoading = true}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.divisi);
      divisiList =
          (res['data'] as List).map((e) => DivisiModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  Future<bool> saveDivisi(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.divisi}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.divisi, body);
      }
      await fetchDivisi();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteDivisi(int id) async {
    try {
      await ApiClient.delete('${ApiConfig.divisi}/$id');
      await fetchDivisi();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── CHECKLIST TEMPLATE ─────────────────────────────────────────
  Future<void> fetchChecklist({String? jenis}) async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(
        ApiConfig.checklistTemplate,
        query: jenis != null ? {'jenis': jenis} : null,
      );
      if (kDebugMode) {
        debugPrint('[Checklist] fetched ${res['data']?.length ?? 0} rows'
            '${jenis != null ? ' for jenis=$jenis' : ''}');
      }
      checklistList = (res['data'] as List)
          .map((e) => ChecklistTemplateModel.fromJson(e))
          .toList();
      if (kDebugMode) {
        debugPrint(
            '[Checklist] provider list length = ${checklistList.length}');
      }
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchJenis({bool showLoading = false}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.jenis);
      jenisMaster =
          (res['data'] as List).map((e) => JenisModel.fromJson(e)).toList();
      _jenisKategoriMap
        ..clear()
        ..addEntries(
            jenisMaster.map((j) => MapEntry(j.jenisId, j.jenisKategori)));
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
    notifyListeners();
  }

  Future<void> fetchJenisWithInventaris({bool showLoading = false}) async {
    if (showLoading) _setLoading(true);
    try {
      final res = await ApiClient.get('${ApiConfig.inventaris}/jenis');
      final rawList = res['data'] as List;
      _jenisWithInventarisIds = rawList
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toSet();
      _setError(null);
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  Future<bool> saveJenis(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('${ApiConfig.jenis}/$id', body);
      } else {
        await ApiClient.post(ApiConfig.jenis, body);
      }
      await fetchJenis();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteJenis(int id) async {
    try {
      await ApiClient.delete('${ApiConfig.jenis}/$id');
      await fetchJenis();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> bulkCreateChecklist(
      String jenis, List<Map<String, dynamic>> items) async {
    try {
      await ApiClient.post('${ApiConfig.checklistTemplate}/bulk', {
        'ct_jenis_id': jenis,
        'items': items,
      });
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> saveChecklist(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('${ApiConfig.checklistTemplate}/$id', body);
      else
        await ApiClient.post(ApiConfig.checklistTemplate, body);
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteChecklist(int id) async {
    try {
      await ApiClient.delete('${ApiConfig.checklistTemplate}/$id');
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── USERS ──────────────────────────────────────────────────────
  Future<List<UserModel>> fetchUsers(
      {String? jabatan,
      String? divisi,
      String? kategori,
      bool showLoading = true,
      bool replaceState = true}) async {
    final toggleLoading = showLoading && replaceState;
    if (toggleLoading) _setLoading(true);
    try {
      final query = {
        if (jabatan != null) 'jabatan': jabatan,
        if (divisi != null) 'divisi': divisi,
        if (kategori != null) 'kategori': kategori,
      };
      final res = await ApiClient.get(ApiConfig.users,
          query: query.isEmpty ? null : query);
      final list =
          (res['data'] as List).map((e) => UserModel.fromJson(e)).toList();
      if (replaceState) {
        userList = list;
        _setError(null);
      }
      return list;
    } on ApiException catch (e) {
      if (replaceState) {
        _setError(e.message);
        return const [];
      }
      rethrow;
    } finally {
      if (toggleLoading) _setLoading(false);
    }
  }

  Future<bool> saveUser(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('${ApiConfig.users}/$id', body);
      else
        await ApiClient.post(ApiConfig.users, body);
      await fetchUsers();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleUserAktif(int id) async {
    try {
      await ApiClient.patch('${ApiConfig.users}/$id/aktif', {});
      await fetchUsers();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }
}
