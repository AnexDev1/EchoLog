import 'package:intl/intl.dart';
import '../models/recording_entry.dart';

class DynamicGreetingService {
  static String getMoodAwareGreeting(String mood, {String? emoji}) {
    final moodLower = mood.toLowerCase();
    final moodEmoji = emoji ?? '';

    if (moodLower.contains('vent')) {
      final ventGreetings = [
        "Let it all out. This is your safe space to vent $moodEmoji.",
        "Release your thoughts—no filter needed $moodEmoji.",
        "Venting helps lighten the load. Go ahead $moodEmoji.",
        "Say whatever’s on your mind. It’s okay to vent $moodEmoji.",
        "Your feelings are valid. Let’s talk it out $moodEmoji.",
      ];
      return ventGreetings[DateTime.now().second % ventGreetings.length];
    } else if (moodLower.contains('brainstorm')) {
      final brainstormGreetings = [
        "Ready to spark new ideas? Let’s brainstorm! $moodEmoji",
        "No idea is too wild—let your creativity flow $moodEmoji.",
        "Brainstorming zone: anything goes! $moodEmoji",
        "Let’s capture your next big idea $moodEmoji.",
        "Throw your thoughts out there—let’s innovate $moodEmoji.",
      ];
      return brainstormGreetings[DateTime.now().second %
          brainstormGreetings.length];
    } else if (moodLower.contains('random')) {
      final randomGreetings = [
        "Random talk time! Say whatever comes to mind $moodEmoji.",
        "No topic? No problem. Let’s just chat $moodEmoji.",
        "Let your thoughts wander—randomness welcome $moodEmoji.",
        "Anything goes! What’s on your mind? $moodEmoji",
        "Let’s see where this random talk takes us $moodEmoji.",
      ];
      return randomGreetings[DateTime.now().second % randomGreetings.length];
    } else if (moodLower.contains('gratitude')) {
      final gratitudeGreetings = [
        "Gratitude time! What are you thankful for today? $moodEmoji",
        "Let’s reflect on the good—share your gratitude $moodEmoji.",
        "Big or small, every gratitude counts $moodEmoji.",
        "Thankfulness makes the heart lighter. What’s yours? $moodEmoji",
        "Let’s echo your gratitude and spread positivity $moodEmoji.",
      ];
      return gratitudeGreetings[DateTime.now().second %
          gratitudeGreetings.length];
    }
    // ...other moods...

    // Fallback
    return "Ready to share your $mood mood? $moodEmoji";
  }

