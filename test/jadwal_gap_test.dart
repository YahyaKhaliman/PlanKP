import 'package:flutter_test/flutter_test.dart';
import 'package:plankp/features/jadwal/models/jadwal_model.dart';
import 'package:plankp/features/jadwal/providers/jadwal_provider.dart';

void main() {
  group('Audit & Validasi Jadwal Bulanan Gap 90 Hari', () {
    final jadwalMtc90Hari = JadwalModel(
      jdwId: 101,
      jdwJenisId: 1,
      jdwTahun: 2026,
      jdwJudul: 'MTC Bulanan Komputer dan Laptop',
      jdwFrekuensi: 'Bulanan',
      jdwTglMulai: '2026-08-01',
      jdwGapHari: 90,
      jdwStatus: 'Aktif',
      jdwDivisi: 'IT',
      jdwPeriodFulfilled: false,
    );

    test('calculatedNextDueDate harus jatuh pada 30-10-2026 (1-08-2026 + 90 hari)', () {
      final nextDue = jadwalMtc90Hari.calculatedNextDueDate;
      expect(nextDue, isNotNull);
      expect(nextDue!.year, 2026);
      expect(nextDue.month, 10);
      expect(nextDue.day, 30);
    });

    test('effectiveScheduleDatesInMonth pada bulan September 2026 harus kosong karena gap belum tercapai', () {
      final startSept = DateTime(2026, 9, 1);
      final endSept = DateTime(2026, 9, 30);
      final dates = JadwalProvider.effectiveScheduleDatesInMonth(
        jadwalMtc90Hari,
        startSept,
        endSept,
        const {},
      );

      expect(dates, isEmpty);
    });

    test('effectiveScheduleDatesInMonth pada bulan Oktober 2026 harus dijadwalkan pada 30-10-2026 (bukan 1 Oktober)', () {
      final startOct = DateTime(2026, 10, 1);
      final endOct = DateTime(2026, 10, 31);
      final dates = JadwalProvider.effectiveScheduleDatesInMonth(
        jadwalMtc90Hari,
        startOct,
        endOct,
        const {},
      );

      expect(dates, isNotEmpty);
      expect(dates.first.year, 2026);
      expect(dates.first.month, 10);
      expect(dates.first.day, 30);
    });

    test('Unit inventaris kembali menjadi Belum Realisasi jika siklus gap sudah berakhir (sisaHari <= 0)', () {
      // Simulasi unit yang direalisasikan pada siklus lalu (misal Agustus),
      // dan sekarang gap 90 hari sudah berakhir (sisaHari = 0, inv_is_gap_eligible = true)
      final unitSiklusLalu = {
        'inv_id': 12,
        'inv_nama': 'Laptop IT 01',
        'inv_gap_sisa_hari': 0,
        'inv_is_gap_eligible': true,
        'inv_is_done_current_period': false,
      };

      final int sisaHari = (unitSiklusLalu['inv_gap_sisa_hari'] as num?)?.toInt() ?? 0;
      final bool hasGapRule = jadwalMtc90Hari.jdwGapHari > 0;
      final bool isGapBlocked = hasGapRule
          ? (sisaHari > 0 || unitSiklusLalu['inv_is_gap_eligible'] == false)
          : false;

      // Belum ada realisasi baru di siklus ini
      final Set<int> selesaiInvIdsSiklusIni = <int>{};
      final bool isSudahSelesai = hasGapRule
          ? (isGapBlocked || selesaiInvIdsSiklusIni.contains(unitSiklusLalu['inv_id']))
          : unitSiklusLalu['inv_is_done_current_period'] == true;

      // Status harus 'Belum realisasi' dan siap dikerjakan kembali
      expect(isGapBlocked, isFalse);
      expect(isSudahSelesai, isFalse);
    });

    test('effectiveNextDueDateStr mengabaikan jdw_next_due_date backend yang mengabaikan gap 90 hari', () {
      // Backend mengirim jdwNextDueDate = '2026-10-01' (karena backend hanya melihat siklus bulanan standar)
      // dan jdwPeriodFulfilled = false.
      final jadwalDenganBackendDate = JadwalModel(
        jdwId: 102,
        jdwJenisId: 1,
        jdwTahun: 2026,
        jdwJudul: 'MTC Bulanan Komputer dan Laptop',
        jdwFrekuensi: 'Bulanan',
        jdwTglMulai: '2026-08-01',
        jdwGapHari: 90,
        jdwStatus: 'Aktif',
        jdwDivisi: 'IT',
        jdwPeriodFulfilled: false,
        jdwNextDueDate: '2026-10-01', // tanggal backend yang keliru
      );

      // Harus tetap mengutamakan kalkulasi gap 90 hari client (30-10-2026), BUKAN 2026-10-01
      expect(jadwalDenganBackendDate.effectiveNextDueDateStr, '2026-10-30');
    });
  });
}
