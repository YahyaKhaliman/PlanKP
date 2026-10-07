import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

typedef AppConfirmCallback = FutureOr<void> Function();

class AppNotifier {
  AppNotifier._();

  static const Duration _successSnackDuration = Duration(milliseconds: 1200);

  static double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth <= 600) {
      return screenWidth * 0.92;
    }
    return 420;
  }

  static TextStyle _titleStyle() => GoogleFonts.plusJakartaSans(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle _descStyle() => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle _btnStyle() => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  static Future<void> showWarning(BuildContext context, String message) async {
    if (!context.mounted) return;
    final formatted = DateFormatter.formatMessageDates(message);
    await AwesomeDialog(
      context: context,
      useRootNavigator: true,
      width: _dialogWidth(context),
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'Perhatian',
      titleTextStyle: _titleStyle(),
      desc: formatted,
      descTextStyle: _descStyle(),
      buttonsTextStyle: _btnStyle(),
      btnOkColor: AppColors.warning,
      btnOkOnPress: () {},
      headerAnimationLoop: false,
      dismissOnTouchOutside: true,
      dismissOnBackKeyPress: true,
    ).show();
  }

  static Future<void> showError(BuildContext context, String message) async {
    if (!context.mounted) return;
    final formatted = DateFormatter.formatMessageDates(message);
    await AwesomeDialog(
      context: context,
      useRootNavigator: true,
      width: _dialogWidth(context),
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Terjadi Kesalahan',
      titleTextStyle: _titleStyle(),
      desc: formatted,
      descTextStyle: _descStyle(),
      buttonsTextStyle: _btnStyle(),
      btnOkColor: AppColors.danger,
      btnOkOnPress: () {},
      headerAnimationLoop: false,
      dismissOnTouchOutside: true,
      dismissOnBackKeyPress: true,
    ).show();
  }

  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    Duration? autoHide = const Duration(milliseconds: 2500),
  }) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      useRootNavigator: true,
      width: _dialogWidth(context),
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      titleTextStyle: _titleStyle(),
      desc: message,
      descTextStyle: _descStyle(),
      buttonsTextStyle: _btnStyle(),
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
      autoHide: autoHide,
      headerAnimationLoop: false,
      dismissOnTouchOutside: true,
      dismissOnBackKeyPress: true,
    ).show();
  }

  static void showSuccessSnack(
    BuildContext context,
    String message, {
    Duration duration = _successSnackDuration,
  }) {
    if (!context.mounted) return;
    AwesomeDialog(
      context: context,
      useRootNavigator: true,
      width: _dialogWidth(context),
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      titleTextStyle: _titleStyle(),
      desc: message,
      descTextStyle: _descStyle(),
      buttonsTextStyle: _btnStyle(),
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
      autoHide: duration,
      headerAnimationLoop: false,
    ).show();
  }

  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required AppConfirmCallback onConfirm,
  }) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      useRootNavigator: true,
      width: _dialogWidth(context),
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: title,
      titleTextStyle: _titleStyle(),
      desc: message,
      descTextStyle: _descStyle(),
      buttonsTextStyle: _btnStyle(),
      btnOkColor: AppColors.primary,
      btnCancelColor: AppColors.textSecondary,
      btnOkOnPress: () async {
        await onConfirm();
      },
      btnCancelOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
