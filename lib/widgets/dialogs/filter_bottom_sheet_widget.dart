import 'package:echolog/models/filter_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

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

class _FilterBottomSheetWidgetState extends State<FilterBottomSheetWidget>
    with TickerProviderStateMixin {
  late FilterState _currentFilters;
  late TextEditingController _nameController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.initialFilters;
    _nameController = TextEditingController(
      text: _currentFilters.searchNameQuery,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              surface: theme.colorScheme.surface,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              headerBackgroundColor: theme.colorScheme.primary,
              headerForegroundColor: theme.colorScheme.onPrimary,
              dayStyle: GoogleFonts.poppins(),
              weekdayStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              yearStyle: GoogleFonts.poppins(),
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

  int _getActiveFiltersCount() {
    int count = 0;
    if (_currentFilters.moodName != null) count++;
    if (_currentFilters.durationRangeSeconds != null) count++;
    if (_currentFilters.searchNameQuery?.isNotEmpty == true) count++;
    if (_currentFilters.dateRecordedRange != null) count++;
    return count;
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, trailing: trailing),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeFiltersCount = _getActiveFiltersCount();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Recordings',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (activeFiltersCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$activeFiltersCount active',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood Filter
                      _buildFilterSection(
                        title: 'Mood',
                        trailing: _currentFilters.moodName != null
                            ? TextButton.icon(
                                onPressed: () => setState(() {
                                  _currentFilters = _currentFilters.copyWith(
                                    clearMoodName: true,
                                  );
                                }),
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
                                label: Text(
                                  'Clear',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                            : null,
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            _buildMoodChip(
                              'All',
                              isSelected: _currentFilters.moodName == null,
                              onTap: () => setState(() {
                                _currentFilters = _currentFilters.copyWith(
                                  clearMoodName: true,
                                );
                              }),
                            ),
                            ...widget.categories.map((category) {
                              final String mood = category['name'] as String;
                              return _buildMoodChip(
                                mood,
                                isSelected: _currentFilters.moodName == mood,
                                onTap: () => setState(() {
                                  _currentFilters = _currentFilters.copyWith(
                                    moodName: mood,
                                  );
                                }),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      // Duration Filter
                      _buildFilterSection(
                        title: 'Duration',
                        trailing: _currentFilters.durationRangeSeconds != null
                            ? TextButton.icon(
                                onPressed: () => setState(() {
                                  _currentFilters = _currentFilters.copyWith(
                                    clearDurationRangeSeconds: true,
                                  );
                                }),
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
                                label: Text(
                                  'Clear',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDurationRange(
                                  _currentFilters.durationRangeSeconds,
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                              ),
                              child: RangeSlider(
                                values:
                                    _currentFilters.durationRangeSeconds ??
                                    const RangeValues(
                                      0,
                                      FilterState.maxDurationSliderValue,
                                    ),
                                min: 0,
                                max: FilterState.maxDurationSliderValue,
                                divisions:
                                    (FilterState.maxDurationSliderValue / 60)
                                        .round(),
                                labels: RangeLabels(
                                  _formatSliderDuration(
                                    Duration(
                                      seconds:
                                          (_currentFilters
                                                      .durationRangeSeconds ??
                                                  const RangeValues(0, 0))
                                              .start
                                              .round(),
                                    ),
                                  ),
                                  _formatSliderDuration(
                                    Duration(
                                      seconds:
                                          (_currentFilters
                                                      .durationRangeSeconds ??
                                                  const RangeValues(
                                                    0,
                                                    FilterState
                                                        .maxDurationSliderValue,
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
                            ),
                          ],
                        ),
                      ),

                      // Name Filter
                      _buildFilterSection(
                        title: 'Name Contains',
                        trailing: _nameController.text.isNotEmpty
                            ? TextButton.icon(
                                onPressed: () {
                                  _nameController.clear();
                                  setState(() {
                                    _currentFilters = _currentFilters.copyWith(
                                      searchNameQuery: '',
                                    );
                                  });
                                },
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
                                label: Text(
                                  'Clear',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                            : null,
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            hintStyle: GoogleFonts.poppins(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _currentFilters = _currentFilters.copyWith(
                                searchNameQuery: value,
                              );
                            });
                          },
                          style: GoogleFonts.poppins(),
                        ),
                      ),

                      // Date Filter
                      _buildFilterSection(
                        title: 'Date Recorded',
                        trailing: _currentFilters.dateRecordedRange != null
                            ? TextButton.icon(
                                onPressed: () => setState(() {
                                  _currentFilters = _currentFilters.copyWith(
                                    clearDateRecordedRange: true,
                                  );
                                }),
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
                                label: Text(
                                  'Clear',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDateRange(
                                  _currentFilters.dateRecordedRange,
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _selectDateRange(context),
                                icon: Icon(
                                  Icons.calendar_month_outlined,
                                  size: 20,
                                  color: theme.colorScheme.onSurface,
                                ),
                                label: Text(
                                  'Select Date Range',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.surfaceVariant,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onApplyFilters(_currentFilters.clearAll());
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          _currentFilters = _currentFilters.copyWith(
                            searchNameQuery: _nameController.text,
                          );
                          widget.onApplyFilters(_currentFilters);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Filters',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodChip(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
