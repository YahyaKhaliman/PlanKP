import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna utama aplikasi PlanKP berbasis enterprise design tokens.
class AppColors {
  // Brand & Action
  static const primary = Color(0xFF1D4ED8); // Blue 700 enterprise, terpercaya & tegas
  static const primaryDark = Color(0xFF0F2B6B); // Deep navy appbar & hero header
  static const accent = Color(0xFF2563EB); // Blue 600 aksen aktif
  static const primarySoft = Color(0xFFEFF6FF); // Blue 50 latar belakang elemen aktif / chip

  // Canvas & Surfaces (Clean contrast: Slate 50 canvas vs White card)
  static const surface = Color(0xFFF8FAFC); // Slate 50 background layar (bersih, tidak dominan biru)
  static const surfaceAlt = Color(0xFFF1F5F9); // Slate 100 kontainer sekunder / tabel
  static const cardSurface = Color(0xFFFFFFFF); // Pure white kartu & dialog
  static const bgGray = Color(0xFFF8FAFC); // Slate 50

  // Semantic Status Colors
  static const success = Color(0xFF16A34A); // Green 600 status selesai / disetujui
  static const successSoft = Color(0xFFF0FDF4); // Green 50 soft background
  static const warning = Color(0xFFD97706); // Amber 600 status pending / perhatian
  static const warningSoft = Color(0xFFFFFBEB); // Amber 50 soft background
  static const danger = Color(0xFFDC2626); // Red 600 status terlambat / ditolak
  static const dangerSoft = Color(0xFFFEF2F2); // Red 50 soft background
  static const info = Color(0xFF0284C7); // Sky 600 informasi
  static const infoSoft = Color(0xFFF0F9FF); // Sky 50 soft background

  // Typography Tokens
  static const textPrimary = Color(0xFF0F172A); // Slate 900 kontras tinggi (WCAG AAA)
  static const textSecondary = Color(0xFF475569); // Slate 600 teks pendukung / subtitle
  static const textMuted = Color(0xFF94A3B8); // Slate 400 placeholder & metadata pudar

  // Borders & Dividers
  static const border = Color(0xFFE2E8F0); // Slate 200 garis batas tegas & rapi 1px
  static const borderLight = Color(0xFFF1F5F9); // Slate 100 garis pembatas halus

  // Base
  static const white = Color(0xFFFFFFFF);
}

/// Helper identifikasi warna dan ikon divisi.
class AppDivisiColors {
  static Color getColor(String? divisi) {
    if (divisi == null || divisi.trim().isEmpty) return AppColors.primary;
    switch (divisi.trim().toLowerCase()) {
      case 'it':
        return const Color(0xFF4F46E5); // Indigo enterprise
      case 'ga':
        return const Color(0xFFEA580C); // Orange warm
      case 'driver':
        return const Color(0xFF0D9488); // Teal rich
      case 'hrd':
      case 'hr':
        return const Color(0xFFE11D48); // Rose / Pink
      case 'fat':
      case 'finance':
        return const Color(0xFF0284C7); // Sky Blue / Finance
      case 'logistik':
      case 'log':
        return const Color(0xFF7C3AED); // Purple / Violet
      default:
        return AppColors.primary;
    }
  }

  static Color getSoftColor(String? divisi) {
    return getColor(divisi).withValues(alpha: 0.12);
  }

  static IconData getIcon(String? divisi) {
    if (divisi == null || divisi.trim().isEmpty) return Icons.business_rounded;
    switch (divisi.trim().toLowerCase()) {
      case 'it':
        return Icons.computer_rounded;
      case 'ga':
        return Icons.precision_manufacturing_rounded;
      case 'driver':
        return Icons.local_shipping_rounded;
      case 'hrd':
      case 'hr':
        return Icons.people_alt_rounded;
      case 'fat':
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'logistik':
      case 'log':
        return Icons.inventory_2_rounded;
      default:
        return Icons.business_rounded;
    }
  }
}

/// Breakpoint responsif untuk Mobile, Tablet, dan Desktop.
class AppBreakpoints {
  static const mobile = 600.0;
  static const tablet = 960.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;

  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// Maksimum lebar kontainer konten pada layar lebar.
  static double maxContainerWidth(BuildContext context) {
    return responsiveValue(
      context,
      mobile: double.infinity,
      tablet: 860.0,
      desktop: 1180.0,
    );
  }

