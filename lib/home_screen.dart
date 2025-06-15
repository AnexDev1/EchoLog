import 'dart:convert';

import 'package:echolog/services/recording_service.dart';
import 'package:echolog/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart'; // Added for Provider
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/models/filter_state.dart';
import 'package:echolog/models/custom_category.dart';
import 'package:echolog/widgets/category_selector_widget.dart';
import 'package:echolog/widgets/recording_controls_widget.dart';
import 'package:echolog/widgets/save_recording_dialog.dart';
import 'package:echolog/widgets/filter_bottom_sheet_widget.dart';
import 'package:echolog/utils/custom_snackbar.dart';
import 'package:echolog/main.dart'; // For recordingsBoxName and customCategoriesBoxName
import 'package:echolog/widgets/recordings_list_view.dart';

import 'package:echolog/services/password_service.dart';
import 'package:echolog/widgets/create_password_dialog.dart';
import 'package:echolog/widgets/enter_password_dialog.dart';
import 'package:echolog/hidden_recordings_screen.dart';
import 'package:echolog/providers/playback_provider.dart'; // Import PlaybackProvider

// Key for SharedPreferences
const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';
final String _lemonFoxApiKey = "Sf8cPZsgkaVohAnV31DxsiSO9QiIiqbj";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedCategoryData;
  bool _isTranscribingLemonFox = false;

  final List<Map<String, dynamic>> _predefinedCategories = [
    {
      'name': 'Vent',
      'emoji': '😤',
      'color': Colors.red.shade300,
      'iconColor': Colors.red.shade100,
      'isCustom': false,
      'id': 'Vent',
    },
    {
      'name': 'Random Talk',
      'emoji': '💬',
      'color': Colors.blue.shade300,
      'iconColor': Colors.blue.shade100,
      'isCustom': false,
      'id': 'Random Talk',
    },
    {
      'name': 'Brainstorm',
      'emoji': '💡',
      'color': Colors.green.shade300,
      'iconColor': Colors.green.shade100,
      'isCustom': false,
      'id': 'Brainstorm',
    },
    {
      'name': 'Gratitude',
      'emoji': '🙏',
      'color': Colors.orange.shade300,
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
  String? _currentlyPlayingFileId; // This will be managed for UI feedback
  FilterState _currentFilters = FilterState();
  final PasswordService _passwordService = PasswordService();
  HiddenAccessTriggerMethod _selectedMethod =
      HiddenAccessTriggerMethod.longPressAppBar;
  bool _isGestureAccessActive = false;
  int _tapCount = 0;
  Timer? _tapTimer;
  final int _tripleTapMilliseconds = 500;

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
  }

  // --- Playback from Provider ---
  Future<void> _playRecordingFromProviderOrWidget(RecordingEntry entry) async {
    if (!_isPlayerInitialized || _player == null) {
      showCustomSnackBar(
        context: context,
        message: 'Player not ready.',
        leadingIcon: Icons.play_disabled_rounded,
        duration: const Duration(seconds: 3),
      );
      Provider.of<PlaybackProvider>(
        context,
        listen: false,
      ).clearPlaybackRequest();
      return;
    }

    final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);

    // Stop any currently playing track
    if (_player!.isPlaying) {
      await _player!.stopPlayer();
      if (_currentlyPlayingFileId != null) {
        final previousEntry = recordingsBox.get(_currentlyPlayingFileId);
        if (previousEntry != null) {
          previousEntry.isPlaying = false;
          await recordingsBox.put(_currentlyPlayingFileId!, previousEntry);
        }
      }
      if (mounted) {
        setState(() {
          _currentlyPlayingFileId = null; // Clear current playing ID
        });
      }
    }

    // Check if the file exists
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
      Provider.of<PlaybackProvider>(
        context,
        listen: false,
      ).clearPlaybackRequest();
      return;
    }

    // Start playing the new entry
    try {
      print(
        "[HomeScreen] Attempting to play from provider: ${entry.displayName} at ${entry.filePath}",
      );
      await _player!.startPlayer(
        fromURI: entry.filePath,
        codec: Codec.aacADTS, // Ensure this matches your recording codec
        whenFinished: () {
          if (mounted) {
            final currentEntry = recordingsBox.get(entry.id);
            if (currentEntry != null) {
              currentEntry.isPlaying = false;
              recordingsBox.put(entry.id, currentEntry); // Update Hive
            }
            setState(() {
              if (_currentlyPlayingFileId == entry.id) {
                _currentlyPlayingFileId = null;
              }
            });
            print("[HomeScreen] Playback finished for: ${entry.displayName}");
          }
        },
      );

      // Update state and Hive for the newly playing entry
      entry.isPlaying = true;
      await recordingsBox.put(entry.id, entry);
      if (mounted) {
        setState(() {
          _currentlyPlayingFileId = entry.id;
        });
      }
      print("[HomeScreen] Now playing from provider: ${entry.displayName}");
    } catch (e) {
      print("[HomeScreen] Error playing recording from provider: $e");
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Error playing recording.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
        );
        entry.isPlaying = false; // Ensure isPlaying is false on error
        await recordingsBox.put(entry.id, entry);
        setState(() {
          if (_currentlyPlayingFileId == entry.id) {
            _currentlyPlayingFileId = null;
          }
        });
      }
    } finally {
      // Clear the request from provider after attempting to play
      Provider.of<PlaybackProvider>(
        context,
        listen: false,
      ).clearPlaybackRequest();
    }
  }
  // --- End Playback from Provider ---

  Future<void> _shareRecordingFile(RecordingEntry entry) async {
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
    if (_player != null &&
        _isPlayerInitialized &&
        _currentlyPlayingFileId == entry.id &&
        (_player!.isPlaying || _player!.isPaused)) {
      await _player!.stopPlayer();
      if (mounted) {
        setState(() => _currentlyPlayingFileId = null);
        final box = Hive.box<RecordingEntry>(recordingsBoxName);
        final currentEntry = box.get(entry.id);
        if (currentEntry != null) {
          currentEntry.isPlaying = false;
          box.put(entry.id, currentEntry);
        }
      }
      await Future.delayed(const Duration(milliseconds: 200));
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
    final theme = Theme.of(context);
    final bool hasTranscription =
        entry.transcription != null && entry.transcription!.trim().isNotEmpty;
    if (_player != null &&
        _isPlayerInitialized &&
        _currentlyPlayingFileId == entry.id &&
        (_player!.isPlaying || _player!.isPaused)) {
      await _player!.stopPlayer();
      if (mounted) {
        setState(() => _currentlyPlayingFileId = null);
        final box = Hive.box<RecordingEntry>(recordingsBoxName);
        final currentEntry = box.get(entry.id);
        if (currentEntry != null) {
          currentEntry.isPlaying = false;
          box.put(entry.id, currentEntry);
        }
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
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

  Future<void> _transcribeWithLemonFox(RecordingEntry entry) async {
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
    if (_player != null &&
        _currentlyPlayingFileId == entry.id &&
        (_player!.isPlaying || _player!.isPaused)) {
      await _player!.stopPlayer();
      if (mounted) {
        setState(() => _currentlyPlayingFileId = null);
        final box = Hive.box<RecordingEntry>(recordingsBoxName);
        final currentEntry = box.get(entry.id);
        if (currentEntry != null) {
          currentEntry.isPlaying = false;
          box.put(entry.id, currentEntry);
        }
      }
    }
    setState(() => _isTranscribingLemonFox = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transcribing "${entry.displayName}" with Lemonfox...'),
      ),
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
      request.fields['response_format'] = 'json';
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? transcriptText = responseData['text'];
        if (transcriptText != null) {
          final box = Hive.box<RecordingEntry>(recordingsBoxName);
          entry.transcription = transcriptText;
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
    if (entryToMove.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Recording has no ID and cannot be moved.'),
        ),
      );
      return;
    }
    final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
    final hiddenRecordingsBox = Hive.box<RecordingEntry>(
      hiddenRecordingsBoxName,
    );
    if (hiddenRecordingsBox.containsKey(entryToMove.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${entryToMove.displayName}" is already in the vault.',
          ),
        ),
      );
      return;
    }
    if (_currentlyPlayingFileId == entryToMove.id &&
        _player != null &&
        _player!.isPlaying) {
      await _player!.stopPlayer();
      if (mounted) setState(() => _currentlyPlayingFileId = null);
    }
    final RecordingEntry entryForVault = RecordingEntry(
      id: entryToMove.id,
      filePath: entryToMove.filePath,
      displayName: entryToMove.displayName,
      duration: entryToMove.duration,
      dateRecorded: entryToMove.dateRecorded,
      moodName: entryToMove.moodName,
      moodColor: entryToMove.moodColor,
      moodEmoji: entryToMove.moodEmoji,
      moodIconColor: entryToMove.moodIconColor,
    );
    entryForVault.isPlaying = false;
    try {
      await hiddenRecordingsBox.put(entryForVault.id, entryForVault);
      await recordingsBox.delete(entryToMove.id);
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

  Future<void> _initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted)
        throw RecordingPermissionException('Microphone permission not granted');
      await _recorder!.openRecorder();
      if (mounted) setState(() => _isRecorderInitialized = true);
    } catch (e) {
      print('Error initializing recorder: $e');
      if (mounted) {
        setState(() => _isRecorderInitialized = false);
        showCustomSnackBar(
          context: context,
          message: 'Recorder initialization failed.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _player!.openPlayer();
      _player!.setSubscriptionDuration(
        const Duration(milliseconds: 500),
      ); // For progress updates if needed by UI
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
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _tapTimer?.cancel();
    _recorder?.closeRecorder().catchError(
      (e) => print("Error closing recorder: $e"),
    );
    _recorder = null;
    _player?.closePlayer().catchError((e) => print("Error closing player: $e"));
    _player = null;
    super.dispose();
  }

  Future<void> _loadHiddenAccessPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final methodName = prefs.getString(PREF_HIDDEN_ACCESS_METHOD);
    HiddenAccessTriggerMethod loadedMethod =
        HiddenAccessTriggerMethod.longPressAppBar;
    if (methodName != null) {
      try {
        loadedMethod = HiddenAccessTriggerMethod.values.firstWhere(
          (e) => e.toString() == methodName,
          orElse: () => HiddenAccessTriggerMethod.longPressAppBar,
        );
      } catch (e) {
        loadedMethod = HiddenAccessTriggerMethod.longPressAppBar;
      }
    }
    if (!HiddenAccessTriggerMethod.values.contains(loadedMethod))
      loadedMethod = HiddenAccessTriggerMethod.longPressAppBar;
    if (mounted && _selectedMethod != loadedMethod)
      setState(() => _selectedMethod = loadedMethod);
    else if (!mounted && _selectedMethod != loadedMethod)
      _selectedMethod = loadedMethod;
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
          if (mounted && _selectedCategoryData != null)
            _showSaveRecordingDialog(
              path,
              _recordingDuration,
              _selectedCategoryData!,
            );
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

  void _togglePausePlayRecording() {
    if (!_isRecording || _recorder == null || !_isRecorderInitialized) return;
    if (_recorder!.isPaused)
      _recorder!.resumeRecorder();
    else
      _recorder!.pauseRecorder();
    setState(() => _isRecordingPaused = _recorder!.isPaused);
  }

  void _handleSaveRecording(
    String displayName,
    String filePath,
    Duration duration,
    Map<String, dynamic> categoryData,
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
    );
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    await box.put(newEntry.id, newEntry);
    try {
      // Call the function that's responsible for telling the native side to update.
      // Pass the newly saved entry if the function is designed to take it,
      // otherwise, it can fetch the latest itself.
      await updateWidgetWithRecentRecording(recentEntry: newEntry);
      print(
        "[HomeScreen] Called updateWidgetWithRecentRecording after saving.",
      );
    } catch (e) {
      print("[HomeScreen] Error calling updateWidgetWithRecentRecording: $e");
    }
    if (mounted)
      showCustomSnackBar(
        context: context,
        message: '"${newEntry.displayName}" saved!',
        leadingIcon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green.shade400,
        duration: const Duration(seconds: 3),
      );
  }

  void _handleDiscardRecording() {
    if (mounted)
      showCustomSnackBar(
        context: context,
        message: 'Recording discarded.',
        leadingIcon: Icons.delete_outline_rounded,
        duration: const Duration(seconds: 2),
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
      builder: (BuildContext context) => SaveRecordingDialog(
        filePath: filePath,
        duration: duration,
        categoryData: categoryData,
        player: _player,
        isPlayerInitialized: _isPlayerInitialized,
        onSave: _handleSaveRecording,
        onDiscard: _handleDiscardRecording,
      ),
    );
    if (mounted) setState(() => _recordingDuration = Duration.zero);
  }

  Future<void> _togglePlayRecordingItem(
    RecordingEntry entry,
    List<RecordingEntry>
    currentList /* This list is from ValueListenableBuilder, might be stale if not careful */,
  ) async {
    if (!_isPlayerInitialized || _player == null) {
      showCustomSnackBar(
        context: context,
        message: 'Player not ready.',
        leadingIcon: Icons.play_disabled_rounded,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final recordingsBox = Hive.box<RecordingEntry>(recordingsBoxName);
    final bool wasCurrentlyPlayingThisEntry =
        _currentlyPlayingFileId == entry.id &&
        entry.isPlaying; // Use entry.isPlaying from the passed entry

    // Stop current playback if any
    if (_player!.isPlaying) {
      await _player!.stopPlayer();
      if (_currentlyPlayingFileId != null) {
        final previousEntryFromBox = recordingsBox.get(_currentlyPlayingFileId);
        if (previousEntryFromBox != null && previousEntryFromBox.isPlaying) {
          previousEntryFromBox.isPlaying = false;
          await recordingsBox.put(
            _currentlyPlayingFileId!,
            previousEntryFromBox,
          );
        }
      }
      // If the stopped player was playing the entry we are about to toggle,
      // its isPlaying status will be handled by the logic below.
      // If it was a different entry, its isPlaying status is now false in Hive.
    }
    if (mounted) {
      // Update UI immediately after stopping
      setState(() {
        // If the stopped player was not the current entry, _currentlyPlayingFileId is cleared.
        // If it was the current entry, it will be set again if playback restarts.
        if (_currentlyPlayingFileId != entry.id ||
            !wasCurrentlyPlayingThisEntry) {
          _currentlyPlayingFileId = null;
        }
      });
    }

    if (wasCurrentlyPlayingThisEntry) {
      // If it was playing this entry, we just stopped it. Update Hive.
      entry.isPlaying = false;
      await recordingsBox.put(entry.id, entry);
      if (mounted) {
        setState(() {
          _currentlyPlayingFileId = null;
        });
      }
    } else {
      // Start playing the selected entry
      try {
        await _player!.startPlayer(
          fromURI: entry.filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            if (mounted) {
              final finishedEntry = recordingsBox.get(entry.id);
              if (finishedEntry != null) {
                finishedEntry.isPlaying = false;
                recordingsBox.put(entry.id, finishedEntry);
              }
              setState(() {
                if (_currentlyPlayingFileId == entry.id) {
                  _currentlyPlayingFileId = null;
                }
              });
            }
          },
        );
        entry.isPlaying = true;
        await recordingsBox.put(entry.id, entry);
        if (mounted) {
          setState(() {
            _currentlyPlayingFileId = entry.id;
          });
        }
      } catch (e) {
        print("Error playing recording item: $e");
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Error playing recording.',
            leadingIcon: Icons.error_outline_rounded,
            iconColor: Theme.of(context).colorScheme.error,
          );
          entry.isPlaying = false; // Ensure isPlaying is false on error
          await recordingsBox.put(entry.id, entry);
          setState(() {
            if (_currentlyPlayingFileId == entry.id) {
              _currentlyPlayingFileId = null;
            }
          });
        }
      }
    }
  }

  void _onCategorySelected(Map<String, dynamic>? category) {
    if (_isRecording) return;
    setState(() => _selectedCategoryData = category);
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
        initialFilters: _currentFilters,
        categories: allCategoriesForFilter,
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

  void _handleDismissRecording(RecordingEntry entry) {
    final theme = Theme.of(context);
    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    final String deletedFilePath = entry.filePath;
    box.delete(entry.id);
    if (_currentlyPlayingFileId == entry.id &&
        _player != null &&
        _player!.isPlaying) {
      _player!.stopPlayer().then((_) {
        if (mounted) setState(() => _currentlyPlayingFileId = null);
      });
    }
    showCustomSnackBar(
      context: context,
      message: '"${entry.displayName}" deleted.',
      actionLabel: 'UNDO',
      onActionPressed: () => box.put(entry.id, entry),
      duration: const Duration(seconds: 4),
      leadingIcon: Icons.delete_forever_rounded,
      iconColor: theme.colorScheme.secondary,
    ).closed.then((reason) {
      if (reason != SnackBarClosedReason.action && !box.containsKey(entry.id))
        _deleteRecordingFile(deletedFilePath);
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
        currentScale < 0.7)
      _triggerHiddenScreenAccess();
    else if (_selectedMethod == HiddenAccessTriggerMethod.pinchOutScreen &&
        currentScale > 1.5)
      _triggerHiddenScreenAccess();
  }

  void _handleScreenScaleEnd(ScaleEndDetails details) {
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    Widget appBarWidget = AppBar(
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
            _loadHiddenAccessPreference();
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

    // Consumer for PlaybackProvider
    Widget mainScaffoldContent = Consumer<PlaybackProvider>(
      builder: (context, playbackProvider, child) {
        final recordingToPlayFromWidget = playbackProvider.recordingToPlay;
        final shouldPlayImmediately = playbackProvider.playImmediately;

        if (recordingToPlayFromWidget != null && shouldPlayImmediately) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                playbackProvider.recordingToPlay ==
                    recordingToPlayFromWidget && // Check again
                playbackProvider.playImmediately) {
              _playRecordingFromProviderOrWidget(recordingToPlayFromWidget);
            }
          });
        }

        // Original Scaffold content
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: _buildAppBar(context),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValueListenableBuilder<Box<CustomCategory>>(
              valueListenable: Hive.box<CustomCategory>(
                customCategoriesBoxName,
              ).listenable(),
              builder: (context, customCategoryBox, _) {
                final allDisplayCategories = _getAllCategories(
                  customCategoryBox,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Text(
                        'How are you doing?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onBackground,
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
                    const SizedBox(height: 40),
                    Center(
                      child: RecordingControlsWidget(
                        isRecording: _isRecording,
                        isRecordingPaused: _isRecordingPaused,
                        recordingDuration: _recordingDuration,
                        selectedCategoryData: _selectedCategoryData,
                        isRecorderInitialized: _isRecorderInitialized,
                        onStartStopRecording: _startOrStopRecording,
                        onTogglePausePlayRecording: _togglePausePlayRecording,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Recordings',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _currentFilters.isAnyFilterActive
                                  ? Icons.filter_alt_rounded
                                  : Icons.filter_alt_off_outlined,
                              color: _currentFilters.isAnyFilterActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onBackground.withOpacity(
                                      0.7,
                                    ),
                            ),
                            tooltip: 'Filter Recordings',
                            onPressed: () =>
                                _showAdvancedFilterSheet(allDisplayCategories),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: RecordingsListView(
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
                      ),
                    ),
                  ],
                );
              },
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
        behavior: HitTestBehavior
            .opaque, // Ensures gestures are caught over the whole area
        child: mainScaffoldContent,
      );
    } else {
      return mainScaffoldContent;
    }
  }
}
