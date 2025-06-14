import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/recording_entry.dart';
import '../utils/duration_formatter.dart';

class RecordingListItemWidget extends StatelessWidget {
  final RecordingEntry entry;
  final Function(RecordingEntry) onPlayPause;
  final ThemeData theme;

  const RecordingListItemWidget({
    super.key,
    required this.entry,
    required this.onPlayPause,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: theme.colorScheme.surface.withAlpha(
        230,
      ), // Or theme.colorScheme.surfaceVariant
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(
          color: entry.moodColor.withOpacity(0.7),
          width: 1.5,
        ), // Mood color border
      ),
      elevation: 2.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 10.0,
        ),
        leading: Icon(
          Icons.graphic_eq_rounded,
          color: entry.moodIconColor.withOpacity(0.9), // Using moodIconColor
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
            Text(
              '${formatDuration(entry.duration)} • ${DateFormat('MMM d, yyyy').format(entry.dateRecorded)}',
              style: GoogleFonts.poppins(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 5.0), // Spacing
            Container(
              // This container acts as the "mood tag"
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 3.0,
              ),
              decoration: BoxDecoration(
                color: entry.moodColor.withOpacity(
                  0.15,
                ), // Subtle background from mood color
                borderRadius: BorderRadius.circular(
                  6.0,
                ), // Rounded corners for the tag
              ),
              child: Text(
                entry.moodName,
                style: GoogleFonts.poppins(
                  color: entry.moodColor.withOpacity(
                    0.95,
                  ), // Stronger mood color for text
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            entry.isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 32,
          ),
          splashRadius: 24.0,
          onPressed: () => onPlayPause(entry),
        ),
        onTap: () => onPlayPause(entry),
      ),
    );
  }
}
