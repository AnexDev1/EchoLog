import 'package:echolog/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for preferences

import 'models/recording_entry.dart';
import 'models/filter_state.dart';
import 'models/custom_category.dart';
import 'widgets/category_selector_widget.dart';
import 'widgets/recording_controls_widget.dart';
import 'widgets/save_recording_dialog.dart';
import 'widgets/filter_bottom_sheet_widget.dart';
import 'utils/custom_snackbar.dart';
import 'main.dart'; // For recordingsBoxName and customCategoriesBoxName
import 'widgets/recordings_list_view.dart';

import 'services/password_service.dart';
import 'widgets/create_password_dialog.dart';
import 'widgets/enter_password_dialog.dart';
import 'hidden_recordings_screen.dart';

// Key for SharedPreferences
const String PREF_HIDDEN_ACCESS_METHOD = 'selectedHiddenAccessTriggerMethod';

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

  final PasswordService _passwordService = PasswordService();

  // --- Hidden Vault Access State ---
  HiddenAccessTriggerMethod _selectedMethod =
      HiddenAccessTriggerMethod.longPressAppBar; // Default
  bool _isGestureAccessActive = false; // Debounce for pinch/tap gestures
  int _tapCount = 0;
  Timer? _tapTimer;
  final int _tripleTapMilliseconds = 500;
  // --- End Hidden Vault Access State ---

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
    _loadHiddenAccessPreference(); // Load hidden access method preference
  }

  Future<void> _shareRecording(RecordingEntry entry) async {
    if (entry.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Recording file path is missing.')),
      );
      return;
    }

    // Optional: Check if the file exists before attempting to share
    final file = File(entry.filePath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: Recording file not found. It might have been moved or deleted.',
          ),
        ),
      );
      return;
    }
    // Stop playback if this entry is playing, as sharing might lock the file
    if (_player != null &&
        _isPlayerInitialized &&
        _currentlyPlayingFileId == entry.id &&
        _player!.isPlaying) {
      await _player!.stopPlayer();
      setState(() {
        _currentlyPlayingFileId = null;
        // Update the entry in the list to reflect it's not playing
        final box = Hive.box<RecordingEntry>(recordingsBoxName);
        Hive.box<RecordingEntry>(recordingsBoxName);
        final entries = box.values.toList();
        final entryIndex = entries.indexWhere((e) => e.id == entry.id);
        if (entryIndex != -1) {
          entries[entryIndex].isPlaying = false;
          box.put(entry.id, entries[entryIndex]); // Update the box
        }
      });
    }

    try {
      final xFile = XFile(entry.filePath);
      await Share.shareXFiles(
        [xFile],
        text: 'Check out my Echolog recording: ${entry.displayName}',
        subject:
            'Echolog Recording: ${entry.displayName}', // Subject for email apps
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share recording: $e')),
        );
      }
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

    // Stop playback if this entry is playing
    if (_currentlyPlayingFileId == entryToMove.id &&
        _player != null &&
        _player!.isPlaying) {
      // Assuming _player is your audio player instance
      await _player!.stopPlayer();
      setState(() {
        _currentlyPlayingFileId = null;
        // If _isRecordingPausedForPlayback was a relevant flag, ensure it's handled or removed if not used.
        // For now, focusing on the direct error.
        // The entry will be removed from the list, so no need to update its isPlaying status here
      });
    }

    // Create a NEW RecordingEntry instance for the hidden box
    // This assumes your RecordingEntry has a constructor that takes all its properties.
    // Adjust the constructor call according to your RecordingEntry model.
    final RecordingEntry entryForVault = RecordingEntry(
      id: entryToMove.id,
      filePath: entryToMove.filePath,
      displayName: entryToMove.displayName,
      durationMillis: entryToMove.duration.inMilliseconds,
      dateRecorded: entryToMove.dateRecorded,
      moodName: entryToMove.moodName,
      moodColorValue: entryToMove.moodColor.value,
      emoji: entryToMove.emoji,
      moodIconColorValue: entryToMove.moodIconColor.value,
      // isPlaying: false, // When moving, it's likely not playing in the new context
      // Add any other fields your RecordingEntry has
    );
    // Ensure the isPlaying status is false for the new entry in the vault,
    // as playback was stopped.
    entryForVault.isPlaying = false;

    try {
      // Add the new instance to hidden box
      await hiddenRecordingsBox.put(entryForVault.id, entryForVault);
      // Remove from public box using the original entry's key (ID)
      await recordingsBox.delete(entryToMove.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${entryToMove.displayName}" to vault.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error moving to vault: $e')));
      }
      // If adding to hidden box failed, you might want to avoid deleting from the original box,
      // or implement more sophisticated rollback logic. For now, we proceed with deletion
      // if put succeeded.
    }
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
    _tapTimer?.cancel(); // Cancel tap timer
    _recorder?.closeRecorder().catchError(
      (e) => print("Error closing recorder: $e"),
    );
    _recorder = null;
    _player?.closePlayer().catchError((e) => print("Error closing player: $e"));
    _player = null;
    super.dispose();
  }

  // --- Hidden Vault Access Methods ---
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
        loadedMethod = HiddenAccessTriggerMethod.longPressAppBar;
      }
    }
    if (!HiddenAccessTriggerMethod.values.contains(loadedMethod)) {
      loadedMethod = HiddenAccessTriggerMethod.longPressAppBar;
    }
    if (mounted && _selectedMethod != loadedMethod) {
      setState(() {
        _selectedMethod = loadedMethod;
      });
    } else if (!mounted && _selectedMethod != loadedMethod) {
      _selectedMethod = loadedMethod;
    }
    print("Loaded hidden access method: $_selectedMethod");
  }

  String _getHiddenAccessMethodDescription(HiddenAccessTriggerMethod method) {
    switch (method) {
      case HiddenAccessTriggerMethod.longPressAppBar:
        return "Long-press (Hold) App Bar";
      case HiddenAccessTriggerMethod.tripleTapAppBar:
        return "Triple-tap App Bar";
      case HiddenAccessTriggerMethod.pinchInScreen:
        return "Pinch In on Screen";
      case HiddenAccessTriggerMethod.pinchOutScreen:
        return "Pinch Out on Screen";
    }
  }

  Future<void> _triggerHiddenScreenAccess() async {
    if (_isGestureAccessActive || !mounted) return; // Debounce
    setState(() => _isGestureAccessActive = true);
    print("Attempting to trigger hidden screen access via $_selectedMethod...");

    _tapCount = 0; // Reset tap count for gesture-based triggers
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
        builder: (BuildContext dialogContext) {
          return EnterPasswordDialog(
            passwordService: _passwordService,
            onPasswordEntered: (bool passwordCorrect) {
              if (passwordCorrect) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HiddenRecordingsScreen(),
                  ),
                ).then((_) => _resetGestureAccessFlags());
              } else {
                _resetGestureAccessFlags();
              }
            },
          );
        },
      );
    } else {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return CreatePasswordDialog(
            passwordService: _passwordService,
            onPasswordSet: (bool passwordCreated) {
              if (passwordCreated && mounted) {
                showCustomSnackBar(
                  context: context,
                  message: "Password set! Trigger gesture again to access.",
                  iconColor: Colors.green,
                  duration: const Duration(seconds: 3),
                );
              }
              _resetGestureAccessFlags();
            },
          );
        },
      );
    }
  }

  void _resetGestureAccessFlags() {
    if (mounted) {
      setState(() {
        _isGestureAccessActive = false;
      });
      print("Gesture access flags reset.");
    }
  }

  void _handleTripleTap() {
    if (_isGestureAccessActive) return;
    _tapCount++;
    _tapTimer?.cancel();

    if (_tapCount == 3) {
      print("Triple Tap on AppBar detected!");
      _triggerHiddenScreenAccess(); // This will set _isGestureAccessActive
      _tapCount = 0;
    } else {
      _tapTimer = Timer(Duration(milliseconds: _tripleTapMilliseconds), () {
        if (mounted) {
          _tapCount = 0;
        }
      });
    }
  }
  // --- End Hidden Vault Access Methods ---

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

  void _onCategorySelected(Map<String, dynamic>? category) {
    if (_isRecording) return;
    setState(() {
      _selectedCategoryData = category;
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
      onActionPressed: () {
        box.put(entry.id, entry);
      },
      duration: const Duration(seconds: 4),
      leadingIcon: Icons.delete_forever_rounded,
      iconColor: theme.colorScheme.secondary,
    ).closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        if (!box.containsKey(entry.id)) {
          _deleteRecordingFile(deletedFilePath);
        }
      }
    });
  }

  // --- Pinch Gesture Handlers for Screen Body ---
  void _handleScreenScaleStart(ScaleStartDetails details) {
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
    if (details.pointerCount < 2) return;
    // _isGestureAccessActive is already used by _triggerHiddenScreenAccess for debounce
    // No need to set it here, let _triggerHiddenScreenAccess handle it.
    print("Screen pinch gesture started");
  }

  void _handleScreenScaleUpdate(ScaleUpdateDetails details) {
    if (_isGestureAccessActive) return; // Already processing a gesture
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
    if (details.pointerCount < 2) return;

    final currentScale = details.scale;
    print("Screen pinch update: scale = $currentScale");

    if (_selectedMethod == HiddenAccessTriggerMethod.pinchInScreen &&
        currentScale < 0.7) {
      print("Pinch In on Screen detected!");
      _triggerHiddenScreenAccess(); // This will set _isGestureAccessActive
    } else if (_selectedMethod == HiddenAccessTriggerMethod.pinchOutScreen &&
        currentScale > 1.5) {
      print("Pinch Out on Screen detected!");
      _triggerHiddenScreenAccess(); // This will set _isGestureAccessActive
    }
  }

  void _handleScreenScaleEnd(ScaleEndDetails details) {
    if (_selectedMethod != HiddenAccessTriggerMethod.pinchInScreen &&
        _selectedMethod != HiddenAccessTriggerMethod.pinchOutScreen)
      return;
    // _isGestureAccessActive is reset by _triggerHiddenScreenAccess flow
    print("Screen pinch gesture ended");
  }
  // --- End Pinch Gesture Handlers ---

  Widget _buildAppBar(BuildContext context) {
    // Added context parameter
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
            _loadHiddenAccessPreference(); // Reload preference after returning from settings
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
      case HiddenAccessTriggerMethod.pinchInScreen:
      case HiddenAccessTriggerMethod.pinchOutScreen:
      default:
        return appBarWidget;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget mainContent = Scaffold(
      appBar: PreferredSize(
        // Added PreferredSize for AppBar
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(context), // Pass context
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
                  child: RecordingsListView(
                    onShare: _shareRecording,
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

    if (_selectedMethod == HiddenAccessTriggerMethod.pinchInScreen ||
        _selectedMethod == HiddenAccessTriggerMethod.pinchOutScreen) {
      return GestureDetector(
        onScaleStart: _isGestureAccessActive ? null : _handleScreenScaleStart,
        onScaleUpdate: _isGestureAccessActive ? null : _handleScreenScaleUpdate,
        onScaleEnd: _isGestureAccessActive ? null : _handleScreenScaleEnd,
        behavior: HitTestBehavior.opaque,
        child: mainContent,
      );
    } else {
      return mainContent;
    }
  }
}
