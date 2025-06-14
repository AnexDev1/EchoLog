import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/recording_entry.dart';
import 'models/custom_category.dart';
import 'widgets/recording_list_item_widget.dart';
import 'widgets/category_selector_widget.dart';
import 'main.dart';
import 'utils/custom_snackbar.dart';

class HiddenRecordingsScreen extends StatefulWidget {
  const HiddenRecordingsScreen({super.key});

  @override
  State<HiddenRecordingsScreen> createState() {
    print("[HiddenRecordingsScreen] createState called"); // <-- DIAGNOSTIC
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

  final List<Map<String, dynamic>> _predefinedCategories = [
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
    print("[HiddenRecordingsScreen] initState started"); // <-- DIAGNOSTIC
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _initializePlayer();
    _initializeHiddenRecorder();

    // Defensive check for predefined categories
    if (_predefinedCategories.isNotEmpty) {
      _selectedCategoryDataForHidden = _predefinedCategories.first;
      print(
        "[HiddenRecordingsScreen] Default category set: ${_selectedCategoryDataForHidden?['name']}",
      ); // <-- DIAGNOSTIC
    } else {
      print(
        "[HiddenRecordingsScreen] WARNING: _predefinedCategories is empty!",
      ); // <-- DIAGNOSTIC
    }
    print("[HiddenRecordingsScreen] initState finished"); // <-- DIAGNOSTIC
  }

  Future<void> _initializePlayer() async {
    print(
      "[HiddenRecordingsScreen] _initializePlayer started",
    ); // <-- DIAGNOSTIC
    try {
      await _player!.openPlayer();
      _player!.setSubscriptionDuration(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isPlayerInitialized = true);
        print(
          "[HiddenRecordingsScreen] Player initialized successfully",
        ); // <-- DIAGNOSTIC
      }
    } catch (e, s) {
      print(
        '[HiddenRecordingsScreen] Error initializing player: $e',
      ); // <-- DIAGNOSTIC
      print(s); // <-- DIAGNOSTIC STACKTRACE
      if (mounted) setState(() => _isPlayerInitialized = false);
    }
  }

