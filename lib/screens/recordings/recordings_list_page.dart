import 'package:echolog/hive_box_names.dart';
import 'package:echolog/main.dart';
import 'package:echolog/models/custom_category.dart';
import 'package:echolog/models/filter_state.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/providers/transcription_status_provider.dart';
import 'package:echolog/screens/home/widgets/recording_list_item_widget.dart';
import 'package:echolog/widgets/dialogs/filter_bottom_sheet_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class RecordingsListPage extends StatefulWidget {
  final List<RecordingEntry> allRecordings;
  final Function(RecordingEntry) onRecordingToggled;
  final Function(double) onSeekRequest;
  final ValueNotifier<String?> currentlyPlayingFileIdNotifier;
  final ValueNotifier<Duration> playbackProgress;
  final Duration totalDuration;
  final ValueNotifier<bool> isActuallyPlayingNotifier;
  final Function(RecordingEntry) onDelete;
  final Function(RecordingEntry) onShareFile;
  final Function(RecordingEntry) onShareTranscription;
  final Function(RecordingEntry, String) onRename;
  final Function(RecordingEntry) onEditCategory;
  final Function(RecordingEntry) onToggleHidden;
  final Function(RecordingEntry) onGenerateTranscription;

  const RecordingsListPage({
    super.key,
    required this.allRecordings,
    required this.onRecordingToggled,
    required this.onSeekRequest,
    required this.currentlyPlayingFileIdNotifier,
    required this.playbackProgress,
    required this.totalDuration,
    required this.isActuallyPlayingNotifier,
    required this.onDelete,
    required this.onShareFile,
    required this.onShareTranscription,
    required this.onRename,
    required this.onEditCategory,
    required this.onToggleHidden,
    required this.onGenerateTranscription,
  });

  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage>
    with TickerProviderStateMixin {
  static final Set<String> _expandedTranscriptionIds = <String>{};
  FilterState _currentFilters = FilterState();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedRecordingIds = {};

  // Search focus state
  bool _isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Prevent auto-play of latest recording on page open
    widget.currentlyPlayingFileIdNotifier.value = null;
    widget.isActuallyPlayingNotifier.value = false;
    _initializeAnimations();
    _setupListeners();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

  void _setupListeners() {
    _searchController.addListener(() {
      if (_searchController.text != _currentFilters.searchNameQuery) {
        setState(() {
          _currentFilters = _currentFilters.copyWith(
            searchNameQuery: _searchController.text,
          );
        });
      }
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 100) {
        if (!_fabAnimationController.isCompleted) {
          _fabAnimationController.forward();
        }
      } else {
        if (_fabAnimationController.isCompleted) {
          _fabAnimationController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  // Transcription management
  void _toggleTranscription(String entryId) {
    setState(() {
      if (_expandedTranscriptionIds.contains(entryId)) {
        _expandedTranscriptionIds.remove(entryId);
      } else {
        _expandedTranscriptionIds.clear();
        _expandedTranscriptionIds.add(entryId);
      }
    });
  }

  // Selection mode methods
  void _enterSelectionMode(String recordingId) {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedRecordingIds.add(recordingId);
    });
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedRecordingIds.clear();
    });
  }

  void _toggleSelection(String recordingId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedRecordingIds.contains(recordingId)) {
        _selectedRecordingIds.remove(recordingId);
      } else {
        _selectedRecordingIds.add(recordingId);
      }
      if (_selectedRecordingIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _performBulkDelete() {
    final box = Hive.box<RecordingEntry>(HiveBoxNames.recordingsBoxName);
    final entriesToDelete = _selectedRecordingIds
        .map((id) => box.get(id))
        .where((entry) => entry != null)
        .toList();

    for (final entry in entriesToDelete) {
      widget.onDelete(entry!);
    }
    _exitSelectionMode();
  }

  void _showBulkDeleteConfirmationDialog() {
    final theme = Theme.of(context);
    final count = _selectedRecordingIds.length;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: theme.colorScheme.surface,
          elevation: 8,
          title: Text(
            "Delete $count ${count == 1 ? 'Recording' : 'Recordings'}?",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            "This action cannot be undone. The selected recordings will be permanently deleted.",
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                "Cancel",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performBulkDelete();
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Delete",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Filter methods
  void _showAdvancedFilterSheet(
    List<Map<String, dynamic>> allCategoriesForFilter,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheetWidget(
        initialFilters: _currentFilters,
        categories: allCategoriesForFilter,
        onApplyFilters: (updatedFilters) {
          setState(() {
            _currentFilters = updatedFilters as FilterState;
            final currentSearch = _currentFilters.searchNameQuery ?? '';
            if (_searchController.text != currentSearch) {
              _searchController.text = currentSearch;
            }
          });
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getAllCategories(
    Box<CustomCategory> customCategoryBox,
  ) {
    final predefinedCategories = [
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
    final customCategories = customCategoryBox.values
        .map((c) => c.toMap())
        .toList();
    return [...predefinedCategories, ...customCategories];
  }

  List<RecordingEntry> _getFilteredRecordings(Box<RecordingEntry> box) {
    var recordings = box.values.toList();
    if (_currentFilters.isAnyFilterActive) {
      if (_currentFilters.moodName != null &&
          _currentFilters.moodName!.isNotEmpty) {
        recordings = recordings
            .where((r) => r.moodName == _currentFilters.moodName)
            .toList();
      }
      if (_currentFilters.dateRecordedRange != null) {
        final startDate = _currentFilters.dateRecordedRange!.start;
        final inclusiveEndDate = _currentFilters.dateRecordedRange!.end.add(
          const Duration(days: 1),
        );
        recordings = recordings.where((r) {
          final recordDate = r.dateRecorded;
          return !recordDate.isBefore(startDate) &&
              recordDate.isBefore(inclusiveEndDate);
        }).toList();
      }
      if (_currentFilters.searchNameQuery != null &&
          _currentFilters.searchNameQuery!.trim().isNotEmpty) {
        final query = _currentFilters.searchNameQuery!.toLowerCase().trim();
        recordings = recordings.where((r) {
          return r.displayName.toLowerCase().contains(query) ||
              (r.transcription?.toLowerCase().contains(query) ?? false) ||
              (r.summaryPreview?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    }
    recordings.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
    return recordings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: ValueListenableBuilder<Box<RecordingEntry>>(
        valueListenable: Hive.box<RecordingEntry>(
          recordingsBoxName,
        ).listenable(),
        builder: (context, box, _) {
          final recordings = _getFilteredRecordings(box);

          return ValueListenableBuilder<String?>(
            valueListenable: widget.currentlyPlayingFileIdNotifier,
            builder: (context, currentlyPlayingFileId, __) {
              return ValueListenableBuilder<bool>(
                valueListenable: widget.isActuallyPlayingNotifier,
                builder: (context, isActuallyPlaying, __) {
                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _isSelectionMode
                          ? _buildSelectionAppBar(context)
                          : _buildModernAppBar(context, recordings.length),
                      if (recordings.isEmpty && !_isSelectionMode)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context),
                        )
                      else
                        _buildRecordingsList(
                          recordings,
                          currentlyPlayingFileId,
                        ),
                      // Add bottom padding for better scroll experience
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildSelectionAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
      foregroundColor: theme.colorScheme.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelectionMode,
        tooltip: "Cancel Selection",
      ),
      title: Text(
        '${_selectedRecordingIds.length} selected',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _showBulkDeleteConfirmationDialog,
          tooltip: "Delete Selected",
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildModernAppBar(BuildContext context, int count) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: false,
      expandedHeight: 280.0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withOpacity(0.95),
              ],
            ),
          ),
          child: _buildModernHeader(context, count),
        ),
        collapseMode: CollapseMode.parallax,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                theme.dividerColor.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header text
            Text(
              'Recordings',
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count == 0
                  ? 'No recordings yet'
                  : '$count ${count == 1 ? "recording" : "recordings"}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),

            // Search and filter row
            Row(
              children: [
                Expanded(child: _buildSearchField(theme)),
                const SizedBox(width: 12),
                _buildFilterButton(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSearchFocused
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search recordings...',
          hintStyle: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              size: 20,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
      ),
    );
  }

  Widget _buildFilterButton(ThemeData theme) {
    final isActive = _currentFilters.isAnyFilterActive;
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          isActive ? Icons.filter_list_rounded : Icons.tune_rounded,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.6),
          size: 20,
        ),
        onPressed: () {
          final customCategoryBox = Hive.box<CustomCategory>(
            HiveBoxNames.customCategoriesBoxName,
          );
          _showAdvancedFilterSheet(_getAllCategories(customCategoryBox));
        },
        tooltip: 'Filter recordings',
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _currentFilters.isAnyFilterActive
                    ? Icons.search_off_rounded
                    : Icons.mic_none_rounded,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _currentFilters.isAnyFilterActive
                  ? 'No matches found'
                  : 'No recordings yet',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentFilters.isAnyFilterActive
                  ? 'Try adjusting your search or filters'
                  : 'Start recording to see your entries here',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsList(
    List<RecordingEntry> recordings,
    String? currentlyPlayingFileId,
  ) {
    Map<String, List<RecordingEntry>> grouped = {};
    for (var entry in recordings) {
      String header = _formatDateHeader(entry.dateRecorded);
      if (grouped[header] == null) grouped[header] = [];
      grouped[header]!.add(entry);
    }

    return Consumer<TranscriptionStatusProvider>(
      builder: (context, transcriptionStatus, _) {
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            String header = grouped.keys.elementAt(index);
            List<RecordingEntry> groupItems = grouped[header]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text(
                    header,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Recordings in this group
                ...groupItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final recording = entry.value;
                  final isSelectedForPlayback =
                      widget.currentlyPlayingFileIdNotifier.value ==
                      recording.id;
                  final isSelectedForBulk = _selectedRecordingIds.contains(
                    recording.id,
                  );
                  final isTranscribingThis =
                      transcriptionStatus.isTranscribing &&
                      transcriptionStatus.currentEntryId == recording.id;
                  final double? transcriptionProgress = isTranscribingThis
                      ? transcriptionStatus.progress
                      : null;
                  final String? transcriptionStatusText = isTranscribingThis
                      ? transcriptionStatus.statusText
                      : null;
                  final bool isTranscriptionExpanded = _expandedTranscriptionIds
                      .contains(recording.id);

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      idx == 0 ? 0 : 8,
                      16,
                      idx == groupItems.length - 1 ? 16 : 0,
                    ),
                    child: RecordingListItemWidget(
                      key: ValueKey('listitem_${recording.id}'),
                      entry: recording,
                      isPlaying: isSelectedForPlayback,
                      isSelected: isSelectedForBulk,
                      onPlayPause: widget.onRecordingToggled,
                      onMoveToVault: widget.onToggleHidden,
                      onShare: widget.onShareFile,
                      onTranscribe: widget.onGenerateTranscription,
                      onDelete: widget.onDelete,
                      playbackProgressNotifier: isSelectedForPlayback
                          ? widget.playbackProgress
                          : null,
                      isActuallyPlayingNotifier: isSelectedForPlayback
                          ? widget.isActuallyPlayingNotifier
                          : null,
                      totalDuration: isSelectedForPlayback
                          ? widget.totalDuration
                          : null,
                      onSeekRequest: isSelectedForPlayback
                          ? widget.onSeekRequest
                          : null,
                      transcriptionProgress: transcriptionProgress,
                      transcriptionStatusText: transcriptionStatusText,
                      isTranscribing: isTranscribingThis,
                      isTranscriptionExpanded: isTranscriptionExpanded,
                      onToggleTranscription: () =>
                          _toggleTranscription(recording.id),
                      isTranscriptionHidden: !isTranscriptionExpanded,
                      onToggleTranscriptionVisibility: () =>
                          _toggleTranscription(recording.id),
                    ),
                  );
                }).toList(),
              ],
            );
          }, childCount: grouped.length),
        );
      },
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to recording screen
          Navigator.of(context).pop();
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text(
          'Record',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) return 'TODAY';
    if (dateToCompare == yesterday) return 'YESTERDAY';
    return DateFormat.yMMMMd().format(date).toUpperCase();
  }
}
