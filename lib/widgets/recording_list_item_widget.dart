import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/recording_entry.dart';
import '../utils/duration_formatter.dart';

class RecordingListItemWidget extends StatelessWidget {
  final RecordingEntry entry;
  final Function(RecordingEntry) onPlayPause;
  final Function(RecordingEntry) onMoveToVault;
  final Function(RecordingEntry) onShare; // NEW: Callback for sharing

  const RecordingListItemWidget({
    super.key,
    required this.entry,
    required this.onPlayPause,
    required this.onMoveToVault,
    required this.onShare, // NEW
  });

  void _showMoveToVaultDialog(BuildContext context, RecordingEntry itemToMove) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor:
              theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          shape:
              theme.dialogTheme.shape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Text(
            'Move to Vault?',
            style:
                theme.dialogTheme.titleTextStyle ??
                GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
          ),
          content: Text(
            'Are you sure you want to move "${itemToMove.displayName}" to the secret vault? It will be hidden from this list.',
            style:
                theme.dialogTheme.contentTextStyle ??
                GoogleFonts.poppins(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
          ),
          actions: <Widget>[
            TextButton(
              style: theme.textButtonTheme.style,
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: theme.textButtonTheme.style?.copyWith(
                foregroundColor: MaterialStateProperty.all(
                  theme.colorScheme.primary,
                ),
              ),
              child: const Text('Move to Vault'),
              onPressed: () {
                onMoveToVault(itemToMove);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color moodTagTextColor =
        ThemeData.estimateBrightnessForColor(entry.moodColor) == Brightness.dark
        ? Colors.white.withOpacity(0.9)
        : entry.moodColor;

    return GestureDetector(
      onLongPress: () {
        // Only allow moving to vault if not currently playing to avoid file access issues
        if (!entry.isPlaying) {
          _showMoveToVaultDialog(context, entry);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stop playback before moving to vault.'),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: entry.moodColor.withOpacity(0.6), width: 1.5),
        ),
        elevation: theme.cardTheme.elevation ?? 2.0,
        child: ListTile(
          contentPadding: const EdgeInsets.only(
            left: 16.0,
            right: 4.0,
            top: 10.0,
            bottom: 10.0,
          ), // Adjusted right padding
          leading: Icon(
            Icons.graphic_eq_rounded,
            color: entry.moodIconColor.withOpacity(0.9),
            size: 28,
          ),
          title: Text(
            entry.displayName,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                '${formatDuration(entry.duration)} • ${DateFormat('MMM d, yyyy').format(entry.dateRecorded)}',
                style: GoogleFonts.poppins(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: entry.moodColor.withOpacity(
                    theme.brightness == Brightness.dark ? 0.25 : 0.15,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  entry.moodName,
                  style: GoogleFonts.poppins(
                    color: moodTagTextColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          trailing: Row(
            // NEW: Use Row for multiple trailing icons
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.share_outlined, // Share Icon
                  color: theme.colorScheme.onSurface.withOpacity(
                    0.7,
                  ), // Themed color
                  size: 26,
                ),
                tooltip: 'Share Recording',
                splashRadius: 22.0,
                onPressed: () => onShare(entry), // Call new callback
              ),
              IconButton(
                icon: Icon(
                  entry.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: theme.colorScheme.primary,
                  size: 34,
                ),
                splashRadius: 26.0,
                tooltip: entry.isPlaying ? 'Pause' : 'Play',
                onPressed: () => onPlayPause(entry),
              ),
            ],
          ),
          onTap: () => onPlayPause(entry),
        ),
      ),
    );
  }
}