  static String getGreeting({
    required DateTime now,
    RecordingEntry? lastRecording,
  }) {
    final hour = now.hour;
    final isMorning = hour >= 5 && hour < 12;
    final isAfternoon = hour >= 12 && hour < 17;
    final isEvening = hour >= 17 && hour < 22;
    final isNight = hour >= 22 || hour < 5;

    String? mood = lastRecording?.moodName;
    String? emoji = lastRecording?.moodEmoji;

    // Use safe fallbacks for mood and emoji
    final safeMood = (mood != null && mood.trim().isNotEmpty) ? mood : '';
    final safeEmoji = (emoji != null && emoji.trim().isNotEmpty) ? emoji : '';

    // Time-based base greetings
    String baseGreeting;
    if (isMorning) {
      baseGreeting = "Good morning";
    } else if (isAfternoon) {
      baseGreeting = "Good afternoon";
    } else if (isEvening) {
      baseGreeting = "Good evening";
    } else {
      baseGreeting = "Burning the midnight oil?";
    }

    // --- MASSIVE GREETING LISTS ---
    List<String> moodGreetings = [];
    List<String> genericGreetings = [
      "$baseGreeting! Ready to share your thoughts?",
      "$baseGreeting! What’s on your mind today?",
      "$baseGreeting! Let’s capture a new moment.",
      "$baseGreeting! Your voice matters.",
      "$baseGreeting! Express yourself freely.",
      "$baseGreeting! Every day is a new story.",
      "$baseGreeting! Let your feelings flow.",
      "$baseGreeting! Speak your truth.",
      "$baseGreeting! Your journey matters.",
      "$baseGreeting! Take a deep breath and begin.",
      "$baseGreeting! Today is a blank page.",
      "$baseGreeting! Let’s make today memorable.",
      "$baseGreeting! You’re doing great.",
      "$baseGreeting! Welcome back, storyteller.",
      "$baseGreeting! Let’s echo your thoughts.",
      "$baseGreeting! Your words are safe here.",
      "$baseGreeting! Another day, another memory.",
      "$baseGreeting! How’s your heart today?",
      "$baseGreeting! Let’s check in with yourself.",
      "$baseGreeting! What’s something new today?",
      "$baseGreeting! Let’s make your voice heard.",
      "$baseGreeting! You’re not alone.",
      "$baseGreeting! Let’s reflect together.",
      "$baseGreeting! Your emotions are valid.",
      "$baseGreeting! Let’s turn feelings into words.",
      "$baseGreeting! Welcome to your safe space.",
      "$baseGreeting! Let’s start a new chapter.",
      "$baseGreeting! What’s your highlight today?",
      "$baseGreeting! Let’s capture this moment.",
      "$baseGreeting! How’s your energy today?",
      "$baseGreeting! Let’s make time for you.",
      "$baseGreeting! What’s something you’re grateful for?",
      "$baseGreeting! Let’s celebrate your progress.",
      "$baseGreeting! What’s your intention for today?",
      "$baseGreeting! Let’s pause and reflect.",
      "$baseGreeting! You’re making history.",
      "$baseGreeting! Let’s create a memory.",
      "$baseGreeting! How’s your mind feeling?",
      "$baseGreeting! Let’s turn thoughts into action.",
      "$baseGreeting! Welcome to your echo chamber.",
      "$baseGreeting! Let’s make your day brighter.",
      "$baseGreeting! What’s your mood right now?",
      "$baseGreeting! Let’s check in with your soul.",
      "$baseGreeting! You’re the author of your story.",
      "$baseGreeting! Let’s make your feelings count.",
      "$baseGreeting! What’s something you want to remember?",
      "$baseGreeting! Let’s make today count.",
      "$baseGreeting! You’re here, and that’s enough.",
      "$baseGreeting! Let’s honor your journey.",
      "$baseGreeting! What’s your biggest win today?",
      "$baseGreeting! Let’s echo your emotions.",
      "$baseGreeting! Welcome to your daily ritual.",
      "$baseGreeting! Let’s make space for your thoughts.",
      "$baseGreeting! What’s your hope for today?",
      "$baseGreeting! Let’s start with gratitude.",
      "$baseGreeting! You’re doing better than you think.",
      "$baseGreeting! Let’s check in with your dreams.",
      "$baseGreeting! What’s your favorite memory today?",
      "$baseGreeting! Let’s make your voice shine.",
      "$baseGreeting! You’re the hero of your story.",
      "$baseGreeting! Let’s make your feelings visible.",
      "$baseGreeting! What’s your secret wish today?",
      "$baseGreeting! Let’s turn silence into words.",
      "$baseGreeting! Welcome to your mindful moment.",
      "$baseGreeting! Let’s celebrate your uniqueness.",
      "$baseGreeting! What’s your mood color today?",
      "$baseGreeting! Let’s echo your inner world.",
      "$baseGreeting! You’re safe to share here.",
      "$baseGreeting! Let’s make your thoughts matter.",
      "$baseGreeting! What’s your biggest challenge today?",
      "$baseGreeting! Let’s turn today into a memory.",
      "$baseGreeting! You’re stronger than you know.",
      "$baseGreeting! Let’s check in with your heart.",
      "$baseGreeting! What’s your highlight of the week?",
      "$baseGreeting! Let’s make your story unforgettable.",
      "$baseGreeting! You’re making progress.",
      "$baseGreeting! Let’s echo your hopes.",
      "$baseGreeting! What’s your favorite feeling today?",
      "$baseGreeting! Let’s make your day meaningful.",
      "$baseGreeting! You’re the star of your journey.",
      "$baseGreeting! Let’s check in with your spirit.",
      "$baseGreeting! What’s your biggest lesson today?",
      "$baseGreeting! Let’s echo your gratitude.",
      "$baseGreeting! Welcome to your daily check-in.",
      "$baseGreeting! Let’s make your emotions visible.",
      "$baseGreeting! What’s your mood for the day?",
      "$baseGreeting! Let’s echo your reflections.",
      "$baseGreeting! You’re doing amazing.",
      "$baseGreeting! Let’s make your voice powerful.",
      "$baseGreeting! What’s your dream for today?",
      "$baseGreeting! Let’s echo your intentions.",
      "$baseGreeting! Welcome to your mindful space.",
      "$baseGreeting! Let’s make your thoughts shine.",
      "$baseGreeting! What’s your biggest joy today?",
      "$baseGreeting! Let’s echo your happiness.",
      "$baseGreeting! You’re valued here.",
      "$baseGreeting! Let’s make your feelings heard.",
      "$baseGreeting! What’s your mood right now?",
      "$baseGreeting! Let’s echo your present moment.",
      "$baseGreeting! You’re important.",
      "$baseGreeting! Let’s make your story matter.",
      "$baseGreeting! What’s your hope for tomorrow?",
      "$baseGreeting! Let’s echo your dreams.",
      "$baseGreeting! Welcome to your daily reflection.",
      "$baseGreeting! Let’s make your emotions count.",
      "$baseGreeting! What’s your highlight this month?",
      "$baseGreeting! Let’s echo your journey.",
      "$baseGreeting! You’re making a difference.",
      "$baseGreeting! Let’s make your voice echo.",
      "$baseGreeting! What’s your favorite part of today?",
      "$baseGreeting! Let’s echo your thoughts.",
      "$baseGreeting! You’re heard here.",
      "$baseGreeting! Let’s make your feelings visible.",
      "$baseGreeting! What’s your mood for this hour?",
      "$baseGreeting! Let’s echo your inner voice.",
      "$baseGreeting! You’re welcome here.",
      "$baseGreeting! Let’s make your story shine.",
      "$baseGreeting! What’s your biggest insight today?",
      "$baseGreeting! Let’s echo your wisdom.",
      "$baseGreeting! Welcome to your safe haven.",
      "$baseGreeting! Let’s make your thoughts memorable.",
      "$baseGreeting! What’s your mood for this moment?",
      "$baseGreeting! Let’s echo your uniqueness.",
      "$baseGreeting! You’re special.",
      "$baseGreeting! Let’s make your feelings matter.",
      "$baseGreeting! What’s your biggest hope today?",
      "$baseGreeting! Let’s echo your positivity.",
      "$baseGreeting! Welcome to your daily echo.",
      "$baseGreeting! Let’s make your emotions shine.",
      "$baseGreeting! What’s your favorite thing today?",
      "$baseGreeting! Let’s echo your light.",
      "$baseGreeting! You’re doing awesome.",
      "$baseGreeting! Let’s make your voice count.",
      "$baseGreeting! What’s your mood for this session?",
      "$baseGreeting! Let’s echo your presence.",
      "$baseGreeting! You’re appreciated.",
      "$baseGreeting! Let’s make your story echo.",
      "$baseGreeting! What’s your biggest win this week?",
      "$baseGreeting! Let’s echo your progress.",
      "$baseGreeting! Welcome to your daily moment.",
      "$baseGreeting! Let’s make your feelings shine.",
      "$baseGreeting! What’s your mood for this check-in?",
      "$baseGreeting! Let’s echo your growth.",
      "$baseGreeting! You’re amazing.",
      "$baseGreeting! Let’s make your voice memorable.",
      "$baseGreeting! What’s your favorite memory this week?",
      "$baseGreeting! Let’s echo your journey.",
      "$baseGreeting! You’re making memories.",
      "$baseGreeting! Let’s make your feelings echo.",
      "$baseGreeting! What’s your mood for this day?",
      "$baseGreeting! Let’s echo your experience.",
      "$baseGreeting! You’re unique.",
      "$baseGreeting! Let’s make your story shine.",
      "$baseGreeting! What’s your biggest lesson this week?",
      "$baseGreeting! Let’s echo your learning.",
      "$baseGreeting! Welcome to your daily echo.",
      "$baseGreeting! Let’s make your emotions echo.",
      "$baseGreeting! What’s your mood for this moment?",
      "$baseGreeting! Let’s echo your presence.",
      "$baseGreeting! You’re valued.",
      "$baseGreeting! Let’s make your voice shine.",
      "$baseGreeting! What’s your favorite thing about today?",
      "$baseGreeting! Let’s echo your gratitude.",
      "$baseGreeting! You’re doing great.",
      "$baseGreeting! Let’s make your feelings count.",
      "$baseGreeting! What’s your mood for this reflection?",
      "$baseGreeting! Let’s echo your thoughts.",
      "$baseGreeting! You’re important.",
      "$baseGreeting! Let’s make your story echo.",
      "$baseGreeting! What’s your biggest hope for tomorrow?",
      "$baseGreeting! Let’s echo your dreams.",
      "$baseGreeting! Welcome to your daily check-in.",
      "$baseGreeting! Let’s make your emotions shine.",
      "$baseGreeting! What’s your highlight this week?",
      "$baseGreeting! Let’s echo your journey.",
      "$baseGreeting! You’re making a difference.",
      "$baseGreeting! Let’s make your voice echo.",
      "$baseGreeting! What’s your favorite part of today?",
      "$baseGreeting! Let’s echo your thoughts.",
      "$baseGreeting! You’re heard here.",
      "$baseGreeting! Let’s make your feelings visible.",
      "$baseGreeting! What’s your mood for this hour?",
      "$baseGreeting! Let’s echo your inner voice.",
      "$baseGreeting! You’re welcome here.",
      "$baseGreeting! Let’s make your story shine.",
      "$baseGreeting! What’s your biggest insight today?",
      "$baseGreeting! Let’s echo your wisdom.",
      "$baseGreeting! Welcome to your safe haven.",
      "$baseGreeting! Let’s make your thoughts memorable.",
      "$baseGreeting! What’s your mood for this moment?",
      "$baseGreeting! Let’s echo your uniqueness.",
      "$baseGreeting! You’re special.",
      "$baseGreeting! Let’s make your feelings matter.",
      "$baseGreeting! What’s your biggest hope today?",
      "$baseGreeting! Let’s echo your positivity.",
      "$baseGreeting! Welcome to your daily echo.",
      "$baseGreeting! Let’s make your emotions shine.",
      "$baseGreeting! What’s your favorite thing today?",
      "$baseGreeting! Let’s echo your light.",
      "$baseGreeting! You’re doing awesome.",
      "$baseGreeting! Let’s make your voice count.",
      "$baseGreeting! What’s your mood for this session?",
      "$baseGreeting! Let’s echo your presence.",
      "$baseGreeting! You’re appreciated.",
      "$baseGreeting! Let’s make your story echo.",
      "$baseGreeting! What’s your biggest win this week?",
      "$baseGreeting! Let’s echo your progress.",
      "$baseGreeting! Welcome to your daily moment.",
      "$baseGreeting! Let’s make your feelings shine.",
      "$baseGreeting! What’s your mood for this check-in?",
      "$baseGreeting! Let’s echo your growth.",
      "$baseGreeting! You’re amazing.",
      "$baseGreeting! Let’s make your voice memorable.",
      "$baseGreeting! What’s your favorite memory this week?",
      "$baseGreeting! Let’s echo your journey.",
      "$baseGreeting! You’re making memories.",
      "$baseGreeting! Let’s make your feelings echo.",
      "$baseGreeting! What’s your mood for this day?",
      "$baseGreeting! Let’s echo your experience.",
      "$baseGreeting! You’re unique.",
      "$baseGreeting! Let’s make your story shine.",
      "$baseGreeting! What’s your biggest lesson this week?",
      "$baseGreeting! Let’s echo your learning.",
      // ...add even more for a "big db" feel!
    ];

    // Only use moodGreetings if both mood and emoji are non-empty
    if (safeMood.isNotEmpty && safeEmoji.isNotEmpty) {
      moodGreetings = [
        "$baseGreeting! Last time you felt $safeMood $safeEmoji.",
        "$baseGreeting! How’s your $safeMood $safeEmoji mood today?",
        "$baseGreeting! Recording another $safeMood $safeEmoji moment?",
        "$baseGreeting! Hope your $safeMood $safeEmoji continues.",
        "$baseGreeting! Let’s talk about your $safeMood $safeEmoji today.",
        "$baseGreeting! Remember when you felt $safeMood $safeEmoji?",
        "$baseGreeting! $safeMood $safeEmoji was your last vibe.",
        "$baseGreeting! Echoing your $safeMood $safeEmoji energy.",
        "$baseGreeting! Will today be another $safeMood $safeEmoji day?",
        "$baseGreeting! Your last mood was $safeMood $safeEmoji. How about now?",
        "$baseGreeting! $safeMood $safeEmoji is a powerful feeling.",
        "$baseGreeting! Let's see if $safeMood $safeEmoji returns today.",
        "$baseGreeting! $safeMood $safeEmoji left a mark last time.",
        "$baseGreeting! $safeMood $safeEmoji is still echoing.",
        "$baseGreeting! $safeMood $safeEmoji was your last chapter.",
        "$baseGreeting! $safeMood $safeEmoji—what a mood!",
        "$baseGreeting! $safeMood $safeEmoji, again or something new?",
        "$baseGreeting! $safeMood $safeEmoji, let's talk about it.",
        "$baseGreeting! $safeMood $safeEmoji, your story continues.",
        "$baseGreeting! $safeMood $safeEmoji, let's echo that.",
        // ...add more mood-based for variety!
      ];
    }

    // Optionally, add a date-based greeting for special days
    final today = DateFormat('EEEE').format(now);
    if (today == "Monday") {
      genericGreetings.add("New week, new thoughts! Happy Monday!");
      if (safeMood.isNotEmpty && safeEmoji.isNotEmpty) {
        moodGreetings.add("New week, new $safeMood $safeEmoji? Happy Monday!");
      }
    } else if (today == "Friday") {
      genericGreetings.add("It's Friday! Got weekend plans to record?");
      if (safeMood.isNotEmpty && safeEmoji.isNotEmpty) {
        moodGreetings.add(
          "It's Friday! Will $safeMood $safeEmoji be your weekend vibe?",
        );
      }
    } else if (today == "Sunday") {
      genericGreetings.add("Sunday reflections: what’s on your mind?");
      if (safeMood.isNotEmpty && safeEmoji.isNotEmpty) {
        moodGreetings.add(
          "Sunday $safeMood $safeEmoji reflections: ready to share?",
        );
      }
    }

    // Pick a greeting based on the second, so it feels random and fresh
    final allGreetings = (moodGreetings.isNotEmpty
        ? moodGreetings
        : genericGreetings);
    int idx = (now.millisecond + now.second + now.minute) % allGreetings.length;
    return allGreetings[idx];
  }
}
