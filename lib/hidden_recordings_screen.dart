import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // For sharing
import 'package:http/http.dart' as http; // For HTTP requests
import 'dart:convert'; // For jsonDecode

import '../models/recording_entry.dart';
import '../widgets/category_selector_widget.dart';
import '../widgets/recording_list_item_widget.dart';
import '../main.dart'; // For box names
import '../utils/custom_snackbar.dart';
import '../services/password_service.dart';
import '../widgets/enter_password_dialog.dart';
import '../widgets/create_password_dialog.dart';

class HiddenRecordingsScreen extends StatefulWidget {
  const HiddenRecordingsScreen({super.key});

  @override
  State<HiddenRecordingsScreen> createState() {
    print("[HiddenRecordingsScreen] createState called");
    return _HiddenRecordingsScreenState();
  }
}

class _HiddenRecordingsScreenState extends State<HiddenRecordingsScreen> {
  FlutterSoundPlayer? _player;
  bool _isPlayerInitialized = false;
  String?
  _currentlyPlayingFileId; // Changed from _currentlyPlayingId to be more specific

  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  bool _isRecordingHidden = false;
  Duration _hiddenRecordingDuration = Duration.zero;
  Timer? _hiddenRecordingTimer;
  String? _currentHiddenRecordingPath;

  Map<String, dynamic>? _selectedCategoryDataForHidden;

  final PasswordService _passwordService = PasswordService();

  // For Lemonfox AI Transcription
  final String _lemonFoxApiKey =
      "Sf8cPZsgkaVohAnV31DxsiSO9QiIiqbj"; // <-- IMPORTANT: Replace with your actual key.
  bool _isTranscribing = false; // Generic transcribing flag

  final List<Map<String, dynamic>> _predefinedCategoriesForHidden = [
    {
      'name': 'Secret',
      'emoji': '🤫',
      'color': Colors.purple.shade300,
      'iconColor': Colors.purple.shade100,
      'isCustom': false,
      'id': 'Secret',
    },
    {
      'name': 'Private Thoughts',
      'emoji': '🤐',
      'color': Colors.teal.shade300,
      'iconColor': Colors.teal.shade100,
      'isCustom': false,
      'id': 'Private Thoughts',
    },
    {
      'name': 'Ideas',
      'emoji': '💡',
      'color': Colors.indigo.shade300,
      'iconColor': Colors.indigo.shade100,
      'isCustom': false,
      'id': 'Ideas',
    },
  ];

  @override
  void initState() {
    super.initState();
    print("[HiddenRecordingsScreen] initState started");
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _initializePlayer();
    _initializeHiddenRecorder();

    if (_predefinedCategoriesForHidden.isNotEmpty) {
      _selectedCategoryDataForHidden = _predefinedCategoriesForHidden.first;
      print(
        "[HiddenRecordingsScreen] Default category set: ${_selectedCategoryDataForHidden?['name']}",
      );
    } else {
      print(
        "[HiddenRecordingsScreen] WARNING: _predefinedCategoriesForHidden is empty!",
      );
    }
    print("[HiddenRecordingsScreen] initState finished");
  }

