import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows a custom styled, modern SnackBar aligned with the app theme.
///
/// Returns the [ScaffoldFeatureController] for the SnackBar.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showCustomSnackBar({
  required BuildContext context,
  required String message,
  String? actionLabel,
  VoidCallback? onActionPressed,
  Duration duration = const Duration(seconds: 4),
  IconData? leadingIcon,
  Color?
  iconColor, // Explicit color for the icon (e.g., for error/success states)
  Color? backgroundColor, // Custom background for the SnackBar
  Color? textColor, // Explicit color for the message text
}) {
  final theme = Theme.of(context);

  // Determine SnackBar background color
  final Color actualSnackBarBackgroundColor =
      backgroundColor ?? theme.colorScheme.inverseSurface;

  // Determine default content color (for text and fallback icon color)
  final Color defaultContentColor;
  if (backgroundColor != null) {
    // If a custom background is provided, estimate a contrasting color
    defaultContentColor =
        ThemeData.estimateBrightnessForColor(actualSnackBarBackgroundColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  } else {
    // Otherwise, use the theme's onInverseSurface color
    defaultContentColor = theme.colorScheme.onInverseSurface;
  }

  // Determine the icon color
  final Color actualIconColor;
  if (iconColor != null) {
    actualIconColor = iconColor; // User-specified icon color takes precedence
  } else if (leadingIcon != null) {
    // If there's an icon but no specific color, use the theme's secondary color for branding
    actualIconColor = theme.colorScheme.secondary; // Your app's teal color
  } else {
    actualIconColor =
        defaultContentColor; // Fallback (though not used if no icon)
  }

  final Color actualTextColor = textColor ?? defaultContentColor;

  final snackBar = SnackBar(
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, color: actualIconColor, size: 22),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.poppins(
              color: actualTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    backgroundColor: actualSnackBarBackgroundColor,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    margin: const EdgeInsets.fromLTRB(15, 5, 15, 12),
    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
    duration: duration,
    elevation: 3.0,
    action: actionLabel != null && onActionPressed != null
        ? SnackBarAction(
            label: actionLabel.toUpperCase(),
            textColor: theme
                .colorScheme
                .secondary, // Action button uses secondary color (teal)
            onPressed: onActionPressed,
          )
        : null,
  );

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
