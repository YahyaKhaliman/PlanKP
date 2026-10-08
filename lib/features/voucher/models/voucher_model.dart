import 'spbu_model.dart';

class VoucherModel {
  final int voucherId;
  final String? voucherNoBon;
  final int voucherUserId;
  final int voucherInvId;
  final int voucherSpbuId;
  final String voucherJenisBbm;
  final double voucherJumlahLiter;
  final int? voucherOdometer;
  final String voucherStatus;
  final int? voucherApprovedBy;
  final DateTime? voucherApprovedAt;
  final DateTime voucherCreatedAt;

  // Relasi nested
  final Map<String, dynamic>? pemohon;
  final Map<String, dynamic>? inventaris;
  final SpbuModel? spbu;
  final Map<String, dynamic>? approver;

  VoucherModel({
    required this.voucherId,
    this.voucherNoBon,
    required this.voucherUserId,
    required this.voucherInvId,
    required this.voucherSpbuId,
    required this.voucherJenisBbm,
    required this.voucherJumlahLiter,
    this.voucherOdometer,
    required this.voucherStatus,
    this.voucherApprovedBy,
    this.voucherApprovedAt,
    required this.voucherCreatedAt,
    this.pemohon,
    this.inventaris,
    this.spbu,
    this.approver,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      voucherId: json['voucher_id'] is int ? json['voucher_id'] : int.tryParse('${json['voucher_id']}') ?? 0,
      voucherNoBon: json['voucher_no_bon']?.toString(),
      voucherUserId: json['voucher_user_id'] is int ? json['voucher_user_id'] : int.tryParse('${json['voucher_user_id']}') ?? 0,
      voucherInvId: json['voucher_inv_id'] is int ? json['voucher_inv_id'] : int.tryParse('${json['voucher_inv_id']}') ?? 0,
      voucherSpbuId: json['voucher_spbu_id'] is int ? json['voucher_spbu_id'] : int.tryParse('${json['voucher_spbu_id']}') ?? 0,
      voucherJenisBbm: json['voucher_jenis_bbm']?.toString() ?? 'Pertalite',
      voucherJumlahLiter: (json['voucher_jumlah_liter'] is num)
          ? (json['voucher_jumlah_liter'] as num).toDouble()
          : double.tryParse('${json['voucher_jumlah_liter']}') ?? 0.0,
      voucherOdometer: json['voucher_odometer'] != null ? int.tryParse('${json['voucher_odometer']}') : null,
      voucherStatus: json['voucher_status']?.toString() ?? 'Menunggu',
      voucherApprovedBy: json['voucher_approved_by'] != null ? int.tryParse('${json['voucher_approved_by']}') : null,
      voucherApprovedAt: json['voucher_approved_at'] != null
          ? (DateTime.tryParse('${json['voucher_approved_at']}')?.toLocal())
          : null,
      voucherCreatedAt: json['voucher_created_at'] != null
          ? (DateTime.tryParse('${json['voucher_created_at']}')?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
      pemohon: json['pemohon'] is Map<String, dynamic> ? json['pemohon'] : null,
      inventaris: json['inventaris'] is Map<String, dynamic> ? json['inventaris'] : null,
      spbu: json['spbu'] is Map<String, dynamic> ? SpbuModel.fromJson(json['spbu']) : null,
      approver: json['approver'] is Map<String, dynamic> ? json['approver'] : null,
    );
  }

  String get namaPemohon => pemohon?['user_nama'] ?? 'Driver';
  String get noPolisi {
    final sn = inventaris?['inv_serial_number']?.toString().trim();
    if (sn != null && sn.isNotEmpty) return sn;
    return '-';
  }
  String get namaInventaris => inventaris?['inv_nama'] ?? '-';
  String get namaSpbu => spbu?.spbuNama ?? '-';
}
