import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:echolog/main.dart';
// For recordingsBoxName, customCategoriesBoxName, hiddenRecordingsBox
import 'package:echolog/models/custom_category.dart';
import 'package:echolog/models/filter_state.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/providers/playback_provider.dart';
import 'package:echolog/providers/streak_provider.dart';
import 'package:echolog/providers/transcription_status_provider.dart';
import 'package:echolog/screens/hidden/hidden_recordings_screen.dart';
import 'package:echolog/screens/home/widgets/category_selector_widget.dart';
import 'package:echolog/screens/home/widgets/recording_controls_widget.dart';
import 'package:echolog/screens/home/widgets/streak_widget.dart';
import 'package:echolog/screens/recordings/recordings_list_page.dart';
import 'package:echolog/screens/settings/settings_screen.dart';
import 'package:echolog/services/dynamic_greeting_service.dart';
import 'package:echolog/services/password_service.dart';
import 'package:echolog/services/recording_service.dart';
import 'package:echolog/services/security_service.dart';
import 'package:echolog/utils/custom_snackbar.dart';
import 'package:echolog/widgets/dialogs/create_password_dialog.dart';
import 'package:echolog/widgets/dialogs/enter_password_dialog.dart';
import 'package:echolog/widgets/dialogs/filter_bottom_sheet_widget.dart';
import 'package:echolog/widgets/dialogs/save_recording_dialog.dart';
import 'package:echolog/widgets/transcription_progress_bar.dart';
// import 'package:echolog/services/recording_service.dart'; // Not used directly in this file

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../calendar_screen.dart';