  Future<void> _initializePlayer() async {
    print("[HiddenRecordingsScreen] _initializePlayer started");
    try {
      await _player!.openPlayer();
      _player!.setSubscriptionDuration(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isPlayerInitialized = true);
        print("[HiddenRecordingsScreen] Player initialized successfully");
      }
    } catch (e, s) {
      print('[HiddenRecordingsScreen] Error initializing player: $e');
      print(s);
      if (mounted) setState(() => _isPlayerInitialized = false);
    }
  }

  Future<void> _initializeHiddenRecorder() async {
    print("[HiddenRecordingsScreen] _initializeHiddenRecorder started");
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print(
          "[HiddenRecordingsScreen] Microphone permission not granted for hidden recorder",
        );
        throw RecordingPermissionException(
          'Microphone permission not granted for hidden recorder',
        );
      }
      await _recorder!.openRecorder();
      if (mounted) {
        setState(() => _isRecorderInitialized = true);
        print(
          "[HiddenRecordingsScreen] Hidden recorder initialized successfully",
        );
      }
    } catch (e, s) {
      print('[HiddenRecordingsScreen] Error initializing hidden recorder: $e');
      print(s);
      if (mounted) {
        setState(() => _isRecorderInitialized = false);
      }
    }
  }

  @override
  void dispose() {
    print("[HiddenRecordingsScreen] dispose called");
    _player?.closePlayer().catchError(
      (e) => print("[HiddenRecordingsScreen] Error closing player: $e"),
    );
    _player = null;
    _recorder?.closeRecorder().catchError(
      (e) =>
          print("[HiddenRecordingsScreen] Error closing hidden recorder: $e"),
    );
    _recorder = null;
    _hiddenRecordingTimer?.cancel();
    super.dispose();
  }

  void _onHiddenCategorySelected(Map<String, dynamic>? category) {
    if (_isRecordingHidden) return;
    setState(() {
      _selectedCategoryDataForHidden = category;
      print("[HiddenRecordingsScreen] Category selected: ${category?['name']}");
    });
  }

  Future<void> _stopCurrentPlayback() async {
    if (_player != null && _player!.isPlaying) {
      await _player!.stopPlayer();
    }
    if (mounted && _currentlyPlayingFileId != null) {
      // Update the specific entry in the list if needed, or rely on ValueListenableBuilder
      // For simplicity, just clear the playing ID. The list item will rebuild.
      setState(() {
        _currentlyPlayingFileId = null;
      });
    }
  }

  Future<void> _togglePlayRecordingItem(
    RecordingEntry entry,
    // List<RecordingEntry> currentList, // No longer need currentList if we update via Hive/ValueListenableBuilder
  ) async {
    if (!_isPlayerInitialized || _player == null) {
      if (mounted) {
        showCustomSnackBar(context: context, message: 'Player not ready.');
      }
      return;
    }

    final bool wasCurrentlyPlayingThisEntry =
        _currentlyPlayingFileId == entry.id;

    // Stop any current playback
    await _stopCurrentPlayback();

    if (wasCurrentlyPlayingThisEntry) {
      // If it was this entry, it's now stopped, so update its state
      // The actual isPlaying flag on the entry object is managed by the list item widget itself
      // based on _currentlyPlayingFileId. Here we just clear the global ID.
      if (mounted) {
        setState(() {
          _currentlyPlayingFileId = null;
        });
      }
    } else {
      // Play the new entry
      try {
        await _player!.startPlayer(
          fromURI: entry.filePath,
          codec: Codec.aacADTS, // Ensure this matches your recording format
          whenFinished: () {
            if (mounted) {
              setState(() {
                _currentlyPlayingFileId = null;
              });
            }
          },
        );
        if (mounted) {
          setState(() {
            _currentlyPlayingFileId = entry.id;
          });
        }
      } catch (e, s) {
        print(
          "[HiddenRecordingsScreen] Error playing hidden recording item: $e",
        );
        print(s);
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Error playing recording.',
          );
          setState(() {
            _currentlyPlayingFileId = null;
          });
        }
      }
    }
  }

  Future<void> _deleteRecordingFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, s) {
      print(
        '[HiddenRecordingsScreen] Error deleting hidden audio file $filePath: $e',
      );
      print(s);
    }
  }

  void _handleDismissHiddenRecording(RecordingEntry entry) {
    final box = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
    final String deletedFilePath = entry.filePath;

    box.delete(entry.id); // This will trigger ValueListenableBuilder

    if (_currentlyPlayingFileId == entry.id) {
      _stopCurrentPlayback(); // Ensure playback stops and ID is cleared
    }
    _deleteRecordingFile(deletedFilePath);
    if (mounted) {
      showCustomSnackBar(
        context: context,
        message: '"${entry.displayName}" deleted from hidden.',
      );
    }
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
            if (mounted) {
              setState(() {
                _isRecordingHidden = false;
                _hiddenRecordingDuration = Duration.zero;
              });
            }
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
            isPlaying: false, // Ensure isPlaying is false initially
            transcription: null,
          );
          final box = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
          box.put(newEntry.id, newEntry);
          if (mounted) {
            showCustomSnackBar(
              context: context,
              message: '"$recordingName" saved to hidden.',
              iconColor: Colors.green,
            );
          }
        }
      } catch (e, s) {
        print('[HiddenRecordingsScreen] Error stopping hidden recorder: $e');
        print(s);
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
            message: 'Please select a category for your hidden note.',
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
      } catch (e, s) {
        print('[HiddenRecordingsScreen] Error starting hidden recorder: $e');
        print(s);
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
    print("[_handleChangePin] Initiating PIN change process.");
    bool? currentPinVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return EnterPasswordDialog(
          passwordService: _passwordService,
          onPasswordEntered: (bool passwordCorrect) {
            // The assignment to currentPinVerified is removed.
            // The value for currentPinVerified will be set by the result of await showDialog
            // when EnterPasswordDialog calls Navigator.pop().
          },
        );
      },
    );

    if (currentPinVerified == true) {
      if (!mounted) return;
      bool? newPinSet = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return CreatePasswordDialog(
            passwordService: _passwordService,
            onPasswordSet: (bool passwordCreated) {
              if (passwordCreated) {
                // setState(() {
                //   _isGestureAccessActive = true; // This variable is not defined in this class
                // });
              }
            },
          );
        },
      );

      if (newPinSet == true) {
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: "PIN changed successfully!",
            iconColor: Colors.green,
          );
        }
      } else {
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: "PIN change cancelled or failed.",
            iconColor: Colors.orange,
          );
        }
      }
    } else {
      if (mounted && currentPinVerified == false) {
        // Explicitly false means incorrect PIN
        // EnterPasswordDialog should show its own snackbar for incorrect PIN
      } else if (mounted && currentPinVerified == null) {
        // Null means dialog was dismissed without action
        showCustomSnackBar(
          context: context,
          message: "PIN verification cancelled.",
          iconColor: Colors.orange,
        );
      }
    }
  }

  // --- Transcription Logic ---
  Future<void> _transcribeWithLemonFox(RecordingEntry entry) async {
    if (_lemonFoxApiKey == "YOUR_LEMONFOX_API_KEY" || _lemonFoxApiKey.isEmpty) {
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Lemonfox API Key not set.',
        );
      }
      return;
    }
    if (entry.filePath.isEmpty) {
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file path is missing.',
        );
      }
      return;
    }
    final File audioFile = File(entry.filePath);
    if (!await audioFile.exists()) {
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file not found.',
        );
      }
      return;
    }

    // Stop playback if this entry is playing
    if (_currentlyPlayingFileId == entry.id) {
      await _stopCurrentPlayback();
      await Future.delayed(
        const Duration(milliseconds: 200),
      ); // Ensure file release
    }

    if (mounted) {
      setState(() => _isTranscribing = true);
      showCustomSnackBar(
        context: context,
        message: 'Transcribing "${entry.displayName}"...',
      );
    }

    final Uri apiUri = Uri.parse(
      "https://api.lemonfox.ai/v1/audio/transcriptions",
    );
    try {
      var request = http.MultipartRequest('POST', apiUri);
      request.headers['Authorization'] = 'Bearer $_lemonFoxApiKey';
      request.files.add(
        await http.MultipartFile.fromPath('file', entry.filePath),
      );
      request.fields['response_format'] = 'json'; // Or 'text'
      // request.fields['language'] = 'english'; // Omit for auto-detection if supported

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? transcriptText = responseData['text'];

        if (transcriptText != null) {
          final box = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
          entry.transcription = transcriptText;
          await box.put(
            entry.id,
            entry,
          ); // This will trigger ValueListenableBuilder
          if (mounted) {
            showCustomSnackBar(
              context: context,
              message: 'Transcription complete!',
              iconColor: Colors.green,
            );
          }
        } else {
          throw Exception('Transcription text not found in response.');
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
    } catch (e, s) {
      print("[HiddenRecordingsScreen] Lemonfox transcription failed: $e\n$s");
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Transcription failed: $e',
          iconColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  // --- Sharing Logic ---
  Future<void> _shareRecordingFile(RecordingEntry entry) async {
    if (entry.filePath.isEmpty) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file path is missing.',
        );
      return;
    }
    final File audioFile = File(entry.filePath);
    if (!await audioFile.exists()) {
      if (mounted)
        showCustomSnackBar(
          context: context,
          message: 'Error: Recording file not found.',
        );
      return;
    }

    if (_currentlyPlayingFileId == entry.id) {
      await _stopCurrentPlayback();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final result = await Share.shareXFiles([
      XFile(entry.filePath),
    ], text: 'Hidden Echolog Recording: ${entry.displayName}');

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
          message: 'No transcription available to share.',
        );
      return;
    }

    final result = await Share.share(
      'Hidden Echolog Transcription for "${entry.displayName}":\n\n${entry.transcription}',
      subject: 'Hidden Transcription: ${entry.displayName}',
    );
    if (mounted) {
      if (result.status == ShareResultStatus.success) {
        showCustomSnackBar(
          context: context,
          message: 'Transcription shared!',
          iconColor: Colors.green,
        );
      }
    }
  }

  Future<void> _showShareOptionsDialog(RecordingEntry entry) async {
    final theme = Theme.of(context);
    bool hasTranscription =
        entry.transcription != null && entry.transcription!.trim().isNotEmpty;

    if (_currentlyPlayingFileId == entry.id) {
      await _stopCurrentPlayback();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return; // Check mounted before showing dialog

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
              onPressed: () {
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
    print("[HiddenRecordingsScreen] build started");
    final theme = Theme.of(context);
    Widget bodyContent;

    try {
      final hiddenRecordingsHiveBox = Hive.box<RecordingEntry>(
        hiddenRecordingsBoxName,
      );
      print(
        "[HiddenRecordingsScreen] Hive box '$hiddenRecordingsBoxName' accessed successfully in build.",
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
            const SizedBox(height: 20),
            Expanded(
              child: ValueListenableBuilder<Box<RecordingEntry>>(
                valueListenable: hiddenRecordingsHiveBox.listenable(),
                builder: (context, box, _) {
                  print(
                    "[HiddenRecordingsScreen-List] ValueListenableBuilder building. Box has ${box.length} items.",
                  );
                  List<RecordingEntry> recordings = box.values.toList();
                  recordings.sort(
                    (a, b) => b.dateRecorded.compareTo(a.dateRecorded),
                  );

                  // Update isPlaying status based on _currentlyPlayingFileId
                  // This ensures list items reflect the correct playback state
                  for (var rec in recordings) {
                    rec.isPlaying = (rec.id == _currentlyPlayingFileId);
                  }

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
                      // Use a more specific key to help Flutter update items correctly,
                      // especially when transcription or playback state changes.
                      final itemKey = ValueKey(
                        '${entry.id}_${entry.isPlaying}_${entry.transcription?.hashCode ?? 'no_transcription'}',
                      );
                      return Dismissible(
                        key: ValueKey(
                          'dismiss_${entry.id}',
                        ), // Dismissible key should be stable for the item
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
                        onDismissed: (direction) {
                          _handleDismissHiddenRecording(entry);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: RecordingListItemWidget(
                            key: itemKey, // Pass the more specific key here
                            entry: entry,
                            onPlayPause: (selectedEntry) =>
                                _togglePlayRecordingItem(selectedEntry),
                            onTranscribe: _transcribeWithLemonFox, // WIRED UP
                            onShare: _showShareOptionsDialog, // WIRED UP
                            onMoveToVault: (selectedEntry) {
                              if (mounted) {
                                showCustomSnackBar(
                                  context: context,
                                  message:
                                      '"${selectedEntry.displayName}" is already in the hidden vault.',
                                );
                              }
                            },
                          ),
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
      print("[HiddenRecordingsScreen] CRITICAL ERROR IN BUILD: $e");
      print(s);
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

    print("[HiddenRecordingsScreen] build finished");
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
