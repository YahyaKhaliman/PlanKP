import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_notifier.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/master/models/user_model.dart';
import '../../../features/master/providers/master_provider.dart';
import '../../../features/master/widgets/jenis_lookup_sheet.dart';
import '../../../features/master/models/jenis_model.dart';
import '../models/jadwal_model.dart';
import '../providers/jadwal_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  JADWAL SCREEN
// ═══════════════════════════════════════════════════════════════
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});
  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  static const _statuses = ['Semua', 'Draft', 'Aktif', 'Selesai', 'Dibatalkan'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final isAdmin = auth.user?['user_jabatan'] == 'admin';
      final jadwalProvider = context.read<JadwalProvider>();
      if (isAdmin) {
        jadwalProvider.fetchJadwal();
      } else {
        jadwalProvider.fetchJadwalByDivisi();
      }
      context.read<MasterProvider>().fetchJenis();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openForm([JadwalModel? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JadwalForm(item: item),
    );
  }

  Future<void> _handleJadwalTap(
    JadwalModel jadwal, {
    required bool isAdmin,
    required bool isUser,
  }) async {
    if (isAdmin || !isUser) {
      Navigator.pushNamed(context, AppRoutes.jadwalDetail,
          arguments: jadwal.jdwId);
      return;
    }

    if (jadwal.jdwStatus != 'Aktif') {
      await AppNotifier.showError(
          context, 'Jadwal belum aktif untuk direalisasi');
      return;
    }

    final p = context.read<JadwalProvider>();
    await p.fetchJadwalDetail(jadwal.jdwId);
    if (!mounted) return;

    final inventarisList = p.inventarisByJenis
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (inventarisList.isEmpty) {
      await AppNotifier.showError(
          context, 'Inventaris untuk jadwal ini belum ada');
      return;
    }

    if (inventarisList.length == 1) {
      _openRealisasiFromInventaris(jadwal, inventarisList.first);
      return;
    }

    _showInventarisPicker(jadwal, inventarisList);
  }

  void _showInventarisPicker(
    JadwalModel jadwal,
    List<Map<String, dynamic>> inventarisList,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilih Unit untuk Realisasi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: inventarisList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final inv = inventarisList[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.primary),
                          title: Text(inv['inv_nama'] ?? '-'),
                          subtitle: Text(
                              '${inv['inv_no'] ?? '-'} · ${inv['inv_lokasi'] ?? '-'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            _openRealisasiFromInventaris(jadwal, inv);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRealisasiFromInventaris(
    JadwalModel jadwal,
    Map<String, dynamic> inv,
  ) {
    final invJenisRaw =
        inv['inv_jenis_id'] ?? inv['inv_jenis'] ?? jadwal.jdwJenisId;
    final invJenisId = invJenisRaw is int
        ? invJenisRaw
        : int.tryParse('$invJenisRaw') ?? jadwal.jdwJenisId;
    final invIdRaw = inv['inv_id'];
    final invId = invIdRaw is int ? invIdRaw : int.tryParse('$invIdRaw');

    final jenis = context.read<MasterProvider>().jenisById(invJenisId);
    Navigator.pushNamed(
      context,
      AppRoutes.realisasiForm,
      arguments: {
        'jadwalId': jadwal.jdwId,
        'invJenisId': invJenisId,
        'invJenisNama': jenis?.jenisNama ?? 'ID $invJenisId',
        'invId': invId,
        'invNama': inv['inv_nama'],
        'invNo': inv['inv_no'],
        'invKondisi': inv['inv_kondisi'],
        'invPicNama': inv['pic_user']?['user_nama'],
        'invPicId': inv['pic_user']?['user_id'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?['user_jabatan'] == 'admin';
    final isUser = auth.user?['user_jabatan'] == 'user';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penjadwalan'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.65),
          indicatorColor: AppColors.white,
          tabs: _statuses.map((s) => Tab(text: s)).toList(),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Buat Jadwal'),
            )
          : null,
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          if (p.loading)
            return const Center(child: CircularProgressIndicator());

          return TabBarView(
            controller: _tab,
            children: _statuses.map((s) {
              final list = s == 'Semua'
                  ? p.jadwalList
                  : p.jadwalList.where((j) => j.jdwStatus == s).toList();

              if (list.isEmpty) return _emptyState(s);

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _JadwalCard(
                  jadwal: list[i],
                  onTap: () => _handleJadwalTap(
                    list[i],
                    isAdmin: isAdmin,
                    isUser: isUser,
                  ),
                  onEdit: () => _openForm(list[i]),
                  onStatusChange: (st) => context
                      .read<JadwalProvider>()
                      .updateStatusJadwal(list[i].jdwId, st),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _emptyState(String status) => EmptyState(
        message:
            status == 'Semua' ? 'Belum ada jadwal' : 'Tidak ada jadwal $status',
      );
}

// ── Card ────────────────────────────────────────────────────
class _JadwalCard extends StatelessWidget {
  final JadwalModel jadwal;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final void Function(String) onStatusChange;
  const _JadwalCard({
    required this.jadwal,
    required this.onTap,
    required this.onEdit,
    required this.onStatusChange,
  });

  static const _statusColor = {
    'Draft': Color(0xFF64748B),
    'Aktif': Color(0xFF16A34A),
    'Selesai': Color(0xFF1E40AF),
    'Dibatalkan': Color(0xFFDC2626),
  };
  static const _statusBg = {
    'Draft': Color(0xFFF1F5F9),
    'Aktif': Color(0xFFDCFCE7),
    'Selesai': Color(0xFFDBEAFE),
    'Dibatalkan': Color(0xFFFEE2E2),
  };
  static const _frekuensiIcon = {
    'Harian': Icons.today_outlined,
    'Mingguan': Icons.date_range_outlined,
    'Bulanan': Icons.calendar_month_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor[jadwal.jdwStatus] ?? AppColors.textSecondary;
    final sb = _statusBg[jadwal.jdwStatus] ?? AppColors.bgGray;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // baris 1: judul + status badge
            Row(children: [
              Icon(_frekuensiIcon[jadwal.jdwFrekuensi] ?? Icons.event_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(jadwal.jdwJudul,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: sb, borderRadius: BorderRadius.circular(6)),
                child: Text(jadwal.jdwStatus,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: sc)),
              ),
            ]),
            const SizedBox(height: 8),

            // baris 2: jenis + frekuensi
            Wrap(spacing: 6, runSpacing: 4, children: [
              _chip('Jenis ${jadwal.jdwJenisId}', Icons.label_outline),
              _chip(jadwal.jdwFrekuensi, Icons.repeat_outlined),
            ]),
            const SizedBox(height: 6),

            // baris 3: tanggal
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(_formatTgl(jadwal.jdwTglMulai, jadwal.jdwTglSelesai),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 10),

            // baris 4: actions
            Row(children: [
              // Edit
              _actionBtn(
                  Icons.edit_outlined, 'Edit', AppColors.textSecondary, onEdit),
              const SizedBox(width: 8),
              // Status transitions
              if (jadwal.jdwStatus == 'Draft') ...[
                _actionBtn(Icons.play_arrow_outlined, 'Aktifkan',
                    AppColors.success, () => onStatusChange('Aktif')),
                const SizedBox(width: 8),
                _actionBtn(Icons.cancel_outlined, 'Batalkan', AppColors.danger,
                    () => onStatusChange('Dibatalkan')),
              ],
              if (jadwal.jdwStatus == 'Aktif')
                _actionBtn(Icons.check_circle_outline, 'Selesaikan',
                    AppColors.primary, () => onStatusChange('Selesai')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ]),
      );

  Widget _actionBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ]),
        ),
      );

  String _formatTgl(String mulai, String? selesai) {
    final m = DateFormatter.toDisplay(mulai);
    if (selesai == null || selesai.trim().isEmpty) return m;
    final s = DateFormatter.toDisplay(selesai);
    return '$m s/d $s';
  }
}

// ═══════════════════════════════════════════════════════════════
//  JADWAL DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════
class JadwalDetailScreen extends StatefulWidget {
  final int jadwalId;
  const JadwalDetailScreen({super.key, required this.jadwalId});
  @override
  State<JadwalDetailScreen> createState() => _JadwalDetailScreenState();
}

class _JadwalDetailScreenState extends State<JadwalDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JadwalProvider>().fetchJadwalDetail(widget.jadwalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Jadwal')),
      body: Consumer<JadwalProvider>(
        builder: (_, p, __) {
          if (p.loading)
            return const Center(child: CircularProgressIndicator());
          if (p.jadwalDetail == null) return const SizedBox.shrink();

          final jdw = p.jadwalDetail!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            // info jadwal
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(jdw.jdwJudul,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _row('Jenis Inventaris', 'ID ${jdw.jdwJenisId}'),
                      _row('Frekuensi', jdw.jdwFrekuensi),
                      _row('Tanggal Mulai',
                          DateFormatter.toDisplay(jdw.jdwTglMulai)),
                      if (jdw.jdwTglSelesai != null)
                        _row('Tanggal Selesai',
                            DateFormatter.toDisplay(jdw.jdwTglSelesai!)),
                      _row('Status', jdw.jdwStatus),
                      if (jdw.jdwNotes != null) _row('Catatan', jdw.jdwNotes!),
                    ]),
              ),
            ),
            const SizedBox(height: 16),

            // daftar inventaris
            const Text('Unit Inventaris yang Terjadwal',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ...p.inventarisByJenis.map((inv) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    title: Text(inv['inv_nama'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${inv['inv_no']} · ${inv['inv_lokasi'] ?? '-'}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: jdw.jdwStatus == 'Aktif'
                        ? ElevatedButton(
                            onPressed: () {
                              final invJenisRaw = inv['inv_jenis_id'] ??
                                  inv['inv_jenis'] ??
                                  jdw.jdwJenisId;
                              final invJenisId = invJenisRaw is int
                                  ? invJenisRaw
                                  : int.tryParse('$invJenisRaw') ??
                                      jdw.jdwJenisId;
                              final invIdRaw = inv['inv_id'];
                              final invId = invIdRaw is int
                                  ? invIdRaw
                                  : int.tryParse('$invIdRaw');
                              final jenis = context
                                  .read<MasterProvider>()
                                  .jenisById(invJenisId);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.realisasiForm,
                                arguments: {
                                  'jadwalId': widget.jadwalId,
                                  'invJenisId': invJenisId,
                                  'invJenisNama':
                                      jenis?.jenisNama ?? 'ID $invJenisId',
                                  'invId': invId,
                                  'invNama': inv['inv_nama'],
                                  'invNo': inv['inv_no'],
                                  'invKondisi': inv['inv_kondisi'],
                                  'invPicNama': inv['pic_user']?['user_nama'],
                                  'invPicId': inv['pic_user']?['user_id'],
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Realisasi'),
                          )
                        : null,
                  ),
                )),
          ]);
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  JADWAL FORM
// ═══════════════════════════════════════════════════════════════
class _JadwalForm extends StatefulWidget {
  final JadwalModel? item;
  const _JadwalForm({this.item});
  @override
  State<_JadwalForm> createState() => _JadwalFormState();
}

class _JadwalFormState extends State<_JadwalForm> {
  final _form = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final TextEditingController _jenisCtrl = TextEditingController();
  int? _jenisId;
  String? _divisi;
  String _frekuensi = 'Harian';
  DateTime? _tglMulai;
  DateTime? _tglSelesai;

  static const _frekuensiList = ['Harian', 'Mingguan', 'Bulanan'];

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null) {
      _judulCtrl.text = d.jdwJudul;
      _notesCtrl.text = d.jdwNotes ?? '';
      _jenisId = d.jdwJenisId;
      _divisi = d.jdwDivisi;
      _frekuensi = d.jdwFrekuensi;
      _tglMulai = DateTime.tryParse(d.jdwTglMulai);
      _tglSelesai =
          d.jdwTglSelesai != null ? DateTime.tryParse(d.jdwTglSelesai!) : null;
      final jenis = context.read<MasterProvider>().jenisById(d.jdwJenisId);
      _jenisCtrl.text = jenis?.jenisNama ?? 'ID ${d.jdwJenisId}';
    }
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _notesCtrl.dispose();
    _jenisCtrl.dispose();
    super.dispose();
  }

  String _fmtDateApi(DateTime? d) => DateFormatter.toApi(d);

  String _fmtDateDisplay(DateTime? d) =>
      DateFormatter.toDisplayFromDate(d, fallback: '');

  Future<void> _pickDate(bool isMulai) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isMulai
          ? (_tglMulai ?? DateTime.now())
          : (_tglSelesai ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isMulai)
          _tglMulai = picked;
        else
          _tglSelesai = picked;
      });
    }
  }

  Future<void> _pickJenis() async {
    final master = context.read<MasterProvider>();
    if (master.jenisMaster.isEmpty) {
      await master.fetchJenis(showLoading: false);
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<JenisModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JenisLookupSheet(
        items: master.jenisMaster,
        initialId: _jenisId,
      ),
    );
    if (result != null) {
      setState(() {
        _jenisId = result.jenisId;
        _jenisCtrl.text = result.jenisNama;
        final kategori = master.kategoriByJenisId(result.jenisId);
        if (_divisi == null && kategori != null) {
          _divisi = _divisiFromKategori(kategori) ?? _validDivisi(kategori);
        } else if (_divisi != null) {
          _divisi = _validDivisi(_divisi);
        }
      });
    }
  }

  Widget _jenisPickerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _jenisCtrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Jenis Inventaris',
          hintText: 'Cari...',
          prefixIcon: const Icon(Icons.label_outline),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _pickJenis,
          ),
        ),
        validator: (_) => _jenisId == null ? 'Jenis wajib dipilih' : null,
        onTap: _pickJenis,
      ),
    );
  }

  String? _divisiFromKategori(String? kategori) {
    if (kategori == null || kategori.isEmpty) return null;
    final allowed = UserModel.kategoriToDivisi[kategori];
    if (allowed != null && allowed.isNotEmpty) {
      for (final div in allowed) {
        final valid = _validDivisi(div);
        if (valid != null) return valid;
      }
    }
    return _validDivisi(kategori);
  }

  String? _validDivisi(String? value) {
    if (value == null || value.isEmpty) return null;
    return UserModel.divisiList.contains(value) ? value : null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      await AppNotifier.showWarning(
          context, 'Lengkapi data jadwal terlebih dahulu');
      return;
    }
    if (_jenisId == null) {
      await AppNotifier.showWarning(context, 'Jenis inventaris wajib dipilih');
      return;
    }
    if (_tglMulai == null) {
      await AppNotifier.showWarning(context, 'Tanggal mulai wajib dipilih');
      return;
    }
    final master = context.read<MasterProvider>();
    final p = context.read<JadwalProvider>();
    final divisi = _divisi ??
        (_jenisId != null ? master.kategoriByJenisId(_jenisId!) : null) ??
        widget.item?.jdwDivisi;
    final body = {
      'jdw_judul': _judulCtrl.text.trim(),
      'jdw_jenis_id': _jenisId!,
      'jdw_divisi': divisi,
      'jdw_frekuensi': _frekuensi,
      'jdw_tgl_mulai': _fmtDateApi(_tglMulai),
      'jdw_tgl_selesai': _tglSelesai != null ? _fmtDateApi(_tglSelesai) : null,
      'jdw_notes':
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };
    final isEdit = widget.item != null;
    final ok = await p.saveJadwal(body, id: widget.item?.jdwId);
    if (ok && mounted) {
      await AppNotifier.showSuccess(context,
          isEdit ? 'Jadwal berhasil diperbarui' : 'Jadwal berhasil dibuat');
      if (!mounted) return;
      Navigator.pop(context);
    } else if (mounted) {
      await AppNotifier.showError(context, p.error ?? 'Gagal menyimpan jadwal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final master = context.watch<MasterProvider>();
    final jadwalP = context.watch<JadwalProvider>();
    if (_jenisId != null && _jenisCtrl.text.isEmpty) {
      final jenis = master.jenisById(_jenisId!);
      if (jenis != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _jenisCtrl.text = jenis.jenisNama);
        });
      }
    }
    final allDivisi = UserModel.divisiList;
    final kategori =
        _jenisId != null ? master.kategoriByJenisId(_jenisId!) : null;
    final defaultDivisi =
        kategori != null && UserModel.divisiList.contains(kategori)
            ? kategori
            : null;
    final divisiValue = _divisi ?? defaultDivisi ?? widget.item?.jdwDivisi;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _form,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(
                  child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              )),
              Text(isEdit ? 'Edit Jadwal' : 'Buat Jadwal Baru',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // Judul
              TextFormField(
                controller: _judulCtrl,
                decoration: const InputDecoration(
                  labelText: 'Judul Jadwal',
                  prefixIcon: Icon(Icons.title_outlined),
                  hintText: 'Maintenance Mesin Sewing Mingguan...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Judul wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),

              _jenisPickerField(),
              const SizedBox(height: 14),

              // Divisi target
              DropdownButtonFormField<String>(
                value: divisiValue,
                decoration: const InputDecoration(
                  labelText: 'Divisi Pelaksana',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                hint: const Text('Pilih divisi pelaksanan'),
                items: allDivisi
                    .map(
                        (div) => DropdownMenuItem(value: div, child: Text(div)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _divisi = v);
                },
                validator: (v) => v == null ? 'Divisi wajib dipilih' : null,
              ),
              const SizedBox(height: 14),

              // Frekuensi
              DropdownButtonFormField<String>(
                value: _frekuensi,
                decoration: const InputDecoration(
                  labelText: 'Frekuensi',
                  prefixIcon: Icon(Icons.repeat_outlined),
                ),
                items: _frekuensiList
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _frekuensi = v!),
              ),
              const SizedBox(height: 14),

              // Tanggal mulai
              InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Mulai',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _tglMulai != null
                        ? _fmtDateDisplay(_tglMulai)
                        : 'Pilih tanggal',
                    style: TextStyle(
                      color: _tglMulai != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Tanggal selesai (opsional)
              InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal Selesai (opsional)',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: _tglSelesai != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _tglSelesai = null))
                        : null,
                  ),
                  child: Text(
                    _tglSelesai != null
                        ? _fmtDateDisplay(_tglSelesai)
                        : 'Tidak ada batas',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Catatan
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              if (jadwalP.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(jadwalP.error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13))),
                  ]),
                ),

              Consumer<JadwalProvider>(
                builder: (_, p, __) => ElevatedButton(
                  onPressed: p.loading ? null : _submit,
                  child: p.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Simpan Perubahan' : 'Buat Jadwal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
