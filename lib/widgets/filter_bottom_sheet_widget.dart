import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/filter_state.dart'; // Import your FilterState model

class FilterBottomSheetWidget extends StatefulWidget {
  final FilterState initialFilters;
  final List<Map<String, dynamic>> categories; // For mood selection
  final Function(FilterState) onApplyFilters;

  const FilterBottomSheetWidget({
    super.key,
    required this.initialFilters,
    required this.categories,
    required this.onApplyFilters,
  });

  @override
  State<FilterBottomSheetWidget> createState() =>
      _FilterBottomSheetWidgetState();
}

class _FilterBottomSheetWidgetState extends State<FilterBottomSheetWidget> {
  late FilterState _currentFilters;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.initialFilters;
    _nameController = TextEditingController(
      text: _currentFilters.searchNameQuery,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _currentFilters.dateRecordedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ), // Allow picking future dates if relevant, or just DateTime.now()
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: isDark ? Colors.white : Colors.black,
              surface: isDark ? theme.colorScheme.surface : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black,
              background: isDark ? theme.colorScheme.background : Colors.white,
            ),
            dialogBackgroundColor: isDark
                ? theme.colorScheme.surface
                : Colors.white,
            textTheme: theme.textTheme.apply(
              bodyColor: isDark ? Colors.white : Colors.black,
              displayColor: isDark ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _currentFilters.dateRecordedRange) {
      setState(() {
        _currentFilters = _currentFilters.copyWith(dateRecordedRange: picked);
      });
    }
  }

  String _formatDurationRange(RangeValues? range) {
    if (range == null) return 'Any Duration';
    final start = Duration(seconds: range.start.round());
    final end = Duration(seconds: range.end.round());
    return '${_formatSliderDuration(start)} - ${_formatSliderDuration(end)}';
  }

  String _formatSliderDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}h ${twoDigitMinutes}m";
    } else if (duration.inMinutes > 0) {
      return "${twoDigitMinutes}m ${twoDigitSeconds}s";
    } else {
      return "${twoDigitSeconds}s";
    }
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'Any Date';
    final DateFormat formatter = DateFormat('MMM d, yyyy');
    return '${formatter.format(range.start)} - ${formatter.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
        left: 16,
        right: 16,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Filter Recordings',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Mood Filter
            Text(
              'Mood',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(
                  label: Text(
                    'All',
                    style: GoogleFonts.poppins(
                      color: _currentFilters.moodName == null
                          ? theme.colorScheme.onPrimary
                          : null,
                    ),
                  ),
                  selected: _currentFilters.moodName == null,
                  selectedColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    setState(() {
                      _currentFilters = _currentFilters.copyWith(
                        clearMoodName: true,
                      );
                    });
                  },
                ),
                ...widget.categories.map((category) {
                  final String mood = category['name'] as String;
                  return ChoiceChip(
                    label: Text(
                      mood,
                      style: GoogleFonts.poppins(
                        color: _currentFilters.moodName == mood
                            ? theme.colorScheme.onPrimary
                            : null,
                      ),
                    ),
                    selected: _currentFilters.moodName == mood,
                    selectedColor: theme.colorScheme.primary,
                    avatar: _currentFilters.moodName == mood
                        ? Icon(
                            Icons.check,
                            color: theme.colorScheme.onPrimary,
                            size: 16,
                          )
                        : null,
                    onSelected: (selected) {
                      setState(() {
                        _currentFilters = _currentFilters.copyWith(
                          moodName: mood,
                        );
                      });
                    },
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 16),

            // Duration Filter
            Text(
              'Duration: ${_formatDurationRange(_currentFilters.durationRangeSeconds)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            RangeSlider(
              values:
                  _currentFilters.durationRangeSeconds ??
                  const RangeValues(0, FilterState.maxDurationSliderValue),
              min: 0,
              max: FilterState.maxDurationSliderValue,
              divisions: (FilterState.maxDurationSliderValue / 60)
                  .round(), // divisions per minute
              labels: RangeLabels(
                _formatSliderDuration(
                  Duration(
                    seconds:
                        (_currentFilters.durationRangeSeconds ??
                                const RangeValues(0, 0))
                            .start
                            .round(),
                  ),
                ),
                _formatSliderDuration(
                  Duration(
                    seconds:
                        (_currentFilters.durationRangeSeconds ??
                                const RangeValues(
                                  0,
                                  FilterState.maxDurationSliderValue,
                                ))
                            .end
                            .round(),
                  ),
                ),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(
                    durationRangeSeconds: values,
                  );
                });
              },
            ),
            TextButton(
              onPressed: () => setState(
                () => _currentFilters = _currentFilters.copyWith(
                  clearDurationRangeSeconds: true,
                ),
              ),
              child: Text(
                'Clear Duration Filter',
                style: GoogleFonts.poppins(color: theme.colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 16),

            // Name Filter
            Text(
              'Name Contains',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: GoogleFonts.poppins(),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _nameController.clear();
                          setState(() {
                            _currentFilters = _currentFilters.copyWith(
                              searchNameQuery: '',
                            );
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                // Debounce could be added here for performance if needed
                setState(() {
                  _currentFilters = _currentFilters.copyWith(
                    searchNameQuery: value,
                  );
                });
              },
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),

            // Date Filter
            Text(
              'Date Recorded: ${_formatDateRange(_currentFilters.dateRecordedRange)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Select Range', style: GoogleFonts.poppins()),
                  onPressed: () => _selectDateRange(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _currentFilters = _currentFilters.copyWith(
                      clearDateRecordedRange: true,
                    ),
                  ),
                  child: Text(
                    'Clear Date Filter',
                    style: GoogleFonts.poppins(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onApplyFilters(_currentFilters.clearAll());
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Clear All Filters',
                    style: GoogleFonts.poppins(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // Update search query from controller before applying
                    _currentFilters = _currentFilters.copyWith(
                      searchNameQuery: _nameController.text,
                    );
                    widget.onApplyFilters(_currentFilters);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                  ),
                  child: Text(
                    'Apply Filters',
                    style: GoogleFonts.poppins(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Padding for bottom
          ],
        ),
      ),
    );
  }
}
