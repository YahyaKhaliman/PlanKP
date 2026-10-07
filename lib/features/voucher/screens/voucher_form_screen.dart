// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../master/providers/master_provider.dart';
import '../../master/models/user_model.dart';
import '../providers/voucher_provider.dart';

class VoucherFormScreen extends StatefulWidget {
  final int? targetUserId;

  const VoucherFormScreen({super.key, this.targetUserId});

  @override
  State<VoucherFormScreen> createState() => _VoucherFormScreenState();
}

class _VoucherFormScreenState extends State<VoucherFormScreen> {
  static const _kPageBg = AppColors.surface;
  final _formKey = GlobalKey<FormState>();

  int? _targetUserId;
  int? _selectedInvId;
  int? _selectedSpbuId;
  String _selectedBbm = 'Pertalite';
  final _literCtrl = TextEditingController(text: '2.0');
  final _odometerCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final isAdmin = role == 'admin' || role == 'manager';
    final master = context.read<MasterProvider>();
    final p = context.read<VoucherProvider>();

    if (isAdmin) {
      await master.fetchUsers(showLoading: false);
      if (widget.targetUserId != null) {
        _targetUserId = widget.targetUserId;
      } else if (_targetUserId == null) {
        // Prioritaskan user dengan divisi DRIVER
        final drivers = master.userList
            .where((u) => u.userDivisi.trim().toUpperCase() == 'DRIVER')
            .toList();
        if (drivers.isNotEmpty) {
          _targetUserId = drivers.first.userId;
        } else if (master.userList.isNotEmpty) {
          _targetUserId = master.userList.first.userId;
        }
      }
    } else {
      _targetUserId = auth.user?['user_id'];
    }

    await Future.wait([
      p.fetchSpbuList(),
      p.fetchBbmTypes(),
      p.fetchEligibleInventaris(userId: _targetUserId),
    ]);