  /// Padding horizontal konten utama per breakpoint.
  static EdgeInsets contentPadding(
    BuildContext context, {
    double mobileH = 16.0,
    double tabletH = 24.0,
    double desktopH = 32.0,
    double mobileV = 12.0,
    double tabletV = 16.0,
    double desktopV = 20.0,
  }) {
    if (isDesktop(context)) {
      return EdgeInsets.symmetric(horizontal: desktopH, vertical: desktopV);
    }
    if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: tabletH, vertical: tabletV);
    }
    return EdgeInsets.symmetric(horizontal: mobileH, vertical: mobileV);
  }

  /// Padding konten di dalam sheet/dialog responsif.
  static EdgeInsets sheetContentPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.fromLTRB(28, 16, 28, 32);
    }
    if (isTablet(context)) {
      return const EdgeInsets.fromLTRB(24, 14, 24, 28);
    }
    return const EdgeInsets.fromLTRB(20, 12, 20, 24);
  }
}

/// Token jarak antar elemen (spacing scale).
class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Token sudut kelengkungan (border radius scale).
class AppRadius {
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 10.0;
  static const xl = 12.0;
  static const card = 16.0;
  static const sheet = 20.0;
  static const modal = 24.0;
  static const full = 9999.0;
}

/// Helper tipografi responsif untuk Mobile, Tablet, dan Desktop.
class AppTypography {
  static double scale(BuildContext context) {
    if (AppBreakpoints.isDesktop(context)) return 1.10;
    if (AppBreakpoints.isTablet(context)) return 1.05;
    return 1.0;
  }

  static TextStyle titleLarge(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 18 * s,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -0.3,
      height: 1.25,
    );
  }

  static TextStyle titleMedium(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 15 * s,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -0.2,
      height: 1.3,
    );
  }

  static TextStyle titleSmall(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 13.5 * s,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      height: 1.35,
    );
  }

  static TextStyle bodyLarge(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 13.5 * s,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.textPrimary,
      height: 1.45,
    );
  }

  static TextStyle bodyMedium(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 12.5 * s,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? AppColors.textSecondary,
      height: 1.45,
    );
  }

  static TextStyle bodySmall(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 11.5 * s,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppColors.textSecondary,
      height: 1.4,
    );
  }

  static TextStyle caption(
    BuildContext context, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    final s = scale(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 10.5 * s,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.textMuted,
      letterSpacing: 0.2,
    );
  }
}

/// Reusable Badge / Pill status dengan gaya shadcn/ui.
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;
  final IconData? icon;
  final bool outlined;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.backgroundColor,
    this.icon,
    this.outlined = false,
    this.fontSize = 11.5,
    this.padding,
  });

  factory AppBadge.success({
    required String label,
    IconData? icon,
    bool outlined = false,
  }) {
    return AppBadge(
      label: label,
      color: AppColors.success,
      backgroundColor: AppColors.successSoft,
      icon: icon,
      outlined: outlined,
    );
  }

  factory AppBadge.warning({
    required String label,
    IconData? icon,
    bool outlined = false,
  }) {
    return AppBadge(
      label: label,
      color: AppColors.warning,
      backgroundColor: AppColors.warningSoft,
      icon: icon,
      outlined: outlined,
    );
  }

  factory AppBadge.danger({
    required String label,
    IconData? icon,
    bool outlined = false,
  }) {
    return AppBadge(
      label: label,
      color: AppColors.danger,
      backgroundColor: AppColors.dangerSoft,
      icon: icon,
      outlined: outlined,
    );
  }

  factory AppBadge.info({
    required String label,
    IconData? icon,
    bool outlined = false,
  }) {
    return AppBadge(
      label: label,
      color: AppColors.info,
      backgroundColor: AppColors.infoSoft,
      icon: icon,
      outlined: outlined,
    );
  }

  factory AppBadge.neutral({
    required String label,
    IconData? icon,
    bool outlined = false,
  }) {
    return AppBadge(
      label: label,
      color: AppColors.textSecondary,
      backgroundColor: AppColors.surfaceAlt,
      icon: icon,
      outlined: outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.12);
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: outlined ? color : color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Konfigurasi tema global aplikasi PlanKP.
class AppTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.35,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
        error: AppColors.danger,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.white,
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: const BorderSide(color: AppColors.border, width: 1),
        backgroundColor: AppColors.white,
        selectedColor: AppColors.primarySoft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          color: AppColors.primarySoft,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1),
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
