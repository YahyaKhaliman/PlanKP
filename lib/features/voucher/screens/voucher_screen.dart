// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/voucher_model.dart';
import '../providers/voucher_provider.dart';
import '../widgets/voucher_bon_dialog.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  static const _kPageBg = AppColors.surface;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final List<String> _filterTabs = [
    'Semua',
    'Menunggu',
    'Disetujui',
    'Ditolak'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<VoucherProvider>();
      p.fetchVouchers();
      p.fetchSpbuList();
      p.fetchBbmTypes();
    });
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<VoucherModel> _filterVouchers(List<VoucherModel> rawList) {
    if (_searchQuery.isEmpty) return rawList;
    return rawList.where((v) {
      final noBon = (v.voucherNoBon ?? '').toLowerCase();
      final invNama = v.namaInventaris.toLowerCase();
      final noPol = v.noPolisi.toLowerCase();
      final spbu = v.namaSpbu.toLowerCase();
      final pemohon = v.namaPemohon.toLowerCase();
      final bbm = v.voucherJenisBbm.toLowerCase();

      return noBon.contains(_searchQuery) ||
          invNama.contains(_searchQuery) ||
          noPol.contains(_searchQuery) ||
          spbu.contains(_searchQuery) ||
          pemohon.contains(_searchQuery) ||
          bbm.contains(_searchQuery);
    }).toList();
  }

  int _countByStatus(List<VoucherModel> list, String status) {
    if (status == 'Semua') return list.length;
    return list
        .where((v) => v.voucherStatus.toLowerCase() == status.toLowerCase())
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final p = context.watch<VoucherProvider>();
    final role = auth.user?['user_jabatan']?.toString().toLowerCase() ?? '';
    final divisi = auth.user?['user_divisi']?.toString().toUpperCase() ?? '';
    final isAdmin = role == 'admin' || role == 'manager';
    final isDriver = divisi == 'DRIVER';

    final filteredList = _filterVouchers(p.vouchers);

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        title: const Text('Voucher BBM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => p.fetchVouchers(),
          ),
        ],
      ),
      floatingActionButton: (isDriver || isAdmin)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result =
                    await Navigator.pushNamed(context, AppRoutes.voucherForm);
                if (result == true) {
                  p.fetchVouchers();
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Ajukan Voucher',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = AppBreakpoints.responsiveValue(
            context,
            mobile: constraints.maxWidth,
            tablet: constraints.maxWidth > 880 ? 860.0 : constraints.maxWidth,
            desktop: 1180.0,
          );

          return Center(
            child: SizedBox(
              width: maxContentWidth,
              child: Column(
                children: [
                  // 1. Search Bar & Status Filters
                  Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.fromLTRB(
                      AppBreakpoints.isDesktop(context) ? 0 : 12,
                      12,
                      AppBreakpoints.isDesktop(context) ? 0 : 12,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Box
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.border, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x040F172A),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: isAdmin
                                  ? 'Cari no. bon, driver, kendaraan, SPBU...'
                                  : 'Cari kendaraan, no. bon, SPBU, jenis BBM...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _filterTabs.map((tab) {
                              final isSelected = p.selectedStatus == tab;
                              final count = _countByStatus(p.vouchers, tab);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    tab == 'Semua'
                                        ? 'Semua ($count)'
                                        : '$tab ($count)',
                                  ),
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
                                    if (selected) p.setSelectedStatus(tab);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Info Counter Header
                  if (!p.isLoading && filteredList.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppBreakpoints.isDesktop(context) ? 4 : 16,
                        4,
                        AppBreakpoints.isDesktop(context) ? 4 : 16,
                        8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Menampilkan ${filteredList.length} voucher',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (_searchQuery.isNotEmpty)
                            Text(
                              'Hasil pencarian "$_searchQuery"',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // 3. List Content
                  Expanded(
                    child: p.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : filteredList.isEmpty
                            ? _searchQuery.isNotEmpty
                                ? EmptyState(
                                    message:
                                        'Tidak ada voucher yang cocok dengan pencarian "$_searchQuery"',
                                    actionLabel: 'Reset Pencarian',
                                    onAction: () => _searchCtrl.clear(),
                                  )
                                : EmptyState(
                                    message: p.selectedStatus == 'Semua'
                                        ? 'Belum ada data voucher BBM'
                                        : 'Tidak ada voucher dengan status "${p.selectedStatus}"',
                                    actionLabel: (isDriver || isAdmin)
                                        ? 'Ajukan Sekarang'
                                        : null,
                                    onAction: (isDriver || isAdmin)
                                        ? () async {
                                            final res =
                                                await Navigator.pushNamed(
                                              context,
                                              AppRoutes.voucherForm,
                                            );
                                            if (res == true) p.fetchVouchers();
                                          }
                                        : null,
                                  )
                            : RefreshIndicator(
                                onRefresh: () => p.fetchVouchers(),
                                child: ListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    AppBreakpoints.isDesktop(context) ? 0 : 12,
                                    4,
                                    AppBreakpoints.isDesktop(context) ? 0 : 12,
                                    90,
                                  ),
                                  itemCount: filteredList.length,
                                  itemBuilder: (context, index) {
                                    final voucher = filteredList[index];
                                    return _buildVoucherCard(voucher, isAdmin);
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoucherCard(VoucherModel voucher, bool isAdmin) {
    final statusColor = _getStatusColor(voucher.voucherStatus);
    final hasNoBon =
        voucher.voucherNoBon != null && voucher.voucherNoBon!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await VoucherBonDialog.show(context,
                voucher: voucher, isAdmin: isAdmin);
            if (!context.mounted) return;
            if (result == 'approved') {
              AppNotifier.showSuccess(
                  context, 'Voucher berhasil disetujui & nomor bon tercatat');
              context.read<VoucherProvider>().fetchVouchers();
            } else if (result == 'rejected') {
              AppNotifier.showSuccess(context, 'Voucher telah ditolak');
              context.read<VoucherProvider>().fetchVouchers();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Baris: No Bon & Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasNoBon
                            ? AppColors.primarySoft
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: hasNoBon
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 13,
                            color: hasNoBon
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasNoBon
                                ? 'No. Permintaan: ${voucher.voucherNoBon}'
                                : 'Menunggu No. Permintaan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasNoBon
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            voucher.voucherStatus,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Baris Info: Kendaraan & BBM
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488)
                            .withValues(alpha: 0.1), // Driver Teal
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Color(0xFF0D9488),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                voucher.namaInventaris,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppColors.border,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  voucher.noPolisi,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${voucher.voucherJenisBbm} • ${voucher.voucherJumlahLiter.toStringAsFixed(1)} L',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                              if (voucher.voucherOdometer != null) ...[
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.speed_rounded,
                                      size: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${voucher.voucherOdometer} KM',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_gas_station_rounded,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  voucher.namaSpbu,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),

                // Footer Baris: Pemohon & Tanggal
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 13.5,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      voucher.namaPemohon,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${voucher.voucherCreatedAt.day.toString().padLeft(2, '0')}-${voucher.voucherCreatedAt.month.toString().padLeft(2, '0')}-${voucher.voucherCreatedAt.year}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'selesai':
        return AppColors.success;
      case 'ditolak':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }
}
