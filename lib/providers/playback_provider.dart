import 'package:flutter/foundation.dart';
import 'package:echolog/models/recording_entry.dart'; // Adjust import path if needed

class PlaybackProvider with ChangeNotifier {
  RecordingEntry? _recordingToPlay;
  bool _playImmediately = false;

  RecordingEntry? get recordingToPlay => _recordingToPlay;
  bool get playImmediately => _playImmediately;

  void setRecordingToPlay(RecordingEntry entry, {bool playNow = true}) {
    _recordingToPlay = entry;
    _playImmediately = playNow; // Flag to indicate it should play right away
    notifyListeners();
  }

  // Call this after HomeScreen has started playing to avoid re-triggering
  void clearPlaybackRequest() {
    _playImmediately = false;
    // Optionally clear _recordingToPlay if you only want it to be a one-time trigger
    // _recordingToPlay = null;
    // notifyListeners(); // Only if you clear _recordingToPlay and want UI to react
  }
}
