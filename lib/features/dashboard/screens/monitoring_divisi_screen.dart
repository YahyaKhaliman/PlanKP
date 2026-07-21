import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../jadwal/providers/jadwal_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/shimmer_loading.dart';

int _toInt(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val.toInt();
  return int.tryParse('$val') ?? 0;
}

class MonitoringDivisiScreen extends StatefulWidget {
  const MonitoringDivisiScreen({super.key});

  @override
  State<MonitoringDivisiScreen> createState() => _MonitoringDivisiScreenState();
}

class _MonitoringDivisiScreenState extends State<MonitoringDivisiScreen> with SingleTickerProviderStateMixin {
  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showClear = false;
  late TabController _tabController;

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final shouldShow = _searchController.text.isNotEmpty;
    if (shouldShow != _showClear) {
      setState(() {
        _showClear = shouldShow;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JadwalProvider>().fetchMonitoringDivisi();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<JadwalProvider>();
    await provider.fetchMonitoringDivisi(
      bulan: provider.monitoringBulan,
      tahun: provider.monitoringTahun,
    );
    if (provider.error != null && mounted) {
      AppNotifier.showError(context, provider.error!);
    }
  }

  void _executeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  IconData _iconForDivisi(String divisi) {
    switch (divisi.toLowerCase()) {
      case 'it':
        return Icons.computer_rounded;
      case 'ga':
        return Icons.precision_manufacturing_rounded;
      case 'driver':
        return Icons.local_shipping_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  Color _colorForDivisi(String divisi) {
    switch (divisi.toLowerCase()) {
      case 'it':
        return const Color(0xFF6366F1); // Indigo modern
      case 'ga':
        return const Color(0xFFF97316); // Orange vibrant
      case 'driver':
        return const Color(0xFF0D9488); // Teal rich
      default:
        return AppColors.primary;
    }
  }

  Map<String, dynamic> _computeSummary(List<dynamic> list) {
    if (list.isEmpty) {
      return {
        'totalDivisi': 0,
        'divisiSelesaiPenjadwalan': 0,
        'avgPenjadwalan': 0,
        'totalBelumDijadwalkan': 0,
        'totalJadwalAktif': 0,
        'totalJadwalSelesai': 0,
        'avgRealisasi': 0,
        'totalJadwalBelumSelesai': 0,
        'totalTargetUnit': 0,
        'totalRealisasiUnit': 0,
      };
    }
    int divisiSelesaiPenjadwalan = 0;
    double sumPenjadwalanPersen = 0;
    int totalBelumDijadwalkan = 0;
    
    int totalJadwal = 0;
    int totalJadwalSelesai = 0;
    double sumRealisasiPersen = 0;
    int totalJadwalBelumSelesai = 0;
    int totalTargetUnit = 0;
    int totalRealisasiUnit = 0;

    for (final item in list) {
      if (item['sudah_dibuat_semua'] == true) divisiSelesaiPenjadwalan++;
      final int progressPenjadwalan = _toInt(item['progress_percent'] ?? item['progress_persen']);
      sumPenjadwalanPersen += progressPenjadwalan;

      final jenisList = item['jenis_list'] as List<dynamic>? ?? [];
      int divJadwal = 0;
      int divJadwalSelesai = 0;

      for (final jen in jenisList) {
        final bool sudahDijadwalkan = jen['sudah_dijadwalkan'] == true;
        if (!sudahDijadwalkan) {
          totalBelumDijadwalkan++;
        }
        
        final jadwal = jen['jadwal'] as List<dynamic>? ?? [];
        divJadwal += jadwal.length;
        for (final j in jadwal) {
          final int target = _toInt(j['jdw_target']);
          final int real = _toInt(j['jdw_realisasi']);
          totalTargetUnit += target;
          totalRealisasiUnit += real;
          if (target > 0 && real >= target) {
            divJadwalSelesai++;
          } else {
            totalJadwalBelumSelesai++;
          }
        }
      }
      
      totalJadwal += divJadwal;
      totalJadwalSelesai += divJadwalSelesai;
      
      final double divRealisasiPersen = divJadwal > 0 
          ? (divJadwalSelesai / divJadwal) * 100 
          : 0.0;
      sumRealisasiPersen += divRealisasiPersen;
    }

    return {
      'totalDivisi': list.length,
      'divisiSelesaiPenjadwalan': divisiSelesaiPenjadwalan,
      'avgPenjadwalan': list.isNotEmpty ? (sumPenjadwalanPersen / list.length).round() : 0,
      'totalBelumDijadwalkan': totalBelumDijadwalkan,
      'totalJadwalAktif': totalJadwal,
      'totalJadwalSelesai': totalJadwalSelesai,
      'avgRealisasi': list.isNotEmpty ? (sumRealisasiPersen / list.length).round() : 0,
      'totalJadwalBelumSelesai': totalJadwalBelumSelesai,
      'totalTargetUnit': totalTargetUnit,
      'totalRealisasiUnit': totalRealisasiUnit,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JadwalProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final data = provider.monitoringDivisiList;
    final summary = _computeSummary(data);

    String periodeText = '';
    if (provider.monitoringBulan != null && provider.monitoringTahun != null) {
      periodeText = '${_months[provider.monitoringBulan! - 1]} ${provider.monitoringTahun}';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            final isProgressTab = _tabController.index == 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monitoring Divisi'),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: (isProgressTab && periodeText.isNotEmpty)
                      ? InkWell(
                          key: const ValueKey('periode_dropdown'),
                          onTap: () => _selectMonthYear(context, provider),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Periode: $periodeText',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty_periode')),
                ),
              ],
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: const [
            Tab(text: 'Penjadwalan'),
            Tab(text: 'Progress'),
          ],
        ),
      ),
      body: provider.loading
          ? Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 860 : double.infinity,
                ),
                child: _buildSkeleton(isDesktop),
              ),
            )
          : Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 860 : double.infinity,
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPenjadwalanTab(data, summary, isDesktop),
                    _buildProgressTab(data, summary, isDesktop),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPenjadwalanTab(List<dynamic> data, Map<String, dynamic> summary, bool isDesktop) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        key: const PageStorageKey('penjadwalan_tab_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Status Penjadwalan Divisi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...List.generate(data.length, (index) {
            final item = data[index];
            final String divisi = item['divisi'] ?? '-';
            return Padding(
              padding: EdgeInsets.only(bottom: index < data.length - 1 ? 14 : 0),
              child: _PenjadwalanDivisiCard(
                item: item,
                isDesktop: isDesktop,
                divColor: _colorForDivisi(divisi),
                divIcon: _iconForDivisi(divisi),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressTab(List<dynamic> data, Map<String, dynamic> summary, bool isDesktop) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final provider = context.read<JadwalProvider>();
    String periodeText = '';
    if (provider.monitoringBulan != null && provider.monitoringTahun != null) {
      periodeText = '${_months[provider.monitoringBulan! - 1]} ${provider.monitoringTahun}';
    }

    // Pra-proses filter pencarian untuk menghitung total kecocokan
    int totalMatched = 0;
    final Map<String, List<dynamic>> filteredDataMap = {};

    for (final item in data) {
      final String divisi = item['divisi'] ?? '-';
      final List<dynamic> jenisList = item['jenis_list'] ?? [];
      final filteredJadwal = [];
      for (final jen in jenisList) {
        final String jenisNama = jen['jenis_nama'] ?? '-';
        final jadwalList = jen['jadwal'] ?? [];
        for (final j in jadwalList) {
          final String title = j['jdw_judul'] ?? '-';
          if (_searchQuery.isEmpty ||
              title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              jenisNama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              divisi.toLowerCase().contains(_searchQuery.toLowerCase())) {
            filteredJadwal.add({
              'jenis_nama': jenisNama,
              'jadwal': j,
            });
          }
        }
      }
      if (_searchQuery.isEmpty || filteredJadwal.isNotEmpty) {
        filteredDataMap[divisi] = filteredJadwal;
        totalMatched += filteredJadwal.length;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        key: const PageStorageKey('progress_tab_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildSearchField(),
          const SizedBox(height: 16),
          
          // Indikator/Penjelasan Pencarian Aktif (Minimalis)
          if (_searchQuery.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    totalMatched > 0 ? Icons.check_rounded : Icons.info_outline_rounded,
                    size: 14,
                    color: totalMatched > 0 ? AppColors.primary : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        children: [
                          TextSpan(
                            text: totalMatched > 0
                                ? 'Menampilkan '
                                : 'Tidak ditemukan hasil untuk ',
                          ),
                          if (totalMatched > 0)
                            TextSpan(
                              text: '$totalMatched ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (totalMatched > 0)
                            const TextSpan(text: 'progress untuk kata kunci '),
                          TextSpan(
                            text: '"$_searchQuery"',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalMatched > 0 ? AppColors.primary : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (totalMatched > 0 || _searchQuery.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
              child: Text(
                'Progress Realisasi Divisi ($periodeText)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...List.generate(data.length, (index) {
              final item = data[index];
              final String divisi = item['divisi'] ?? '-';
              
              if (_searchQuery.isNotEmpty && !filteredDataMap.containsKey(divisi)) {
                return const SizedBox.shrink();
              }

              final filteredJadwal = filteredDataMap[divisi] ?? [];

              return Padding(
                padding: EdgeInsets.only(bottom: index < data.length - 1 ? 14 : 0),
                child: _ProgressDivisiCard(
                  item: item,
                  filteredJadwal: filteredJadwal,
                  isDesktop: isDesktop,
                  divColor: _colorForDivisi(divisi),
                  divIcon: _iconForDivisi(divisi),
                ),
              );
            }),
          ] else ...[
            // Tampilan jika hasil pencarian kosong/tidak ditemukan sama sekali (Minimalis)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tidak ada progress yang cocok dengan "$_searchQuery"',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Pencarian', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: AppColors.border),
                SizedBox(height: 12),
                Text(
                  'Tidak ada data monitoring divisi.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input row
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _executeSearch(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari divisi / jadwal...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                // Clear button (animated)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: _showClear
                      ? Material(
                          key: const ValueKey('clear'),
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _clearSearch,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                const SizedBox(width: 6),
                // Search button
                SizedBox(
                  height: 38,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _executeSearch,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Cari',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(bool isDesktop) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final isProgressTab = _tabController.index == 1;
        return AppShimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (isProgressTab) ...[
                const AppSkeletonSquircle(width: double.infinity, height: 46, borderRadius: 14),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 8, bottom: 10),
                  child: AppSkeletonLine(width: 220, height: 16, borderRadius: 4),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: AppSkeletonLine(width: 180, height: 16, borderRadius: 4),
                ),
              ],
              // List Cards Placeholder
              ...List.generate(3, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: AppSkeletonFolderCard(),
              )),
            ],
          ),
        );
      },
    );
  }


  Future<void> _selectMonthYear(BuildContext context, JadwalProvider provider) async {
    final today = DateTime.now();
    int tempBulan = provider.monitoringBulan ?? today.month;
    int tempTahun = provider.monitoringTahun ?? today.year;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Periode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tahun:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: () {
                              setDialogState(() {
                                tempTahun--;
                              });
                            },
                          ),
                          Text(
                            '$tempTahun',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () {
                              setDialogState(() {
                                tempTahun++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    height: 180,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final bulanNum = index + 1;
                        final isSelected = tempBulan == bulanNum;
                        final name = _months[index].substring(0, 3);

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempBulan = bulanNum;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    provider.fetchMonitoringDivisi(bulan: tempBulan, tahun: tempTahun);
                  },
                  child: const Text('Pilih'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// =============================================
// DIVISI CARD WIDGET FOR TAB 1: PENJADWALAN
// =============================================

class _PenjadwalanDivisiCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isDesktop;
  final Color divColor;
  final IconData divIcon;

  const _PenjadwalanDivisiCard({
    required this.item,
    required this.isDesktop,
    required this.divColor,
    required this.divIcon,
  });

  @override
  State<_PenjadwalanDivisiCard> createState() => _PenjadwalanDivisiCardState();
}

class _PenjadwalanDivisiCardState extends State<_PenjadwalanDivisiCard> {
  bool _isExpanded = false;
  bool _isBelumDijadwalkanExpanded = true;
  bool _isSudahDijadwalkanExpanded = true;

  @override
  Widget build(BuildContext context) {
    final String divisi = widget.item['divisi'] ?? '-';
    final bool sudahDibuatSemua = widget.item['sudah_dibuat_semua'] ?? false;
    final int totalJenis = _toInt(widget.item['total_jenis']);
    final int jenisDijadwalkan = _toInt(widget.item['jenis_dijadwalkan']);
    final int progressPersen = _toInt(widget.item['progress_percent'] ?? widget.item['progress_persen']);
    final List<dynamic> jenisList = widget.item['jenis_list'] ?? [];
    
    final double progressValue = totalJenis > 0 ? (jenisDijadwalkan / totalJenis).clamp(0.0, 1.0) : 0.0;

    final scheduled = jenisList.where((j) => j['sudah_dijadwalkan'] == true).toList();
    final unscheduled = jenisList.where((j) => j['sudah_dijadwalkan'] != true).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.divColor.withOpacity(0.15),
                              widget.divColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.divIcon,
                          color: widget.divColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Divisi $divisi',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalJenis jenis inventaris',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sudahDibuatSemua
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sudahDibuatSemua ? Icons.check_circle_rounded : Icons.schedule_rounded,
                              size: 13,
                              color: sudahDibuatSemua ? AppColors.success : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sudahDibuatSemua ? 'Lengkap' : 'Belum Lengkap',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sudahDibuatSemua ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _KpiStrip(
                    label: 'Status Penjadwalan',
                    value: '$jenisDijadwalkan/$totalJenis jenis',
                    percent: progressPersen,
                    progressValue: progressValue,
                    color: widget.divColor,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildPenjadwalanDetails(jenisList, scheduled, unscheduled),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildPenjadwalanDetails(List<dynamic> jenisList, List<dynamic> scheduled, List<dynamic> unscheduled) {
    if (jenisList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Belum ada jenis inventaris aktif',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFD),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unscheduled.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _isBelumDijadwalkanExpanded = !_isBelumDijadwalkanExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Belum Dijadwalkan (${unscheduled.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                    ),
                    AnimatedRotation(
                      turns: _isBelumDijadwalkanExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 6),
                  ...unscheduled.map((jen) => _buildTile(jen, false)),
                ],
              ),
              crossFadeState: _isBelumDijadwalkanExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
            const SizedBox(height: 12),
          ],
          if (scheduled.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _isSudahDijadwalkanExpanded = !_isSudahDijadwalkanExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sudah Dijadwalkan (${scheduled.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                    AnimatedRotation(
                      turns: _isSudahDijadwalkanExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 6),
                  ...scheduled.map((jen) => _buildTile(jen, true)),
                ],
              ),
              crossFadeState: _isSudahDijadwalkanExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(dynamic jen, bool isScheduled) {
    final String name = jen['jenis_nama'] ?? '-';
    final Color color = isScheduled ? AppColors.success : AppColors.danger;
    final List<dynamic> jadwalList = jen['all_jadwal'] ?? jen['jadwal'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (!isScheduled || jadwalList.isEmpty)
              ? null
              : () {
                  if (jadwalList.length == 1) {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.jadwalDetail,
                      arguments: _toInt(jadwalList[0]['jdw_id']),
                    );
                  } else {
                    _showJadwalSelectionSheet(context, name, jadwalList);
                  }
                },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      if (isScheduled && jadwalList.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          jadwalList.length == 1
                              ? 'Mulai: ${DateFormatter.toDisplayFull(jadwalList[0]['jdw_tgl_mulai'])}'
                              : 'Mulai: ${jadwalList.map((j) => DateFormatter.toDisplayFull(j['jdw_tgl_mulai'])).join(', ')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isScheduled ? '${jadwalList.length} jadwal aktif' : 'Belum dijadwalkan',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isScheduled && jadwalList.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showJadwalSelectionSheet(BuildContext context, String jenisNama, List<dynamic> schedules) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Jadwal - $jenisNama',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Silakan pilih jadwal untuk melihat detail selengkapnya:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final s = schedules[index];
                      final String title = s['jdw_judul'] ?? '-';
                      final String freq = s['jdw_frekuensi'] ?? '-';
                      final String tglMulai = DateFormatter.toDisplayFull(s['jdw_tgl_mulai']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Frekuensi: $freq | Mulai: $tglMulai',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primary,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              AppRoutes.jadwalDetail,
                              arguments: _toInt(s['jdw_id']),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================
// DIVISI CARD WIDGET FOR TAB 2: PROGRESS REALISASI
// =============================================

class _ProgressDivisiCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<dynamic> filteredJadwal;
  final bool isDesktop;
  final Color divColor;
  final IconData divIcon;

  const _ProgressDivisiCard({
    required this.item,
    required this.filteredJadwal,
    required this.isDesktop,
    required this.divColor,
    required this.divIcon,
  });

  @override
  State<_ProgressDivisiCard> createState() => _ProgressDivisiCardState();
}

class _ProgressDivisiCardState extends State<_ProgressDivisiCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final String divisi = widget.item['divisi'] ?? '-';
    final List<dynamic> jenisList = widget.item['jenis_list'] ?? [];
    
    int totalJadwal = 0;
    int totalTarget = 0;
    int totalRealisasi = 0;
    bool isAllSelesai = true;

    final today = DateTime.now();
    final provider = context.read<JadwalProvider>();
    final bool isCurrentMonth = provider.monitoringBulan == today.month &&
        provider.monitoringTahun == today.year;

    for (final jen in jenisList) {
      final jadwal = jen['jadwal'] as List<dynamic>? ?? [];
      totalJadwal += jadwal.length;
      for (final j in jadwal) {
        final int target = _toInt(j['jdw_target']);
        final int real = _toInt(j['jdw_realisasi']);
        totalTarget += target;
        totalRealisasi += real;

        final bool scheduleSelesai = isCurrentMonth
            ? (j['jdw_period_fulfilled'] == true)
            : (target > 0 && real >= target);

        if (!scheduleSelesai) {
          isAllSelesai = false;
        }
      }
    }

    if (totalJadwal == 0) {
      isAllSelesai = false;
    }

    final int realisasiPersen = totalTarget > 0 ? ((totalRealisasi / totalTarget) * 100).round().clamp(0, 100) : 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.divColor.withOpacity(0.15),
                              widget.divColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.divIcon,
                          color: widget.divColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Divisi ${divisi.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalJadwal jadwal aktif',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAllSelesai
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAllSelesai ? Icons.check_circle_rounded : Icons.pending_rounded,
                              size: 13,
                              color: isAllSelesai ? AppColors.success : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAllSelesai ? 'Selesai' : 'Belum Selesai',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isAllSelesai ? AppColors.success : AppColors.warning),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _KpiStrip(
                    label: 'Realisasi Jadwal',
                    value: '$totalRealisasi/$totalTarget (Realisasi/Target)',
                    percent: realisasiPersen,
                    progressValue: totalTarget > 0 ? (totalRealisasi / totalTarget).clamp(0.0, 1.0) : 0.0,
                    color: widget.divColor,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildProgressDetails(),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDetails() {
    if (widget.filteredJadwal.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Tidak ada jadwal aktif.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFD),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: widget.filteredJadwal.map((item) {
          final String jenisNama = item['jenis_nama'];
          final j = item['jadwal'];
          final String title = j['jdw_judul'] ?? '-';
          final String freq = j['jdw_frekuensi'] ?? '-';
          final int target = _toInt(j['jdw_target']);
          final int real = _toInt(j['jdw_realisasi']);
          final int pct = _toInt(j['jdw_persen']);
          final double barVal = target > 0 ? (real / target).clamp(0.0, 1.0) : 0.0;
          final today = DateTime.now();
          final provider = context.read<JadwalProvider>();
          final bool isCurrentMonth = provider.monitoringBulan == today.month &&
              provider.monitoringTahun == today.year;
          final bool isSelesai = isCurrentMonth
              ? (j['jdw_period_fulfilled'] == true)
              : (target > 0 && real >= target);

          final Color barColor = isSelesai
              ? AppColors.success
              : pct > 50
                  ? AppColors.primary
                  : pct > 0
                      ? AppColors.warning
                      : AppColors.border;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.jadwalDetail,
                    arguments: _toInt(j['jdw_id']),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              jenisNama,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.divColor),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              freq,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelesai ? AppColors.success.withOpacity(0.08) : AppColors.warning.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSelesai ? 'SELESAI' : 'BELUM SELESAI',
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelesai ? AppColors.success : AppColors.warning,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 11,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mulai: ${DateFormatter.toDisplayFull(j['jdw_tgl_mulai'])}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: barVal,
                                minHeight: 6,
                                backgroundColor: AppColors.bgGray,
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$real/$target (Realisasi/Target)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: barColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$pct%',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: barColor),
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
        }).toList(),
      ),
    );
  }
}

// =============================================
// REUSABLE WIDGETS
// =============================================

class _KpiStrip extends StatelessWidget {
  final String label;
  final String value;
  final int percent;
  final double progressValue;
  final Color color;

  const _KpiStrip({
    required this.label,
    required this.value,
    required this.percent,
    required this.progressValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 5,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
