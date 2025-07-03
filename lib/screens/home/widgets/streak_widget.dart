import 'package:flutter/material.dart';

class StreakWidget extends StatefulWidget {
  final int streak;
  const StreakWidget({super.key, required this.streak});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget>
    with SingleTickerProviderStateMixin {
  int _oldStreak = 0;

  @override
  void initState() {
    super.initState();
    _oldStreak = widget.streak;
  }

  @override
  void didUpdateWidget(covariant StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streak != oldWidget.streak) {
      _oldStreak = oldWidget.streak;
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
          child: Image.asset('assets/gif/streak.gif', fit: BoxFit.contain),
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
