import 'package:echolog/main.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/screens/home/widgets/category_selector_widget.dart';
import 'package:echolog/services/password_service.dart';
import 'package:echolog/utils/custom_snackbar.dart';
import 'package:echolog/widgets/dialogs/create_password_dialog.dart';
import 'package:echolog/widgets/dialogs/enter_password_dialog.dart';
import 'package:echolog/widgets/recording_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HiddenRecordingsScreen extends StatefulWidget {
  const HiddenRecordingsScreen({super.key});

  @override
  State<HiddenRecordingsScreen> createState() => _HiddenRecordingsScreenState();
}

class _HiddenRecordingsScreenState extends State<HiddenRecordingsScreen> {
  FlutterSoundPlayer? _player;
  bool _isPlayerInitialized = false;
  String? _currentlyPlayingFileId;
  bool _isPlayerActuallyPlaying = false;
  Duration _currentPlaybackProgress = Duration.zero;
  Duration _currentTotalDuration = Duration.zero;
  StreamSubscription? _playerSubscription;

  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  bool _isRecordingHidden = false;
  Duration _hiddenRecordingDuration = Duration.zero;
  Timer? _hiddenRecordingTimer;
  String? _currentHiddenRecordingPath;

  Map<String, dynamic>? _selectedCategoryDataForHidden;

  final PasswordService _passwordService = PasswordService();

  final String _lemonFoxApiKey = "Sf8cPZsgkaVohAnV31DxsiSO9QiIiqbj";
  bool _isTranscribing = false;

