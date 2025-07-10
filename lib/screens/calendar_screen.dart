import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  final List<DateTime> recordingDates; // Pass recording dates to show streaks

  const CalendarPage({Key? key, required this.recordingDates})
    : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  late DateTime _today;
  late List<List<DateTime>> _streaks;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _currentMonth = DateTime(_today.year, _today.month);
    _calculateStreaks();
  }

  void _calculateStreaks() {
    _streaks = [];
    if (widget.recordingDates.isEmpty) return;

    // Sort dates
    final sortedDates = widget.recordingDates.toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    List<DateTime> currentStreak = [sortedDates.first];

    for (int i = 1; i < sortedDates.length; i++) {
      final current = sortedDates[i];
      final previous = sortedDates[i - 1];

      // Check if dates are consecutive
      if (current.difference(previous).inDays == 1) {
        currentStreak.add(current);
      } else {
        // End current streak and start new one
        if (currentStreak.length > 1) {
          _streaks.add(List.from(currentStreak));
        }
        currentStreak = [current];
      }
    }

    // Add final streak if it has more than one day
    if (currentStreak.length > 1) {
      _streaks.add(currentStreak);
    }
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];

    for (int i = 0; i < lastDay.day; i++) {
      days.add(firstDay.add(Duration(days: i)));
    }

    return days;
  }

  int _getWeekdayOffset(DateTime firstDay) {
    // Get the weekday (1 = Monday, 7 = Sunday)
    // Convert to 0-6 where 0 = Sunday
    return (firstDay.weekday % 7);
  }

  bool _isDateInStreak(DateTime date) {
    return _streaks.any(
      (streak) => streak.any(
        (streakDate) =>
            streakDate.year == date.year &&
            streakDate.month == date.month &&
            streakDate.day == date.day,
      ),
    );
  }

  bool _hasRecording(DateTime date) {
    return widget.recordingDates.any(
      (recordingDate) =>
          recordingDate.year == date.year &&
          recordingDate.month == date.month &&
          recordingDate.day == date.day,
    );
  }

  List<DateTime> _getStreakForDate(DateTime date) {
    for (final streak in _streaks) {
      if (streak.any(
        (streakDate) =>
            streakDate.year == date.year &&
            streakDate.month == date.month &&
            streakDate.day == date.day,
      )) {
        return streak;
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _getDaysInMonth(_currentMonth);
    final firstDay = days.first;
    final weekdayOffset = _getWeekdayOffset(firstDay);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          DateFormat('MMMM yyyy').format(_currentMonth),
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.today_rounded, color: theme.colorScheme.primary),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_today.year, _today.month);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Navigation
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: theme.colorScheme.onBackground,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onBackground,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          // Calendar Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Weekday Headers
                  Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onBackground.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Calendar Grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                      itemCount: 42, // 6 weeks * 7 days
                      itemBuilder: (context, index) {
                        final adjustedIndex = index - weekdayOffset;

                        if (adjustedIndex < 0 || adjustedIndex >= days.length) {
                          return const SizedBox.shrink();
                        }

                        final date = days[adjustedIndex];
                        final isToday =
                            date.year == _today.year &&
                            date.month == _today.month &&
                            date.day == _today.day;
                        final hasRecording = _hasRecording(date);
                        final isInStreak = _isDateInStreak(date);
                        final streak = _getStreakForDate(date);

                        return _buildCalendarDay(
                          date,
                          isToday,
                          hasRecording,
                          isInStreak,
                          streak,
                          theme,
                        );
                      },
                    ),
                  ),

                  // Legend
                  _buildLegend(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(
    DateTime date,
    bool isToday,
    bool hasRecording,
    bool isInStreak,
    List<DateTime> streak,
    ThemeData theme,
  ) {
    Color backgroundColor = Colors.transparent;
    Color textColor = theme.colorScheme.onBackground;
    Color borderColor = Colors.transparent;

    if (isToday) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (hasRecording) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.3);
      textColor = theme.colorScheme.onBackground;
    }

    if (isToday) {
      borderColor = theme.colorScheme.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isToday ? 2 : 0),
      ),
      child: Stack(
        children: [
          // Streak connection lines
          if (isInStreak && streak.length > 1)
            _buildStreakConnections(date, streak, theme),

          // Day content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (hasRecording && !isToday)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakConnections(
    DateTime date,
    List<DateTime> streak,
    ThemeData theme,
  ) {
    final dateIndex = streak.indexWhere(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    if (dateIndex == -1) return const SizedBox.shrink();

    final isFirst = dateIndex == 0;
    final isLast = dateIndex == streak.length - 1;

    return Positioned.fill(
      child: CustomPaint(
        painter: StreakConnectionPainter(
          color: theme.colorScheme.secondary.withOpacity(0.6),
          showLeft: !isFirst,
          showRight: !isLast,
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(theme.colorScheme.primary, 'Today', theme),
              _buildLegendItem(
                theme.colorScheme.primary.withOpacity(0.3),
                'Has Recording',
                theme,
              ),
              _buildLegendItem(
                theme.colorScheme.secondary.withOpacity(0.6),
                'Streak',
                theme,
                isLine: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label,
    ThemeData theme, {
    bool isLine = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isLine ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(4),
            border: isLine ? Border.all(color: color, width: 2) : null,
          ),
          child: isLine
              ? Center(child: Container(width: 12, height: 2, color: color))
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class StreakConnectionPainter extends CustomPainter {
  final Color color;
  final bool showLeft;
  final bool showRight;

  StreakConnectionPainter({
    required this.color,
    required this.showLeft,
    required this.showRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;

    if (showLeft) {
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width / 2, centerY),
        paint,
      );
    }

    if (showRight) {
      canvas.drawLine(
        Offset(size.width / 2, centerY),
        Offset(size.width, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
