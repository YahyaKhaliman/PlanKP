import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/jenis_model.dart';
import '../../../core/theme/app_theme.dart';

class JenisLookupSheet extends StatefulWidget {
  final List<JenisModel> items;
  final int? initialId;
  const JenisLookupSheet({super.key, required this.items, this.initialId});

  @override
  State<JenisLookupSheet> createState() => _JenisLookupSheetState();
}

class _JenisLookupSheetState extends State<JenisLookupSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _keyword.toLowerCase();
    final filtered = widget.items
        .where((j) =>
            j.jenisNama.toLowerCase().contains(query) ||
            j.jenisKategori.toLowerCase().contains(query) ||
            '${j.jenisId}'.contains(query))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari jenis berdasarkan nama/kategori',
                    hintStyle:
                        GoogleFonts.plusJakartaSans(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _keyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _keyword = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _keyword = value),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada jenis yang sesuai',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final jenis = filtered[index];
                          final selected = jenis.jenisId == widget.initialId;
                          return Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primarySoft
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(jenis.jenisNama,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5)),
                              trailing: selected
                                  ? const Icon(Icons.check,
                                      color: AppColors.primary)
                                  : null,
                              onTap: () => Navigator.pop(context, jenis),
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
  }
}
