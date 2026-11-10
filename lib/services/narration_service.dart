import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_tts/flutter_tts.dart';

import '../models/poi.dart';

/// Reads text aloud with the iPhone's built-in voice (free, works offline).
///
/// [speakingId] says what's being read right now (a POI id), or null when
/// quiet, so the UI can show Listen / Stop.
class NarrationService {
  NarrationService() {
    _tts
      ..setStartHandler(() {})
      ..setCompletionHandler(_done)
      ..setCancelHandler(_done)
      ..setErrorHandler((_) => _done());
  }

  final _tts = FlutterTts();
  bool _configured = false;

  final speakingId = ValueNotifier<String?>(null);

  bool _disposed = false;

  /// One-time voice and audio setup. Failures are logged, not thrown, so a
  /// speech problem never breaks the tour; setup is retried on next use.
  Future<void> _configure() async {
    if (_configured) return;
    try {
      await _tts.setLanguage('en-US');
      // 0.5 is iOS's normal pace; slightly slower is easier to follow outdoors.
      await _tts.setSpeechRate(0.47);
      await _tts.setSharedInstance(true);
      // Play even with the Silent switch on, and lower (not stop) any music.
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions
            .interruptSpokenAudioAndMixWithOthers,
      ], IosTextToSpeechAudioMode.spokenAudio);
      _configured = true;
    } on MissingPluginException {
      debugPrint(
        'Text-to-speech plugin missing from this build. Stop the app and '
        'run it again (hot reload/restart cannot add native plugins).',
      );
    } catch (e) {
      debugPrint('Text-to-speech setup failed: $e');
    }
  }

  /// Reads a stop's description, introduced by its name.
  Future<void> narratePoi(Poi poi, {bool arrived = false}) => speak(
    id: poi.id,
    text: [
      arrived ? "You've arrived at ${poi.name}." : '${poi.name}.',
      poi.description,
    ].join('\n\n'),
  );

  Future<void> speak({required String id, required String text}) async {
    await _configure();
    if (!_configured || _disposed) return;
    try {
      await _tts.stop();
      speakingId.value = id;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Text-to-speech failed: $e');
      _done();
    }
  }

  Future<void> stop() async {
    if (_disposed || speakingId.value == null) return;
    speakingId.value = null;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('Text-to-speech stop failed: $e');
    }
  }

  /// Called by the plugin when speech ends, is cancelled, or errors — which
  /// can happen after [dispose] (e.g. leaving the map mid-sentence).
  void _done() {
    if (!_disposed) speakingId.value = null;
  }

  void dispose() {
    _disposed = true;
    speakingId.dispose();
    _tts.stop().catchError((_) => null);
  }
}
