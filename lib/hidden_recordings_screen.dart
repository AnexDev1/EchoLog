import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? _currentlyPlayingFileId;

  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  bool _isRecordingHidden = false;
  Duration _hiddenRecordingDuration = Duration.zero;
  Timer? _hiddenRecordingTimer;
  String? _currentHiddenRecordingPath;

  Map<String, dynamic>? _selectedCategoryDataForHidden;

  final PasswordService _passwordService = PasswordService();

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

  Future<void> _togglePlayRecordingItem(
    RecordingEntry entry,
    List<RecordingEntry> currentList,
  ) async {
    if (!_isPlayerInitialized || _player == null) {
      if (mounted)
        showCustomSnackBar(context: context, message: 'Player not ready.');
      return;
    }
    final bool wasCurrentlyPlayingThisEntry =
        _currentlyPlayingFileId == entry.id;

    if (_player!.isPlaying) {
      await _player!.stopPlayer();
    }

    if (wasCurrentlyPlayingThisEntry) {
      if (mounted)
        setState(() {
          entry.isPlaying = false;
          _currentlyPlayingFileId = null;
        });
    } else {
      final previousPlayingIndex = currentList.indexWhere(
        (e) => e.id == _currentlyPlayingFileId,
      );
      if (previousPlayingIndex != -1 &&
          currentList[previousPlayingIndex].isPlaying) {
        if (mounted) {
          setState(() {
            currentList[previousPlayingIndex].isPlaying = false;
          });
        }
      }

      try {
        await _player!.startPlayer(
          fromURI: entry.filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            if (mounted)
              setState(() {
                entry.isPlaying = false;
                _currentlyPlayingFileId = null;
              });
          },
        );
        if (mounted)
          setState(() {
            entry.isPlaying = true;
            _currentlyPlayingFileId = entry.id;
          });
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
            entry.isPlaying = false;
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

    box.delete(entry.id);

    if (_currentlyPlayingFileId == entry.id &&
        _player != null &&
        _player!.isPlaying) {
      _player!.stopPlayer().then((_) {
        if (mounted) setState(() => _currentlyPlayingFileId = null);
      });
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

          final newEntry = RecordingEntry.create(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            filePath: path,
            displayName: recordingName,
            duration: _hiddenRecordingDuration,
            dateRecorded: DateTime.now(),
            moodName: categoryToSave['name'] as String,
            moodColor: categoryToSave['color'] as Color,
            moodIconColor: categoryToSave['iconColor'] as Color,
            emoji: categoryToSave['emoji'] as String? ?? '🤫',
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

    // Step 1: Ask for current PIN
    print(
      "[_handleChangePin] Showing EnterPasswordDialog to verify current PIN.",
    );
    bool? currentPinVerified = await showDialog<bool>(
      context: context,
      barrierDismissible:
          false, // Ensures dialog is explicitly popped with a value
      builder: (BuildContext dialogContext) {
        return EnterPasswordDialog(
          passwordService:
              _passwordService, // Make sure _passwordService is initialized
          onPasswordEntered: (bool _) {
            // This callback is primarily for the dialog's internal use or other listeners.
            // The value returned by showDialog (currentPinVerified) is key here.
          },
        );
      },
    );

    print(
      "[_handleChangePin] Result from EnterPasswordDialog (currentPinVerified): $currentPinVerified",
    );

    // THIS IS THE CRITICAL CHECK:
    // If currentPinVerified is true, it means EnterPasswordDialog successfully
    // verified the current PIN and called Navigator.of(context).pop(true).
    if (currentPinVerified == true) {
      print(
        "[_handleChangePin] Current PIN verification successful. Proceeding to set new PIN.",
      );
      if (!mounted) {
        print(
          "[_handleChangePin] Widget is no longer mounted after current PIN verification. Aborting.",
        );
        return;
      }

      // Step 2: Current PIN correct, now show CreatePasswordDialog for new PIN
      print(
        "[_handleChangePin] Showing CreatePasswordDialog for new PIN setup.",
      );
      bool? newPinSet = await showDialog<bool>(
        context: context,
        barrierDismissible:
            false, // Ensures dialog is explicitly popped with a value
        builder: (BuildContext dialogContext) {
          return CreatePasswordDialog(
            passwordService:
                _passwordService, // Make sure _passwordService is initialized
            onPasswordSet: (bool _) {
              // Similar to EnterPasswordDialog, the key is the value returned by showDialog.
            },
          );
        },
      );

      print(
        "[_handleChangePin] Result from CreatePasswordDialog (newPinSet): $newPinSet",
      );

      if (newPinSet == true) {
        if (mounted) {
          print("[_handleChangePin] New PIN successfully set.");
          showCustomSnackBar(
            context: context,
            message: "PIN changed successfully!",
            iconColor: Colors.green,
          );
        }
      } else if (newPinSet == false) {
        if (mounted) {
          print("[_handleChangePin] CreatePasswordDialog was cancelled.");
          showCustomSnackBar(
            context: context,
            message: "PIN change cancelled.",
            iconColor: Colors.orange,
          );
        }
      } else {
        // newPinSet is null
        print(
          "[_handleChangePin] CreatePasswordDialog returned null. Issue in CreatePasswordDialog pop logic.",
        );
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: "Failed to set new PIN. Please try again.",
            iconColor: Colors.red,
          );
        }
      }
    } else if (currentPinVerified == false) {
      print(
        "[_handleChangePin] Current PIN verification was cancelled (EnterPasswordDialog returned false).",
      );
      // User cancelled the EnterPasswordDialog.
    } else {
      // currentPinVerified is null
      print(
        "[_handleChangePin] EnterPasswordDialog returned null. CRITICAL: This means EnterPasswordDialog did not pop with true on success.",
      );
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message:
              "Error verifying current PIN. Please try again.", // This is the message you saw
          iconColor: Colors.red,
        );
      }
    }
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
            // --- Content of HiddenRecordingSetupWidget (Category Selector and Status) ---
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
            // --- End Content of HiddenRecordingSetupWidget ---
            const SizedBox(height: 20), // Spacing
            // --- Content of HiddenRecordingsListView (The List Itself) ---
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
                      return Dismissible(
                        key: ValueKey(entry.id),
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
                            entry: entry,
                            onPlayPause: (selectedEntry) =>
                                _togglePlayRecordingItem(
                                  selectedEntry,
                                  recordings,
                                ),
                            theme: theme,
                            // isDense: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // --- End Content of HiddenRecordingsListView ---
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