  Future<void> _initializeHiddenRecorder() async {
    print(
      "[HiddenRecordingsScreen] _initializeHiddenRecorder started",
    ); // <-- DIAGNOSTIC
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        print(
          "[HiddenRecordingsScreen] Microphone permission not granted for hidden recorder",
        ); // <-- DIAGNOSTIC
        throw RecordingPermissionException(
          'Microphone permission not granted for hidden recorder',
        );
      }
      await _recorder!.openRecorder();
      if (mounted) {
        setState(() => _isRecorderInitialized = true);
        print(
          "[HiddenRecordingsScreen] Hidden recorder initialized successfully",
        ); // <-- DIAGNOSTIC
      }
    } catch (e, s) {
      print(
        '[HiddenRecordingsScreen] Error initializing hidden recorder: $e',
      ); // <-- DIAGNOSTIC
      print(s); // <-- DIAGNOSTIC STACKTRACE
      if (mounted) {
        setState(() => _isRecorderInitialized = false);
      }
    }
  }

  @override
  void dispose() {
    print("[HiddenRecordingsScreen] dispose called"); // <-- DIAGNOSTIC
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
      print(
        "[HiddenRecordingsScreen] Category selected: ${category?['name']}",
      ); // <-- DIAGNOSTIC
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
        _currentlyPlayingFileId == entry.id && entry.isPlaying;

    if (_player!.isPlaying) {
      await _player!.stopPlayer();
      if (_currentlyPlayingFileId != null) {
        final previousEntryIndex = currentList.indexWhere(
          (e) => e.id == _currentlyPlayingFileId,
        );
        if (previousEntryIndex != -1 &&
            mounted &&
            currentList[previousEntryIndex].isPlaying) {
          setState(() => currentList[previousEntryIndex].isPlaying = false);
        }
      }
    }

    if (wasCurrentlyPlayingThisEntry) {
      if (mounted)
        setState(() {
          entry.isPlaying = false;
          _currentlyPlayingFileId = null;
        });
    } else {
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
        ); // <-- DIAGNOSTIC
        print(s); // <-- DIAGNOSTIC STACKTRACE
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
      ); // <-- DIAGNOSTIC
      print(s); // <-- DIAGNOSTIC STACKTRACE
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
              _selectedCategoryDataForHidden ?? _predefinedCategories.first;

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
        print(
          '[HiddenRecordingsScreen] Error stopping hidden recorder: $e',
        ); // <-- DIAGNOSTIC
        print(s); // <-- DIAGNOSTIC STACKTRACE
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
          }
        });
      } catch (e, s) {
        print(
          '[HiddenRecordingsScreen] Error starting hidden recorder: $e',
        ); // <-- DIAGNOSTIC
        print(s); // <-- DIAGNOSTIC STACKTRACE
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

  @override
  Widget build(BuildContext context) {
    print("[HiddenRecordingsScreen] build started"); // <-- DIAGNOSTIC
    final theme = Theme.of(context);
    Widget bodyContent;

    try {
      // Attempt to access Hive boxes early in build to catch errors if they are not open
      // This is a common point of failure if boxes aren't opened correctly in main.dart
      // or if there's a type mismatch from previous runs.
      final hiddenBox = Hive.box<RecordingEntry>(hiddenRecordingsBoxName);
      final customCategoryBox = Hive.box<CustomCategory>(
        customCategoriesBoxName,
      );
      print(
        "[HiddenRecordingsScreen] Hive boxes accessed successfully in build.",
      ); // <-- DIAGNOSTIC

      bodyContent = ValueListenableBuilder<Box<CustomCategory>>(
        valueListenable: customCategoryBox.listenable(),
        builder: (context, catBox, _) {
          print(
            "[HiddenRecordingsScreen] CustomCategory ValueListenableBuilder building.",
          ); // <-- DIAGNOSTIC
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Select a category for your hidden note:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 15),
                CategorySelectorWidget(
                  predefinedCategories: _predefinedCategories,
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
                Expanded(
                  child: ValueListenableBuilder<Box<RecordingEntry>>(
                    valueListenable: hiddenBox.listenable(),
                    builder: (context, box, _) {
                      print(
                        "[HiddenRecordingsScreen] RecordingEntry ValueListenableBuilder building.",
                      ); // <-- DIAGNOSTIC
                      List<RecordingEntry> recordings = box.values.toList();
                      recordings.sort(
                        (a, b) => b.dateRecorded.compareTo(a.dateRecorded),
                      );

                      for (var rec in recordings) {
                        if (rec.id != _currentlyPlayingFileId) {
                          rec.isPlaying = false;
                        }
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              alignment: Alignment.centerRight,
                              child: const Icon(
                                Icons.delete_sweep_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            onDismissed: (direction) {
                              final String deletedFilePath = entry.filePath;
                              box.delete(entry.id);
                              if (_currentlyPlayingFileId == entry.id &&
                                  _player != null &&
                                  _player!.isPlaying) {
                                _player!.stopPlayer().then((_) {
                                  if (mounted)
                                    setState(
                                      () => _currentlyPlayingFileId = null,
                                    );
                                });
                              }
                              _deleteRecordingFile(deletedFilePath);
                              if (mounted)
                                showCustomSnackBar(
                                  context: context,
                                  message:
                                      '"${entry.displayName}" deleted from hidden.',
                                );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
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
              ],
            ),
          );
        },
      );
    } catch (e, s) {
      print(
        "[HiddenRecordingsScreen] CRITICAL ERROR IN BUILD: $e",
      ); // <-- DIAGNOSTIC
      print(s); // <-- DIAGNOSTIC STACKTRACE
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

    print("[HiddenRecordingsScreen] build finished"); // <-- DIAGNOSTIC
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hidden Recordings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surfaceVariant,
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
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
