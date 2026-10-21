import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../../core/utils/date_formatter.dart';
import '../models/jadwal_model.dart';

class _C {
  static const primary     = PdfColor.fromInt(0xFF0D3B6E);
  static const primaryLight= PdfColor.fromInt(0xFFE3EDF8);
  static const good        = PdfColor.fromInt(0xFF16A34A);
  static const goodBg      = PdfColor.fromInt(0xFFDCFCE7);
  static const info        = PdfColor.fromInt(0xFF2563EB);
  static const infoBg      = PdfColor.fromInt(0xFFDBEAFE);
  static const textDark    = PdfColor.fromInt(0xFF0F172A);
  static const textMid     = PdfColor.fromInt(0xFF475569);
  static const textLight   = PdfColor.fromInt(0xFF94A3B8);
  static const borderLight = PdfColor.fromInt(0xFFCBD5E1);
  static const bgAlt       = PdfColor.fromInt(0xFFF8FAFC);
  static const white       = PdfColors.white;
}

class JadwalPdfService {
  static Future<Uint8List> generateJadwalPdf({
    required String divisiFilter,
    String? pelaksanaFilter,
    String? frekuensiFilter,
    required int month,
    required int year,
    required List<JadwalModel> jadwalList,
  }) async {
    final pdf = pw.Document(
      title: 'Laporan Jadwal Maintenance',
      author: 'PlanKP | CV. Kencana Print',
    );

    // Muat logo jika tersedia
    Uint8List? logoBytes;
    try {
      final d = await rootBundle.load('assets/images/logo.png');
      logoBytes = d.buffer.asUint8List();
    } catch (_) {}
    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final selectedPelaksana = (pelaksanaFilter ?? 'Semua Pelaksana').trim();
    final selectedFrekuensi = (frekuensiFilter ?? 'Semua Frekuensi').trim();

    // ── Filter Jadwal Sesuai Periode, Divisi, Pelaksana, Frekuensi ────────────
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

    final filteredJadwal = jadwalList.where((j) {
      // Filter Divisi
      if (divisiFilter != 'Semua Divisi' && divisiFilter.isNotEmpty) {
        if (j.jdwDivisi.trim().toUpperCase() != divisiFilter.trim().toUpperCase()) {
          return false;
        }
      }

      // Filter Pelaksana
      if (selectedPelaksana != 'Semua Pelaksana' && selectedPelaksana.isNotEmpty) {
        final assignedName = (j.assignedUser?['user_nama'] ?? '').toString().trim().toLowerCase();
        if (!assignedName.contains(selectedPelaksana.toLowerCase())) {
          return false;
        }
      }

      // Filter Frekuensi
      if (selectedFrekuensi != 'Semua Frekuensi' && selectedFrekuensi.isNotEmpty) {
        if (j.jdwFrekuensi.trim().toLowerCase() != selectedFrekuensi.trim().toLowerCase()) {
          return false;
        }
      }

      // Filter Rentang Periode Keaktifan Jadwal
      final tglMulai = DateTime.tryParse(j.jdwTglMulai);
      if (tglMulai != null && tglMulai.isAfter(monthEnd)) {
        return false;
      }
      if (j.jdwTglSelesai != null && j.jdwTglSelesai!.isNotEmpty) {
        final tglSelesai = DateTime.tryParse(j.jdwTglSelesai!);
        if (tglSelesai != null && tglSelesai.isBefore(monthStart)) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final freqA = _freqPriority(a.jdwFrekuensi);
        final freqB = _freqPriority(b.jdwFrekuensi);
        if (freqA != freqB) return freqA.compareTo(freqB);
        return a.jdwTglMulai.compareTo(b.jdwTglMulai);
      });

    // ── Hitung Statistik Total Unit & Capaian ─────────────────────────────────
    int totalTargetUnit = 0;
    int totalSelesaiUnit = 0;

    for (final j in filteredJadwal) {
      final tgt = j.jdwTarget ?? j.jdwTotalUnit ?? 0;
      final sls = j.jdwSelesaiUnit ?? 0;
      totalTargetUnit += tgt;
      totalSelesaiUnit += sls;
    }

    final totalPctOverall = totalTargetUnit > 0
        ? ((totalSelesaiUnit / totalTargetUnit) * 100).round().clamp(0, 100)
        : (totalSelesaiUnit > 0 ? 100 : 0);

    final periodeStr = '${DateFormatter.monthNames[month - 1]} $year';
    final printStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // ── Bangun Dokumen PDF dalam MODE PORTRAIT (A4) ──────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // Mode Portrait
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
        header: (_) => _buildHeader(
          logoImage: logoImage,
          periodeStr: periodeStr,
          divisiFilter: divisiFilter,
          pelaksanaFilter: selectedPelaksana,
          frekuensiFilter: selectedFrekuensi,
          printStr: printStr,
        ),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) => [
          pw.SizedBox(height: 6),

          // ── KOTAK KPI RINGKASAN PORTRAIT ────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: pw.BoxDecoration(
              color: _C.bgAlt,
              border: pw.Border.all(color: _C.borderLight, width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                // Badge Total Persentase
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: totalPctOverall >= 100
                        ? _C.goodBg
                        : (totalPctOverall > 0 ? _C.infoBg : _C.bgAlt),
                    border: pw.Border.all(
                      color: totalPctOverall >= 100
                          ? _C.good
                          : (totalPctOverall > 0 ? _C.info : _C.borderLight),
                      width: 1,
                    ),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        '$totalPctOverall%',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: totalPctOverall >= 100
                              ? _C.good
                              : (totalPctOverall > 0 ? _C.info : _C.textMid),
                        ),
                      ),
                      pw.Text(
                        'Capaian',
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: totalPctOverall >= 100
                              ? _C.good
                              : (totalPctOverall > 0 ? _C.info : _C.textMid),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),

                // Info Teks Ringkasan
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Ringkasan Jadwal & Realisasi Unit',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _C.textDark,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Divisi: $divisiFilter | Periode: $periodeStr',
                        style: const pw.TextStyle(fontSize: 7.5, color: _C.textMid),
                      ),
                      pw.Text(
                        'Total: ${filteredJadwal.length} Jadwal | Target: $totalTargetUnit Unit | Selesai: $totalSelesaiUnit Unit',
                        style: const pw.TextStyle(fontSize: 7.5, color: _C.textLight),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(width: 8),

                // Pill Ringkas
                _kpiPill('Jadwal', '${filteredJadwal.length}', _C.primary, _C.primaryLight),
                pw.SizedBox(width: 5),
                _kpiPill('Target', '$totalTargetUnit', _C.textMid, _C.bgAlt),
                pw.SizedBox(width: 5),
                _kpiPill('Selesai', '$totalSelesaiUnit', _C.good, _C.goodBg),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          // ── TABEL JADWAL PORTRAIT ───────────────────────────────────────────
          _buildJadwalTablePortrait(filteredJadwal),

          pw.SizedBox(height: 14),

          // ── BAGIAN TANDA TANGAN PORTRAIT ────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Dibuat / Dilaporkan Oleh,',
                      style: const pw.TextStyle(fontSize: 7.5, color: _C.textMid)),
                  pw.SizedBox(height: 32),
                  pw.Container(
                    width: 120,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: _C.textDark, width: 0.8)),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    selectedPelaksana != 'Semua Pelaksana' ? selectedPelaksana : 'Pelaksana Maintenance',
                    style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _C.textDark),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Mengetahui / Menyetujui,',
                      style: const pw.TextStyle(fontSize: 7.5, color: _C.textMid)),
                  pw.SizedBox(height: 32),
                  pw.Container(
                    width: 120,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: _C.textDark, width: 0.8)),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Kepala Divisi / Manager',
                    style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _C.textDark),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static int _freqPriority(String? frekuensi) {
    switch (frekuensi) {
      case 'Harian':
        return 1;
      case 'Mingguan':
        return 2;
      case 'Bulanan':
        return 3;
      default:
        return 4;
    }
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    pw.MemoryImage? logoImage,
    required String periodeStr,
    required String divisiFilter,
    required String pelaksanaFilter,
    required String frekuensiFilter,
    required String printStr,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null)
              pw.Container(
                width: 28,
                height: 28,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(logoImage),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CV. KENCANA PRINT',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _C.primary,
                    ),
                  ),
                  pw.Text(
                    'Aplikasi PlanKP | Sistem Penjadwalan & Pemeliharaan Terpadu',
                    style: const pw.TextStyle(fontSize: 7, color: _C.textMid),
                  ),
                  pw.Text(
                    'LAPORAN JADWAL PEMELIHARAAN (PREVENTIVE MAINTENANCE)',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _C.textDark,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Dicetak: $printStr',
              style: const pw.TextStyle(fontSize: 7, color: _C.textMid),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 1.2, color: _C.primary),
        pw.SizedBox(height: 2),
      ],
    );
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.only(top: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _C.borderLight, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('CV. Kencana Print | Aplikasi Mobile & Web PlanKP',
              style: const pw.TextStyle(fontSize: 6.5, color: _C.textLight)),
          pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: _C.primary,
              )),
        ],
      ),
    );
  }

  // ── KPI PILL ──────────────────────────────────────────────────────────────
  static pw.Widget _kpiPill(String label, String val, PdfColor color, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border.all(color: color, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(val,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text(label, style: pw.TextStyle(fontSize: 6, color: color)),
        ],
      ),
    );
  }

  // ── TABEL JADWAL KHUSUS MODE PORTRAIT ─────────────────────────────────────
  static pw.Widget _buildJadwalTablePortrait(List<JadwalModel> list) {
    if (list.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 20),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _C.borderLight, width: 0.7),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Center(
          child: pw.Text(
            'Tidak ada data jadwal untuk periode dan kriteria filter ini.',
            style: const pw.TextStyle(fontSize: 8, color: _C.textMid),
          ),
        ),
      );
    }

    // 9 Kolom yang dirancang sangat pas dan proporsional untuk A4 Portrait
    const headers = [
      'No',
      'Nama Kegiatan / Jadwal',
      'Jenis & Lokasi',
      'Frek',
      'Jatuh Tempo',
      'PIC',
      'Tgt',
      'Sls',
      'Persentase', // Per instruksi: isi kolom status adalah persentase saja
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _C.borderLight, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(16),  // No
        1: pw.FlexColumnWidth(3.0),  // Nama Jadwal
        2: pw.FlexColumnWidth(2.0),  // Jenis & Pabrik
        3: pw.FixedColumnWidth(38),  // Frek
        4: pw.FixedColumnWidth(46),  // Jatuh Tempo
        5: pw.FlexColumnWidth(1.6),  // PIC
        6: pw.FixedColumnWidth(22),  // Target
        7: pw.FixedColumnWidth(22),  // Selesai
        8: pw.FixedColumnWidth(36),  // Persentase (%)
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _C.primary),
          children: headers.map((h) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              alignment: pw.Alignment.center,
              child: pw.Text(
                h,
                style: const pw.TextStyle(
                  fontSize: 6.8,
                  fontWeight: pw.FontWeight.bold,
                  color: _C.white,
                ),
              ),
            );
          }).toList(),
        ),

        // Data Rows
        ...list.asMap().entries.map((entry) {
          final i = entry.key;
          final j = entry.value;

          final jenisNama = j.jdwInvJenis ?? '-';
          final pabrikStr = j.jdwPabrikList.isNotEmpty
              ? j.jdwPabrikList.join(', ')
              : (j.jdwDivisi.isNotEmpty ? j.jdwDivisi : 'Semua');
          final kategoriLokasi = '$jenisNama ($pabrikStr)';

          final pic = (j.assignedUser?['user_nama'] ?? '-').toString();

          final target = j.jdwTarget ?? j.jdwTotalUnit ?? 0;
          final selesai = j.jdwSelesaiUnit ?? 0;
          final pct = target > 0
              ? ((selesai / target) * 100).round().clamp(0, 100)
              : (selesai > 0 ? 100 : 0);

          // Format tanggal jatuh tempo ringkas & humanis
          String dueDate = '-';
          if (j.jdwNextDueDate != null && j.jdwNextDueDate!.isNotEmpty) {
            final dt = DateTime.tryParse(j.jdwNextDueDate!);
            if (dt != null) {
              dueDate = '${dt.day} ${DateFormatter.monthNames[dt.month - 1].substring(0, 3)}';
            } else {
              dueDate = j.jdwNextDueDate!;
            }
          } else if (j.jdwFrekuensi == 'Harian') {
            dueDate = 'Harian';
          } else if (j.jdwFrekuensi == 'Mingguan') {
            dueDate = 'Mingguan';
          }

          final bg = i % 2 == 0 ? _C.white : _C.bgAlt;

          // Warna Badge Persentase Saja
          PdfColor pctColor;
          PdfColor pctBg;
          if (pct >= 100) {
            pctColor = _C.good;
            pctBg = _C.goodBg;
          } else if (pct > 0) {
            pctColor = _C.info;
            pctBg = _C.infoBg;
          } else {
            pctColor = _C.textLight;
            pctBg = _C.bgAlt;
          }

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              // 0. No
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text('${i + 1}',
                    style: const pw.TextStyle(fontSize: 6.8, color: _C.textDark)),
              ),
              // 1. Nama Jadwal
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  j.jdwJudul,
                  style: const pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: _C.textDark),
                ),
              ),
              // 2. Kategori & Lokasi
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(kategoriLokasi,
                    style: const pw.TextStyle(fontSize: 6.5, color: _C.textMid)),
              ),
              // 3. Frekuensi
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text(j.jdwFrekuensi,
                    style: const pw.TextStyle(fontSize: 6.8, color: _C.textDark)),
              ),
              // 4. Jatuh Tempo
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text(dueDate,
                    style: const pw.TextStyle(fontSize: 6.5, color: _C.textMid)),
              ),
              // 5. PIC
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(pic,
                    style: const pw.TextStyle(fontSize: 6.8, color: _C.textDark)),
              ),
              // 6. Target
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text('$target',
                    style: const pw.TextStyle(fontSize: 6.8, color: _C.textDark)),
              ),
              // 7. Selesai
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text('$selesai',
                    style: pw.TextStyle(
                      fontSize: 6.8,
                      fontWeight: pw.FontWeight.bold,
                      color: selesai >= target && target > 0 ? _C.good : _C.textDark,
                    )),
              ),
              // 8. Persentase Saja (Badge %)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                alignment: pw.Alignment.center,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: pctBg,
                    border: pw.Border.all(color: pctColor, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    '$pct%',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: pctColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