    if (mounted) {
      if (p.spbuList.isNotEmpty && _selectedSpbuId == null) {
        setState(() => _selectedSpbuId = p.spbuList.first.spbuId);
      }
      if (p.eligibleInventaris.isNotEmpty && _selectedInvId == null) {
        setState(() => _selectedInvId = p.eligibleInventaris.first['inv_id']);
      }
      if (p.bbmTypes.isNotEmpty) {
        setState(() => _selectedBbm = p.bbmTypes.first);
      }
    }
  }

  Future<void> _onTargetUserChanged(int? newUserId) async {
    if (newUserId == null || newUserId == _targetUserId) return;
    setState(() {
      _targetUserId = newUserId;
      _selectedInvId = null;
    });

    final p = context.read<VoucherProvider>();
    await p.fetchEligibleInventaris(userId: newUserId);

    if (mounted && p.eligibleInventaris.isNotEmpty) {
      setState(() {
        _selectedInvId = p.eligibleInventaris.first['inv_id'];
      });
    }
  }

  @override
  void dispose() {
    _literCtrl.dispose();
    _odometerCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final auth = context.read<AuthProvider>();
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final isAdmin = role == 'admin' || role == 'manager';

    if (!_formKey.currentState!.validate()) return;

    if (isAdmin && _targetUserId == null) {
      AppNotifier.showError(context, 'Pilih driver pemohon terlebih dahulu');
      return;
    }

    if (_selectedInvId == null) {
      AppNotifier.showError(context, 'Pilih kendaraan operasional');
      return;
    }
    if (_selectedSpbuId == null) {
      AppNotifier.showError(context, 'Pilih SPBU tujuan');
      return;
    }

    final liter = double.tryParse(_literCtrl.text.trim());
    if (liter == null || liter <= 0) {
      AppNotifier.showError(context, 'Jumlah liter tidak valid');
      return;
    }
    if (liter > 100) {
      AppNotifier.showError(context, 'Jumlah liter maksimal 100 liter');
      return;
    }

    final odo = int.tryParse(_odometerCtrl.text.trim());

    setState(() => _isSubmitting = true);
    final p = context.read<VoucherProvider>();
    final success = await p.createVoucher(
      invId: _selectedInvId!,
      spbuId: _selectedSpbuId!,
      jenisBbm: _selectedBbm,
      jumlahLiter: liter,
      odometer: odo,
      userIdTarget: isAdmin ? _targetUserId : null,
    );
    setState(() => _isSubmitting = false);

    if (success) {
      await AppNotifier.showSuccess(
        context,
        'Permintaan voucher BBM berhasil diajukan',
      );
      if (mounted) Navigator.of(context).pop(true);
    } else {
      AppNotifier.showError(
        context,
        p.errorMessage ?? 'Gagal mengajukan permintaan voucher',
      );
    }
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Text.rich(
      TextSpan(
        text: label,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        children: isRequired
            ? [
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.danger,
                  ),
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final voucherProvider = context.watch<VoucherProvider>();
    final master = context.watch<MasterProvider>();
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final isAdmin = role == 'admin' || role == 'manager';
    final eligibleInvs = voucherProvider.eligibleInventaris;

    // Filter list user untuk admin (urutkan divisi Driver di atas)
    final sortedUserList = List<UserModel>.from(master.userList)
      ..sort((a, b) {
        final aIsDriver = a.userDivisi.trim().toUpperCase() == 'DRIVER';
        final bIsDriver = b.userDivisi.trim().toUpperCase() == 'DRIVER';
        if (aIsDriver && !bIsDriver) return -1;
        if (!aIsDriver && bIsDriver) return 1;
        return a.userNama.compareTo(b.userNama);
      });

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        title: Text(
            isAdmin ? 'Pengajuan Voucher (Admin)' : 'Pengajuan Voucher BBM'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxFormWidth = AppBreakpoints.responsiveValue(
            context,
            mobile: constraints.maxWidth,
            tablet: 580.0,
            desktop: 580.0,
          );

          return Center(
            child: SizedBox(
              width: maxFormWidth,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppBreakpoints.isDesktop(context) ? 0 : 16,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Profil / Pemilihan Pemohon
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x060F172A),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Driver / Pemohon',
                                  isRequired: true),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _targetUserId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                      size: 18),
                                  hintText: 'Pilih driver pemohon',
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                items: sortedUserList.map((u) {
                                  final isDriver =
                                      u.userDivisi.trim().toUpperCase() ==
                                          'DRIVER';
                                  return DropdownMenuItem<int>(
                                    value: u.userId,
                                    child: Text(
                                      '${u.userNama} (${u.userDivisi}) • NIK: ${u.userNik}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: isDriver
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isDriver
                                            ? const Color(0xFF0F766E)
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _onTargetUserChanged,
                              ),
                            ],
                          ),
                        )
                      else
                        // Tampilan untuk Driver biasa
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x060F172A),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488)
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: Color(0xFF0D9488),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.user?['user_nama'] ?? 'Driver',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Divisi: ${auth.user?['user_divisi'] ?? '-'} • NIK: ${auth.user?['user_nik'] ?? '-'}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

                      // 2. Form Isian Utama Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x060F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Kendaraan Inventaris ---
                            _buildFieldLabel('Kendaraan Operasional',
                                isRequired: true),
                            const SizedBox(height: 6),
                            if (voucherProvider.isLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              )
                            else if (eligibleInvs.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                      color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        isAdmin
                                            ? 'Driver belum memiliki jadwal aktif dengan realisasi berstatus "Selesai" periode ini.'
                                            : 'Belum ada jadwal aktif dengan realisasi berstatus "Selesai" periode ini.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: const Color(0xFF991B1B),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              DropdownButtonFormField<int>(
                                value: _selectedInvId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                      Icons.directions_car_rounded,
                                      size: 18),
                                  hintText: 'Pilih kendaraan terjadwal',
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                items: eligibleInvs.map((inv) {
                                  final nama =
                                      inv['inv_nama']?.toString().trim() ?? '';
                                  final sn = (inv['inv_serial_number'] ?? '')
                                      .toString()
                                      .trim();
                                  final label =
                                      sn.isNotEmpty ? '$nama ($sn)' : nama;
                                  return DropdownMenuItem<int>(
                                    value: inv['inv_id'],
                                    child: Text(
                                      label,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedInvId = val),
                              ),
                            const SizedBox(height: 16),

                            // --- Odometer / KM Kendaraan ---
                            _buildFieldLabel('Odometer (KM)'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _odometerCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.speed_rounded, size: 18),
                                hintText: 'Masukkan odometer terkini',
                                suffixText: 'KM',
                                suffixStyle: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // --- SPBU ---
                            _buildFieldLabel('SPBU Tujuan', isRequired: true),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: _selectedSpbuId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.storefront_rounded,
                                    size: 18),
                                hintText: 'Pilih SPBU',
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              selectedItemBuilder: (context) {
                                return voucherProvider.spbuList.map((s) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      s.spbuNama,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList();
                              },
                              items: voucherProvider.spbuList.map((s) {
                                final hasAlamat = s.spbuAlamat != null &&
                                    s.spbuAlamat!.trim().isNotEmpty;
                                return DropdownMenuItem<int>(
                                  value: s.spbuId,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.spbuNama,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (hasAlamat)
                                        Text(
                                          s.spbuAlamat!.trim(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedSpbuId = val),
                            ),
                            const SizedBox(height: 16),

                            // --- Jenis BBM ---
                            _buildFieldLabel('Jenis BBM', isRequired: true),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: voucherProvider.bbmTypes.map((type) {
                                final isSelected = _selectedBbm == type;
                                return ChoiceChip(
                                  label: Text(type),
                                  selected: isSelected,
                                  selectedColor: AppColors.primarySoft,
                                  backgroundColor: Colors.white,
                                  labelStyle: GoogleFonts.plusJakartaSans(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                    ),
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedBbm = type);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // --- Jumlah Liter ---
                            _buildFieldLabel('Jumlah Liter BBM',
                                isRequired: true),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _literCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*')),
                              ],
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                    Icons.local_gas_station_rounded,
                                    size: 18),
                                suffixText: 'Liter',
                                suffixStyle: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Jumlah liter wajib diisi';
                                }
                                final num = double.tryParse(val.trim());
                                if (num == null || num <= 0) {
                                  return 'Masukkan angka lebih dari 0';
                                }
                                if (num > 100) {
                                  return 'Jumlah liter maksimal 100 liter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: ['1', '2', '3', '4', '5'].map((l) {
                                return ActionChip(
                                  label: Text('$l L'),
                                  labelStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full),
                                    side: const BorderSide(
                                        color: AppColors.border),
                                  ),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  onPressed: () {
                                    setState(() => _literCtrl.text = '$l.0');
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Tombol Submit
                      ElevatedButton.icon(
                        onPressed: (_isSubmitting || eligibleInvs.isEmpty)
                            ? null
                            : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Ajukan Permintaan Voucher',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
