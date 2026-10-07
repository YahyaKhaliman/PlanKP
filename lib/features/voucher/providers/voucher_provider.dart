import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../models/spbu_model.dart';
import '../models/voucher_model.dart';

class VoucherProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<VoucherModel> _vouchers = [];
  List<VoucherModel> get vouchers => _vouchers;

  List<VoucherModel> _pendingVouchers = [];
  List<VoucherModel> get pendingVouchers => _pendingVouchers;
  int get pendingCount => _pendingVouchers.length;

  bool _isLoadingPending = false;
  bool get isLoadingPending => _isLoadingPending;

  List<SpbuModel> _spbuList = [];
  List<SpbuModel> get spbuList => _spbuList;

  List<String> _bbmTypes = ['Pertalite', 'Pertamax', 'Solar', 'Dexlite'];
  List<String> get bbmTypes => _bbmTypes;

  List<Map<String, dynamic>> _eligibleInventaris = [];
  List<Map<String, dynamic>> get eligibleInventaris => _eligibleInventaris;

  String _selectedStatus = 'Semua';
  String get selectedStatus => _selectedStatus;

  void setSelectedStatus(String status) {
    if (_selectedStatus != status) {
      _selectedStatus = status;
      notifyListeners();
      fetchVouchers(status: status);
    }
  }

  Future<void> fetchPendingVouchers() async {
    _isLoadingPending = true;
    notifyListeners();

    try {
      final res = await ApiClient.get(ApiConfig.voucher, query: {'status': 'Menunggu', 'limit': 100});
      if (res['success'] == true) {
        final data = res['data'];
        final List items = data is Map ? (data['items'] ?? []) : (data is List ? data : []);
        _pendingVouchers = items.map((e) => VoucherModel.fromJson(e)).toList();
      } else {
        _pendingVouchers = [];
      }
    } catch (e) {
      debugPrint('[VoucherProvider] Error fetchPendingVouchers: $e');
      _pendingVouchers = [];
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  Future<void> fetchVouchers({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final query = <String, dynamic>{};
      final targetStatus = status ?? _selectedStatus;
      if (targetStatus != 'Semua') {
        query['status'] = targetStatus;
      }

      final res = await ApiClient.get(ApiConfig.voucher, query: query);
      if (res['success'] == true) {
        final data = res['data'];
        final List items = data is Map ? (data['items'] ?? []) : (data is List ? data : []);
        _vouchers = items.map((e) => VoucherModel.fromJson(e)).toList();
      } else {
        _errorMessage = res['message'] ?? 'Gagal memuat voucher';
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSpbuList() async {
    try {
      final res = await ApiClient.get(ApiConfig.voucherSpbu);
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        _spbuList = data.map((e) => SpbuModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetchSpbuList: $e');
    }
  }

  Future<void> fetchBbmTypes() async {
    try {
      final res = await ApiClient.get(ApiConfig.voucherBbmTypes);
      if (res['success'] == true && res['data'] is List) {
        _bbmTypes = List<String>.from(res['data']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetchBbmTypes: $e');
    }
  }

  Future<void> fetchEligibleInventaris({int? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final query = <String, dynamic>{};
      if (userId != null) query['user_id'] = userId;

      final res = await ApiClient.get(ApiConfig.voucherEligibleInv, query: query);
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        _eligibleInventaris = data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _eligibleInventaris = [];
      }
    } catch (e) {
      _eligibleInventaris = [];
      debugPrint('Error fetchEligibleInventaris: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createVoucher({
    required int invId,
    required int spbuId,
    required String jenisBbm,
    required double jumlahLiter,
    int? odometer,
    int? userIdTarget,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'voucher_inv_id': invId,
        'voucher_spbu_id': spbuId,
        'voucher_jenis_bbm': jenisBbm,
        'voucher_jumlah_liter': jumlahLiter,
      };
      if (odometer != null) body['voucher_odometer'] = odometer;
      if (userIdTarget != null) body['user_id_target'] = userIdTarget;

      final res = await ApiClient.post(ApiConfig.voucher, body);
      if (res['success'] == true) {
        await Future.wait([
          fetchVouchers(),
          fetchPendingVouchers(),
        ]);
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Gagal mengajukan voucher';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveVoucher({
    required int voucherId,
    required String noBon,
    int? spbuId,
    String? jenisBbm,
    double? jumlahLiter,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'voucher_no_bon': noBon,
      };
      if (spbuId != null) body['voucher_spbu_id'] = spbuId;
      if (jenisBbm != null) body['voucher_jenis_bbm'] = jenisBbm;
      if (jumlahLiter != null) body['voucher_jumlah_liter'] = jumlahLiter;

      final res = await ApiClient.put('${ApiConfig.voucher}/$voucherId/approve', body);
      if (res['success'] == true) {
        await Future.wait([
          fetchVouchers(),
          fetchPendingVouchers(),
        ]);
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Gagal menyetujui voucher';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> rejectVoucher(int voucherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.put('${ApiConfig.voucher}/$voucherId/reject', {});
      if (res['success'] == true) {
        await Future.wait([
          fetchVouchers(),
          fetchPendingVouchers(),
        ]);
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Gagal menolak voucher';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
