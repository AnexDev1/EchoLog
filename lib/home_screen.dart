import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:echolog/hidden_recordings_screen.dart';
import 'package:echolog/main.dart';
// For recordingsBoxName, customCategoriesBoxName, hiddenRecordingsBox
import 'package:echolog/models/custom_category.dart';
import 'package:echolog/models/filter_state.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/providers/playback_provider.dart';
import 'package:echolog/providers/streak_provider.dart';
import 'package:echolog/recordings_list_page.dart';
import 'package:echolog/services/password_service.dart';
import 'package:echolog/services/recording_service.dart';
import 'package:echolog/settings_screen.dart';
import 'package:echolog/utils/custom_snackbar.dart';
import 'package:echolog/widgets/category_selector_widget.dart';
// import 'package:echolog/services/recording_service.dart'; // Not used directly in this file
import 'package:echolog/widgets/create_password_dialog.dart';
import 'package:echolog/widgets/enter_password_dialog.dart';
import 'package:echolog/widgets/filter_bottom_sheet_widget.dart';
import 'package:echolog/widgets/recording_controls_widget.dart';
import 'package:echolog/widgets/recordings_list_view.dart';
import 'services/dynamic_greeting_service.dart';
import 'package:echolog/widgets/save_recording_dialog.dart';
import 'package:echolog/widgets/streak_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';
final String _lemonFoxApiKey =
    "Sf8cPZsgkaVohAnV31DxsiSO9QiIiqbj"; // Consider moving to a config file and .gitignore

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedCategoryData;
  bool _isTranscribingLemonFox = false;
  String? _currentGreeting;
  String? _cachedDynamicGreeting;
  DateTime? _lastGreetingUpdateDate;
  late AnimationController _greetingAnimController;
  late Animation<double> _greetingFadeAnim;
  final List<Map<String, dynamic>> _predefinedCategories = [
    {
      'name': 'Vent',
      'emoji': '😤',
      'color': Colors.red.shade400,
      'iconColor': Colors.red.shade100,
      'isCustom': false,
      'id': 'Vent',
    },
    {
      'name': 'Random Talk',
      'emoji': '💬',
      'color': Colors.blue.shade400,
      'iconColor': Colors.blue.shade100,
      'isCustom': false,
      'id': 'Random Talk',
    },
    {
      'name': 'Brainstorm',
      'emoji': '💡',
      'color': Colors.green.shade400,
      'iconColor': Colors.green.shade100,
      'isCustom': false,
      'id': 'Brainstorm',
    },
    {
      'name': 'Gratitude',
      'emoji': '🙏',
      'color': Colors.orange.shade400,
      'iconColor': Colors.orange.shade100,
      'isCustom': false,
      'id': 'Gratitude',
    },
  ];

  bool _isRecording = false;
  bool _isRecordingPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  String? _currentRecordingPath;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;

  // State for playback and interactive waveforms
  String? _currentlyPlayingFileId;
  RecordingEntry?
  _currentlyPlayingEntry; // To access waveform points and mood color
  // For the main RecordingControlsWidget waveform
  Duration _currentPlaybackProgress = Duration.zero;
  Duration _currentTotalDuration = Duration.zero;
  StreamSubscription? _playerSubscription;

  FilterState _currentFilters = FilterState();
  final PasswordService _passwordService = PasswordService();
  HiddenAccessTriggerMethod _selectedMethod =
      HiddenAccessTriggerMethod.longPressAppBar;
  bool _isGestureAccessActive = false;
  int _tapCount = 0;
  Timer? _tapTimer;
  final int _tripleTapMilliseconds = 500;
  DateTime? _lastBackPressed;

  List<Map<String, dynamic>> _getAllCategories(
    Box<CustomCategory> customCategoryBox,
  ) {
    final customCategories = customCategoryBox.values
        .map((c) => c.toMap())
        .toList();
    return [..._predefinedCategories, ...customCategories];
  }

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initializeRecorder();
    _initializePlayer();
    _loadHiddenAccessPreference();
    _greetingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _greetingFadeAnim = CurvedAnimation(
      parent: _greetingAnimController,
      curve: Curves.easeInOut,
    );
    _greetingAnimController.value = 1.0;
    _updateDynamicGreetingIfNeeded(force: true);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _tapTimer?.cancel();
    _playerSubscription?.cancel();
    _recorder?.closeRecorder().catchError(
      (e) => print("Error closing recorder: $e"),
    );
    _recorder = null;
    _player?.closePlayer().catchError((e) => print("Error closing player: $e"));
    _player = null;
    super.dispose();
  }

  void _updateDynamicGreetingIfNeeded({bool force = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_cachedDynamicGreeting == null ||
        _lastGreetingUpdateDate != today ||
        force) {
      final box = Hive.box<RecordingEntry>(recordingsBoxName);
      final lastRecording = box.isNotEmpty ? box.values.last : null;
      _cachedDynamicGreeting = DynamicGreetingService.getGreeting(
        now: now,
        lastRecording: lastRecording,
      );
      _lastGreetingUpdateDate = today;
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
      await _recorder!.openRecorder();
      if (mounted) setState(() => _isRecorderInitialized = true);
    } catch (e) {
      print('Error initializing recorder: $e');
      if (mounted) {
        setState(() => _isRecorderInitialized = false);
        showCustomSnackBar(
          context: context,
          message: 'Recorder initialization failed. Check permissions.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _player!.openPlayer();
      _player!.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      ); // More frequent updates for smoother UI

      _playerSubscription = _player!.onProgress!.listen((e) {
        if (mounted &&
            _currentlyPlayingFileId != null &&
            (_player?.isPlaying ?? false)) {
          setState(() {
            _currentPlaybackProgress = e.position;
            _currentTotalDuration =
                e.duration; // Player provides total duration
          });
        }
      });
      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (e) {
      print('Error initializing player: $e');
      if (mounted) {
        setState(() => _isPlayerInitialized = false);
        showCustomSnackBar(
          context: context,
          message: 'Player initialization failed.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _handleSeek(double seekPercent) async {
    if (_player != null &&
        _isPlayerInitialized &&
        _currentlyPlayingFileId != null &&
        _currentTotalDuration.inMilliseconds > 0) {
      final targetPosition = Duration(
        milliseconds: (_currentTotalDuration.inMilliseconds * seekPercent)
            .round(),
      );
      await _player!.seekToPlayer(targetPosition);
      if (mounted) {
        // Optimistic UI update
        setState(() => _currentPlaybackProgress = targetPosition);
      }
    }
  }

  Future<void> _playRecordingFromProviderOrWidget(RecordingEntry entry) async {
    await _togglePlayRecordingItem(entry, [
      entry,
    ]); // Reuse common logic, pass entry as a single-item list
    // Ensure playback provider request is cleared if it was the source
    Provider.of<PlaybackProvider>(
      context,
      listen: false,
    ).clearPlaybackRequest();
  }
  // ...existing code...

  Future<void> _stopPlaybackAndResetState() async {
    final String? oldPlayingFileId =
        _currentlyPlayingFileId; // Capture before reset

    if (_player != null && (_player!.isPlaying || _player!.isPaused)) {
      try {
        await _player!.stopPlayer();
      } catch (e) {
        print("[HomeScreen] Error stopping player: $e");
        // Potentially show a snackbar or handle error
      }
    }

    // If a track was active, update its isPlaying status in Hive
    if (oldPlayingFileId != null) {
      final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
      final entryToUpdate = recordingsBox.get(oldPlayingFileId);
      if (entryToUpdate != null) {
        if (entryToUpdate.isPlaying) {
          // Only update if it was marked as playing
          entryToUpdate.isPlaying = false;
          // Use try-catch for Hive operations if they can fail
          try {
            await recordingsBox.put(oldPlayingFileId, entryToUpdate);
          } catch (hiveError) {
            print(
              "[HomeScreen] Error updating entry in Hive during stop: $hiveError",
            );
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _currentlyPlayingFileId = null;
        _currentlyPlayingEntry =
            null; // This will ensure cards reflect not playing
        // _currentTotalDuration = Duration.zero; // Optional: reset or keep last known
        _currentPlaybackProgress = Duration.zero;
        // Any other UI state related to playback progress should be reset here
      });
    }
  }

  Future<void> _togglePlayRecordingItem(
    RecordingEntry entry,
    List<RecordingEntry>
    currentList, // This parameter might be used for context or future features
  ) async {
    if (!_isPlayerInitialized || _player == null) {
      showCustomSnackBar(
        context: context,
        message: 'Player not ready.',
        leadingIcon: Icons.play_disabled_rounded,
      );
      return;
    }

    final String entryId = entry.id;
    final bool isTargetEntryCurrentlyPlaying =
        _currentlyPlayingFileId == entryId && _player!.isPlaying;
    final bool isTargetEntryCurrentlyPaused =
        _currentlyPlayingFileId == entryId && _player!.isPaused;

    final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);

    if (isTargetEntryCurrentlyPlaying) {
      // --- CASE 1: Target entry is PLAYING -> PAUSE it ---
      try {
        await _player!.pausePlayer();
        // Update the entry's state for persistence and local model consistency
        // The RecordingCard's isPlaying prop should primarily rely on _player.isPlaying
        final entryInBox = recordingsBox.get(entryId);
        if (entryInBox != null) {
          entryInBox.isPlaying = false;
          await recordingsBox.put(entryId, entryInBox);
        }
        if (_currentlyPlayingEntry?.id == entryId) {
          _currentlyPlayingEntry?.isPlaying = false;
        }

        if (mounted) {
          setState(() {
            // UI will update because the card's isPlaying prop will change
            // (derived from _player.isPlaying)
          });
        }
      } catch (e) {
        print("[HomeScreen] Error pausing player: $e");
        await _stopPlaybackAndResetState(); // Fallback to stop on error
      }
    } else if (isTargetEntryCurrentlyPaused) {
      // --- CASE 2: Target entry is PAUSED -> RESUME it ---
      try {
        await _player!.resumePlayer();
        final entryInBox = recordingsBox.get(entryId);
        if (entryInBox != null) {
          entryInBox.isPlaying = true;
          await recordingsBox.put(entryId, entryInBox);
        }
        if (_currentlyPlayingEntry?.id == entryId) {
          _currentlyPlayingEntry?.isPlaying = true;
        }

        if (mounted) {
          setState(() {
            // UI will update
          });
        }
      } catch (e) {
        print("[HomeScreen] Error resuming player: $e");
        await _stopPlaybackAndResetState(); // Fallback to stop on error
      }
    } else {
      // --- CASE 3: Play NEW entry (or different entry was active) ---
      // Stop any previous playback and reset its state first
      if (_currentlyPlayingFileId != null ||
          _player!.isPlaying ||
          _player!.isPaused) {
        await _stopPlaybackAndResetState();
      }

      final file = File(entry.filePath);
      if (!await file.exists()) {
        print(
          "[HomeScreen] Error: File does not exist at path: ${entry.filePath}",
        );
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file not found.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
        );
        return;
      }

      try {
        await _player!.startPlayer(
          fromURI: entry.filePath,
          codec: Codec.aacADTS, // Ensure this codec is correct for your files
          whenFinished: () {
            // This callback is crucial. Ensure it only acts if this specific track finished.
            if (_currentlyPlayingFileId == entryId) {
              _stopPlaybackAndResetState();
            }
          },
        );

        // Update state for the new playing entry
        final entryInBox = recordingsBox.get(entryId);
        if (entryInBox != null) {
          entryInBox.isPlaying = true;
          await recordingsBox.put(entryId, entryInBox);
          // Update _currentlyPlayingEntry to the instance from the box or the passed entry
          // It's often better to use the instance from the box if available
          _currentlyPlayingEntry = entryInBox;
        } else {
          // Fallback if not in box for some reason, use the passed entry
          entry.isPlaying = true;
          // Consider if you need to add it to the box here if it's missing
          _currentlyPlayingEntry = entry;
        }

        if (mounted) {
          setState(() {
            _currentlyPlayingFileId = entryId;
            // _currentlyPlayingEntry is already set above
            _currentTotalDuration =
                _currentlyPlayingEntry?.duration ?? Duration.zero;
            _currentPlaybackProgress =
                Duration.zero; // Reset progress for new track
          });
        }
      } catch (e) {
        print("[HomeScreen] Error playing recording item: $e");
        showCustomSnackBar(
          context: context,
          message: 'Error playing recording.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
        );
        await _stopPlaybackAndResetState(); // Ensure state is reset on error
      }
    }
  }

  // ...rest of your HomeScreen code...
  Future<void> _shareRecordingFile(RecordingEntry entry) async {
    await _stopPlaybackAndResetState(); // Stop playback before sharing
    if (entry.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Recording file path is missing.')),
      );
      return;
    }
    final File audioFile = File(entry.filePath);
    if (!await audioFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Recording file not found.')),
      );
      return;
    }
    final result = await Share.shareXFiles([
      XFile(entry.filePath),
    ], text: 'Check out this audio recording: ${entry.displayName}');
    if (result.status == ShareResultStatus.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recording shared!')));
    }
  }

  Future<void> _shareTranscriptionText(RecordingEntry entry) async {
    // No need to stop playback for sharing text
    if (entry.transcription == null || entry.transcription!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcription available to share.')),
      );
      return;
    }
    await Share.share(
      'Transcription for "${entry.displayName}":\n\n${entry.transcription}',
      subject: 'Transcription: ${entry.displayName}',
    );
  }

  Future<void> _showShareOptionsDialog(RecordingEntry entry) async {
    await _stopPlaybackAndResetState(); // Stop playback before showing dialog
    final theme = Theme.of(context);
    final bool hasTranscription =
        entry.transcription != null && entry.transcription!.trim().isNotEmpty;
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
            'Share Options',
            style:
                theme.dialogTheme.titleTextStyle ??
                GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.audiotrack_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  'Share Audio Recording',
                  style: GoogleFonts.poppins(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _shareRecordingFile(entry);
                },
              ),
              if (hasTranscription)
                ListTile(
                  leading: Icon(
                    Icons.description_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Share Transcription',
                    style: GoogleFonts.poppins(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _shareTranscriptionText(entry);
                  },
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: theme.textButtonTheme.style,
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  String _generateSummaryPreview(String fullText, {int maxLength = 100}) {
    if (fullText.isEmpty) return "";
    return fullText.length <= maxLength
        ? fullText
        : '${fullText.substring(0, maxLength)}...';
  }

  Future<void> _transcribeWithLemonFox(RecordingEntry entry) async {
    await _stopPlaybackAndResetState(); // Stop playback before transcribing
    if (_lemonFoxApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lemonfox API Key not set.')),
      );
      return;
    }
    if (entry.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Recording file path is missing.')),
      );
      return;
    }
    final File audioFile = File(entry.filePath);
    if (!await audioFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Recording file not found.')),
      );
      return;
    }

    setState(() => _isTranscribingLemonFox = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transcribing "${entry.displayName}"...')),
    );
    final Uri apiUri = Uri.parse(
      "https://api.lemonfox.ai/v1/audio/transcriptions",
    );
    try {
      var request = http.MultipartRequest('POST', apiUri);
      request.headers['Authorization'] = 'Bearer $_lemonFoxApiKey';
      request.files.add(
        await http.MultipartFile.fromPath('file', entry.filePath),
      );
      request.fields['response_format'] =
          'json'; // Ensure this is correct for LemonFox
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? transcriptText = responseData['text'];
        if (transcriptText != null) {
          final box = Hive.box<RecordingEntry>(recordingsBoxName);
          entry.transcription = transcriptText;
          entry.summaryPreview = _generateSummaryPreview(
            transcriptText,
          ); // Generate and save summary
          await box.put(entry.id, entry);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Transcription complete for "${entry.displayName}"!',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception('Transcription text not found in response.');
        }
      } else {
        String errorMessage = "Error ${response.statusCode}";
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage += errorData['detail'] != null
              ? "\n${errorData['detail']}"
              : (errorData['message'] != null
                    ? "\n${errorData['message']}"
                    : "\n${response.body}");
        } catch (_) {
          errorMessage += "\n${response.body}";
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lemonfox transcription failed: $e')),
      );
    } finally {
      setState(() => _isTranscribingLemonFox = false);
    }
  }

  Future<void> _moveToVault(RecordingEntry entryToMove) async {
    await _stopPlaybackAndResetState(); // Stop playback before moving
    if (entryToMove.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Recording has no ID and cannot be moved.'),
        ),
      );
      return;
    }
    final hiddenBox = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
    if (hiddenBox.containsKey(entryToMove.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${entryToMove.displayName}" is already in the vault.',
          ),
        ),
      );
      return;
    }

    // // Ensure isPlaying is false and isVaulted is true for the entry being moved
    // final RecordingEntry entryForVault = entryToMove.copyWith(
    //   isVaulted: true,
    //   isPlaying: false, // Explicitly set isPlaying to false
    //   // waveformPoints and summaryPreview are preserved by copyWith if they exist
    // );

    try {
      final recordingsBox = Hive.box<RecordingEntry>(
        recordingsBoxName,
      ); // Define recordingsBox
      // await hiddenBox.put(entryForVault.id, entryForVault);
      await recordingsBox.delete(entryToMove.id); // Delete from the main box
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${entryToMove.displayName}" to vault.'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moving to vault: $e')));
    }
  }

  Future<void> _loadHiddenAccessPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final methodName = prefs.getString(PREF_HIDDEN_ACCESS_METHOD);
    HiddenAccessTriggerMethod loadedMethod =
        HiddenAccessTriggerMethod.longPressAppBar; // Default
    if (methodName != null) {
      try {
        loadedMethod = HiddenAccessTriggerMethod.values.firstWhere(
          (e) => e.toString() == methodName,
          orElse: () => HiddenAccessTriggerMethod.longPressAppBar,
        );
      } catch (e) {
        /* Default already set */
      }
    }
    if (mounted && _selectedMethod != loadedMethod)
      setState(() => _selectedMethod = loadedMethod);
    else if (!mounted && _selectedMethod != loadedMethod)
      _selectedMethod = loadedMethod; // For initState case
  }

  Future<void> _triggerHiddenScreenAccess() async {
    if (_isGestureAccessActive || !mounted) return;
    setState(() => _isGestureAccessActive = true);
    _tapCount = 0;
    _tapTimer?.cancel();

    bool hasPassword = await _passwordService.hasPassword();
    if (!mounted) {
      _resetGestureAccessFlags();
      return;
    }

    if (hasPassword) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => EnterPasswordDialog(
          passwordService: _passwordService,
          onPasswordEntered: (bool passwordCorrect) {
            if (passwordCorrect)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HiddenRecordingsScreen(),
                ),
              ).then((_) => _resetGestureAccessFlags());
            else
              _resetGestureAccessFlags();
          },
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => CreatePasswordDialog(
          passwordService: _passwordService,
          onPasswordSet: (bool passwordCreated) {
            if (passwordCreated && mounted)
              showCustomSnackBar(
                context: context,
                message: "Password set! Trigger gesture again to access.",
                iconColor: Colors.green,
                duration: const Duration(seconds: 3),
              );
            _resetGestureAccessFlags();
          },
        ),
      );
    }
  }

  void _resetGestureAccessFlags() {
    if (mounted) setState(() => _isGestureAccessActive = false);
  }

  void _handleTripleTap() {
    if (_isGestureAccessActive) return;
    _tapCount++;
    _tapTimer?.cancel();
    if (_tapCount == 3) {
      _triggerHiddenScreenAccess();
      _tapCount = 0;
    } else {
      _tapTimer = Timer(Duration(milliseconds: _tripleTapMilliseconds), () {
        if (mounted) _tapCount = 0;
      });
    }
  }

  Future<void> _startOrStopRecording() async {
    if (!_isRecorderInitialized) {
      showCustomSnackBar(
        context: context,
        message: 'Recorder not ready. Grant permissions or wait.',
        leadingIcon: Icons.mic_off_rounded,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    if (_isRecording) {
      try {
        final path = await _recorder!.stopRecorder();
        _recordingTimer?.cancel();
        if (path != null) {
          _currentRecordingPath = path;
          // For now, waveformPoints will be generated in SaveRecordingDialog or remain null
          if (mounted && _selectedCategoryData != null) {
            _showSaveRecordingDialog(
              path,
              _recordingDuration,
              _selectedCategoryData!,
            );
          }
        }
      } catch (e) {
        if (mounted)
          showCustomSnackBar(
            context: context,
            message: 'Error stopping recording.',
            leadingIcon: Icons.error_outline_rounded,
            iconColor: Theme.of(context).colorScheme.error,
          );
      } finally {
        if (mounted)
          setState(() {
            _isRecording = false;
            _isRecordingPaused = false;
          });
      }
    } else {
      if (_selectedCategoryData == null) {
        showCustomSnackBar(
          context: context,
          message: 'Please select a mood category first.',
          leadingIcon: Icons.category_outlined,
        );
        return;
      }
      await _stopPlaybackAndResetState(); // Stop any playback before starting new recording
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'echolog_${DateTime.now().millisecondsSinceEpoch}.aac';
        _currentRecordingPath = '${directory.path}/$fileName';
        await _recorder!.startRecorder(
          toFile: _currentRecordingPath,
          codec: Codec.aacADTS,
        );
        if (mounted)
          setState(() {
            _isRecording = true;
            _isRecordingPaused = false;
            _recordingDuration = Duration.zero;
          });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isRecordingPaused && mounted)
            setState(
              () => _recordingDuration = Duration(
                seconds: _recordingDuration.inSeconds + 1,
              ),
            );
        });
      } catch (e) {
        if (mounted) {
          setState(() => _isRecording = false);
          showCustomSnackBar(
            context: context,
            message: 'Error starting recording.',
            leadingIcon: Icons.error_outline_rounded,
            iconColor: Theme.of(context).colorScheme.error,
          );
        }
      }
    }
  }

  Future<void> _togglePausePlayRecording() async {
    if (!_isRecording || _recorder == null || !_isRecorderInitialized) return;

    if (_recorder!.isPaused) {
      await _recorder!.resumeRecorder();
    } else {
      await _recorder!.pauseRecorder();
    }

    if (mounted) {
      setState(() => _isRecordingPaused = _recorder!.isPaused);
    }
  }

  // Updated to match the signature expected by SaveRecordingDialog's onSave
  void _handleSaveRecording(
    String displayName,
    String filePath,
    Duration duration,
    Map<String, dynamic> categoryData,
    List<double>? waveformPoints,
    String? summaryPreview,
  ) async {
    final newEntry = RecordingEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: filePath,
      displayName: displayName,
      duration: duration,
      dateRecorded: DateTime.now(),
      moodName: categoryData['name'] as String,
      moodColor: categoryData['color'] as Color,
      moodIconColor: categoryData['iconColor'] as Color,
      moodEmoji: categoryData['emoji'] as String? ?? '',
      waveformPoints: waveformPoints, // Save generated waveform
      summaryPreview: summaryPreview, // Save generated summary
    );
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    await box.put(newEntry.id, newEntry);
    Provider.of<StreakProvider>(context, listen: false).onNewRecording();

    try {
      await updateWidgetWithRecentRecording(recentEntry: newEntry);
    } catch (e) {
      print("[HomeScreen] Error calling updateWidgetWithRecentRecording: $e");
    }
    if (mounted)
      showCustomSnackBar(
        context: context,
        message: '"${newEntry.displayName}" saved!',
        leadingIcon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green.shade400,
      );
  }

  void _handleDiscardRecording() {
    if (mounted)
      showCustomSnackBar(
        context: context,
        message: 'Recording discarded.',
        leadingIcon: Icons.delete_outline_rounded,
      );
  }

  Future<void> _showSaveRecordingDialog(
    String filePath,
    Duration duration,
    Map<String, dynamic> categoryData,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Renamed context to avoid conflict
        return SaveRecordingDialog(
          filePath: filePath,
          duration: duration,
          categoryData: categoryData,
          player: _player, // Pass player for preview functionality in dialog
          isPlayerInitialized: _isPlayerInitialized, // Pass player status
          onSave:
              (
                String displayName,
                String filePath,
                Duration duration,
                Map<String, dynamic> categoryData,
              ) {
                // Adapt to the expected signature by SaveRecordingDialog.
                // SaveRecordingDialog is expected to be updated to provide waveformPoints and summaryPreview.
                // For now, we pass null as _handleSaveRecording can handle them being null.
                _handleSaveRecording(
                  displayName,
                  filePath,
                  duration,
                  categoryData,
                  null,
                  null,
                );
              },
          onDiscard: _handleDiscardRecording,
        );
      },
    );
    if (mounted)
      setState(
        () => _recordingDuration = Duration.zero,
      ); // Reset duration after dialog
  }

  void _onCategorySelected(Map<String, dynamic>? category) async {
    if (_isRecording) return; // Don't change category while recording

    // Mood-aware greetings for these moods:
    final moodsWithSpecialGreeting = [
      'vent',
      'brainstorm',
      'random talk',
      'gratitude',
    ];

    String? moodGreeting;
    if (category != null) {
      final mood = (category['name'] as String?) ?? '';
      final emoji = (category['emoji'] as String?) ?? '';
      if (moodsWithSpecialGreeting.any((m) => mood.toLowerCase().contains(m))) {
        moodGreeting = DynamicGreetingService.getMoodAwareGreeting(
          mood,
          emoji: emoji,
        );
      }
    }

    // Animate out, set greeting, then animate in
    await _greetingAnimController.reverse();
    setState(() {
      _selectedCategoryData = category;
      _currentGreeting = moodGreeting;
    });
    await _greetingAnimController.forward();
  }

  void _resetGreetingToDynamic() async {
    await _greetingAnimController.reverse();
    setState(() {
      _currentGreeting = null;
      _updateDynamicGreetingIfNeeded(force: true);
    });
    await _greetingAnimController.forward();
  }

  void _showAdvancedFilterSheet(
    List<Map<String, dynamic>> allCategoriesForFilter,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterBottomSheetWidget(
        initialFilters: _currentFilters, // Pass current filters
        categories: allCategoriesForFilter, // Pass all categories
        onApplyFilters: (updatedFilters) =>
            setState(() => _currentFilters = updatedFilters),
      ),
    );
  }

  Future<void> _deleteRecordingFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Could not delete the audio file.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        );
    }
  }

  void _handleDismissRecording(RecordingEntry entry) async {
    final theme = Theme.of(context);
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    final String deletedFilePath = entry.filePath;

    await _stopPlaybackAndResetState(); // Stop playback if it's this entry

    // Prepare entry for potential undo, ensuring isPlaying is false
    // final RecordingEntry entryToPotentiallyRestore = entry.copyWith(isPlaying: false);
    await box.delete(entry.id);

    showCustomSnackBar(
      context: context,
      message: '"${entry.displayName}" deleted.',
      // actionLabel: 'UNDO',
      onActionPressed: () {
        // box.put(entry.id, entryToPotentiallyRestore); // Restore with isPlaying false
      },
      duration: const Duration(seconds: 4),
      leadingIcon: Icons.delete_forever_rounded,
      iconColor: theme.colorScheme.secondary,
    ).closed.then((reason) {
      if (reason != SnackBarClosedReason.action && !box.containsKey(entry.id)) {
        _deleteRecordingFile(deletedFilePath);
      }
    });
  }

  void _handleScreenScaleStart(ScaleStartDetails details) {
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
    if (details.pointerCount < 2) return;
  }

  void _handleScreenScaleUpdate(ScaleUpdateDetails details) {
    if (_isGestureAccessActive) return;
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
    if (details.pointerCount < 2) return;
    final currentScale = details.scale;
    if (_selectedMethod == HiddenAccessTriggerMethod.pinchInScreen &&
        currentScale < 0.7) {
      _triggerHiddenScreenAccess();
    } else if (_selectedMethod == HiddenAccessTriggerMethod.pinchOutScreen &&
        currentScale > 1.5) {
      _triggerHiddenScreenAccess();
    }
  }

  void _handleScreenScaleEnd(ScaleEndDetails details) {
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    final lastRecording = box.isNotEmpty ? box.values.last : null;
    final greeting = DynamicGreetingService.getGreeting(
      now: DateTime.now(),
      lastRecording: lastRecording,
    );
    Widget appBarWidget = AppBar(
      leading: Consumer<StreakProvider>(
        builder: (context, streakProvider, _) {
          return StreakWidget(streak: streakProvider.streak);
        },
      ),
      title: Text(
        'Echolog',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
            _loadHiddenAccessPreference(); // Reload preference in case it changed
          },
        ),
      ],
      backgroundColor:
          theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: theme.appBarTheme.elevation ?? 0,
      foregroundColor:
          theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
    );
    switch (_selectedMethod) {
      case HiddenAccessTriggerMethod.longPressAppBar:
        return GestureDetector(
          onLongPress: _isGestureAccessActive
              ? null
              : _triggerHiddenScreenAccess,
          child: appBarWidget,
        );
      case HiddenAccessTriggerMethod.tripleTapAppBar:
        return GestureDetector(
          onTap: _isGestureAccessActive ? null : _handleTripleTap,
          child: appBarWidget,
        );
      default:
        return appBarWidget;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget mainScaffoldContent = Consumer<PlaybackProvider>(
      builder: (context, playbackProvider, child) {
        final recordingToPlayFromWidget = playbackProvider.recordingToPlay;
        final shouldPlayImmediately = playbackProvider.playImmediately;

        if (recordingToPlayFromWidget != null && shouldPlayImmediately) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                playbackProvider.recordingToPlay == recordingToPlayFromWidget &&
                playbackProvider.playImmediately) {
              _playRecordingFromProviderOrWidget(recordingToPlayFromWidget);
            }
          });
        }

        return WillPopScope(
          onWillPop: () async {
            if (Navigator.of(context).canPop()) {
              return true;
            }
            if (_lastBackPressed == null ||
                DateTime.now().difference(_lastBackPressed!) >
                    const Duration(seconds: 2)) {
              // First press
              _lastBackPressed = DateTime.now();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Press back again to exit'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return false; // Prevent app from exiting
            }
            return true;
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: _buildAppBar(context),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                0,
              ), // Use all(16.0) or specific as needed
              child: ValueListenableBuilder<Box<CustomCategory>>(
                valueListenable: Hive.box<CustomCategory>(
                  customCategoriesBoxName,
                ).listenable(),
                builder: (context, customCategoryBox, _) {
                  final allDisplayCategories = _getAllCategories(
                    customCategoryBox,
                  );
                  final bool isAudioPlaying =
                      _currentlyPlayingFileId != null &&
                      (_player?.isPlaying ?? false);

                  Map<String, dynamic>? controlsCategoryData =
                      _selectedCategoryData;
                  if (_currentlyPlayingEntry != null) {
                    // If an audio track is loaded/playing
                    controlsCategoryData = {
                      'name': _currentlyPlayingEntry!.moodName,
                      'emoji': _currentlyPlayingEntry!.moodEmoji,
                      'color': _currentlyPlayingEntry!.moodColor,
                      'iconColor': _currentlyPlayingEntry!.moodIconColor,
                    };
                  }

                  // Define greeting here
                  final box = Hive.box<RecordingEntry>(recordingsBoxName);
                  final lastRecording = box.isNotEmpty ? box.values.last : null;
                  final greeting = DynamicGreetingService.getGreeting(
                    now: DateTime.now(),
                    lastRecording: lastRecording,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // If mood-aware greeting is showing, revert to dynamic on tap
                            if (_currentGreeting != null) {
                              _resetGreetingToDynamic();
                            }
                          },
                          child: SizedBox(
                            height: 72,
                            child: FadeTransition(
                              opacity: _greetingFadeAnim,
                              child: Center(
                                child: Text(
                                  _currentGreeting ??
                                      _cachedDynamicGreeting ??
                                      '',
                                  // Use the greeting from DynamicGreetingService
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onBackground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),
                      CategorySelectorWidget(
                        predefinedCategories: _predefinedCategories,
                        selectedCategoryData: _selectedCategoryData,
                        isRecording: _isRecording,
                        onCategorySelected: _onCategorySelected,
                      ),
                      const SizedBox(height: 20), // Adjusted spacing from 40
                      Center(
                        child: RecordingControlsWidget(
                          waveformColor: Colors.red,
                          isRecording: _isRecording,
                          isRecordingPaused: _isRecordingPaused,
                          recordingDuration: _recordingDuration,
                          selectedCategoryData:
                              controlsCategoryData, // Dynamic category for color
                          isRecorderInitialized: _isRecorderInitialized,
                          onStartStopRecording: _startOrStopRecording,
                          onTogglePausePlayRecording: _togglePausePlayRecording,

                          // Props for the interactive waveform (main controls)
                        ),
                      ),
                      const SizedBox(height: 25), // Adjusted spacing from 40
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0.0,
                        ), // Adjusted from 8.0
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Recordings',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onBackground,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              tooltip: 'View All Recordings',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RecordingsListPage(
                                      onTranscribe: _transcribeWithLemonFox,
                                      onShare: _showShareOptionsDialog,
                                      onMoveToVault: _moveToVault,
                                      onTogglePlay: _togglePlayRecordingItem,
                                      onDismissRecording:
                                          _handleDismissRecording,
                                      currentlyPlayingFileId:
                                          _currentlyPlayingFileId,
                                      currentPlaybackProgress:
                                          _currentPlaybackProgress,
                                      currentTotalDuration:
                                          _currentTotalDuration,
                                      onSeekRequest: _handleSeek,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5), // Adjusted from 15
                      Expanded(
                        child: ValueListenableBuilder<Box<RecordingEntry>>(
                          valueListenable: Hive.box<RecordingEntry>(
                            recordingsBoxName,
                          ).listenable(),
                          builder: (context, box, _) {
                            final allRecordings = box.values.toList()
                              ..sort(
                                (a, b) =>
                                    b.dateRecorded.compareTo(a.dateRecorded),
                              );
                            final recentRecordings = allRecordings
                                .take(2)
                                .toList();
                            return RecordingsListView(
                              onTranscribe: _transcribeWithLemonFox,
                              onShare: _showShareOptionsDialog,
                              onMoveToVault: _moveToVault,
                              recordingsBoxListenable: Hive.box<RecordingEntry>(
                                recordingsBoxName,
                              ).listenable(),
                              currentFilters: _currentFilters,
                              onTogglePlay: _togglePlayRecordingItem,
                              onDismissRecording: _handleDismissRecording,
                              currentlyPlayingFileId: _currentlyPlayingFileId,
                              currentPlaybackProgress: _currentPlaybackProgress,
                              currentTotalDuration: _currentTotalDuration,
                              onSeekRequest: _handleSeek,
                              showOnlyRecent: true,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (_selectedMethod == HiddenAccessTriggerMethod.pinchInScreen ||
        _selectedMethod == HiddenAccessTriggerMethod.pinchOutScreen) {
      return GestureDetector(
        onScaleStart: _isGestureAccessActive ? null : _handleScreenScaleStart,
        onScaleUpdate: _isGestureAccessActive ? null : _handleScreenScaleUpdate,
        onScaleEnd: _isGestureAccessActive ? null : _handleScreenScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: mainScaffoldContent,
      );
    } else {
      return mainScaffoldContent;
    }
  }
}

// Define RecordingPermissionException if not already defined elsewhere
class RecordingPermissionException implements Exception {
  final String message;
  RecordingPermissionException(this.message);
  @override
  String toString() => 'RecordingPermissionException: $message';
}

// Define HiddenAccessTriggerMethod if not already defined elsewhere
enum HiddenAccessTriggerMethod {
  longPressAppBar,
  tripleTapAppBar,
  pinchInScreen,
  pinchOutScreen,
}