  final List<Map<String, dynamic>> _predefinedCategoriesForHidden = [
    {
      'name': 'Secret',
      'emoji': '🤫',
      'color': Colors.purple,
      'iconColor': Colors.purpleAccent,
      'isCustom': false,
      'id': 'Secret',
    },
    {
      'name': 'Private Thoughts',
      'emoji': '🤐',
      'color': Colors.teal,
      'iconColor': Colors.tealAccent,
      'isCustom': false,
      'id': 'Private Thoughts',
    },
    {
      'name': 'Ideas',
      'emoji': '💡',
      'color': Colors.indigo,
      'iconColor': Colors.indigoAccent,
      'isCustom': false,
      'id': 'Ideas',
    },
  ];

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _initializePlayer();
    _initializeHiddenRecorder();
    if (_predefinedCategoriesForHidden.isNotEmpty) {
      _selectedCategoryDataForHidden = _predefinedCategoriesForHidden.first;
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _player!.openPlayer();
      await _player!.setSubscriptionDuration(const Duration(milliseconds: 200));
      _playerSubscription = _player!.onProgress?.listen((e) {
        if (mounted && (_player?.isPlaying ?? false)) {
          setState(() {
            _currentPlaybackProgress = e.position;
            _currentTotalDuration = e.duration;
          });
        }
      });
      if (mounted) setState(() => _isPlayerInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _isPlayerInitialized = false);
    }
  }

  Future<void> _moveOutOfVault(RecordingEntry entry) async {
    final hiddenBox = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
    final mainBox = Hive.box<RecordingEntry>(
      recordingsBoxName,
    ); // Make sure this is your main box name

    // Remove from hidden
    await hiddenBox.delete(entry.id);

    // Add to main
    await mainBox.put(entry.id, entry);

    if (mounted) {
      showCustomSnackBar(
        context: context,
        message: '"${entry.displayName}" moved out of vault!',
        iconColor: Colors.green,
      );
    }
  }

  Future<void> _initializeHiddenRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted)
        throw RecordingPermissionException('Microphone permission not granted');
      await _recorder!.openRecorder();
      if (mounted) setState(() => _isRecorderInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _isRecorderInitialized = false);
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _player?.closePlayer();
    _player = null;
    _recorder?.closeRecorder();
    _recorder = null;
    _hiddenRecordingTimer?.cancel();
    super.dispose();
  }

  void _onHiddenCategorySelected(Map<String, dynamic>? category) {
    if (_isRecordingHidden) return;
    setState(() => _selectedCategoryDataForHidden = category);
  }

  Future<void> _stopPlaybackAndResetState() async {
    if (_player != null && (_player!.isPlaying || _player!.isPaused)) {
      await _player!.stopPlayer();
    }
    if (mounted) {
      setState(() {
        _currentlyPlayingFileId = null;
        _isPlayerActuallyPlaying = false;
        _currentPlaybackProgress = Duration.zero;
        _currentTotalDuration = Duration.zero;
      });
    }
  }

  Future<void> _togglePlayRecordingItem(RecordingEntry entry) async {
    if (!_isPlayerInitialized || _player == null) {
      if (mounted)
        showCustomSnackBar(context: context, message: 'Player not ready.');
      return;
    }
    final String entryId = entry.id;
    final bool isTargetEntryCurrentlyLoaded =
        _currentlyPlayingFileId == entryId;
    if (isTargetEntryCurrentlyLoaded && _player!.isPlaying) {
      // Pause
      await _player!.pausePlayer();
      if (mounted) setState(() => _isPlayerActuallyPlaying = false);
    } else if (isTargetEntryCurrentlyLoaded && _player!.isPaused) {
      // Resume
      await _player!.resumePlayer();
      if (mounted) setState(() => _isPlayerActuallyPlaying = true);
    } else {
      // Play new
      await _stopPlaybackAndResetState();
      final file = File(entry.filePath);
      if (!await file.exists()) {
        if (mounted)
          showCustomSnackBar(
            context: context,
            message: 'Recording file not found.',
          );
        return;
      }
      await _player!.startPlayer(
        fromURI: entry.filePath,
        codec: Codec.aacADTS,
        whenFinished: () {
          if (_currentlyPlayingFileId == entryId) _stopPlaybackAndResetState();
        },
      );
      if (mounted) {
        setState(() {
          _currentlyPlayingFileId = entryId;
          _isPlayerActuallyPlaying = true;
          _currentTotalDuration = entry.duration;
          _currentPlaybackProgress = Duration.zero;
        });
      }
    }
  }

  Future<void> _handleSeekRequest(double seekPercent) async {
    if (_player == null ||
        !_isPlayerInitialized ||
        _currentTotalDuration == Duration.zero)
      return;
    final seekPosition = Duration(
      milliseconds: (_currentTotalDuration.inMilliseconds * seekPercent)
          .round(),
    );
    try {
      await _player!.seekToPlayer(seekPosition);
      if (mounted) setState(() => _currentPlaybackProgress = seekPosition);
    } catch (_) {}
  }

  void _handleDismissHiddenRecording(RecordingEntry entry) async {
    final box = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
    final String deletedFilePath = entry.filePath;
    await box.delete(entry.id);
    if (_currentlyPlayingFileId == entry.id) await _stopPlaybackAndResetState();
    final file = File(deletedFilePath);
    if (await file.exists()) await file.delete();
    if (mounted)
      showCustomSnackBar(
        context: context,
        message: '"${entry.displayName}" deleted.',
      );
  }

  Future<void> _startOrStopHiddenRecording() async {
    if (!_isRecorderInitialized || _recorder == null) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Hidden recorder not ready.',
        );
      return;
    }
    if (_isRecordingHidden) {
      try {
        final path = await _recorder!.stopRecorder();
        _hiddenRecordingTimer?.cancel();
        if (path != null) {
          _currentHiddenRecordingPath = path;
          final String? recordingName = await _promptForRecordingName();
          if (recordingName == null || recordingName.isEmpty) {
            final tempFile = File(path);
            if (await tempFile.exists()) await tempFile.delete();
            if (mounted)
              showCustomSnackBar(
                context: context,
                message: "Hidden recording discarded.",
              );
            if (mounted) setState(() => _isRecordingHidden = false);
            return;
          }
          final categoryToSave =
              _selectedCategoryDataForHidden ??
              _predefinedCategoriesForHidden.first;
          final newEntry = RecordingEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            filePath: path,
            displayName: recordingName,
            duration: _hiddenRecordingDuration,
            dateRecorded: DateTime.now(),
            moodName: categoryToSave['name'] as String,
            moodColor: categoryToSave['color'] as Color,
            moodIconColor: categoryToSave['iconColor'] as Color,
            moodEmoji: categoryToSave['emoji'] as String? ?? '🤫',
            isPlaying: false,
            transcription: null,
          );
          final box = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
          await box.put(newEntry.id, newEntry);
          if (mounted) {
            showCustomSnackBar(
              context: context,
              message: '"$recordingName" saved.',
              iconColor: Colors.green,
            );
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isRecordingHidden = false);
      } finally {
        if (mounted) {
          setState(() {
            _isRecordingHidden = false;
            _hiddenRecordingDuration = Duration.zero;
          });
        }
      }
    } else {
      if (_selectedCategoryDataForHidden == null) {
        if (mounted)
          showCustomSnackBar(
            context: context,
            message: 'Please select a category.',
          );
        return;
      }
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'hidden_echolog_${DateTime.now().millisecondsSinceEpoch}.aac';
        _currentHiddenRecordingPath = '${directory.path}/$fileName';
        await _recorder!.startRecorder(
          toFile: _currentHiddenRecordingPath,
          codec: Codec.aacADTS,
        );
        if (mounted) {
          setState(() {
            _isRecordingHidden = true;
            _hiddenRecordingDuration = Duration.zero;
          });
        }
        _hiddenRecordingTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) {
          if (mounted) {
            setState(
              () => _hiddenRecordingDuration = Duration(
                seconds: _hiddenRecordingDuration.inSeconds + 1,
              ),
            );
          } else {
            timer.cancel();
          }
        });
      } catch (e) {
        if (mounted) setState(() => _isRecordingHidden = false);
      }
    }
  }

  Future<String?> _promptForRecordingName() async {
    final TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Name Your Hidden Recording', style: GoogleFonts.poppins()),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name (optional)',
            hintStyle: GoogleFonts.poppins(),
          ),
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.poppins()),
            onPressed: () => Navigator.of(context).pop(null),
          ),
          TextButton(
            child: Text('Save', style: GoogleFonts.poppins()),
            onPressed: () {
              Navigator.of(context).pop(
                nameController.text.trim().isNotEmpty
                    ? nameController.text.trim()
                    : "Hidden Note ${DateTime.now().toIso8601String().substring(11, 19)}",
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePin() async {
    bool? currentPinVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => EnterPasswordDialog(
        passwordService: _passwordService,
        onPasswordEntered: (bool _) {},
      ),
    );
    if (currentPinVerified == true) {
      if (!mounted) return;
      bool? newPinSet = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => CreatePasswordDialog(
          passwordService: _passwordService,
          onPasswordSet: (bool _) {},
        ),
      );
      if (newPinSet == true && mounted) {
        showCustomSnackBar(
          context: context,
          message: "PIN changed successfully!",
          iconColor: Colors.green,
        );
      } else if (mounted) {
        showCustomSnackBar(
          context: context,
          message: "PIN change cancelled or failed.",
          iconColor: Colors.orange,
        );
      }
    } else if (mounted && currentPinVerified == null) {
      showCustomSnackBar(
        context: context,
        message: "PIN verification cancelled.",
        iconColor: Colors.orange,
      );
    }
  }

  Future<void> _transcribeWithLemonFox(RecordingEntry entry) async {
    if (_lemonFoxApiKey == "YOUR_LEMONFOX_API_KEY" || _lemonFoxApiKey.isEmpty) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Lemonfox API Key not set.',
        );
      return;
    }
    if (entry.filePath.isEmpty || !await File(entry.filePath).exists()) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file not found.',
        );
      return;
    }
    if (_currentlyPlayingFileId == entry.id) {
      await _stopPlaybackAndResetState();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) setState(() => _isTranscribing = true);
    if (mounted)
      showCustomSnackBar(
        context: context,
        message: 'Transcribing "${entry.displayName}"...',
      );
    final Uri apiUri = Uri.parse(
      "https://api.lemonfox.ai/v1/audio/transcriptions",
    );
    try {
      var request = http.MultipartRequest('POST', apiUri)
        ..headers['Authorization'] = 'Bearer $_lemonFoxApiKey'
        ..files.add(await http.MultipartFile.fromPath('file', entry.filePath))
        ..fields['response_format'] = 'json';
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? transcriptText = responseData['text'];
        if (transcriptText != null) {
          final box = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
          entry.transcription = transcriptText;
          await box.put(entry.id, entry);
          if (mounted)
            showCustomSnackBar(
              context: context,
              message: 'Transcription complete!',
              iconColor: Colors.green,
            );
        } else {
          throw Exception('Transcription text not found.');
        }
      } else {
        String errorMessage = "Error ${response.statusCode}";
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage +=
              "\n${errorData['detail'] ?? errorData['message'] ?? response.body}";
        } catch (_) {
          errorMessage += "\n${response.body}";
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Transcription failed: $e',
          iconColor: Colors.red,
        );
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _shareRecordingFile(RecordingEntry entry) async {
    if (entry.filePath.isEmpty || !await File(entry.filePath).exists()) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file not found.',
        );
      return;
    }
    if (_currentlyPlayingFileId == entry.id) {
      await _stopPlaybackAndResetState();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    final result = await Share.shareXFiles([
      XFile(entry.filePath),
    ], text: 'Hidden Echolog: ${entry.displayName}');
    if (mounted) {
      if (result.status == ShareResultStatus.success) {
        showCustomSnackBar(
          context: context,
          message: 'Recording shared!',
          iconColor: Colors.green,
        );
      } else if (result.status != ShareResultStatus.dismissed) {
        showCustomSnackBar(
          context: context,
          message: 'Sharing failed: ${result.status}',
          iconColor: Colors.red,
        );
      }
    }
  }

  Future<void> _shareTranscriptionText(RecordingEntry entry) async {
    if (entry.transcription == null || entry.transcription!.trim().isEmpty) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'No transcription available.',
        );
      return;
    }
    final result = await Share.share(
      'Hidden Echolog Transcription for "${entry.displayName}":\n\n${entry.transcription}',
      subject: 'Hidden Transcription: ${entry.displayName}',
    );
    if (mounted && result.status == ShareResultStatus.success) {
      showCustomSnackBar(
        context: context,
        message: 'Transcription shared!',
        iconColor: Colors.green,
      );
    }
  }

  Future<void> _showShareOptionsDialog(RecordingEntry entry) async {
    final theme = Theme.of(context);
    bool hasTranscription =
        entry.transcription != null && entry.transcription!.trim().isNotEmpty;
    if (_currentlyPlayingFileId == entry.id) {
      await _stopPlaybackAndResetState();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
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
          children: <Widget>[
            ListTile(
              leading: Icon(
                Icons.audiotrack_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                'Share Audio Recording',
                style: GoogleFonts.poppins(color: theme.colorScheme.onSurface),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bodyContent;
    try {
      final hiddenRecordingsHiveBox = Hive.box<RecordingEntry>(
        hiddenRecordingsBoxName,
      );
      bodyContent = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategorySelectorWidget(
                  predefinedCategories: _predefinedCategoriesForHidden,
                  selectedCategoryData: _selectedCategoryDataForHidden,
                  onCategorySelected: _onHiddenCategorySelected,
                  isRecording: _isRecordingHidden,
                ),
                const SizedBox(height: 25),
                if (_isRecordingHidden)
                  Text(
                    'Recording: ${_hiddenRecordingDuration.toString().split('.').first.padLeft(8, "0")}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_isRecordingHidden) const SizedBox(height: 20),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ValueListenableBuilder<Box<RecordingEntry>>(
                valueListenable: hiddenRecordingsHiveBox.listenable(),
                builder: (context, box, _) {
                  List<RecordingEntry> recordings = box.values.toList();
                  recordings.sort(
                    (a, b) => b.dateRecorded.compareTo(a.dateRecorded),
                  );
                  if (recordings.isEmpty) {
                    return Center(
                      child: Text(
                        'No hidden recordings yet.\nSelect a category and tap the mic.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade500,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: recordings.length,
                    itemBuilder: (context, index) {
                      final entry = recordings[index];
                      final isThisCardTheActiveTrack =
                          _currentlyPlayingFileId == entry.id;
                      final showAsPlayingButton =
                          isThisCardTheActiveTrack && _isPlayerActuallyPlaying;
                      double progressPercentForThisCard = 0.0;
                      if (isThisCardTheActiveTrack &&
                          _currentTotalDuration.inMilliseconds > 0) {
                        progressPercentForThisCard =
                            (_currentPlaybackProgress.inMilliseconds /
                                    _currentTotalDuration.inMilliseconds)
                                .clamp(0.0, 1.0);
                      }
                      return Dismissible(
                        key: ValueKey('dismiss_${entry.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          child: const Icon(
                            Icons.delete_sweep_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        onDismissed: (direction) =>
                            _handleDismissHiddenRecording(entry),
                        child: RecordingCard(
                          key: ValueKey(
                            'rc_${entry.id}_${showAsPlayingButton}_${progressPercentForThisCard.toStringAsFixed(4)}',
                          ),
                          recording: entry,
                          isPlaying: showAsPlayingButton,
                          onPlayToggle: () => _togglePlayRecordingItem(entry),
                          onShare: () => _showShareOptionsDialog(entry),
                          onTranscribe: () => _transcribeWithLemonFox(entry),
                          onDelete: () => _handleDismissHiddenRecording(entry),
                          onMoveToVault: () => _moveOutOfVault(entry),
                          playbackProgressPercent: progressPercentForThisCard,
                          onSeekRequest: isThisCardTheActiveTrack
                              ? _handleSeekRequest
                              : null,
                          isOut: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    } catch (e, s) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Error loading hidden recordings screen.\nPlease try again or check logs.\n\n$e",
            style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hidden Recordings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surfaceVariant,
        actions: [
          IconButton(
            icon: Icon(
              Icons.lock_reset_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Change PIN',
            onPressed: _handleChangePin,
          ),
        ],
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: _startOrStopHiddenRecording,
        backgroundColor: _isRecordingHidden
            ? Colors.red.shade400
            : theme.colorScheme.secondary,
        tooltip: _isRecordingHidden
            ? 'Stop Hidden Recording'
            : 'Start Hidden Recording',
        child: Icon(
          _isRecordingHidden ? Icons.stop_rounded : Icons.mic_none_rounded,
          color: theme.colorScheme.onSecondary,
          size: 30,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
