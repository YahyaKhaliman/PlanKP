import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppNotifier {
  AppNotifier._();

  static Future<void> showError(BuildContext context, String message) async {
    return AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Terjadi Kesalahan',
      desc: message,
      btnOkColor: AppColors.danger,
      btnOkOnPress: () {},
      headerAnimationLoop: false,
    ).show();
  }

  static Future<void> showSuccess(BuildContext context, String message) async {
    return AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      desc: message,
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
      headerAnimationLoop: false,
    ).show();
  }

  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) async {
    return AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: title,
      desc: message,
      btnOkColor: AppColors.primary,
      btnCancelColor: AppColors.textSecondary,
      btnOkOnPress: onConfirm,
      btnCancelOnPress: () {},
      headerAnimationLoop: false,
    ).show();
  }
}
