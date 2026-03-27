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

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
