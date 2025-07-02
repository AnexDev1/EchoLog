import 'package:echolog/hive_box_names.dart';
import 'package:echolog/main.dart';
import 'package:echolog/models/custom_category.dart';
import 'package:echolog/models/filter_state.dart';
import 'package:echolog/models/recording_entry.dart';
import 'package:echolog/widgets/filter_bottom_sheet_widget.dart';
import 'package:echolog/widgets/recording_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

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

class _RecordingsListPageState extends State<RecordingsListPage> {
  FilterState _currentFilters = FilterState();
  final TextEditingController _searchController = TextEditingController();

  // State for bulk selection
  bool _isSelectionMode = false;
  final Set<String> _selectedRecordingIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text != _currentFilters.searchNameQuery) {
        setState(() {
          _currentFilters = _currentFilters.copyWith(
            searchNameQuery: _searchController.text,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Selection Mode Logic ---

  void _enterSelectionMode(String recordingId) {
    setState(() {
      _isSelectionMode = true;
      _selectedRecordingIds.add(recordingId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedRecordingIds.clear();
    });
  }

  void _toggleSelection(String recordingId) {
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            "Delete $count ${count == 1 ? 'Recording' : 'Recordings'}?",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            "Are you sure you want to permanently delete these recordings?\n\nThis action cannot be undone.",
            style: GoogleFonts.poppins(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Delete",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performBulkDelete();
              },
            ),
          ],
        );
      },
    );
  }

  // --- End Selection Mode Logic ---

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
        onApplyFilters: (updatedFilters) {
          setState(() {
            _currentFilters = updatedFilters;
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
    // Professional fix: Always rebuild the list when playback progress changes, for real-time UI updates
    return Scaffold(
      body: ValueListenableBuilder<Box<RecordingEntry>>(
        valueListenable: Hive.box<RecordingEntry>(
          recordingsBoxName,
        ).listenable(),
        builder: (context, box, _) {
          final recordings = _getFilteredRecordings(box);
          // NEW: Listen to the currently playing file ID to rebuild the whole list when it changes
          return ValueListenableBuilder<String?>(
            valueListenable: widget.currentlyPlayingFileIdNotifier,
            builder: (context, currentlyPlayingFileId, __) {
              // NEW: Listen to the actual playing state
              return ValueListenableBuilder<bool>(
                valueListenable: widget.isActuallyPlayingNotifier,
                builder: (context, isActuallyPlaying, __) {
                  // Listen to playback progress for real-time updates
                  return CustomScrollView(
                    slivers: [
                      _isSelectionMode
                          ? _buildSelectionAppBar(context)
                          : _buildDynamicAppBar(context, recordings.length),
                      if (recordings.isEmpty && !_isSelectionMode)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(context),
                        )
                      else
                        _buildGroupedList(recordings, currentlyPlayingFileId),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectionAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      foregroundColor: theme.colorScheme.primary,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
        tooltip: "Cancel Selection",
      ),
      title: Text(
        '${_selectedRecordingIds.length} selected',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _showBulkDeleteConfirmationDialog,
          tooltip: "Delete Selected",
        ),
      ],
    );
  }

  Widget _buildDynamicAppBar(BuildContext context, int count) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 240.0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0.5,
      title: Text(
        'All Recordings',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeader(context, count),
        collapseMode: CollapseMode.pin,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Echolog',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? "entry" : "entries"} found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by title or content...',
                      prefixIcon: Icon(Icons.search, color: theme.hintColor),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(
                        0.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    _currentFilters.isAnyFilterActive
                        ? Icons.filter_list_rounded
                        : Icons.filter_list_off_outlined,
                    color: _currentFilters.isAnyFilterActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: () {
                    final customCategoryBox = Hive.box<CustomCategory>(
                      HiveBoxNames.customCategoriesBoxName,
                    );
                    _showAdvancedFilterSheet(
                      _getAllCategories(customCategoryBox),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceVariant
                        .withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentFilters.isAnyFilterActive
                ? Icons.search_off_rounded
                : Icons.history_rounded,
            size: 80,
            color: theme.colorScheme.surfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            _currentFilters.isAnyFilterActive
                ? 'No Matches Found'
                : 'Your Story Awaits',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentFilters.isAnyFilterActive
                ? 'Try adjusting your search or filters.'
                : 'Record your first entry to see it here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    List<RecordingEntry> recordings,
    String? currentlyPlayingFileId,
  ) {
    Map<String, List<RecordingEntry>> grouped = {};
    for (var entry in recordings) {
      String header = _formatDateHeader(entry.dateRecorded);
      if (grouped[header] == null) grouped[header] = [];
      grouped[header]!.add(entry);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        String header = grouped.keys.elementAt(index);
        List<RecordingEntry> groupItems = grouped[header]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              child: Text(
                header,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...groupItems.map((entry) {
              final isSelectedForPlayback = currentlyPlayingFileId == entry.id;
              final isSelectedForBulk = _selectedRecordingIds.contains(
                entry.id,
              );

              // The card for the currently playing item needs to listen to progress
              if (isSelectedForPlayback) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: widget.playbackProgress,
                  builder: (context, progress, _) {
                    // Also listen to the play/pause state for real-time updates
                    return ValueListenableBuilder<bool>(
                      valueListenable: widget.isActuallyPlayingNotifier,
                      builder: (context, isActuallyPlaying, __) {
                        return RecordingCard(
                          key: ValueKey('list_${entry.id}_playing'),
                          recording: entry,
                          isPlaying: isSelectedForPlayback && isActuallyPlaying,
                          playbackProgressPercent:
                              (widget.totalDuration.inMilliseconds > 0)
                              ? progress.inMilliseconds /
                                    widget.totalDuration.inMilliseconds
                              : 0.0,
                          onPlayToggle: () => widget.onRecordingToggled(entry),
                          onSeekRequest: widget.onSeekRequest,
                          onDelete: () => widget.onDelete(entry),
                          onShare: () => widget.onShareFile(entry),
                          onTranscribe: () =>
                              widget.onGenerateTranscription(entry),
                          onMoveToVault: () => widget.onToggleHidden(entry),
                          onEdit: () => widget.onEditCategory(entry),
                          isSelected: isSelectedForBulk,
                          onLongPress: () => _enterSelectionMode(entry.id),
                          onSelect: _isSelectionMode
                              ? () => _toggleSelection(entry.id)
                              : null,
                        );
                      },
                    );
                  },
                );
              } else {
                // Render a static card if it's not the one playing
                return RecordingCard(
                  key: ValueKey('list_${entry.id}_static'),
                  recording: entry,
                  isPlaying: false, // Not playing
                  playbackProgressPercent: 0.0,
                  onPlayToggle: () => widget.onRecordingToggled(entry),
                  onSeekRequest:
                      null, // No seeking if not the currently playing track
                  onDelete: () => widget.onDelete(entry),
                  onShare: () => widget.onShareFile(entry),
                  onTranscribe: () => widget.onGenerateTranscription(entry),
                  onMoveToVault: () => widget.onToggleHidden(entry),
                  onEdit: () => widget.onEditCategory(entry),
                  isSelected: isSelectedForBulk,
                  onLongPress: () => _enterSelectionMode(entry.id),
                  onSelect: _isSelectionMode
                      ? () => _toggleSelection(entry.id)
                      : null,
                );
              }
            }).toList(),
          ],
        );
      }, childCount: grouped.length),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) return 'Today';
    if (dateToCompare == yesterday) return 'Yesterday';
    return DateFormat.yMMMMd().format(date);
  }
}
