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
      await provider.fetchJadwalByDivisi();
      await provider.fetchRealisasi(status: 'Selesai', byDivisi: true);
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
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
            final metrics = _buildMonthlyMetrics(
              jadwalList: p.jadwalList,
              realisasiList: monthRealisasi,
              month: _selectedMonth,
            );

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: _MonthSwitcher(
                      monthLabel: _monthLabel(_selectedMonth),
                      onPrevious: _previousMonth,
                      onNext: _nextMonth,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: _SummaryCard(
                      monthLabel: _monthLabel(_selectedMonth),
                      metrics: metrics,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Realisasi Bulan Ini',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${monthRealisasi.length} item',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (monthRealisasi.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      message: 'Belum ada realisasi selesai pada bulan ini',
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: monthRealisasi.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        i == 0 ? 4 : 0,
                        16,
                        i == monthRealisasi.length - 1 ? 120 : 0,
                      ),
                      child: _HistoryRealisasiCard(
                        item: monthRealisasi[i],
                        onDetail: () => _openHistoryDetail(monthRealisasi[i]),
                      ),
                    ),
                  ),
              ],
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

  _MonthlyHistoryMetrics _buildMonthlyMetrics({
    required List<JadwalModel> jadwalList,
    required List<RealisasiModel> realisasiList,
    required DateTime month,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    int targetCount = 0;
    for (final jadwal in jadwalList) {
      if (jadwal.jdwStatus != 'Aktif') continue;
      targetCount += _countScheduleAppearancesInMonth(
        jadwal,
        monthStart,
        monthEnd,
      );
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
          color: AppColors.primary.withOpacity(0.08),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan $monthLabel',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
            Row(
              children: [
                _DonutChart(
                  progress: completionRate,
                  doneColor: AppColors.success,
                  remainingColor: const Color(0xFFE2E8F0),
                  size: 132,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
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
                        value: '${(completionRate * 100).toStringAsFixed(1)}%',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              progress: clamped,
              doneColor: doneColor,
              remainingColor: remainingColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(clamped * 100).toStringAsFixed(0)}%',
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
    if (targetCount <= 0) return doneCount > 0 ? 1 : 0;
    return (doneCount / targetCount).clamp(0, 1);
  }
}
