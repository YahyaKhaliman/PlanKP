import 'package:flutter/foundation.dart';
import '../../../core/utils/api_client.dart';
import '../models/inventaris_model.dart';
import '../models/checklist_template_model.dart';
import '../models/user_model.dart';
import '../models/divisi_model.dart';
import '../models/mesin_model.dart';

class MasterProvider extends ChangeNotifier {
  List<InventarisModel> inventarisList = [];
  List<ChecklistTemplateModel> checklistList = [];
  List<UserModel> userList = [];
  List<DivisiModel> divisiList = [];
  List<MesinModel> mesinList = [];

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
  Future<void> fetchInventaris(
      {String? kategori, String? jenis, String? q}) async {
    _setLoading(true);
    try {
      final params = <String>[];
      if (kategori != null) params.add('kategori=$kategori');
      if (jenis != null) params.add('jenis=$jenis');
      if (q != null) params.add('q=$q');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiClient.get('/master/inventaris$query');
      inventarisList = (res['data'] as List)
          .map((e) => InventarisModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  // ── MESIN ──────────────────────────────────────────────────────
  Future<void> fetchMesin() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('/master/mesin');
      mesinList =
          (res['data'] as List).map((e) => MesinModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveMesin(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('/master/mesin/$id', body);
      } else {
        await ApiClient.post('/master/mesin', body);
      }
      await fetchMesin();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleMesinAktif(int id) async {
    try {
      await ApiClient.patch('/master/mesin/$id/aktif', {});
      await fetchMesin();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> saveInventaris(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('/master/inventaris/$id', body);
      else
        await ApiClient.post('/master/inventaris', body);
      await fetchInventaris();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleInventarisAktif(int id) async {
    try {
      await ApiClient.patch('/master/inventaris/$id/aktif', {});
      await fetchInventaris();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── DIVISI ──────────────────────────────────────────────────
  Future<void> fetchDivisi() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get('/master/divisi');
      divisiList =
          (res['data'] as List).map((e) => DivisiModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveDivisi(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null) {
        await ApiClient.put('/master/divisi/$id', body);
      } else {
        await ApiClient.post('/master/divisi', body);
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
      await ApiClient.delete('/master/divisi/$id');
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
      final query = jenis != null ? '?jenis=$jenis' : '';
      final res = await ApiClient.get('/master/checklist-template$query');
      checklistList = (res['data'] as List)
          .map((e) => ChecklistTemplateModel.fromJson(e))
          .toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveChecklist(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('/master/checklist-template/$id', body);
      else
        await ApiClient.post('/master/checklist-template', body);
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> deleteChecklist(int id) async {
    try {
      await ApiClient.delete('/master/checklist-template/$id');
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  // ── USERS ──────────────────────────────────────────────────────
  Future<void> fetchUsers({String? jabatan}) async {
    _setLoading(true);
    try {
      final query = jabatan != null ? '?jabatan=$jabatan' : '';
      final res = await ApiClient.get('/master/users$query');
      userList =
          (res['data'] as List).map((e) => UserModel.fromJson(e)).toList();
      _setError(null);
    } on ApiException catch (e) {
      _setError(e.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveUser(Map<String, dynamic> body, {int? id}) async {
    try {
      if (id != null)
        await ApiClient.put('/master/users/$id', body);
      else
        await ApiClient.post('/master/users', body);
      await fetchUsers();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> toggleUserAktif(int id) async {
    try {
      await ApiClient.patch('/master/users/$id/aktif', {});
      await fetchUsers();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }
}
