import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../models/checklist_template_model.dart';
import '../models/divisi_model.dart';
import '../models/inventaris_model.dart';
import '../models/user_model.dart';

class MasterProvider extends ChangeNotifier {
  List<InventarisModel> inventarisList = [];
  List<ChecklistTemplateModel> checklistList = [];
  List<UserModel> userList = [];
  List<DivisiModel> divisiList = [];
  List<String> jenisChecklist = [];

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
      final query = {
        if (kategori != null) 'kategori': kategori,
        if (jenis != null) 'jenis': jenis,
        if (q != null) 'q': q,
      };
      final res = await ApiClient.get(ApiConfig.inventaris, query: query);
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
  Future<void> fetchDivisi() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiConfig.divisi);
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

  Future<void> fetchJenis() async {
    try {
      final res = await ApiClient.get('${ApiConfig.inventaris}/jenis');
      jenisChecklist = List<String>.from(res['data'] ?? []);
      notifyListeners();
    } on ApiException catch (e) {
      _setError(e.message);
    }
  }

  Future<bool> bulkCreateChecklist(
      String jenis, List<Map<String, dynamic>> items) async {
    try {
      await ApiClient.post('${ApiConfig.checklistTemplate}/bulk', {
        'ct_inv_jenis': jenis,
        'items': items,
      });
      await fetchChecklist();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    }
  }

  Future<bool> reorderChecklist(List<Map<String, dynamic>> orders) async {
    try {
      await ApiClient.patch('${ApiConfig.checklistTemplate}/reorder', {
        'orders': orders,
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
  Future<void> fetchUsers({String? jabatan}) async {
    _setLoading(true);
    try {
      final query = jabatan != null ? {'jabatan': jabatan} : null;
      final res = await ApiClient.get(ApiConfig.users, query: query);
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
