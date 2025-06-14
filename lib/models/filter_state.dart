import 'package:flutter/material.dart'; // For RangeValues and DateTimeRange

class FilterState {
  final String? moodName;
  final RangeValues? durationRangeSeconds; // Duration in seconds
  final String? searchNameQuery;
  final DateTimeRange? dateRecordedRange;

  // Define a practical maximum duration for the slider, e.g., 2 hours in seconds
  static const double maxDurationSliderValue = 2 * 60 * 60; // 7200 seconds

  FilterState({
    this.moodName,
    this.durationRangeSeconds,
    this.searchNameQuery,
    this.dateRecordedRange,
  });

  bool get isAnyFilterActive {
    return moodName != null ||
        durationRangeSeconds != null ||
        (searchNameQuery != null && searchNameQuery!.isNotEmpty) ||
        dateRecordedRange != null;
  }

  FilterState copyWith({
    String? moodName,
    bool clearMoodName = false,
    RangeValues? durationRangeSeconds,
    bool clearDurationRangeSeconds = false,
    String? searchNameQuery,
    bool clearSearchNameQuery = false,
    DateTimeRange? dateRecordedRange,
    bool clearDateRecordedRange = false,
  }) {
    return FilterState(
      moodName: clearMoodName ? null : (moodName ?? this.moodName),
      durationRangeSeconds: clearDurationRangeSeconds
          ? null
          : (durationRangeSeconds ?? this.durationRangeSeconds),
      searchNameQuery: clearSearchNameQuery
          ? null
          : (searchNameQuery ?? this.searchNameQuery),
      dateRecordedRange: clearDateRecordedRange
          ? null
          : (dateRecordedRange ?? this.dateRecordedRange),
    );
  }

  FilterState clearAll() {
    return FilterState();
  }
}
