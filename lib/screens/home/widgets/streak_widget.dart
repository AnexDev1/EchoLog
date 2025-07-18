import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakWidget extends StatefulWidget {
  final int streak;
  const StreakWidget({super.key, required this.streak});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget>
    with SingleTickerProviderStateMixin {
  int _oldStreak = 0;
  String _lottieAsset = 'assets/gif/zero_streak.json';
  int? _lastStreakValue;
  DateTime? _lastDay;

  @override
  void initState() {
    super.initState();
    _oldStreak = widget.streak;
    _initDayCheck();
  }

  Future<void> _initDayCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDayStr = prefs.getString('streak_last_day');
    final lastStreak = prefs.getInt('streak_last_value');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lastDayStr != null) {
      final lastDay = DateTime.tryParse(lastDayStr);
      if (lastDay != null && lastDay.isBefore(today)) {
        // New day detected, reset animation to zero_streak
        setState(() {
          _lottieAsset = 'assets/gif/zero_streak.json';
        });
        await prefs.setString('streak_last_day', today.toIso8601String());
        await prefs.setInt('streak_last_value', widget.streak);
        _lastStreakValue = widget.streak;
      } else {
        // Not a new day, keep previous animation
        setState(() {
          _lottieAsset = (widget.streak > (lastStreak ?? 0)) && widget.streak > 0
              ? 'assets/gif/fourth_streak.json'
              : 'assets/gif/zero_streak.json';
        });
        _lastStreakValue = lastStreak;
      }
    } else {
      // First launch, set today
      await prefs.setString('streak_last_day', today.toIso8601String());
      await prefs.setInt('streak_last_value', widget.streak);
      setState(() {
        _lottieAsset = 'assets/gif/zero_streak.json';
      });
      _lastStreakValue = widget.streak;
    }
  }

  @override
  void didUpdateWidget(covariant StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streak != oldWidget.streak) {
      _oldStreak = oldWidget.streak;
      _handleStreakChange();
    }
  }

  Future<void> _handleStreakChange() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDayStr = prefs.getString('streak_last_day');
    final lastStreak = prefs.getInt('streak_last_value') ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? lastDay = lastDayStr != null ? DateTime.tryParse(lastDayStr) : null;
    // If new day and streak increased, show fourth_streak
    if (lastDay != null && lastDay.isBefore(today) && widget.streak > lastStreak) {
      setState(() {
        _lottieAsset = 'assets/gif/fourth_streak.json';
      });
      await prefs.setString('streak_last_day', today.toIso8601String());
      await prefs.setInt('streak_last_value', widget.streak);
    } else if (lastDay != null && lastDay.isBefore(today)) {
      // New day but streak did not increase, reset to zero_streak
      setState(() {
        _lottieAsset = 'assets/gif/zero_streak.json';
      });
      await prefs.setString('streak_last_day', today.toIso8601String());
      await prefs.setInt('streak_last_value', widget.streak);
    } else if (widget.streak > lastStreak) {
      // Same day, streak increased (shouldn't happen, but handle just in case)
      setState(() {
        _lottieAsset = 'assets/gif/fourth_streak.json';
      });
      await prefs.setInt('streak_last_value', widget.streak);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 35,
          height: 52,
          child: Lottie.asset(_lottieAsset, fit: BoxFit.contain, repeat: true),
        ),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: _oldStreak, end: streak),
          duration: const Duration(milliseconds: 700),
          builder: (context, value, child) => Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
                fontSize: 14,
                shadows: [
                  Shadow(color: Colors.orange.withOpacity(0.2), blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
