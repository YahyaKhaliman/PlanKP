// ignore_for_file: prefer_const_constructors, deprecated_member_use, curly_braces_in_flow_control_structures, dead_null_aware_expression, control_flow_in_finally

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../../../core/widgets/app_notifier.dart';
import '../widgets/realisasi_detail_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/responsive_sheet.dart';
import '../../../core/utils/date_formatter.dart';
import '../widgets/export_pdf_dialog.dart';

class RealisasiHistoryScreen extends StatefulWidget {
  final String? initialTab;
  const RealisasiHistoryScreen({super.key, this.initialTab});

  @override
  State<RealisasiHistoryScreen> createState() => _RealisasiHistoryScreenState();
}

class _RealisasiHistoryScreenState extends State<RealisasiHistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;
  int? _selectedUserId;
  String _activeTab = 'Selesai'; // 'Selesai' atau 'Draft' (Menunggu TTD)
  List<RealisasiModel> _draftRealisasiList = [];
  bool _loadingDraft = false;
  bool _isInitialLoading = true;
  final TextEditingController _draftSearchCtrl = TextEditingController();
  String _draftSearchQuery = '';

  @override
  void dispose() {
    _draftSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _activeTab = widget.initialTab!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadDraftData() async {
    setState(() => _loadingDraft = true);
    try {
      final auth = context.read<AuthProvider>();
      final role = auth.user?['user_jabatan'];
      final isManager = role == 'manager';
      final isAdmin = role == 'admin';
      final provider = context.read<JadwalProvider>();
      final drafts = await provider.fetchDraftRealisasi(
        byDivisi: isManager ? false : isAdmin,
      );
      setState(() {
        _draftRealisasiList = drafts;
      });
    } catch (e) {
      debugPrint('[LOAD DRAFT ERROR] $e');
    } finally {
      setState(() => _loadingDraft = false);
    }
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final role = auth.user?['user_jabatan'];
    final isAdmin = role == 'admin';
    final isManager = role == 'manager';
    final provider = context.read<JadwalProvider>();

    try {
      if (_activeTab == 'Selesai') {
        int? effectiveUserId = _selectedUserId;
        if (!isAdmin && !isManager) {
          final rawId = auth.user?['user_id'];
          if (rawId is int) {
            effectiveUserId = rawId;
          } else if (rawId != null) {
            effectiveUserId = int.tryParse(rawId.toString());
          }
          _selectedUserId = effectiveUserId;
        }

        if (isManager) {
          await provider.fetchJadwal();
          await provider.fetchRealisasi(status: 'Selesai');
        } else if (isAdmin) {
          await provider.fetchJadwalByDivisi();
          await provider.fetchRealisasi(status: 'Selesai', byDivisi: true);
        } else {
          await provider.fetchJadwalByUser();
          await provider.fetchRealisasi(status: 'Selesai');
        }
        await provider.fetchHariLiburForMonth(
          _selectedMonth,
          onlyDb: isManager,
          menu: 'realisasi',
        );
        await provider.fetchRealisasiHistorySummary(
          bulan: _selectedMonth.month,
          tahun: _selectedMonth.year,
          userId: effectiveUserId,
        );
      } else {
        await _loadDraftData();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDay = null;
    });
    final auth = context.read<AuthProvider>();
    final role =
        auth.user?['user_jabatan']?.toString().toLowerCase();
    final isManager = role == 'manager';
    final isAdmin = role == 'admin';
    int? effectiveUserId;
    if (!isAdmin && !isManager) {
      final rawId = auth.user?['user_id'];
      if (rawId is int) {
        effectiveUserId = rawId;
      } else if (rawId != null) {
        effectiveUserId = int.tryParse(rawId.toString());
      }
    } else {
      effectiveUserId = _selectedUserId;
    }

    final p = context.read<JadwalProvider>();
    p.fetchHariLiburForMonth(
      _selectedMonth,
      onlyDb: isManager,
      menu: 'realisasi',
    );
    p.fetchRealisasiHistorySummary(
      bulan: _selectedMonth.month,
      tahun: _selectedMonth.year,
      userId: effectiveUserId,
    );
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDay = null;
    });
    final auth = context.read<AuthProvider>();
    final role =
        auth.user?['user_jabatan']?.toString().toLowerCase();
    final isManager = role == 'manager';
    final isAdmin = role == 'admin';
    int? effectiveUserId;
    if (!isAdmin && !isManager) {
      final rawId = auth.user?['user_id'];
      if (rawId is int) {
        effectiveUserId = rawId;
      } else if (rawId != null) {
        effectiveUserId = int.tryParse(rawId.toString());
      }
    } else {
      effectiveUserId = _selectedUserId;
    }

    final p = context.read<JadwalProvider>();
    p.fetchHariLiburForMonth(
      _selectedMonth,
      onlyDb: isManager,
      menu: 'realisasi',
    );
    p.fetchRealisasiHistorySummary(
      bulan: _selectedMonth.month,
      tahun: _selectedMonth.year,
      userId: effectiveUserId,
    );
  }

  void _onUserFilterChanged(int? value) {
    setState(() {
      _selectedUserId = value;
      _selectedDay = null;
    });
    context.read<JadwalProvider>().fetchRealisasiHistorySummary(
          bulan: _selectedMonth.month,
          tahun: _selectedMonth.year,
          userId: value,
        );
  }

  Future<void> _showRealisasiDetail(RealisasiModel item) async {
    final provider = context.read<JadwalProvider>();
    await provider.fetchRealisasiDetail(item.realId);
    if (!mounted) return;

    final detail = provider.realisasiDetail;
    if (detail == null) {
      await AppNotifier.showError(context, 'Detail realisasi tidak ditemukan');
      return;
    }

    await RealisasiDetailSheet.show(
      context,
      detail: detail,
      title: 'Detail Realisasi Unit',
    );
  }

  // Meta item untuk popup detail hari
  Widget _buildCompactMetaItem({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.2,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<void> _showDayRealisasiPopup({
    required int day,
    required List<RealisasiModel> filteredMonthRealisasi,
  }) async {
    final selectedDate =
        DateTime(_selectedMonth.year, _selectedMonth.month, day);
    final dayRealisasi =
        _filterRealisasiBySelectedDay(filteredMonthRealisasi, day);

    setState(() {
      _selectedDay = day;
    });

    try {
      await showResponsiveSheet<void>(
        context,
        maxDesktopWidth: 560,
        builder: (context) {
          final media = MediaQuery.of(context);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detail Realisasi ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('${dayRealisasi.length} realisasi',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    if (dayRealisasi.isEmpty)
                      const Expanded(
                          child: Center(
                              child: EmptyState(
                                  message:
                                      'Tidak ada realisasi pada tanggal ini')))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: dayRealisasi.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = dayRealisasi[index];
                            final title = (item.jadwal?['jdw_judul'] ?? '')
                                .toString()
                                .trim();
                            final teknisi = (item.teknisi?['user_nama'] ?? '')
                                .toString()
                                .trim();

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ListTile(
                                dense: true,
                                onTap: () => _showRealisasiDetail(item),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                leading: const Icon(Icons.task_alt_rounded,
                                    color: AppColors.success),
                                title: Text(
                                    title.isEmpty
                                        ? 'Jadwal #${item.realJadwalId}'
                                        : title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _buildCompactMetaItem(
                                            label: 'Inv',
                                            value: item.invNama ?? '-'),
                                        _buildCompactMetaItem(
                                            label: 'Teknisi',
                                            value: teknisi.isEmpty
                                                ? '-'
                                                : teknisi),
                                        _buildCompactMetaItem(
                                            label: 'PIC',
                                            value: item.realTtdPicNama ?? '-'),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: OutlinedButton(
                                  onPressed: () => _showRealisasiDetail(item),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(
                                        color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Detail',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _selectedDay = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?['user_jabatan']?.toString().toLowerCase();
    final isManager = role == 'manager';
    final isAdmin = role == 'admin' || isManager;
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);
    final horizontalPadding = isDesktop
        ? 24.0
        : isTablet
            ? 20.0
            : 16.0;
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realisasi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: InkWell(
              onTap: () {
                final p = context.read<JadwalProvider>();
                ExportPdfDialog.show(
                  context,
                  realisasiList: p.realisasiList,
                  jadwalList: p.jadwalList,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent,
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.file_download_rounded,
                        size: 16, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<JadwalProvider>(
          builder: (_, p, __) {
            final isLoading = _isInitialLoading ||
                (_activeTab == 'Selesai' ? p.loading : _loadingDraft);
            if (isLoading) {
              return _buildSkeleton(
                isDesktop: isDesktop,
                horizontalPadding: horizontalPadding,
                maxContentWidth: maxContentWidth,
              );
            }

            List<RealisasiModel> monthRealisasi = [];
            List<JadwalModel> filteredJadwal = [];
            List<RealisasiModel> filteredMonthRealisasi = [];
            Set<int> holidayDays = {};
            _MonthlyHistoryMetrics metrics =
                _MonthlyHistoryMetrics(targetCount: 0, doneCount: 0);
            List<_UserFilterItem> userItems = [];
            _MonthlyRecapData recapData = _MonthlyRecapData(groups: []);
            List<int> sortedCrossMonthWeeks = [];

            if (_activeTab == 'Selesai') {
              final isStaffOnly = !isAdmin && !isManager;
              int? currentUserId;
              final rawId = auth.user?['user_id'];
              if (rawId is int) {
                currentUserId = rawId;
              } else if (rawId != null) {
                currentUserId = int.tryParse(rawId.toString());
              }
              final int? effectiveUserId =
                  isStaffOnly ? currentUserId : _selectedUserId;

              monthRealisasi =
                  _filterRealisasiByMonth(p.realisasiList, _selectedMonth);
              filteredJadwal =
                  _filterJadwalBySelectedUser(p.jadwalList, effectiveUserId);
              filteredMonthRealisasi = _filterRealisasiBySelectedUser(
                  monthRealisasi, effectiveUserId);
              holidayDays = p.getHolidayDaysForMonth(
                _selectedMonth,
                onlyDb: isManager,
                menu: 'realisasi',
              );

              userItems = isStaffOnly
                  ? []
                  : _buildUserFilterItems(p.jadwalList, p.realisasiList);

              if (p.historySummaryData != null) {
                final data = p.historySummaryData!;
                final int totalTarget = data['total_target'] ?? 0;
                final int totalRealisasi = data['total_realisasi'] ?? 0;
                metrics = _MonthlyHistoryMetrics(
                  targetCount: totalTarget,
                  doneCount: totalRealisasi,
                );

                final List<dynamic> rawGroups = data['groups'] ?? [];
                final groups = rawGroups.map((g) {
                  final String freq = g['frequency'] ?? 'Harian';
                  final List<dynamic> rawDetails = g['details'] ?? [];
                  final details = rawDetails.map((d) {
                    return _RekapDetailRow(
                      namaTugas: d['nama_tugas'] ?? '-',
                      totalTargetPerPeriod: d['total_target_per_period'] ?? 0,
                      target: d['target'] ?? 0,
                      realisasi: d['realisasi'] ?? 0,
                    );
                  }).toList();
                  return _RekapFrequencyGroup(
                      frequency: freq, details: details);
                }).toList();

                recapData = _MonthlyRecapData(groups: groups);
                final List<dynamic> rawWeeks = data['cross_month_weeks'] ?? [];
                sortedCrossMonthWeeks =
                    rawWeeks.map((w) => (w as num).toInt()).toList()..sort();
              } else {
                metrics = _buildMonthlyMetrics(
                  jadwalList: filteredJadwal,
                  realisasiList: filteredMonthRealisasi,
                  month: _selectedMonth,
                  holidayDays: holidayDays,
                );

                recapData = _buildRecapData(
                  jadwalList: filteredJadwal,
                  realisasiList: filteredMonthRealisasi,
                  month: _selectedMonth,
                  holidayDays: holidayDays,
                );

                final crossMonthWeeks = <int>{};
                for (final r in filteredMonthRealisasi) {
                  final frekuensi =
                      (r.jadwal?['jdw_frekuensi'] ?? '').toString();
                  if (frekuensi == 'Mingguan') {
                    final hasOtherMonth = p.realisasiList.any((other) =>
                        other.realWeekNumber == r.realWeekNumber &&
                        other.realTahun == r.realTahun &&
                        other.realBulan != r.realBulan);
                    if (hasOtherMonth) {
                      crossMonthWeeks.add(r.realWeekNumber);
                    }
                  }
                }
                sortedCrossMonthWeeks = crossMonthWeeks.toList()..sort();
              }
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Tab Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 16, horizontalPadding, 8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppColors.border, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x060F172A),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _activeTab = 'Selesai';
                                    });
                                    _loadData();
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 'Selesai'
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _activeTab == 'Selesai'
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 15,
                                            color: _activeTab == 'Selesai'
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Selesai',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _activeTab == 'Selesai'
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _activeTab = 'Draft';
                                    });
                                    _loadData();
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 'Draft'
                                          ? AppColors.warning
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _activeTab == 'Draft'
                                          ? [
                                              BoxShadow(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.draw_rounded,
                                            size: 15,
                                            color: _activeTab == 'Draft'
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Menunggu TTD',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _activeTab == 'Draft'
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                          if (_draftRealisasiList
                                              .isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _activeTab == 'Draft'
                                                    ? Colors.white
                                                    : AppColors.warningSoft,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: _activeTab == 'Draft'
                                                      ? Colors.white
                                                      : AppColors.warning
                                                          .withValues(
                                                              alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '${_draftRealisasiList.length}',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_activeTab == 'Selesai') ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 16, horizontalPadding, 10),
                          child: LayoutBuilder(
                            builder: (_, constraints) {
                              final canFilterUser =
                                  (isAdmin || isManager) && userItems.isNotEmpty;
                              final canUseSingleRow =
                                  canFilterUser && constraints.maxWidth >= 840;

                              if (!canFilterUser) {
                                return _MonthSwitcher(
                                  monthLabel: _monthLabel(_selectedMonth),
                                  onPrevious: _previousMonth,
                                  onNext: _nextMonth,
                                );
                              }

                              if (canUseSingleRow) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: _MonthSwitcher(
                                          monthLabel:
                                              _monthLabel(_selectedMonth),
                                          onPrevious: _previousMonth,
                                          onNext: _nextMonth,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 5,
                                        child: _UserFilterCard(
                                          selectedUserId: _selectedUserId,
                                          users: userItems,
                                          onChanged: _onUserFilterChanged,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: _MonthSwitcher(
                                      monthLabel: _monthLabel(_selectedMonth),
                                      onPrevious: _previousMonth,
                                      onNext: _nextMonth,
                                    ),
                                  ),
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: _UserFilterCard(
                                      selectedUserId: _selectedUserId,
                                      users: userItems,
                                      onChanged: _onUserFilterChanged,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (sortedCrossMonthWeeks.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding, 0, horizontalPadding, 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2, right: 6),
                                    child: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Catatan: Terdapat realisasi jadwal Mingguan pada minggu ke-${sortedCrossMonthWeeks.join(', ')} yang dicatat lintas bulan. Progres mingguan tetap dihitung sebagai 1 periode.',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF92400E),
                                          height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 10, horizontalPadding, 10),
                          child: _SummaryCard(
                              monthLabel: _monthLabel(_selectedMonth),
                              metrics: metrics),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 4, horizontalPadding, 10),
                          child: _MonthlyDatePreview(
                            month: _selectedMonth,
                            realisasiList: filteredMonthRealisasi,
                            holidayDays: holidayDays,
                            selectedDay: _selectedDay,
                            onDayTap: (day) => _showDayRealisasiPopup(
                              day: day,
                              filteredMonthRealisasi: filteredMonthRealisasi,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 16, horizontalPadding, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                    'Penilaian ${_selectedUserId == null ? (isAdmin || isManager ? 'Semua User' : (auth.user?['user_nama'] ?? 'User')) : userItems.firstWhere((u) => u.userId == _selectedUserId, orElse: () => _UserFilterItem(userId: _selectedUserId ?? 0, userName: auth.user?['user_nama'] ?? 'User')).userName} Bulan ${_monthLabel(_selectedMonth)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 4, horizontalPadding, 100),
                          child: _MonthlyRecapTableCard(
                            data: recapData,
                          ),
                        ),
                      ),
                    ],

                    if (_activeTab == 'Draft') ...[
                      // Header Info & Search Banner for Drafts
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 12, horizontalPadding, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_draftRealisasiList.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                AppSearchField(
                                  controller: _draftSearchCtrl,
                                  hintText:
                                      'Cari aset, jadwal, teknisi, lokasi...',
                                  onSubmitted: (val) {
                                    setState(() {
                                      _draftSearchQuery = _draftSearchCtrl.text;
                                    });
                                  },
                                  onSearch: () {
                                    setState(() {
                                      _draftSearchQuery = _draftSearchCtrl.text;
                                    });
                                  },
                                  onClear: () {
                                    setState(() {
                                      _draftSearchQuery = '';
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      () {
                        final query = _draftSearchQuery.trim().toLowerCase();
                        final filteredDrafts =
                            _draftRealisasiList.where((item) {
                          if (query.isEmpty) return true;
                          final title = (item.jadwal?['jdw_judul'] ?? '')
                              .toString()
                              .toLowerCase();
                          final invNama = (item.invNama).toLowerCase();
                          final invNo = (item.invNo).toLowerCase();
                          final teknisi = (item.teknisi?['user_nama'] ??
                                  item.realTtdPicNama ??
                                  '')
                              .toString()
                              .toLowerCase();
                          final divisi = (item.jadwal?['jdw_divisi'] ?? '')
                              .toString()
                              .toLowerCase();
                          final pabrik = (item.jadwal?['jdw_pabrik_kode'] ??
                                  item.inventaris?['inv_pabrik_kode'] ??
                                  '')
                              .toString()
                              .toLowerCase();
                          return title.contains(query) ||
                              invNama.contains(query) ||
                              invNo.contains(query) ||
                              teknisi.contains(query) ||
                              divisi.contains(query) ||
                              pabrik.contains(query);
                        }).toList();

                        if (_draftRealisasiList.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: AppColors.successSoft,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.success
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.task_alt_rounded,
                                        color: AppColors.success,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Semua Realisasi Selesai',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tidak ada antrean draft yang menunggu tanda tangan PIC saat ini.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _activeTab = 'Selesai';
                                        });
                                        _loadData();
                                      },
                                      icon: const Icon(
                                        Icons.history_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        'Lihat Riwayat Selesai',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        if (filteredDrafts.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search_off_rounded,
                                      color: AppColors.textMuted,
                                      size: 44,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tidak ada draft yang cocok',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tidak ditemukan draft dengan kata kunci "$_draftSearchQuery"',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () {
                                        _draftSearchCtrl.clear();
                                        setState(() {
                                          _draftSearchQuery = '';
                                        });
                                      },
                                      child: Text(
                                        'Reset Pencarian',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        final isMobile = AppBreakpoints.isMobile(context);
                        if (isMobile) {
                          return SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPadding, 4, horizontalPadding, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = filteredDrafts[index];
                                  return _buildDraftCard(
                                      context, item, isAdmin);
                                },
                                childCount: filteredDrafts.length,
                              ),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalPadding, 4, horizontalPadding, 100),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 540,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              mainAxisExtent: 265,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = filteredDrafts[index];
                                return _buildDraftCard(context, item, isAdmin);
                              },
                              childCount: filteredDrafts.length,
                            ),
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeleton({
    required bool isDesktop,
    required double horizontalPadding,
    required double maxContentWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: AppShimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 16, horizontalPadding, 40),
            children: [
              // 1. Tab Selector Placeholder
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: AppSkeletonSquircle(
                        width: double.infinity,
                        height: 38,
                        borderRadius: 10,
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: AppSkeletonSquircle(
                        width: double.infinity,
                        height: 38,
                        borderRadius: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_activeTab == 'Selesai') ...[
                // 2. Month Switcher & Filter Placeholder
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppSkeletonCircle(size: 28),
                            AppSkeletonLine(width: 120, height: 16),
                            AppSkeletonCircle(size: 28),
                          ],
                        ),
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              AppSkeletonCircle(size: 26),
                              SizedBox(width: 10),
                              AppSkeletonLine(width: 110, height: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Summary / Target Metric Card Placeholder
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              AppSkeletonSquircle(
                                  width: 36, height: 36, borderRadius: 10),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppSkeletonLine(width: 130, height: 15),
                                  SizedBox(height: 6),
                                  AppSkeletonLine(width: 90, height: 11),
                                ],
                              ),
                            ],
                          ),
                          AppSkeletonSquircle(
                              width: 50, height: 26, borderRadius: 8),
                        ],
                      ),
                      SizedBox(height: 16),
                      AppSkeletonSquircle(
                        width: double.infinity,
                        height: 8,
                        borderRadius: 999,
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                AppSkeletonLine(width: 50, height: 16),
                                SizedBox(height: 4),
                                AppSkeletonLine(width: 70, height: 11),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                AppSkeletonLine(width: 50, height: 16),
                                SizedBox(height: 4),
                                AppSkeletonLine(width: 70, height: 11),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                AppSkeletonLine(width: 50, height: 16),
                                SizedBox(height: 4),
                                AppSkeletonLine(width: 70, height: 11),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Monthly Calendar Grid Placeholder
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      // Days of week header (Sen - Min)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          7,
                          (i) => const AppSkeletonLine(
                            width: 28,
                            height: 12,
                            borderRadius: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Calendar date rows (4 rows x 7 days)
                      ...List.generate(
                        4,
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              7,
                              (col) => const AppSkeletonSquircle(
                                width: 34,
                                height: 34,
                                borderRadius: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. List Items Cards
                ...List.generate(
                  2,
                  (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AppSkeletonListCard(),
                  ),
                ),
              ] else ...[
                // Draft Tab Skeleton: Search Bar + List Cards
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      AppSkeletonCircle(size: 20),
                      SizedBox(width: 12),
                      AppSkeletonLine(width: 180, height: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(
                  4,
                  (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AppSkeletonListCard(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Methods (Filter & Logic) ---
  List<RealisasiModel> _filterRealisasiByMonth(
      List<RealisasiModel> list, DateTime month) {
    return list.where((item) {
      final tgl = DateTime.tryParse(item.realTgl);
      return tgl != null && tgl.year == month.year && tgl.month == month.month;
    }).toList();
  }

  List<RealisasiModel> _filterRealisasiBySelectedDay(
      List<RealisasiModel> list, int? day) {
    if (day == null) return list;
    return list.where((item) {
      final tgl = DateTime.tryParse(item.realTgl);
      return tgl != null && tgl.day == day;
    }).toList();
  }

  List<JadwalModel> _filterJadwalBySelectedUser(
      List<JadwalModel> list, int? selectedUserId) {
    if (selectedUserId == null) return list;
    return list.where((item) => item.jdwAssignedTo == selectedUserId).toList();
  }

  List<RealisasiModel> _filterRealisasiBySelectedUser(
      List<RealisasiModel> list, int? selectedUserId) {
    if (selectedUserId == null) return list;
    return list.where((item) => item.realTeknisiId == selectedUserId).toList();
  }

  List<_UserFilterItem> _buildUserFilterItems(
      List<JadwalModel> jadwalList, List<RealisasiModel> realisasiList) {
    final byId = <int, String>{};
    for (final item in jadwalList) {
      final id = item.jdwAssignedTo;
      if (id == null || id <= 0) continue;
      final name = (item.assignedUser?['user_nama'] ?? '').toString().trim();
      byId[id] = name.isEmpty ? 'User #$id' : name;
    }
    for (final item in realisasiList) {
      final id = item.realTeknisiId;
      if (id <= 0) continue;
      final name = (item.teknisi?['user_nama'] ?? '').toString().trim();
      byId[id] = name.isEmpty ? (byId[id] ?? 'User #$id') : name;
    }
    return byId.entries
        .map((e) => _UserFilterItem(userId: e.key, userName: e.value))
        .toList()
      ..sort((a, b) => a.userName.compareTo(b.userName));
  }

  _MonthlyRecapData _buildRecapData({
    required List<JadwalModel> jadwalList,
    required List<RealisasiModel> realisasiList,
    required DateTime month,
    required Set<int> holidayDays,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final targetByJdwId = <int, int>{};
    final targetPerPeriodByJdwId = <int, int>{};
    final realisasiByJdwId = <int, int>{};
    final frequencyByJdwId = <int, String>{};
    final taskNameByJdwId = <int, String>{};

    for (final j in jadwalList) {
      if (j.jdwStatus != 'Aktif' && j.jdwStatus != 'Selesai') continue;
      frequencyByJdwId[j.jdwId] = j.jdwFrekuensi;
      taskNameByJdwId[j.jdwId] =
          j.jdwJudul.isEmpty ? 'Jadwal #${j.jdwId}' : j.jdwJudul;

      final appearances =
          JadwalProvider.effectiveScheduleDatesInMonth(j, monthStart, monthEnd, holidayDays)
              .length;
      final perTarget =
          (j.jdwTarget ?? 0) > 0 ? (j.jdwTarget ?? 0) : (j.jdwTotalUnit ?? 0);

      targetByJdwId[j.jdwId] = appearances * perTarget;
      targetPerPeriodByJdwId[j.jdwId] = perTarget;
    }

    for (final r in realisasiList) {
      realisasiByJdwId.update(r.realJadwalId, (val) => val + 1,
          ifAbsent: () => 1);
      if (!taskNameByJdwId.containsKey(r.realJadwalId)) {
        taskNameByJdwId[r.realJadwalId] =
            (r.jadwal?['jdw_judul'] ?? '').toString();
        frequencyByJdwId[r.realJadwalId] =
            (r.jadwal?['jdw_frekuensi'] ?? '').toString();
      }
    }

    final freqs = ['Harian', 'Mingguan', 'Bulanan'];
    final groups = freqs.map((f) {
      final ids = frequencyByJdwId.entries
          .where((e) => e.value.toLowerCase() == f.toLowerCase())
          .map((e) => e.key)
          .toList();
      final details = ids
          .map((id) => _RekapDetailRow(
                namaTugas: taskNameByJdwId[id] ?? 'Jadwal #$id',
                totalTargetPerPeriod: targetPerPeriodByJdwId[id] ?? 0,
                target: targetByJdwId[id] ?? 0,
                realisasi: realisasiByJdwId[id] ?? 0,
              ))
          .toList()
        ..sort((a, b) => a.namaTugas.compareTo(b.namaTugas));

      return _RekapFrequencyGroup(frequency: f, details: details);
    }).toList();

    return _MonthlyRecapData(groups: groups);
  }

  Widget _buildDraftCard(
      BuildContext context, RealisasiModel item, bool isAdmin) {
    final title = (item.jadwal?['jdw_judul'] ?? '').toString().trim();
    final divisi =
        (item.jadwal?['jdw_divisi'] ?? item.inventaris?['inv_divisi'] ?? '')
            .toString()
            .trim();
    final pabrik = (item.jadwal?['jdw_pabrik_kode'] ??
            item.inventaris?['inv_pabrik_kode'] ??
            '')
        .toString()
        .trim();
    final tglString = DateFormatter.toDisplay(item.realTgl);
    final jamMulai = item.realJamMulai ?? '-';
    final invNama = item.invNama.trim().isEmpty ? 'Unit Aset' : item.invNama;
    final invNo = item.invNo;
    final jdwId = item.realJadwalId;
    final invJenisId = item.jadwal?['jdw_inv_jenis_id'] ?? 0;
    final invId = item.realInvId;
    final teknisi = (item.teknisi?['user_nama'] ?? item.realTtdPicNama ?? '')
        .toString()
        .trim();
    final kondisiAkhir = (item.realKondisiAkhir ?? '').trim();
    final keterangan = (item.realKeterangan ?? '').trim();
    final checklistCount = item.hasilChecklist.length;

    Color kondisiColor = AppColors.textSecondary;
    Color kondisiBg = AppColors.surfaceAlt;
    final kLower = kondisiAkhir.toLowerCase();
    if (kLower == 'normal' || kLower == 'ok' || kLower == 'baik') {
      kondisiColor = AppColors.success;
      kondisiBg = AppColors.successSoft;
    } else if (kLower == 'rusak' || kLower == 'nk' || kLower == 'buruk') {
      kondisiColor = AppColors.danger;
      kondisiBg = AppColors.dangerSoft;
    } else if (kondisiAkhir.isNotEmpty && kondisiAkhir != '-') {
      kondisiColor = AppColors.warning;
      kondisiBg = AppColors.warningSoft;
    }

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.warning,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badges Row
                Row(
                  children: [
                    if (divisi.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppDivisiColors.getSoftColor(divisi),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          divisi.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppDivisiColors.getColor(divisi),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (pabrik.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 11,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              pabrik,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.draw_rounded,
                            size: 13,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Menunggu TTD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Asset Hero Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        AppDivisiColors.getIcon(divisi),
                        color: AppColors.primary,
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
                              Expanded(
                                child: Text(
                                  invNama,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.25,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (invNo.isNotEmpty && invNo != '-') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppColors.border, width: 0.8),
                                  ),
                                  child: Text(
                                    invNo,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title.isEmpty ? 'Jadwal #$jdwId' : title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metadata Chips Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildDraftChip(
                      icon: Icons.calendar_today_rounded,
                      label: tglString,
                    ),
                    _buildDraftChip(
                      icon: Icons.access_time_rounded,
                      label: 'Pukul $jamMulai',
                    ),
                    if (teknisi.isNotEmpty)
                      _buildDraftChip(
                        icon: Icons.person_outline_rounded,
                        label: teknisi,
                      ),
                    if (kondisiAkhir.isNotEmpty && kondisiAkhir != '-')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: kondisiBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: kondisiColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.health_and_safety_outlined,
                              size: 12,
                              color: kondisiColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              kondisiAkhir,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kondisiColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (checklistCount > 0)
                      _buildDraftChip(
                        icon: Icons.checklist_rounded,
                        label: '$checklistCount item',
                      ),
                  ],
                ),

                // Notes Bubble if available
                if (keterangan.isNotEmpty && keterangan != '-') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1, right: 6),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            keterangan,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Action Buttons
                if (isAdmin) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRealisasiDetail(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                                vertical: 9, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: Text(
                            'Lihat Rincian Draft',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.realisasiForm,
                              arguments: {
                                'realId': item.realId,
                                'jadwalId': jdwId,
                                'invJenisId': invJenisId,
                                'invId': invId,
                                'invNama': invNama,
                                'invNo': item.inventaris?['inv_serial_number'] ??
                                    item.inventaris?['inv_no'],
                                'invMerk': item.inventaris?['inv_merk'],
                                'invKondisi': item.inventaris?['inv_kondisi'],
                                'invPicNama': item.inventaris?['pic_user']?['user_nama'] ??
                                    item.inventaris?['inv_pic'] ??
                                    item.realTtdPicNama,
                              },
                            );
                            _loadData();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.draw_rounded, size: 16),
                          label: Text(
                            'Lanjutkan & Minta TTD PIC',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Pratinjau Draft',
                        onPressed: () => _showRealisasiDetail(item),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceAlt,
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                                color: AppColors.border, width: 0.8),
                          ),
                          padding: const EdgeInsets.all(9),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  _MonthlyHistoryMetrics _buildMonthlyMetrics({
    required List<JadwalModel> jadwalList,
    required List<RealisasiModel> realisasiList,
    required DateTime month,
    required Set<int> holidayDays,
  }) {
    int target = 0;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    for (final j in jadwalList) {
      if (j.jdwStatus != 'Aktif' && j.jdwStatus != 'Selesai') continue;
      final count =
          JadwalProvider.effectiveScheduleDatesInMonth(j, start, end, holidayDays).length;
      target += count *
          ((j.jdwTarget ?? 0) > 0 ? (j.jdwTarget ?? 0) : (j.jdwTotalUnit ?? 0));
    }
    return _MonthlyHistoryMetrics(
        targetCount: target, doneCount: realisasiList.length);
  }

  String _monthLabel(DateTime m) {
    return '${DateFormatter.monthNames[m.month - 1]} ${m.year}';
  }
}

String _monthLabel(DateTime m) {
  return '${DateFormatter.monthNames[m.month - 1]} ${m.year}';
}

// --- REFINED RECAP COMPONENTS ---

class _MonthlyRecapTableCard extends StatefulWidget {
  final _MonthlyRecapData data;
  const _MonthlyRecapTableCard({required this.data});

  @override
  State<_MonthlyRecapTableCard> createState() => _MonthlyRecapTableCardState();
}

class _MonthlyRecapTableCardState extends State<_MonthlyRecapTableCard> {
  final Set<String> _expandedFrequencies = <String>{};

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTopStats(),
            const SizedBox(height: 14),
            const Divider(height: 32),
            ...widget.data.groups
                .map((group) => _buildFrequencyBlock(context, group)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStats() {
    final summary = _summaryLabel(widget.data.totalNilaiPercent);
    final summaryColor = _summaryColor(widget.data.totalNilaiPercent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(
                'Target', '${widget.data.totalTarget}', AppColors.primary),
            _statItem('Realisasi', '${widget.data.totalRealisasi}',
                AppColors.success),
            _statItem(
                'Presentase',
                '${widget.data.totalNilaiPercent.toStringAsFixed(1)}%',
                AppColors.warning),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: summaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: summaryColor.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insights_rounded, size: 14, color: summaryColor),
                const SizedBox(width: 6),
                Text(
                  'Skor: $summary',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: summaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _summaryLabel(double percent) {
    if (percent >= 90) return 'Sempurna';
    if (percent >= 80) return 'Baik';
    if (percent >= 70) return 'Cukup';
    return 'Buruk';
  }

  Color _summaryColor(double percent) {
    if (percent >= 90) return AppColors.success;
    if (percent >= 80) return AppColors.primary;
    if (percent >= 70) return AppColors.warning;
    return AppColors.danger;
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildFrequencyBlock(
      BuildContext context, _RekapFrequencyGroup group) {
    final isExpanded = _expandedFrequencies.contains(group.frequency);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          initiallyExpanded: false,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedFrequencies.add(group.frequency);
              } else {
                _expandedFrequencies.remove(group.frequency);
              }
            });
          },
          title: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.frequency,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${group.nilaiPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          children: group.details.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Jadwal tidak ada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ]
              : group.details
                  .asMap()
                  .entries
                  .map((entry) =>
                      _recapItem(entry.value, group.frequency, entry.key))
                  .toList(),
        ),
      ),
    );
  }

  Widget _recapItem(_RekapDetailRow detail, String frequency, int index) {
    final percent = detail.nilaiPercent;
    final color = percent >= 90
        ? AppColors.success
        : (percent >= 70 ? AppColors.warning : AppColors.danger);
    final orderNumber = index + 1;
    final periodLabel = _periodLabelByFrequency(frequency);

    final bg = _detailCardBackground(frequency, index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Text(
                        '$orderNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail.namaTugas,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text('${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricBadge(
                  label: 'Total Target',
                  value: '${detail.target}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBadge(
                  label: 'Realisasi',
                  value: '${detail.realisasi}',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Target per $periodLabel: ${detail.totalTargetPerPeriod}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _detailCardBackground(String frequency, int index) {
    final isEven = index.isEven;
    if (frequency == 'Harian') {
      return isEven ? const Color(0xFFEAF4FF) : const Color(0xFFF1F8FF);
    }
    if (frequency == 'Mingguan') {
      return isEven ? const Color(0xFFF1FBEF) : const Color(0xFFF7FCF5);
    }
    return isEven ? const Color(0xFFFFF6E8) : const Color(0xFFFFFAF1);
  }

  String _periodLabelByFrequency(String frequency) {
    switch (frequency) {
      case 'Harian':
        return 'hari';
      case 'Mingguan':
        return 'minggu';
      case 'Bulanan':
        return 'bulan';
      default:
        return 'periode';
    }
  }
}

// --- SHARED UI COMPONENTS (MonthSwitcher, SummaryCard, etc.) ---

class _MonthSwitcher extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  const _MonthSwitcher(
      {required this.monthLabel,
      required this.onPrevious,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: onPrevious,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.primary, size: 22),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  monthLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: onNext,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String monthLabel;
  final _MonthlyHistoryMetrics metrics;
  const _SummaryCard({required this.monthLabel, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final rate = metrics.completionRate;
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _DonutChart(
              progress: rate,
              size: 96,
              doneColor: AppColors.success,
              remainingColor: AppColors.border),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capaian $monthLabel',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _rowMetric('Target', '${metrics.targetCount}',
                    AppColors.textSecondary),
                _rowMetric(
                    'Realisasi', '${metrics.doneCount}', AppColors.primary),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _rowMetric(String l, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            l,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            v,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFilterCard extends StatelessWidget {
  final int? selectedUserId;
  final List<_UserFilterItem> users;
  final ValueChanged<int?> onChanged;
  const _UserFilterCard(
      {required this.selectedUserId,
      required this.users,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButtonFormField<int?>(
          value: selectedUserId,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Pilih User',
              prefixIcon: Icon(Icons.person_outline),
              border: InputBorder.none),
          items: [
            const DropdownMenuItem(
                value: null,
                child: Text('Semua User',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textPrimary))),
            ...users.map((u) => DropdownMenuItem(
                value: u.userId,
                child: Text(u.userName,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MonthlyDatePreview extends StatelessWidget {
  final DateTime month;
  final List<RealisasiModel> realisasiList;
  final Set<int> holidayDays;
  final int? selectedDay;
  final ValueChanged<int> onDayTap;

  const _MonthlyDatePreview(
      {required this.month,
      required this.realisasiList,
      required this.holidayDays,
      required this.selectedDay,
      required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1; // Senin = 1
    final counts = <int, int>{};
    for (var r in realisasiList) {
      final d = DateTime.tryParse(r.realTgl);
      if (d != null) counts.update(d.day, (v) => v + 1, ifAbsent: () => 1);
    }

    final cells = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= totalDays; day++) {
      final count = counts[day] ?? 0;
      cells.add(
        _dayCell(
          day: day,
          count: count,
          isHoliday: holidayDays.contains(day),
          isToday: _isToday(day),
          isSelected: selectedDay == day,
          onTap: () => onDayTap(day),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kalender Realisasi ${_monthLabel(month)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: const [
                _LegendDot(color: AppColors.success, label: 'Realisasi'),
                _LegendDot(color: AppColors.danger, label: 'Hari libur'),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                final ratio = constraints.maxWidth < 430
                    ? 0.95
                    : constraints.maxWidth > 980
                        ? 1.25
                        : 1.05;

                return GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: ratio,
                  children: [
                    ..._weekdayHeaders(),
                    ...cells,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month && now.day == day;
  }

  List<Widget> _weekdayHeaders() {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return names
        .map(
          (name) => Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _dayCell({
    required int day,
    required int count,
    required bool isHoliday,
    required bool isToday,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final hasRealisasi = count > 0;
    final bg = isSelected
        ? AppColors.primary
        : isHoliday
            ? const Color(0xFFFEE2E2)
            : hasRealisasi
                ? AppColors.success.withValues(alpha: 0.14)
                : Colors.white;
    final fg = isSelected
        ? Colors.white
        : isHoliday
            ? AppColors.danger
            : hasRealisasi
                ? AppColors.success
                : AppColors.textPrimary;
    final borderColor = isSelected
        ? AppColors.primary
        : isToday
            ? AppColors.primary
            : AppColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (count > 1)
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : (isHoliday ? AppColors.danger : AppColors.success),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DonutChart extends StatelessWidget {
  final double progress;
  final double size;
  final Color doneColor;
  final Color remainingColor;
  const _DonutChart(
      {required this.progress,
      required this.size,
      required this.doneColor,
      required this.remainingColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
                progress: progress,
                doneColor: doneColor,
                remainingColor: remainingColor),
          ),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color doneColor;
  final Color remainingColor;
  _DonutPainter(
      {required this.progress,
      required this.doneColor,
      required this.remainingColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = remainingColor;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = doneColor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- DATA MODELS ---

class _MonthlyHistoryMetrics {
  final int targetCount;
  final int doneCount;
  _MonthlyHistoryMetrics({required this.targetCount, required this.doneCount});
  double get completionRate =>
      targetCount > 0 ? (doneCount / targetCount).clamp(0.0, 1.0) : 0.0;
}

class _UserFilterItem {
  final int userId;
  final String userName;
  _UserFilterItem({required this.userId, required this.userName});
}

class _RekapDetailRow {
  final String namaTugas;
  final int totalTargetPerPeriod;
  final int realisasi;
  final int target;
  _RekapDetailRow(
      {required this.namaTugas,
      required this.totalTargetPerPeriod,
      required this.realisasi,
      required this.target});
  double get nilaiPercent => target > 0 ? (realisasi / target) * 100 : (realisasi > 0 ? 100.0 : 0.0);
}

class _RekapFrequencyGroup {
  final String frequency;
  final List<_RekapDetailRow> details;
  _RekapFrequencyGroup({required this.frequency, required this.details});
  int get totalTarget => details.fold(0, (s, i) => s + i.target);
  int get totalRealisasi => details.fold(0, (s, i) => s + i.realisasi);
  double get nilaiPercent =>
      totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : (totalRealisasi > 0 ? 100.0 : 0.0);
}

class _MonthlyRecapData {
  final List<_RekapFrequencyGroup> groups;
  _MonthlyRecapData({required this.groups});
  int get totalTarget => groups.fold(0, (s, i) => s + i.totalTarget);
  int get totalRealisasi => groups.fold(0, (s, i) => s + i.totalRealisasi);
  int get totalDetailRows => groups.fold(0, (s, i) => s + i.details.length);
  double get totalNilaiPercent =>
      totalTarget > 0 ? (totalRealisasi / totalTarget) * 100 : (totalRealisasi > 0 ? 100.0 : 0.0);
}
