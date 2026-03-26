class DateFormatter {
  static final RegExp _yyyyMmDd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _ddMmYyyy = RegExp(r'^\d{2}/\d{2}/\d{4}$');

  static String toDisplay(String? value, {String fallback = '-'}) {
    if (value == null || value.trim().isEmpty) return fallback;
    final raw = value.trim();

    if (_ddMmYyyy.hasMatch(raw)) return raw;

    final datePart = raw.contains('T') ? raw.split('T').first : raw;
    if (_yyyyMmDd.hasMatch(datePart)) {
      final parts = datePart.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return toDisplayFromDate(parsed, fallback: fallback);
  }

  static String toDisplayFromDate(DateTime? date, {String fallback = ''}) {
    if (date == null) return fallback;
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  static String toApi(DateTime? date, {String fallback = ''}) {
    if (date == null) return fallback;
    final yyyy = date.year.toString();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
