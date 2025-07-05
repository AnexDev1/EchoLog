import 'package:flutter/material.dart';

class TranscriptionStatusProvider extends ChangeNotifier {
  bool _isTranscribing = false;
  double _progress = 0.0; // 0.0 to 1.0
  String _statusText = '';
  String? _currentEntryId;

  bool get isTranscribing => _isTranscribing;
  double get progress => _progress;
  String get statusText => _statusText;
  String? get currentEntryId => _currentEntryId;

  void startTranscription(String entryId) {
    _isTranscribing = true;
    _progress = 0.0;
    _statusText = 'Preparing to transcribe...';
    _currentEntryId = entryId;
    notifyListeners();
  }

  void updateProgress(double progress, String statusText) {
    _progress = progress;
    _statusText = statusText;
    notifyListeners();
  }

  void finishTranscription() {
    _isTranscribing = false;
    _progress = 1.0;
    _statusText = 'Transcription complete!';
    _currentEntryId = null;
    notifyListeners();
  }

  void failTranscription(String error) {
    _isTranscribing = false;
    _progress = 0.0;
    _statusText = error;
    _currentEntryId = null;
    notifyListeners();
  }
}