const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';
final String _lemonFoxApiKey = dotenv.env['LEMONFOX_API_KEY'] ?? "";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Track which context controls playback: 'home' or 'list'
  String _playbackContext = 'home';
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
  final ValueNotifier<String?> _currentlyPlayingFileIdNotifier =
      ValueNotifier<String?>(null);
  RecordingEntry?
  _currentlyPlayingEntry; // To access waveform points and mood color
  // For the main RecordingControlsWidget waveform
  ValueNotifier<Duration> _currentPlaybackProgress = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<bool> _isActuallyPlayingNotifier = ValueNotifier<bool>(
    false,
  );
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
    // Ensure streak is loaded from persistent storage on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<StreakProvider>(context, listen: false).initialize();
      }
    });
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
            _currentlyPlayingFileIdNotifier.value != null &&
            (_player?.isPlaying ?? false)) {
          setState(() {
            _currentPlaybackProgress.value = e.position;
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
        _currentlyPlayingFileIdNotifier.value != null &&
        _currentTotalDuration.inMilliseconds > 0) {
      final targetPosition = Duration(
        milliseconds: (_currentTotalDuration.inMilliseconds * seekPercent)
            .round(),
      );
      await _player!.seekToPlayer(targetPosition);
      if (mounted) {
        // Optimistic UI update
        setState(() => _currentPlaybackProgress.value = targetPosition);
      }
    }
  }

  Future<void> _playRecordingFromProviderOrWidget(RecordingEntry entry) async {
    await _startPlaybackForEntry(entry);
    // Ensure playback provider request is cleared if it was the source
    Provider.of<PlaybackProvider>(
      context,
      listen: false,
    ).clearPlaybackRequest();
  }

  Future<void> _stopPlaybackAndResetState() async {
    final String? oldPlayingFileId =
        _currentlyPlayingFileIdNotifier.value; // Capture before reset

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
        _currentlyPlayingFileIdNotifier.value = null;
        _currentlyPlayingEntry =
            null; // This will ensure cards reflect not playing
        // _currentTotalDuration = Duration.zero; // Optional: reset or keep last known
        _currentPlaybackProgress.value = Duration.zero;
        _isActuallyPlayingNotifier.value = false;
        // Any other UI state related to playback progress should be reset here
      });
    }
  }

  Future<void> _togglePlayRecordingItem(
    RecordingEntry entry,
    List<RecordingEntry> allEntries, {
    String playbackContext = 'home',
  }) async {
    final isCurrent = _currentlyPlayingFileIdNotifier.value == entry.id;
    final isPlaying = isCurrent && (_player?.isPlaying ?? false);
    final isPaused = isCurrent && (_player?.isPaused ?? false);

    if (isPlaying) {
      // Pause playback
      await _player?.pausePlayer();
      if (mounted)
        setState(() {
          _isActuallyPlayingNotifier.value = false;
        });
    } else if (isPaused) {
      // Resume playback
      await _player?.resumePlayer();
      if (mounted)
        setState(() {
          _isActuallyPlayingNotifier.value = true;
        });
    } else {
      // Start new playback
      await _startPlaybackForEntry(entry);
    }
  }

  Future<void> _startPlaybackForEntry(RecordingEntry entry) async {
    await _stopPlaybackAndResetState();
    await _player?.startPlayer(
      fromURI: entry.filePath,
      codec: Codec.aacADTS,
      whenFinished: () {
        if (mounted) {
          setState(() {
            _currentlyPlayingFileIdNotifier.value = null;
            _currentlyPlayingEntry = null;
            _isActuallyPlayingNotifier.value = false;
            _currentPlaybackProgress.value = Duration.zero;
          });
        }
      },
    );
    if (mounted)
      setState(() {
        _currentlyPlayingFileIdNotifier.value = entry.id;
        _currentlyPlayingEntry = entry;
        _isActuallyPlayingNotifier.value = true;
      });
  }

  // ...existing code...
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

  void _deleteRecording(String recordingId) async {
    await _stopPlaybackAndResetState();
    final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
    final entry = recordingsBox.get(recordingId);
    if (entry != null) {
      // First, delete the associated file
      try {
        final file = File(entry.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print("Error deleting file for recording $recordingId: $e");
        // Optionally show a snackbar to the user that file deletion failed
      }

      // Then, delete the entry from Hive
      await recordingsBox.delete(recordingId);

      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: '"${entry.displayName}" deleted.',
          leadingIcon: Icons.delete_sweep_rounded,
        );
        // No need to call setState, ValueListenableBuilder will handle it
      }
    }
  }

  void _renameRecording(RecordingEntry entry, String newName) async {
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    entry.displayName = newName;
    await box.put(entry.id, entry);
    if (mounted) {
      // No need for setState, ValueListenableBuilder will handle it
      showCustomSnackBar(
        context: context,
        message: 'Recording renamed to "$newName".',
        leadingIcon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green,
      );
    }
  }

  void _editRecordingCategory(RecordingEntry entry) async {
    final box = Hive.box<CustomCategory>(customCategoriesBoxName);
    final allCategories = _getAllCategories(box);

    final selectedCategoryData =
        await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          builder: (context) => CategorySelectorWidget(
            predefinedCategories: _predefinedCategories,
            isRecording: _isRecording,

            onCategorySelected: (categoryData) {
              Navigator.pop(context, categoryData);
            },
          ),
        );

    if (selectedCategoryData != null && mounted) {
      final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
      entry.moodName = selectedCategoryData['name'];
      entry.moodColor = selectedCategoryData['color'];
      entry.moodIconColor = selectedCategoryData['iconColor'];
      entry.moodEmoji = selectedCategoryData['emoji'];
      await recordingsBox.put(entry.id, entry);

      showCustomSnackBar(
        context: context,
        message: 'Category updated for "${entry.displayName}".',
        leadingIcon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green,
      );
      // No need for setState, ValueListenableBuilder will handle it
    }
  }

  String _generateSummaryPreview(String fullText, {int maxLength = 100}) {
    if (fullText.isEmpty) return "";
    return fullText.length <= maxLength
        ? fullText
        : '${fullText.substring(0, maxLength)}...';
  }

  Future<void> _transcribeWithLemonFox(RecordingEntry entry) async {
    await _stopPlaybackAndResetState(); // Stop playback before transcribing
    final transcriptionStatus = Provider.of<TranscriptionStatusProvider>(
      context,
      listen: false,
    );
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

    transcriptionStatus.startTranscription(entry.id);
    try {
      // Simulate progress: Preparing
      transcriptionStatus.updateProgress(0.1, 'Preparing to transcribe...');
      await Future.delayed(const Duration(milliseconds: 600));
      // Simulate progress: Detecting language
      transcriptionStatus.updateProgress(0.3, 'Detecting language...');
      await Future.delayed(const Duration(milliseconds: 900));
      // Simulate progress: Transcribing
      transcriptionStatus.updateProgress(0.6, 'Transcribing...');
      await Future.delayed(const Duration(milliseconds: 1200));
      // Actually send the request
      final Uri apiUri = Uri.parse(
        "https://api.lemonfox.ai/v1/audio/transcriptions",
      );
      var request = http.MultipartRequest('POST', apiUri);
      request.headers['Authorization'] = 'Bearer $_lemonFoxApiKey';
      request.files.add(
        await http.MultipartFile.fromPath('file', entry.filePath),
      );
      request.fields['response_format'] = 'json';
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        transcriptionStatus.updateProgress(0.95, 'Finalizing transcription...');
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? transcriptText = responseData['text'];
        if (transcriptText != null) {
          final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
          entry.transcription = transcriptText;
          await recordingsBox.put(entry.id, entry);
          transcriptionStatus.finishTranscription();
          showCustomSnackBar(
            context: context,
            message: 'Transcription complete!',
            iconColor: Colors.green,
          );
        } else {
          transcriptionStatus.failTranscription(
            'Transcription text not found.',
          );
          throw Exception('Transcription text not found.');
        }
      } else {
        String errorMessage = "Error ${response.statusCode}";
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage += "\n${errorData['error'] ?? 'Unknown error'}";
          errorMessage += (errorData['detail'] != null
              ? errorData['detail']
              : (errorData['message'] != null
                    ? errorData['message']
                    : response.body));
        } catch (_) {
          errorMessage += "\n${response.body}";
        }
        transcriptionStatus.failTranscription(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      transcriptionStatus.failTranscription(
        'Lemonfox transcription failed: $e',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lemonfox transcription failed: $e')),
      );
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
    // Check if password is set before moving
    final hasPassword = await _passwordService.hasPassword();
    if (!hasPassword) {
      // Prompt user to set password first
      showCustomSnackBar(
        context: context,
        message: 'Set up a vault password before moving recordings.',
        iconColor: Colors.orange,
        duration: const Duration(seconds: 3),
      );
      // Optionally, open the password setup dialog here
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => CreatePasswordDialog(
          passwordService: _passwordService,
          onPasswordSet: (bool passwordCreated) {
            if (passwordCreated && mounted) {
              showCustomSnackBar(
                context: context,
                message: "Password set! Now move your recording to the vault.",
                iconColor: Colors.green,
                duration: const Duration(seconds: 3),
              );
            }
          },
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
    try {
      final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
      // Always encrypt with a new unique .enc file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'echolog_${DateTime.now().millisecondsSinceEpoch}_${entryToMove.id}.aac.enc';
      final encryptedPath = '${directory.path}/$fileName';
      debugPrint(
        '[Vault] Encrypting file: ${entryToMove.filePath} -> $encryptedPath',
      );
      await SecurityService().encryptFile(entryToMove.filePath, encryptedPath);
      await File(entryToMove.filePath).delete(); // Remove unencrypted file
      // Create a copy of the entry with the encrypted file path
      final entryCopy = RecordingEntry(
        id: entryToMove.id,
        filePath: encryptedPath,
        displayName: entryToMove.displayName,
        duration: entryToMove.duration,
        dateRecorded: entryToMove.dateRecorded,
        moodName: entryToMove.moodName,
        moodColor: entryToMove.moodColor,
        moodIconColor: entryToMove.moodIconColor,
        moodEmoji: entryToMove.moodEmoji,
        transcription: entryToMove.transcription,
        waveformPoints: entryToMove.waveformPoints,
        summaryPreview: entryToMove.summaryPreview,
        isPlaying: false,
      );
      await hiddenBox.put(entryToMove.id, entryCopy); // Save copy to vault
      await recordingsBox.delete(entryToMove.id); // Then remove from main box
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
      waveformPoints: waveformPoints,
      // Save generated waveform
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
          player: _player,
          // Pass player for preview functionality in dialog
          isPlayerInitialized: _isPlayerInitialized,
          // Pass player status
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
    if (_isRecording) {
      return; // Don't change category while recording
    }

    // Animate out, set greeting, then animate in
    await _greetingAnimController.reverse();
    setState(() {
      _selectedCategoryData = category;
      if (category != null) {
        final name = category['name'] as String? ?? '';
        final emoji = category['emoji'] as String? ?? '';
        _currentGreeting = DynamicGreetingService.getMoodAwareGreeting(
          name,
          emoji: emoji,
        );
      } else {
        _currentGreeting = null; // Fall back to default greeting
      }
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
            setState(() => _currentFilters = updatedFilters as FilterState),
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

  Widget _buildRecordingPlayPauseButton(RecordingEntry entry) {
    final isPlaying =
        _currentlyPlayingFileIdNotifier.value == entry.id &&
        (_player?.isPlaying ?? false);
    // Use the mood color for the play/pause icon if available, else fallback to primary
    final Color moodColor = entry.moodColor is Color
        ? entry.moodColor
        : Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: moodColor,
            size: 32,
          ),
          onPressed: () => _togglePlayRecordingItem(entry, [entry]),
          tooltip: isPlaying ? 'Pause' : 'Play',
        ),
        if (isPlaying)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              'Playing',
              style: TextStyle(color: moodColor, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  void _handleStartOrStopRecording() {
    _startOrStopRecording();
  }

  // Helper to safely get category name
  String _safeCategoryName(Map<String, dynamic>? category) {
    if (category == null) return '';
    final name = category['name'];
    return (name is String && name.trim().isNotEmpty) ? name : '';
  }

  // Helper to safely get category emoji
  String _safeCategoryEmoji(Map<String, dynamic>? category) {
    if (category == null) return '';
    final emoji = category['emoji'];
    return (emoji is String && emoji.trim().isNotEmpty) ? emoji : '';
  }

  // Helper to safely get category color
  Color _safeCategoryColor(Map<String, dynamic>? category) {
    if (category == null) return Colors.grey;
    final color = category['color'];
    return (color is Color) ? color : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Format date components
    final dayOfWeek = DateFormat('EEEE').format(now);
    final monthDay = DateFormat('MMMM d').format(now);
    final year = DateFormat('y').format(now);

    Widget mainScaffoldContent = Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(context),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
        child: ValueListenableBuilder<Box<CustomCategory>>(
          valueListenable: Hive.box<CustomCategory>(
            customCategoriesBoxName,
          ).listenable(),
          builder: (context, customCategoryBox, _) {
            final allDisplayCategories = _getAllCategories(customCategoryBox);
            final bool isAudioPlaying =
                _currentlyPlayingFileIdNotifier.value != null &&
                (_player?.isPlaying ?? false);

            Map<String, dynamic>? controlsCategoryData = _selectedCategoryData;
            if (_currentlyPlayingEntry != null) {
              controlsCategoryData = {
                'name': _currentlyPlayingEntry!.moodName,
                'emoji': _currentlyPlayingEntry!.moodEmoji,
                'color': _currentlyPlayingEntry!.moodColor,
                'iconColor': _currentlyPlayingEntry!.moodIconColor,
              };
            }

            // Use safe helpers for greeting display
            final greetingText =
                _currentGreeting ?? _cachedDynamicGreeting ?? '';
            final safeCategoryName = _safeCategoryName(_selectedCategoryData);
            final safeCategoryEmoji = _safeCategoryEmoji(_selectedCategoryData);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Enhanced Date Display Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Main date display
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayOfWeek,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onBackground.withOpacity(
                                0.7,
                              ),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            monthDay,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // Elegant calendar icon with subtle background
                      GestureDetector(
                        onTap: () {
                          // Get all recording dates for streak calculation
                          final recordingDates =
                              Hive.box<RecordingEntry>(recordingsBoxName).values
                                  .map(
                                    (entry) => DateTime(
                                      entry.dateRecorded.year,
                                      entry.dateRecorded.month,
                                      entry.dateRecorded.day,
                                    ),
                                  )
                                  .toList();

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  CalendarPage(recordingDates: recordingDates),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                year,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtle divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        theme.colorScheme.onBackground.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Greeting section with better spacing
                Center(
                  child: SizedBox(
                    height: 110, // Increased height for dynamic title
                    child: FadeTransition(
                      opacity: _greetingFadeAnim,
                      child: Center(
                        child: Text(
                          greetingText.isNotEmpty
                              ? greetingText
                              : (safeCategoryEmoji.isNotEmpty ||
                                        safeCategoryName.isNotEmpty
                                    ? '${safeCategoryEmoji.isNotEmpty ? safeCategoryEmoji + ' ' : ''}${safeCategoryName}'
                                    : ''),
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
                const SizedBox(height: 16), // Reduced space after dynamic title
                CategorySelectorWidget(
                  predefinedCategories: _predefinedCategories,
                  selectedCategoryData: _selectedCategoryData,
                  isRecording: _isRecording,
                  onCategorySelected: _onCategorySelected,
                ),
                const SizedBox(height: 24), // Reduced space after category tags
                // Main recording controls - centered and prominent
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RecordingControlsWidget(
                        waveformColor: Colors.red,
                        isRecording: _isRecording,
                        isRecordingPaused: _isRecordingPaused,
                        recordingDuration: _recordingDuration,
                        selectedCategoryData:
                            controlsCategoryData ??
                            {
                              'name': 'Category',
                              'emoji': '',
                              'color': Colors.grey,
                              'iconColor': Colors.grey.shade200,
                            },
                        isRecorderInitialized: _isRecorderInitialized,
                        // Use a theme-adaptive color for the record icon
                        recordIconColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        onStartStopRecording:
                            (_selectedCategoryData == null ||
                                (_player?.isPlaying ?? false))
                            ? () {}
                            : _handleStartOrStopRecording,
                        onTogglePausePlayRecording: _togglePausePlayRecording,
                      ),
                      if (_selectedCategoryData == null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10.0,
                          ), // Reduced space
                          child: Text(
                            'Choose a topic to start recording',
                            style: GoogleFonts.poppins(
                              color: theme.colorScheme.onBackground.withOpacity(
                                0.6,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 24,
                ), // Reduced space before Play Latest button
                // Recording stats and quick actions section
                // Recording stats and navigation section
                Expanded(
                  child: ValueListenableBuilder<Box<RecordingEntry>>(
                    valueListenable: Hive.box<RecordingEntry>(
                      recordingsBoxName,
                    ).listenable(),
                    builder: (context, box, _) {
                      final allRecordings = box.values.toList()
                        ..sort(
                          (a, b) => b.dateRecorded.compareTo(a.dateRecorded),
                        );

                      final todayRecordings = allRecordings.where((recording) {
                        final recordingDate = recording.dateRecorded;
                        final today = DateTime.now();
                        return recordingDate.year == today.year &&
                            recordingDate.month == today.month &&
                            recordingDate.day == today.day;
                      }).length;

                      final totalRecordings = allRecordings.length;
                      final totalDuration = allRecordings.fold<Duration>(
                        Duration.zero,
                        (sum, recording) => sum + recording.duration,
                      );

                      return Column(
                        children: [
                          // Quick play button (only show if there are recordings)
                          if (allRecordings.isNotEmpty) ...[
                            ValueListenableBuilder<String?>(
                              valueListenable: _currentlyPlayingFileIdNotifier,
                              builder: (context, currentlyPlayingId, _) {
                                final mostRecent = allRecordings.first;
                                final isPlaying =
                                    currentlyPlayingId == mostRecent.id &&
                                    (_player?.isPlaying ?? false);
                                return GestureDetector(
                                  onTap: () async {
                                    // Defensive: check file exists
                                    if (mostRecent.filePath.isEmpty) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Recording file path is missing.',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    final file = File(mostRecent.filePath);
                                    if (!await file.exists()) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Recording file not found.',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    // Use the correct toggle logic for play/pause
                                    await _togglePlayRecordingItem(mostRecent, [
                                      mostRecent,
                                    ]);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPlaying
                                                    ? Icons.pause_circle_filled
                                                    : Icons.play_circle_filled,
                                                color:
                                                    theme.colorScheme.primary,
                                                size: 28,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  isPlaying
                                                      ? 'Pause Latest'
                                                      : 'Play Latest',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Navigation card
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecordingsListPage(
                                    allRecordings: allRecordings,
                                    onRecordingToggled: (entry) =>
                                        _togglePlayRecordingItem(
                                          entry,
                                          allRecordings,
                                          playbackContext: 'list',
                                        ),
                                    playbackProgress: _currentPlaybackProgress,
                                    totalDuration: _currentTotalDuration,
                                    currentlyPlayingFileIdNotifier:
                                        _currentlyPlayingFileIdNotifier,
                                    isActuallyPlayingNotifier:
                                        _isActuallyPlayingNotifier,
                                    onSeekRequest: _handleSeek,
                                    onDelete: _handleDismissRecording,
                                    onShareFile: _shareRecordingFile,
                                    onShareTranscription:
                                        _shareTranscriptionText,
                                    onRename: _renameRecording,
                                    onEditCategory: _editRecordingCategory,
                                    onToggleHidden: _moveToVault,
                                    onGenerateTranscription:
                                        _transcribeWithLemonFox,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                10,
                                20,
                                8,
                              ), // Increased bottom padding to prevent overflow
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.transparent,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  // Main shadow
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                  // Light reflection effect
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.8),
                                    blurRadius: 1,
                                    offset: const Offset(0, -0.5),
                                  ),
                                ],
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.surface,
                                    theme.colorScheme.surface.withOpacity(0.95),
                                  ],
                                  stops: const [0.0, 1.0],
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon container with subtle glow
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.2),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.queue_music_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 24,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Text content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'View All Recordings',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                theme.colorScheme.onBackground,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          totalRecordings > 0
                                              ? 'Browse through $totalRecordings recordings'
                                              : 'No recordings yet',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow indicator
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: theme.colorScheme.onBackground
                                        .withOpacity(0.4),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );

    // Stack with transcription overlay
    return Stack(
      children: [
        if (_selectedMethod == HiddenAccessTriggerMethod.pinchInScreen ||
            _selectedMethod == HiddenAccessTriggerMethod.pinchOutScreen)
          GestureDetector(
            onScaleStart: _isGestureAccessActive
                ? null
                : _handleScreenScaleStart,
            onScaleUpdate: _isGestureAccessActive
                ? null
                : _handleScreenScaleUpdate,
            onScaleEnd: _isGestureAccessActive ? null : _handleScreenScaleEnd,
            behavior: HitTestBehavior.opaque,
            child: mainScaffoldContent,
          )
        else
          mainScaffoldContent,
        // Overlay the progress bar at the bottom if transcribing
        Consumer<TranscriptionStatusProvider>(
          builder: (context, transcriptionStatus, _) {
            if (!transcriptionStatus.isTranscribing) return SizedBox.shrink();
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TranscriptionProgressBar(
                progress: transcriptionStatus.progress,
                statusText: transcriptionStatus.statusText,
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
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

enum HiddenAccessTriggerMethod {
  longPressAppBar,
  tripleTapAppBar,
  pinchInScreen,
  pinchOutScreen,
}
