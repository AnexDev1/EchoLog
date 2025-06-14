import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/recording_entry.dart';
import 'models/filter_state.dart';
import 'models/custom_category.dart';
import 'widgets/category_selector_widget.dart';
import 'widgets/recording_controls_widget.dart';
import 'widgets/recording_list_item_widget.dart';
import 'widgets/save_recording_dialog.dart';
import 'widgets/filter_bottom_sheet_widget.dart';
// import 'utils/duration_formatter.dart'; // Not directly used here, but good to keep if other parts use it
import 'utils/custom_snackbar.dart';
import 'main.dart'; // For recordingsBoxName and customCategoriesBoxName

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedCategoryData;

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
  String? _currentlyPlayingFileId;
  FilterState _currentFilters = FilterState();

  List<Map<String, dynamic>> _getAllCategories(
    Box<CustomCategory> customCategoryBox,
  ) {
    final customCategories = customCategoryBox.values
        .map((c) => c.toMap())
        .toList();
    // Predefined categories already have 'isCustom' and 'id'
    return [..._predefinedCategories, ...customCategories];
  }

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initializeRecorder();
    _initializePlayer();
  }

  Future<void> _initializeRecorder() async {
    try {
      final status = await Permission.microphone.request();
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
      _player!.setSubscriptionDuration(const Duration(milliseconds: 500));
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
    _recorder?.closeRecorder().catchError(
      (e) => print("Error closing recorder: $e"),
    );
    _recorder = null;
    _player?.closePlayer().catchError((e) => print("Error closing player: $e"));
    _player = null;
    super.dispose();
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
          if (mounted && _selectedCategoryData != null) {
            _showSaveRecordingDialog(
              path,
              _recordingDuration,
              _selectedCategoryData!,
            );
          }
        }
      } catch (e) {
        print('Error stopping recorder: $e');
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Error stopping recording.',
            leadingIcon: Icons.error_outline_rounded,
            iconColor: Theme.of(context).colorScheme.error,
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isRecordingPaused = false;
          });
        }
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
        if (mounted) {
          setState(() {
            _isRecording = true;
            _isRecordingPaused = false;
            _recordingDuration = Duration.zero;
          });
        }
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isRecordingPaused && mounted) {
            setState(
              () => _recordingDuration = Duration(
                seconds: _recordingDuration.inSeconds + 1,
              ),
            );
          }
        });
      } catch (e) {
        print('Error starting recorder: $e');
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
    if (_recorder!.isPaused) {
      _recorder!.resumeRecorder();
    } else {
      _recorder!.pauseRecorder();
    }
    setState(() {
      _isRecordingPaused = _recorder!.isPaused;
    });
  }

  void _handleSaveRecording(
    String displayName,
    String filePath,
    Duration duration,
    Map<String, dynamic> categoryData,
  ) {
    final newEntry = RecordingEntry.create(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: filePath,
      displayName: displayName,
      duration: duration,
      dateRecorded: DateTime.now(),
      moodName: categoryData['name'] as String,
      moodColor: categoryData['color'] as Color,
      moodIconColor: categoryData['iconColor'] as Color,
      emoji: categoryData['emoji'] as String? ?? '',
    );

    final box = Hive.box<RecordingEntry>(recordingsBoxName);
    box.put(newEntry.id, newEntry);
    if (mounted) {
      showCustomSnackBar(
        context: context,
        message: '"${newEntry.displayName}" saved!',
        leadingIcon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green.shade400,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _handleDiscardRecording() {
    if (mounted) {
      showCustomSnackBar(
        context: context,
        message: 'Recording discarded.',
        leadingIcon: Icons.delete_outline_rounded,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _showSaveRecordingDialog(
    String filePath,
    Duration duration,
    Map<String, dynamic> categoryData,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SaveRecordingDialog(
          filePath: filePath,
          duration: duration,
          categoryData: categoryData,
          player: _player,
          isPlayerInitialized: _isPlayerInitialized,
          onSave: _handleSaveRecording,
          onDiscard: _handleDiscardRecording,
        );
      },
    );
    if (mounted) {
      setState(() {
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _togglePlayRecordingItem(
    RecordingEntry entry,
    List<RecordingEntry> currentList,
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
      } catch (e) {
        print("Error playing recording item: $e");
        if (mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Error playing recording.',
            leadingIcon: Icons.error_outline_rounded,
            iconColor: Theme.of(context).colorScheme.error,
          );
          setState(() {
            entry.isPlaying = false;
            _currentlyPlayingFileId = null;
          });
        }
      }
    }
  }

  // Updated to accept nullable category
  void _onCategorySelected(Map<String, dynamic>? category) {
    if (_isRecording) return;
    setState(() {
      _selectedCategoryData = category; // This will be null if category is null
    });
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
      builder: (context) {
        return FilterBottomSheetWidget(
          initialFilters: _currentFilters,
          categories: allCategoriesForFilter,
          onApplyFilters: (updatedFilters) {
            setState(() {
              _currentFilters = updatedFilters;
            });
          },
        );
      },
    );
  }

  Future<void> _deleteRecordingFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('File deleted: $filePath');
      }
    } catch (e) {
      print('Error deleting file $filePath: $e');
      if (mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Could not delete the audio file.',
          leadingIcon: Icons.error_outline_rounded,
          iconColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Echolog',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<Box<CustomCategory>>(
          valueListenable: Hive.box<CustomCategory>(
            customCategoriesBoxName,
          ).listenable(),
          builder: (context, customCategoryBox, _) {
            final allDisplayCategories = _getAllCategories(customCategoryBox);

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
                  predefinedCategories:
                      _predefinedCategories, // Pass predefined separately
                  selectedCategoryData: _selectedCategoryData,
                  isRecording: _isRecording,
                  onCategorySelected:
                      _onCategorySelected, // Pass the updated method
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
                    theme: theme,
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
                              : theme.colorScheme.onBackground.withOpacity(0.7),
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
                  child: ValueListenableBuilder<Box<RecordingEntry>>(
                    valueListenable: Hive.box<RecordingEntry>(
                      recordingsBoxName,
                    ).listenable(),
                    builder: (context, box, _) {
                      List<RecordingEntry> recordings = box.values.toList();

                      if (_currentFilters.moodName != null) {
                        recordings = recordings
                            .where(
                              (entry) =>
                                  entry.moodName == _currentFilters.moodName,
                            )
                            .toList();
                      }
                      if (_currentFilters.searchNameQuery != null &&
                          _currentFilters.searchNameQuery!.isNotEmpty) {
                        final query = _currentFilters.searchNameQuery!
                            .toLowerCase();
                        recordings = recordings
                            .where(
                              (entry) => entry.displayName
                                  .toLowerCase()
                                  .contains(query),
                            )
                            .toList();
                      }
                      if (_currentFilters.durationRangeSeconds != null) {
                        recordings = recordings.where((entry) {
                          final durationInSeconds = entry.duration.inSeconds
                              .toDouble();
                          return durationInSeconds >=
                                  _currentFilters.durationRangeSeconds!.start &&
                              durationInSeconds <=
                                  _currentFilters.durationRangeSeconds!.end;
                        }).toList();
                      }
                      if (_currentFilters.dateRecordedRange != null) {
                        recordings = recordings.where((entry) {
                          final recordDate = DateTime(
                            entry.dateRecorded.year,
                            entry.dateRecorded.month,
                            entry.dateRecorded.day,
                          );
                          final startDate = DateTime(
                            _currentFilters.dateRecordedRange!.start.year,
                            _currentFilters.dateRecordedRange!.start.month,
                            _currentFilters.dateRecordedRange!.start.day,
                          );
                          final endDate = DateTime(
                            _currentFilters.dateRecordedRange!.end.year,
                            _currentFilters.dateRecordedRange!.end.month,
                            _currentFilters.dateRecordedRange!.end.day,
                          );
                          return !recordDate.isBefore(startDate) &&
                              !recordDate.isAfter(endDate);
                        }).toList();
                      }

                      for (var rec in recordings) {
                        if (rec.id != _currentlyPlayingFileId) {
                          rec.isPlaying = false;
                        }
                      }
                      recordings.sort(
                        (a, b) => b.dateRecorded.compareTo(a.dateRecorded),
                      );

                      if (recordings.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              _currentFilters.isAnyFilterActive
                                  ? 'No recordings match your filters.\nTry adjusting or clearing them.'
                                  : 'No recordings yet.\nTap the microphone to start!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
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
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
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
                              final RecordingEntry deletedEntry = entry;
                              final String deletedFilePath = entry.filePath;
                              box.delete(entry.id);
                              if (_currentlyPlayingFileId == deletedEntry.id &&
                                  _player != null &&
                                  _player!.isPlaying) {
                                _player!.stopPlayer().then((_) {
                                  if (mounted)
                                    setState(
                                      () => _currentlyPlayingFileId = null,
                                    );
                                });
                              }
                              showCustomSnackBar(
                                context: context,
                                message:
                                    '"${deletedEntry.displayName}" deleted.',
                                actionLabel: 'UNDO',
                                onActionPressed: () {
                                  box.put(deletedEntry.id, deletedEntry);
                                },
                                duration: const Duration(seconds: 4),
                                leadingIcon: Icons.delete_forever_rounded,
                                iconColor: theme.colorScheme.secondary,
                              ).closed.then((reason) {
                                if (reason != SnackBarClosedReason.action) {
                                  _deleteRecordingFile(deletedFilePath);
                                }
                              });
                            },
                            child: RecordingListItemWidget(
                              entry: entry,
                              onPlayPause: (selectedEntry) =>
                                  _togglePlayRecordingItem(
                                    selectedEntry,
                                    recordings,
                                  ),
                              theme: theme,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
