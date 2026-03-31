import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/jadwal_model.dart';
import '../models/realisasi_model.dart';
import '../providers/jadwal_provider.dart';
import '../widgets/realisasi_detail_sheet.dart';

class RealisasiHistoryScreen extends StatefulWidget {
  const RealisasiHistoryScreen({super.key});

  @override
  State<RealisasiHistoryScreen> createState() => _RealisasiHistoryScreenState();
}

class _RealisasiHistoryScreenState extends State<RealisasiHistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final provider = context.read<JadwalProvider>();

    if (isAdmin) {
      await provider.fetchJadwal();
      await provider.fetchRealisasi(status: 'Selesai');
    } else {
      await provider.fetchJadwalByUser();
      await provider.fetchRealisasi(status: 'Selesai', byDivisi: true);
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDay = null;
    });
  }

  void _toggleDayFilter(int day) {
    setState(() {
      _selectedDay = _selectedDay == day ? null : day;
    });
  }

  Future<void> _openHistoryDetail(RealisasiModel item) async {
    final p = context.read<JadwalProvider>();
    await p.fetchRealisasiDetail(item.realId);
    if (!mounted) return;

    final detail = p.realisasiDetail;
    if (detail == null) {
      await AppNotifier.showError(context, 'Detail realisasi tidak ditemukan');
      return;
    }

    await RealisasiDetailSheet.show(
      context,
      detail: detail,
      title: 'Detail History Realisasi',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isTablet = AppBreakpoints.isTablet(context);
    final horizontalPadding = isDesktop
        ? 24.0
        : isTablet
            ? 20.0
            : 16.0;
    final maxContentWidth = isDesktop ? 1180.0 : 860.0;
    final historyCrossAxisCount = isDesktop ? 2 : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Realisasi'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<JadwalProvider>(
          builder: (_, p, __) {
            if (p.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final monthRealisasi = _filterRealisasiByMonth(
              p.realisasiList,
              _selectedMonth,
            );
            final visibleRealisasi = _filterRealisasiBySelectedDay(
              monthRealisasi,
              _selectedDay,
            );
            final metrics = _buildMonthlyMetrics(
              jadwalList: p.jadwalList,
              realisasiList: monthRealisasi,
              month: _selectedMonth,
            );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 16, horizontalPadding, 6),
                        child: _MonthSwitcher(
                          monthLabel: _monthLabel(_selectedMonth),
                          onPrevious: _previousMonth,
                          onNext: _nextMonth,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 10, horizontalPadding, 10),
                        child: _SummaryCard(
                          monthLabel: _monthLabel(_selectedMonth),
                          metrics: metrics,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 4, horizontalPadding, 10),
                        child: _MonthlyDatePreview(
                          month: _selectedMonth,
                          realisasiList: monthRealisasi,
                          selectedDay: _selectedDay,
                          onDayTap: _toggleDayFilter,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 8, horizontalPadding, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDay == null
                                      ? 'Realisasi Bulan Ini'
                                      : 'Realisasi Tanggal ${_selectedDay.toString().padLeft(2, '0')}/${_selectedMonth.month.toString().padLeft(2, '0')}/${_selectedMonth.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${visibleRealisasi.length} item',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedDay != null) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _selectedDay = null),
                                icon: const Icon(Icons.filter_alt_off_outlined,
                                    size: 16),
                                label: const Text('Tampilkan Semua Tanggal'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (visibleRealisasi.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          message: 'Belum ada realisasi tanggal ini',
                        ),
                      )
                    else if (historyCrossAxisCount == 1)
                      SliverList.separated(
                        itemCount: visibleRealisasi.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            i == 0 ? 4 : 0,
                            horizontalPadding,
                            i == visibleRealisasi.length - 1 ? 120 : 0,
                          ),
                          child: _HistoryRealisasiCard(
                            item: visibleRealisasi[i],
                            onDetail: () =>
                                _openHistoryDetail(visibleRealisasi[i]),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 4, horizontalPadding, 120),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.7,
                          ),
                          itemCount: visibleRealisasi.length,
                          itemBuilder: (_, i) => _HistoryRealisasiCard(
                            item: visibleRealisasi[i],
                            onDetail: () =>
                                _openHistoryDetail(visibleRealisasi[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<RealisasiModel> _filterRealisasiByMonth(
    List<RealisasiModel> list,
    DateTime month,
  ) {
    final filtered = list.where((item) {
      final tgl = DateTime.tryParse(item.realTgl);
      if (tgl == null) return false;
      return tgl.year == month.year && tgl.month == month.month;
    }).toList();

    filtered.sort((a, b) {
      final ad = DateTime.tryParse(a.realTgl) ?? DateTime(1970);
      final bd = DateTime.tryParse(b.realTgl) ?? DateTime(1970);
      return bd.compareTo(ad);
    });

    return filtered;
  }

  List<RealisasiModel> _filterRealisasiBySelectedDay(
    List<RealisasiModel> list,
    int? day,
  ) {
    if (day == null) return list;
    return list.where((item) {
      final tgl = DateTime.tryParse(item.realTgl);
      return tgl != null && tgl.day == day;
    }).toList();
  }

  _MonthlyHistoryMetrics _buildMonthlyMetrics({
    required List<JadwalModel> jadwalList,
    required List<RealisasiModel> realisasiList,
    required DateTime month,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    int targetCount = 0;
    for (final jadwal in jadwalList) {
      if (jadwal.jdwStatus != 'Draft') continue;
      final appearances = _countScheduleAppearancesInMonth(
        jadwal,
        monthStart,
        monthEnd,
      );
      final perScheduleTarget = (jadwal.jdwTarget ?? 0) > 0
          ? (jadwal.jdwTarget ?? 0)
          : ((jadwal.jdwTotalUnit ?? 0) > 0 ? (jadwal.jdwTotalUnit ?? 0) : 0);
      targetCount += appearances * perScheduleTarget;
    }

    final doneCount = realisasiList.length;
    return _MonthlyHistoryMetrics(
      targetCount: targetCount,
      doneCount: doneCount,
    );
  }

  int _countScheduleAppearancesInMonth(
    JadwalModel jadwal,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final start = DateTime.tryParse(jadwal.jdwTglMulai);
    if (start == null) return 0;

    final end = (jadwal.jdwTglSelesai == null || jadwal.jdwTglSelesai!.isEmpty)
        ? monthEnd
        : (DateTime.tryParse(jadwal.jdwTglSelesai!) ?? monthEnd);

    final rangeStart = _maxDate(_dateOnly(start), monthStart);
    final rangeEnd = _minDate(_dateOnly(end), monthEnd);

    if (rangeEnd.isBefore(rangeStart)) return 0;

    int count = 0;
    final startDate = _dateOnly(start);
    for (var cursor = rangeStart;
        !cursor.isAfter(rangeEnd);
        cursor = cursor.add(const Duration(days: 1))) {
      final diff = cursor.difference(startDate).inDays;
      if (diff < 0) continue;

      if (jadwal.jdwFrekuensi == 'Harian') {
        count++;
      } else if (jadwal.jdwFrekuensi == 'Mingguan') {
        if (diff % 7 == 0) count++;
      } else if (jadwal.jdwFrekuensi == 'Bulanan') {
        if (cursor.day == startDate.day) count++;
      }
    }

    return count;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  String _monthLabel(DateTime month) {
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${monthNames[month.month - 1]} ${month.year}';
  }
}

class _MonthSwitcher extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSwitcher({
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _monthButton(
              icon: Icons.chevron_left,
              tooltip: 'Bulan Sebelumnya',
              onTap: onPrevious,
            ),
            Expanded(
              child: Center(
                child: Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _monthButton(
              icon: Icons.chevron_right,
              tooltip: 'Bulan Berikutnya',
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String monthLabel;
  final _MonthlyHistoryMetrics metrics;

  const _SummaryCard({
    required this.monthLabel,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final completionRate = metrics.completionRate;
    return LayoutBuilder(
      builder: (_, constraints) {
        final compact = constraints.maxWidth < 640;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ringkasan $monthLabel',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perbandingan target kemunculan jadwal vs realisasi selesai',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (compact)
                  Column(
                    children: [
                      _DonutChart(
                        progress: completionRate,
                        doneColor: AppColors.success,
                        remainingColor: const Color(0xFFE2E8F0),
                        size: 132,
                      ),
                      const SizedBox(height: 14),
                      _metricsColumn(completionRate),
                    ],
                  )
                else
                  Row(
                    children: [
                      _DonutChart(
                        progress: completionRate,
                        doneColor: AppColors.success,
                        remainingColor: const Color(0xFFE2E8F0),
                        size: 132,
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _metricsColumn(completionRate)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricsColumn(double completionRate) {
    final completionPercent = completionRate * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricLine(
          label: 'Target Jadwal',
          value: '${metrics.targetCount}',
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        _metricLine(
          label: 'Realisasi Selesai',
          value: '${metrics.doneCount}',
          color: AppColors.success,
        ),
        const SizedBox(height: 8),
        _metricLine(
          label: 'Capaian',
          value: '${completionPercent.toStringAsFixed(1)}%',
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _metricLine({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _MonthlyDatePreview extends StatelessWidget {
  final DateTime month;
  final List<RealisasiModel> realisasiList;
  final int? selectedDay;
  final ValueChanged<int> onDayTap;

  const _MonthlyDatePreview({
    required this.month,
    required this.realisasiList,
    required this.selectedDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1; // Senin = 1
    final realizedCountByDay = _realizedCountByDay(realisasiList);

    final cells = <Widget>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= totalDays; day++) {
      final count = realizedCountByDay[day] ?? 0;
      final hasRealisasi = count > 0;
      final isToday = _isToday(day, month);
      final isSunday =
          DateTime(month.year, month.month, day).weekday == DateTime.sunday;
      cells.add(_dayCell(
        day: day,
        hasRealisasi: hasRealisasi,
        count: count,
        isToday: isToday,
        isSunday: isSunday,
        isSelected: selectedDay == day,
        onTap: () => onDayTap(day),
      ));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview Tanggal Bulan Ini',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.circle, color: AppColors.success, size: 10),
                SizedBox(width: 6),
                Text(
                  'Tanggal dengan realisasi',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (_, constraints) {
                final ratio = constraints.maxWidth < 430
                    ? 0.92
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

  Map<int, int> _realizedCountByDay(List<RealisasiModel> list) {
    final map = <int, int>{};
    for (final item in list) {
      final date = DateTime.tryParse(item.realTgl);
      if (date == null) continue;
      map.update(date.day, (old) => old + 1, ifAbsent: () => 1);
    }
    return map;
  }

  bool _isToday(int day, DateTime month) {
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
    required bool hasRealisasi,
    required int count,
    required bool isToday,
    required bool isSunday,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bg = isSunday
        ? const Color(0xFFFEE2E2)
        : hasRealisasi
            ? AppColors.success.withValues(alpha: 0.14)
            : Colors.white;
    final fg = isSunday
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
                      color: isSunday ? AppColors.danger : AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
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

class _DonutChart extends StatelessWidget {
  final double progress;
  final Color doneColor;
  final Color remainingColor;
  final double size;

  const _DonutChart({
    required this.progress,
    required this.doneColor,
    required this.remainingColor,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final chartProgress = progress.clamp(0.0, 1.0);
    final labelPercent = (progress < 0 ? 0 : progress * 100);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              progress: chartProgress,
              doneColor: doneColor,
              remainingColor: remainingColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${labelPercent.toStringAsFixed(0)}%',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Capaian',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color doneColor;
  final Color remainingColor;

  _DonutPainter({
    required this.progress,
    required this.doneColor,
    required this.remainingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final rect = Offset.zero & size;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = remainingColor;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = doneColor;

    canvas.drawArc(rect.deflate(strokeWidth / 2), 0, math.pi * 2, false, base);
    if (progress > 0) {
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.doneColor != doneColor ||
        oldDelegate.remainingColor != remainingColor;
  }
}

class _HistoryRealisasiCard extends StatelessWidget {
  final RealisasiModel item;
  final VoidCallback onDetail;

  const _HistoryRealisasiCard({required this.item, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    final judul = item.jadwal?['jdw_judul'] ?? 'Jadwal #${item.realJadwalId}';
    final invNama = item.inventaris?['inv_nama'] ?? item.invNama;
    final invNo = item.inventaris?['inv_no'] ?? item.invNo;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              '$invNo · $invNama',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'Selesai ${DateFormatter.toDisplay(item.realTgl)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onDetail,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Lihat Detail'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyHistoryMetrics {
  final int targetCount;
  final int doneCount;

  _MonthlyHistoryMetrics({
    required this.targetCount,
    required this.doneCount,
  });

  double get completionRate {
    if (targetCount <= 0) return 0;
    return doneCount / targetCount;
  }
}
