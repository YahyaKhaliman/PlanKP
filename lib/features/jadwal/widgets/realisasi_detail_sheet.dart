import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/realisasi_model.dart';

class RealisasiDetailSheet {
  static Future<void> show(
    BuildContext context, {
    required RealisasiModel detail,
    required String title,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgGray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _detailRow('Jadwal', detail.jadwal?['jdw_judul'] ?? '-'),
              _detailRow('Unit', '${detail.invNo} · ${detail.invNama}'),
              _detailRow('Tanggal', DateFormatter.toDisplay(detail.realTgl)),
              _detailRow('Status', detail.realStatus),
              if ((detail.realJamMulai ?? '').isNotEmpty)
                _detailRow('Jam Mulai', detail.realJamMulai!),
              if ((detail.realJamSelesai ?? '').isNotEmpty)
                _detailRow('Jam Selesai', detail.realJamSelesai!),
              if ((detail.realKondisiAkhir ?? '').isNotEmpty)
                _detailRow('Kondisi Akhir', detail.realKondisiAkhir!),
              if ((detail.realKeterangan ?? '').isNotEmpty)
                _detailRow('Keterangan', detail.realKeterangan!),
              _detailRow(
                'PIC',
                (detail.realTtdPicNama ?? '').trim().isEmpty
                    ? '-'
                    : detail.realTtdPicNama!.trim(),
              ),
              _ttdRow(detail.realTtdData),
              const SizedBox(height: 12),
              const Text(
                'Checklist',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (detail.hasilChecklist.isEmpty)
                const Text('-',
                    style: TextStyle(color: AppColors.textSecondary))
              else
                ...([...detail.hasilChecklist]
                      ..sort((a, b) => a.urutan.compareTo(b.urutan)))
                    .map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${h.itemNama} (${h.hcHasil})${(h.hcKondisi ?? '').isNotEmpty ? ' - ${h.hcKondisi}' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if ((h.hcKeterangan ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 2),
                            child: Text(
                              'Keterangan: ${h.hcKeterangan!.trim()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  static Widget _ttdRow(String? ttdData) {
    final raw = (ttdData ?? '').trim();
    if (raw.isEmpty) return _detailRow('TTD', 'Belum ada');

    final normalized = raw.contains(',') ? raw.split(',').last : raw;
    try {
      final bytes = base64Decode(normalized);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 110,
              child: Text(
                'TTD',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return _detailRow('TTD', 'Data TTD tidak valid');
    }
  }
}
