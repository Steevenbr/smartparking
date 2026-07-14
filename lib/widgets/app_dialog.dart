import 'package:flutter/material.dart';
import '../theme.dart';

/// Diálogos con el estilo visual del flujo conductor (icono, tarjeta, botones).
class AppDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color iconColor = kPrimary,
    Color? iconBgColor,
    Widget? extra,
    String primaryLabel = 'Aceptar',
    VoidCallback? onPrimary,
    Color? primaryColor,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBgColor ?? iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
              if (extra != null) ...[
                const SizedBox(height: 18),
                extra,
              ],
              const SizedBox(height: 20),
              if (secondaryLabel != null)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onSecondary ?? () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(secondaryLabel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor ?? kPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onPrimary ?? () => Navigator.pop(ctx, true),
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor ?? kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onPrimary ?? () => Navigator.pop(ctx, true),
                    child: Text(primaryLabel),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.help_outline,
    Color iconColor = kPrimary,
    Widget? extra,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    Color? confirmColor,
    bool barrierDismissible = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      extra: extra,
      primaryLabel: confirmLabel,
      primaryColor: confirmColor,
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.pop(context, false),
      onPrimary: () => Navigator.pop(context, true),
      barrierDismissible: barrierDismissible,
    );
  }

  static Future<void> success({
    required BuildContext context,
    required String title,
    required String message,
    Widget? extra,
    String primaryLabel = 'Aceptar',
    String? secondaryLabel,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
  }) {
    return show(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF16A34A),
      iconBgColor: const Color(0xFFDCFCE7),
      extra: extra,
      primaryLabel: primaryLabel,
      primaryColor: const Color(0xFF16A34A),
      secondaryLabel: secondaryLabel,
      onPrimary: onPrimary ?? () => Navigator.pop(context),
      onSecondary: onSecondary ?? () => Navigator.pop(context),
      barrierDismissible: false,
    );
  }

  static Future<void> info({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    Color iconColor = kPrimary,
    Color? iconBgColor,
    Widget? extra,
    String primaryLabel = 'Aceptar',
  }) {
    return show(
      context: context,
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor ?? kPrimarySoft,
      extra: extra,
      primaryLabel: primaryLabel,
      barrierDismissible: false,
    );
  }

  static Future<void> error({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return show(
      context: context,
      title: title,
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.red.shade600,
      iconBgColor: Colors.red.shade50,
      primaryLabel: 'Entendido',
      primaryColor: Colors.red.shade600,
      barrierDismissible: true,
    );
  }

  /// Caja de resumen (montos, datos) como en cancelar reserva.
  static Widget summaryBox({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  static Widget summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
    bool large = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: large ? 14.5 : 13.5,
              color: Colors.grey.shade800,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: large ? 18 : 14.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w700,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
