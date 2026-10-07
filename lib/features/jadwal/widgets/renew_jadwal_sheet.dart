import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../master/providers/master_provider.dart';
import '../models/jadwal_model.dart';
import '../providers/jadwal_provider.dart';

class RenewJadwalSheet extends StatefulWidget {
  final JadwalModel jadwal;
  final VoidCallback? onRenewSuccess;

  const RenewJadwalSheet({
    super.key,
    required this.jadwal,
    this.onRenewSuccess,
  });

  @override
  State<RenewJadwalSheet> createState() => _RenewJadwalSheetState();
}

class _RenewJadwalSheetState extends State<RenewJadwalSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _tglMulaiNew;
  late DateTime _tglSelesaiOld;
  DateTime? _tglSelesaiNew;

  bool _targetAutoAll = true;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _autoTargetCtrl;
  late final TextEditingController _gapCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _judulCtrl;

  int? _assignedToUserId;
  int _maxTargetUnit = 0;
  String? _targetLimitError;
  bool _isSubmitting = false;

  int get _currentTargetValue => int.tryParse(_targetCtrl.text.trim()) ?? 1;

  void _setTargetValue(int value) {
    _targetCtrl.text = '$value';
    _targetCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _targetCtrl.text.length),
    );
  }

  void _adjustTarget(int delta) {
    final max = _maxTargetUnit;
    if (max < 1) return;
    final current = _currentTargetValue;
    if (delta > 0 && current >= max) {
      setState(() {
        _targetLimitError = 'Total inventaris aktif hanya $max unit';
      });
      return;
    }

    final next = (current + delta).clamp(1, max);
    _setTargetValue(next);
    if (_targetLimitError != null) {
      setState(() {
        _targetLimitError = null;
      });
    }
  }

  Widget _requiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final d = widget.jadwal;

    // Inisialisasi tanggal: Jadwal baru mulai hari ini (atau awal bulan/senin berikutnya)
    final now = DateTime.now();
    _tglMulaiNew = _nextAllowedDate(now);

    // Tanggal selesai jadwal lama default: 1 hari sebelum jadwal baru mulai
    _tglSelesaiOld = _tglMulaiNew.subtract(const Duration(days: 1));
    final oldStart = DateTime.tryParse(d.jdwTglMulai);
    if (oldStart != null && _tglSelesaiOld.isBefore(oldStart)) {
      _tglSelesaiOld = oldStart;
    }

    _targetAutoAll = d.jdwTarget == null || d.jdwTarget == 0;
    _targetCtrl = TextEditingController(
      text: _targetAutoAll ? '0' : '${d.jdwTarget}',
    );
    _autoTargetCtrl = TextEditingController(
      text: 'Semua Unit ($_maxTargetUnit unit aktif)',
    );
    _gapCtrl = TextEditingController(text: '${d.jdwGapHari}');
    _notesCtrl = TextEditingController();
    _judulCtrl = TextEditingController(text: d.jdwJudul);
    _assignedToUserId = d.jdwAssignedTo;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTargetLimit();
    });
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _autoTargetCtrl.dispose();
    _gapCtrl.dispose();
    _notesCtrl.dispose();
    _judulCtrl.dispose();
    super.dispose();
  }

  bool _isDateAllowedForFrekuensi(DateTime date) {
    if (widget.jadwal.jdwFrekuensi == 'Mingguan') {
      return date.weekday == DateTime.monday;
    }
    if (widget.jadwal.jdwFrekuensi == 'Bulanan') {
      return date.day == 1;
    }
    return true;
  }

  DateTime _nextAllowedDate(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    if (widget.jadwal.jdwFrekuensi == 'Mingguan') {
      final diff = (DateTime.monday - base.weekday + 7) % 7;
      return base.add(Duration(days: diff));
    }
    if (widget.jadwal.jdwFrekuensi == 'Bulanan') {
      if (base.day == 1) return base;
      return DateTime(base.year, base.month + 1, 1);
    }
    return base;
  }

  Future<void> _syncTargetLimit() async {
    final master = context.read<MasterProvider>();
    final items = await master.getInventarisByJenis(widget.jadwal.jdwJenisId);
    if (!mounted) return;

    final matchingInventaris = items.where((inv) {
      if (widget.jadwal.jdwPabrikList.isEmpty) return true;
      return widget.jadwal.jdwPabrikList.contains(inv.invPabrikKode);
    }).toList();

    final maxTarget = matchingInventaris.length;
    setState(() {
      _maxTargetUnit = maxTarget;
      _autoTargetCtrl.text = 'Semua Unit ($maxTarget unit aktif)';
    });

    if (maxTarget > 0 && !_targetAutoAll) {
      final current = _currentTargetValue;
      if (current > maxTarget) {
        _setTargetValue(maxTarget);
      }
    }
  }

  Future<void> _pickDateMulaiNew() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);
    final lastDate = DateTime(now.year + 2, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _tglMulaiNew,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: _isDateAllowedForFrekuensi,
    );

    if (picked != null) {
      setState(() {
        _tglMulaiNew = picked;
        // Otomatis sesuaikan tgl selesai lama
        final computedOldEnd = picked.subtract(const Duration(days: 1));
        final oldStart = DateTime.tryParse(widget.jadwal.jdwTglMulai);
        if (oldStart != null && computedOldEnd.isBefore(oldStart)) {
          _tglSelesaiOld = oldStart;
        } else {
          _tglSelesaiOld = computedOldEnd;
        }
      });
    }
  }

  Future<void> _pickDateSelesaiOld() async {
    final oldStart = DateTime.tryParse(widget.jadwal.jdwTglMulai) ??
        DateTime(DateTime.now().year - 1, 1, 1);
    final lastDate = _tglMulaiNew.subtract(const Duration(days: 1));

    if (lastDate.isBefore(oldStart)) {
      AppNotifier.showWarning(context,
          'Tanggal mulai baru terlalu dekat dengan tanggal mulai lama');
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _tglSelesaiOld.isAfter(lastDate)
          ? lastDate
          : (_tglSelesaiOld.isBefore(oldStart) ? oldStart : _tglSelesaiOld),
      firstDate: oldStart,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() => _tglSelesaiOld = picked);
    }
  }

  Future<void> _pickDateSelesaiNew() async {
    final firstDate = _tglMulaiNew.add(const Duration(days: 1));
    final lastDate = DateTime(_tglMulaiNew.year + 5, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _tglSelesaiNew ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() => _tglSelesaiNew = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final targetVal = _targetAutoAll
        ? (_maxTargetUnit > 0 ? _maxTargetUnit : 1)
        : (int.tryParse(_targetCtrl.text.trim()) ?? 1);

    if (targetVal < 1) {
      AppNotifier.showWarning(context, 'Target jadwal minimal 1 unit');
      return;
    }
    if (_maxTargetUnit > 0 && targetVal > _maxTargetUnit) {
      AppNotifier.showWarning(context,
          'Target ($targetVal) melebihi total unit aktif ($_maxTargetUnit)');
      return;
    }

    final gapVal = int.tryParse(_gapCtrl.text.trim()) ?? 0;
    if (gapVal < 0) {
      AppNotifier.showWarning(context, 'Gap realisasi minimal 0');
      return;
    }

    await AppNotifier.showConfirm(
      context,
      title: 'Perbarui Siklus Jadwal',
      message:
          'Jadwal saat ini akan ditutup per ${DateFormatter.toDisplayFromDate(_tglSelesaiOld)} dan diberi status Selesai. Jadwal baru akan dibuat mulai ${DateFormatter.toDisplayFromDate(_tglMulaiNew)} dengan target $targetVal unit.\n\nLanjutkan?',
      onConfirm: () async {
        if (!mounted) return;
        setState(() => _isSubmitting = true);
        final p = context.read<JadwalProvider>();

        final payload = <String, dynamic>{
          'jdw_tgl_selesai_old': DateFormatter.toApi(_tglSelesaiOld),
          'jdw_tgl_mulai_new': DateFormatter.toApi(_tglMulaiNew),
          if (_tglSelesaiNew != null)
            'jdw_tgl_selesai_new': DateFormatter.toApi(_tglSelesaiNew),
          'jdw_target_new': targetVal,
          'jdw_gap_hari_new': gapVal,
          if (_assignedToUserId != null)
            'jdw_assigned_to_new': _assignedToUserId,
          if (_judulCtrl.text.trim().isNotEmpty)
            'jdw_judul_new': _judulCtrl.text.trim(),
          if (_notesCtrl.text.trim().isNotEmpty)
            'jdw_notes_new': _notesCtrl.text.trim(),
        };

        final ok = await p.renewJadwal(widget.jadwal.jdwId, payload);
        if (!mounted) return;
        setState(() => _isSubmitting = false);

        if (ok) {
          await AppNotifier.showSuccess(
            context,
            'Jadwal lama berhasil diselesaikan & Jadwal baru berhasil dimulai!',
          );
          if (!mounted) return;
          widget.onRenewSuccess?.call();
          Navigator.pop(context, true);
        } else {
          await AppNotifier.showError(
            context,
            p.error ?? 'Gagal memperbarui siklus jadwal',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final master = context.watch<MasterProvider>();
    final d = widget.jadwal;
    final showGap = d.jdwFrekuensi == 'Mingguan' || d.jdwFrekuensi == 'Bulanan';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.autorenew_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perbarui Siklus Jadwal (Renew)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tutup jadwal lama & buat jadwal baru tanpa merusak persentase bulan lalu',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceAlt,
                    foregroundColor: AppColors.textMuted,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info Card: Jadwal Saat Ini (Lama)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          d.jdwFrekuensi.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.jdwJudul,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mulai: ${DateFormatter.toDisplay(d.jdwTglMulai)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        'Target Saat Ini: ${d.jdwTarget ?? 1} unit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Transisi Tanggal
            Text(
              'Transisi Siklus Tanggal',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Tanggal Selesai Jadwal Lama
            InkWell(
              onTap: _pickDateSelesaiOld,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded,
                        size: 20, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jadwal Lama Berakhir Pada',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatter.toDisplayFromDate(_tglSelesaiOld),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded,
                        size: 18, color: AppColors.danger),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tanggal Mulai Jadwal Baru
            InkWell(
              onTap: _pickDateMulaiNew,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        size: 20, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jadwal Baru Mulai Pada *',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatter.toDisplayFromDate(_tglMulaiNew),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded,
                        size: 18, color: AppColors.success),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tanggal Selesai Jadwal Baru (Opsional)
            InkWell(
              onTap: _pickDateSelesaiNew,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_repeat_rounded,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Selesai Jadwal Baru (Opsional)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tglSelesaiNew != null
                                ? DateFormatter.toDisplayFromDate(
                                    _tglSelesaiNew)
                                : 'Tanpa batas akhir (Berjalan terus)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_tglSelesaiNew != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: AppColors.textMuted),
                        onPressed: () => setState(() => _tglSelesaiNew = null),
                      )
                    else
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 16),

            // Section 2: Konfigurasi Target Baru (menyesuaikan format form pembuatan jadwal baru)
            TextFormField(
              key: ValueKey<bool>(_targetAutoAll),
              controller: _targetAutoAll ? _autoTargetCtrl : _targetCtrl,
              readOnly: _targetAutoAll,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _targetAutoAll
                    ? const Color(0xFF15803D)
                    : AppColors.textPrimary,
              ),
              onChanged: (_) {
                if (_targetLimitError != null) {
                  setState(() => _targetLimitError = null);
                }
              },
              decoration: InputDecoration(
                label: _requiredLabel('Target Unit per Jadwal'),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(
                  _targetAutoAll ? Icons.auto_awesome : Icons.flag_outlined,
                  color: _targetAutoAll
                      ? const Color(0xFF16A34A)
                      : AppColors.textSecondary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_targetAutoAll)
                      SizedBox(
                        width: 32,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: _maxTargetUnit <= 0
                                  ? null
                                  : () => setState(() => _adjustTarget(1)),
                              child: const Icon(Icons.keyboard_arrow_up,
                                  size: 16),
                            ),
                            InkWell(
                              onTap: _maxTargetUnit <= 0
                                  ? null
                                  : () => setState(() => _adjustTarget(-1)),
                              child: const Icon(Icons.keyboard_arrow_down,
                                  size: 16),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _targetAutoAll = !_targetAutoAll;
                            if (_targetAutoAll) {
                              _targetCtrl.text = '0';
                              _targetLimitError = null;
                            } else {
                              if (_targetCtrl.text == '0' ||
                                  _targetCtrl.text.isEmpty) {
                                _targetCtrl.text =
                                    '${_maxTargetUnit > 0 ? _maxTargetUnit : 1}';
                              }
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _targetAutoAll
                                ? const Color(0xFFDCFCE7)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _targetAutoAll
                                  ? const Color(0xFF86EFAC)
                                  : AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _targetAutoAll
                                    ? Icons.auto_awesome
                                    : Icons.tune_outlined,
                                size: 12,
                                color: _targetAutoAll
                                    ? const Color(0xFF15803D)
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _targetAutoAll ? 'Otomatis' : 'Manual',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _targetAutoAll
                                      ? const Color(0xFF15803D)
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                helperText: _targetAutoAll
                    ? '✨ Mode Otomatis: Mencakup seluruh unit aktif ($_maxTargetUnit unit) & unit baru yang ditambahkan nanti.'
                    : '⚙️ Mode Manual: Membatasi kuota target maintenance per siklus (maksimal $_maxTargetUnit unit).',
                helperMaxLines: 2,
                errorText: _targetLimitError,
              ),
              validator: (v) {
                if (_targetAutoAll) return null;
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) {
                  return 'Target wajib angka bulat minimal 1';
                }
                if (_maxTargetUnit > 0 && n > _maxTargetUnit) {
                  return 'Target maksimal $_maxTargetUnit unit';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Section 3: Gap & Pelaksana
            if (showGap) ...[
              TextFormField(
                controller: _gapCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Gap Realisasi Jadwal Baru (Hari)',
                  hintText: '0 untuk tanpa gap',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pelaksana Dropdown
            DropdownButtonFormField<int?>(
              value: _assignedToUserId,
              decoration: InputDecoration(
                labelText: 'Pelaksana / Teknisi Baru',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Semua Teknisi / Bebas',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5)),
                ),
                ...master.userList.map((u) => DropdownMenuItem<int?>(
                      value: u.userId,
                      child: Text('${u.userNama} (${u.userDivisi})',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13.5)),
                    )),
              ],
              onChanged: (val) => setState(() => _assignedToUserId = val),
            ),
            const SizedBox(height: 16),

            // Catatan Siklus Baru
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan Pembaruan Siklus (Opsional)',
                hintText: 'Contoh: Penyesuaian target penambahan unit mesin Q4',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Selesaikan & Buat Jadwal Baru',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
