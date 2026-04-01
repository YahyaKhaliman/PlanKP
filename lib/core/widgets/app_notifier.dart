import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

typedef AppConfirmCallback = FutureOr<void> Function();

class AppNotifier {
  AppNotifier._();

  static const Duration _successSnackDuration = Duration(milliseconds: 1200);

  static Future<void> showWarning(BuildContext context, String message) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'Perhatian',
      desc: message,
      btnOkColor: AppColors.warning,
      btnOkOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }

  static Future<void> showError(BuildContext context, String message) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Terjadi Kesalahan',
      desc: message,
      btnOkColor: AppColors.danger,
      btnOkOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }

  static Future<void> showSuccess(BuildContext context, String message) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      desc: message,
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
      headerAnimationLoop: true,
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
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      desc: message,
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
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: title,
      desc: message,
      btnOkColor: AppColors.primary,
      btnCancelColor: AppColors.textSecondary,
      btnOkOnPress: () async {
        await onConfirm();
      },
      btnCancelOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }
}
