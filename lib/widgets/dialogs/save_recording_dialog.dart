import 'dart:async';
import 'dart:math';
import 'package:echolog/services/recording_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SaveRecordingDialog extends StatefulWidget {
  final String filePath;
  final Duration duration;
  final Map<String, dynamic> categoryData;
  final FlutterSoundPlayer? player;
  final bool isPlayerInitialized;
  final Function(
    String displayName,
    String filePath,
    Duration duration,
    Map<String, dynamic> categoryData,
  )
  onSave;
  final VoidCallback onDiscard;

  const SaveRecordingDialog({
    super.key,
    required this.filePath,
    required this.duration,
    required this.categoryData,
    required this.player,
    required this.isPlayerInitialized,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<SaveRecordingDialog> createState() => _SaveRecordingDialogState();
}

class _SaveRecordingDialogState extends State<SaveRecordingDialog> {
  late TextEditingController _nameController;
  bool _isPlayingModalPreview = false;
  StreamSubscription? _playerSubscriptionModal;

  // Generates a random number string for the default recording name
  String randomNumber() {
    // Returns a random integer between 0 (inclusive) and 1000 (exclusive)
    return Random().nextInt(100).toString();
  }

  @override
  @override
  void initState() {
    super.initState();
    // Updated default name format
    String categoryName = widget.categoryData['name'] as String? ?? 'Untitled';
    String timestamp = DateFormat('MMM d, HH:mm').format(DateTime.now());
    _nameController = TextEditingController(
      text: '$categoryName - ${randomNumber()}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (_isPlayingModalPreview &&
        widget.player != null &&
        widget.player!.isPlaying) {
      widget.player!.stopPlayer().catchError(
        (e) => print("Error stopping player on dispose: $e"),
      );
    }
    _playerSubscriptionModal?.cancel();
    super.dispose();
  }

  void _toggleModalPreview() async {
    if (!widget.isPlayerInitialized || widget.player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player not ready for preview.')),
      );
      return;
    }

    if (_isPlayingModalPreview) {
      await widget.player!.stopPlayer();
      if (mounted) setState(() => _isPlayingModalPreview = false);
      _playerSubscriptionModal?.cancel();
    } else {
      try {
        await widget.player!.startPlayer(
          fromURI: widget.filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            if (mounted) setState(() => _isPlayingModalPreview = false);
            _playerSubscriptionModal?.cancel();
          },
        );
        if (mounted) setState(() => _isPlayingModalPreview = true);
      } catch (e) {
        print("Error playing preview: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error playing preview.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final TextTheme textTheme = theme.textTheme; // Not explicitly used, can be removed if not needed

    return AlertDialog(
      backgroundColor:
          theme.colorScheme.surfaceVariant, // Slightly different background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ), // More rounded
      titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 10.0),
      contentPadding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 10.0),
      actionsPadding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 24.0),
      title: Text(
        'Save Your Echo',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 20,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duration: ${formatDuration(widget.duration)}',
                  style: GoogleFonts.poppins(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.categoryData['color'] as Color).withOpacity(
                      0.2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.categoryData['name'] as String,
                    style: GoogleFonts.poppins(
                      color: widget.categoryData['color'] as Color,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Recording Name',
              style: GoogleFonts.poppins(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: GoogleFonts.poppins(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface.withOpacity(0.5),
                hintText: 'Enter a name for your recording...',
                hintStyle: GoogleFonts.poppins(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              cursorColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            if (widget.isPlayerInitialized)
              Center(
                child: OutlinedButton.icon(
                  icon: Icon(
                    _isPlayingModalPreview
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 22,
                  ),
                  label: Text(
                    _isPlayingModalPreview ? 'Pause Preview' : 'Play Preview',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  onPressed: _toggleModalPreview,
                ),
              ),
            const SizedBox(
              height: 10,
            ), // Space before actions if preview is shown
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          child: Text(
            'Discard',
            style: GoogleFonts.poppins(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          onPressed: () {
            if (_isPlayingModalPreview &&
                widget.player != null &&
                widget.player!.isPlaying) {
              widget.player!.stopPlayer().catchError(
                (e) => print("Error stopping player on discard: $e"),
              );
            }
            _playerSubscriptionModal?.cancel();
            widget.onDiscard();
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save_alt_rounded, size: 20),
          label: Text(
            'Save Echo',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            elevation: 3,
          ),
          onPressed: () {
            if (_isPlayingModalPreview &&
                widget.player != null &&
                widget.player!.isPlaying) {
              widget.player!.stopPlayer().catchError(
                (e) => print("Error stopping player on save: $e"),
              );
            }
            _playerSubscriptionModal?.cancel();
            widget.onSave(
              _nameController.text.isNotEmpty
                  ? _nameController.text
                  : 'Untitled Recording',
              widget.filePath,
              widget.duration,
              widget.categoryData,
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
