import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/file_downloader/file_downloader.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../auth/providers/auth_provider.dart';
import '../../master/providers/master_provider.dart';
import '../models/jadwal_model.dart';
import '../providers/jadwal_provider.dart';
import '../services/jadwal_pdf_service.dart';

class ExportJadwalDialog extends StatefulWidget {
  final List<JadwalModel> jadwalList;

  const ExportJadwalDialog({
    super.key,
    required this.jadwalList,
  });

  static Future<void> show(
    BuildContext context, {
    required List<JadwalModel> jadwalList,
  }) async {
    final downloadedFilename = await showDialog<String>(
      context: context,
      builder: (_) => ExportJadwalDialog(jadwalList: jadwalList),
    );

    if (downloadedFilename != null && context.mounted) {
      await AppNotifier.showSuccess(
        context,
        'Berkas Excel berhasil diunduh: $downloadedFilename',
      );
    }
  }

  @override
  State<ExportJadwalDialog> createState() => _ExportJadwalDialogState();
}

class _ExportJadwalDialogState extends State<ExportJadwalDialog> {
  String _selectedDivisi = 'Semua Divisi';
  String _selectedPelaksana = 'Semua Pelaksana';
  String _selectedFrekuensi = 'Semua Frekuensi';
  late int _selectedMonth;
  late int _selectedYear;

  bool _isLoadingPdf = false;
  bool _isLoadingExcel = false;

  bool get _isProcessing => _isLoadingPdf || _isLoadingExcel;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    final auth = context.read<AuthProvider>();
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final divisi = (auth.user?['user_divisi'] ?? '').toString().trim();
    final nama = (auth.user?['user_nama'] ?? '').toString().trim();

    final isManager = role == 'manager';
    final isAdmin = role == 'admin';

    if (isAdmin && divisi.isNotEmpty) {
      _selectedDivisi = _normalizeDivisi(divisi);
      _selectedPelaksana = 'Semua Pelaksana';
    } else if (!isManager && !isAdmin) {
      if (divisi.isNotEmpty) _selectedDivisi = _normalizeDivisi(divisi);
      if (nama.isNotEmpty) _selectedPelaksana = nama;
    } else {
      _selectedDivisi = 'Semua Divisi';
      _selectedPelaksana = 'Semua Pelaksana';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final master = context.read<MasterProvider>();
      if (master.divisiMetadata.isEmpty) {
        master.fetchMetadata(showLoading: false);
      }
      if (master.jenisMaster.isEmpty) {
        master.fetchJenis(showLoading: false);
      }
      if (master.userList.isEmpty) {
        master.fetchUsers(showLoading: false);
      }
    });
  }

  String _normalizeDivisi(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final lower = trimmed.toLowerCase();
    if (lower == 'ga') return 'GA';
    if (lower == 'it') return 'IT';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  List<String> _getDivisiOptions(MasterProvider master, AuthProvider auth) {
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final divisi = (auth.user?['user_divisi'] ?? '').toString().trim();
    final isManager = role == 'manager';

    if (!isManager && divisi.isNotEmpty) {
      return [_normalizeDivisi(divisi)];
    }

    final mapDivisi = <String, String>{};

    void addDivisi(String raw) {
      final norm = _normalizeDivisi(raw);
      if (norm.isNotEmpty) {
        mapDivisi[norm.toLowerCase()] = norm;
      }
    }

    for (final div in master.divisiMetadata) {
      addDivisi(div);
    }

    for (final j in master.jenisMaster) {
      addDivisi(j.jenisKategori);
    }

    if (mapDivisi.isEmpty) {
      for (final d in ['GA', 'Teknisi', 'Driver', 'IT', 'Produksi', 'Workshop']) {
        addDivisi(d);
      }
    }

    final sorted = mapDivisi.values.toList()..sort();
    return ['Semua Divisi', ...sorted];
  }

  List<int> _getYearOptions() {
    final currentYear = DateTime.now().year;
    final endYear = currentYear < 2026 ? 2026 : currentYear + 1;
    final years = <int>[];
    for (int y = 2026; y <= endYear; y++) {
      years.add(y);
    }
    return years;
  }

  List<String> _getPelaksanaOptions(
      JadwalProvider provider, MasterProvider master, AuthProvider auth) {
    final role = (auth.user?['user_jabatan'] ?? '').toString().toLowerCase();
    final nama = (auth.user?['user_nama'] ?? '').toString().trim();
    final isManager = role == 'manager';
    final isAdmin = role == 'admin';

    if (!isManager && !isAdmin && nama.isNotEmpty) {
      return [nama];
    }

    final setNames = <String>{};

    for (final u in master.userList) {
      final uNama = u.userNama.trim();
      final uDiv = u.userDivisi.trim();
      final uJabatan = u.userJabatan.trim().toLowerCase();

      if (uNama.isEmpty) continue;

      final isUserRole =
          uJabatan == 'user' || uJabatan == 'teknisi' || uJabatan == 'it_support';
      if (!isUserRole) continue;

      if (_selectedDivisi != 'Semua Divisi') {
        if (_normalizeDivisi(uDiv) == _normalizeDivisi(_selectedDivisi)) {
          setNames.add(uNama);
        }
      } else {
        setNames.add(uNama);
      }
    }

    final list = widget.jadwalList.isNotEmpty
        ? widget.jadwalList
        : provider.jadwalList;
    for (final j in list) {
      final jDiv = j.jdwDivisi.trim();
      final jNama = (j.assignedUser?['user_nama'] ?? '').toString().trim();
      if (jNama.isEmpty) continue;

      if (_selectedDivisi != 'Semua Divisi') {
        if (_normalizeDivisi(jDiv) == _normalizeDivisi(_selectedDivisi)) {
          setNames.add(jNama);
        }
      } else {
        setNames.add(jNama);
      }
    }

    final sorted = setNames.toList()..sort();
    return ['Semua Pelaksana', ...sorted];
  }

  bool _hasMatchingJadwalData({
    required List<JadwalModel> jadwalList,
    required String divisiFilter,
    required String pelaksanaFilter,
    required String frekuensiFilter,
    required int month,
    required int year,
  }) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

    for (final j in jadwalList) {
      if (divisiFilter != 'Semua Divisi') {
        if (_normalizeDivisi(j.jdwDivisi) != _normalizeDivisi(divisiFilter)) {
          continue;
        }
      }

      if (pelaksanaFilter != 'Semua Pelaksana' && pelaksanaFilter.isNotEmpty) {
        final assignedName =
            (j.assignedUser?['user_nama'] ?? '').toString().trim().toLowerCase();
        if (!assignedName.contains(pelaksanaFilter.toLowerCase())) {
          continue;
        }
      }

      if (frekuensiFilter != 'Semua Frekuensi' && frekuensiFilter.isNotEmpty) {
        if (j.jdwFrekuensi.toLowerCase() != frekuensiFilter.toLowerCase()) {
          continue;
        }
      }

      final tglMulai = DateTime.tryParse(j.jdwTglMulai);
      if (tglMulai != null && tglMulai.isAfter(monthEnd)) {
        continue;
      }
      if (j.jdwTglSelesai != null && j.jdwTglSelesai!.isNotEmpty) {
        final tglSelesai = DateTime.tryParse(j.jdwTglSelesai!);
        if (tglSelesai != null && tglSelesai.isBefore(monthStart)) {
          continue;
        }
      }

      return true;
    }
    return false;
  }

  Future<void> _downloadExcel() async {
    if (_isProcessing) return;

    final provider = context.read<JadwalProvider>();
    final jadwalList = widget.jadwalList.isNotEmpty
        ? widget.jadwalList
        : provider.jadwalList;

    setState(() => _isLoadingExcel = true);
    AppNotifier.showInfo(
        context, 'Memproses unduhan berkas Excel Jadwal Maintenance...');

    try {
      final queryParams = <String, dynamic>{
        'bulan': '$_selectedMonth',
        'tahun': '$_selectedYear',
        'status': 'Aktif',
        'base64': 'true', // Menggunakan JSON Base64 agar tidak dicegat oleh IDM
      };
      if (_selectedDivisi != 'Semua Divisi') {
        queryParams['divisi'] = _selectedDivisi;
      }
      if (_selectedFrekuensi != 'Semua Frekuensi') {
        queryParams['frekuensi'] = _selectedFrekuensi;
      }
      if (_selectedPelaksana != 'Semua Pelaksana') {
        for (final j in jadwalList) {
          final name = (j.assignedUser?['user_nama'] ?? '').toString().trim();
          if (name == _selectedPelaksana && j.jdwAssignedTo != null) {
            queryParams['teknisi_id'] = '${j.jdwAssignedTo}';
            break;
          }
        }
      }

      final res = await ApiClient.get(
        '${ApiConfig.jadwal}/export-excel',
        query: queryParams,
      );

      final data = res['data'];
      if (data is Map && data['base64'] != null) {
        final String base64Str = data['base64'];
        final filename =
            data['filename']?.toString() ?? 'Laporan_Jadwal_Maintenance.xlsx';
        final bytes = base64Decode(base64Str);

        final success = await FileDownloader.downloadBytes(
          bytes: bytes,
          fileName: filename,
        );

        if (success) {
          if (mounted) {
            Navigator.of(context).pop(filename);
          }
        } else {
          if (mounted) {
            await AppNotifier.showError(
              context,
              'Gagal menyimpan berkas Excel ke perangkat',
            );
          }
        }
      } else {
        if (mounted) {
          await AppNotifier.showError(
            context,
            'Gagal memproses berkas Excel: Format respons tidak valid',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await AppNotifier.showError(context, 'Gagal mengunduh Excel: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingExcel = false);
      }
    }
  }

  Future<void> _generateAndPreviewPdf() async {
    if (_isProcessing) return;

    final provider = context.read<JadwalProvider>();
    final selectedDivisi = _selectedDivisi;
    final selectedPelaksana = _selectedPelaksana;
    final selectedFrekuensi = _selectedFrekuensi;
    final selectedMonth = _selectedMonth;
    final selectedYear = _selectedYear;

    setState(() => _isLoadingPdf = true);
    AppNotifier.showInfo(context, 'Menyiapkan dokumen PDF Jadwal Maintenance...');

    try {
      int? assignedToId;
      if (selectedPelaksana != 'Semua Pelaksana') {
        for (final j in provider.jadwalList) {
          final name = (j.assignedUser?['user_nama'] ?? '').toString().trim();
          if (name == selectedPelaksana && j.jdwAssignedTo != null) {
            assignedToId = j.jdwAssignedTo;
            break;
          }
        }
      }

      final fetchedJadwal = await provider.fetchJadwalForReport(
        bulan: selectedMonth,
        tahun: selectedYear,
        divisi: selectedDivisi,
        assignedTo: assignedToId,
        frekuensi: selectedFrekuensi,
        status: 'Aktif',
      );

      final jadwalList = fetchedJadwal.isNotEmpty
          ? fetchedJadwal
          : (widget.jadwalList.isNotEmpty ? widget.jadwalList : provider.jadwalList);

      final hasData = _hasMatchingJadwalData(
        jadwalList: jadwalList,
        divisiFilter: selectedDivisi,
        pelaksanaFilter: selectedPelaksana,
        frekuensiFilter: selectedFrekuensi,
        month: selectedMonth,
        year: selectedYear,
      );

      if (!hasData) {
        if (!mounted) return;
        final bulanNama = DateFormatter.monthNames[selectedMonth - 1];
        final targetStr = selectedPelaksana != 'Semua Pelaksana'
            ? 'user $selectedPelaksana'
            : 'divisi $selectedDivisi';
        await AppNotifier.showWarning(
          context,
          'Tidak ditemukan data jadwal aktif untuk $targetStr pada bulan $bulanNama $selectedYear.',
        );
        return;
      }

      final pdfBytes = await JadwalPdfService.generateJadwalPdf(
        divisiFilter: selectedDivisi,
        pelaksanaFilter: selectedPelaksana,
        frekuensiFilter: selectedFrekuensi,
        month: selectedMonth,
        year: selectedYear,
        jadwalList: jadwalList,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name:
            'Laporan_Jadwal_${selectedDivisi.replaceAll(" ", "_")}_${DateFormatter.monthNames[selectedMonth - 1]}_$selectedYear.pdf',
      );
    } catch (e) {
      if (mounted) {
        await AppNotifier.showError(context, 'Gagal membuat file PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: AppColors.cardSurface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Dialog
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.file_download_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Jadwal (Excel / PDF)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Berdasarkan periode, divisi, dan pelaksana',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceAlt,
                      foregroundColor: AppColors.textSecondary,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Dropdown Divisi
              Text(
                'Pilih Divisi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final master = context.watch<MasterProvider>();
                  final auth = context.watch<AuthProvider>();
                  final divisiList = _getDivisiOptions(master, auth);
                  final safeSelectedDivisi = divisiList.contains(_selectedDivisi)
                      ? _selectedDivisi
                      : divisiList.first;
                  final isDivisiLocked = divisiList.length == 1;

                  return DropdownButtonFormField<String>(
                    value: safeSelectedDivisi,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.business_rounded, size: 18),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: isDivisiLocked,
                      fillColor: isDivisiLocked ? AppColors.surfaceAlt : null,
                    ),
                    items: divisiList.map((div) {
                      return DropdownMenuItem(
                        value: div,
                        child: Text(div,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: isDivisiLocked
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedDivisi = val);
                            }
                          },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Dropdown Pelaksana
              Text(
                'Pilih Pelaksana',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final provider = context.watch<JadwalProvider>();
                  final master = context.watch<MasterProvider>();
                  final auth = context.watch<AuthProvider>();
                  final pelaksanaOptions =
                      _getPelaksanaOptions(provider, master, auth);
                  final safePelaksana =
                      pelaksanaOptions.contains(_selectedPelaksana)
                          ? _selectedPelaksana
                          : pelaksanaOptions.first;
                  final isPelaksanaLocked = pelaksanaOptions.length == 1;

                  return DropdownButtonFormField<String>(
                    value: safePelaksana,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: isPelaksanaLocked,
                      fillColor: isPelaksanaLocked ? AppColors.surfaceAlt : null,
                    ),
                    items: pelaksanaOptions.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          p,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: isPelaksanaLocked
                        ? null
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedPelaksana = val);
                            }
                          },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Dropdown Frekuensi
              Text(
                'Frekuensi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedFrekuensi,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.repeat_rounded, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Semua Frekuensi',
                    child: Text('Semua Frekuensi', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'Harian',
                    child: Text('Harian', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'Mingguan',
                    child: Text('Mingguan', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: 'Bulanan',
                    child: Text('Bulanan', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFrekuensi = val);
                },
              ),
              const SizedBox(height: 14),

              // Filter Periode (Bulan & Tahun)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(
                              value: i + 1,
                              child: Text(DateFormatter.monthNames[i],
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5)),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMonth = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tahun',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final years = _getYearOptions();
                            final safeYear = years.contains(_selectedYear)
                                ? _selectedYear
                                : years.first;

                            return DropdownButtonFormField<int>(
                              value: safeYear,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              items: years.map((yr) {
                                return DropdownMenuItem(
                                  value: yr,
                                  child: Text('$yr',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedYear = val);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isProcessing ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _downloadExcel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isLoadingExcel
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.table_chart_rounded, size: 16),
                      label: Text(
                        _isLoadingExcel ? 'Proses...' : 'Excel',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _generateAndPreviewPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isLoadingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 16),
                      label: Text(
                        _isLoadingPdf ? 'Proses...' : 'PDF',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
