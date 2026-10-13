// lib/channels.dart
//
// ChannelBridge: singleton that owns all platform channels.
// Exposes soundStream and textStream as typed Dart Streams.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'models/alert_event.dart';

class ChannelBridge {
  ChannelBridge._();
  static final ChannelBridge instance = ChannelBridge._();

  static const _control = MethodChannel('control');
  static const _soundChannel = EventChannel('sound_events');
  static const _textChannel = EventChannel('text_events');

  // ── Public streams ────────────────────────────────────────────────────────

  /// Stream of sound alert events from SoundGuardService.
  Stream<AlertEvent> get soundStream => _soundChannel
      .receiveBroadcastStream()
      .map((raw) => AlertEvent.fromJson(json.decode(raw as String) as Map<String, dynamic>));

  /// Stream of raw text events from MindGuardService.
  /// The text field is processed by MindClassifier in Dart.
  Stream<Map<String, dynamic>> get textStream => _textChannel
      .receiveBroadcastStream()
      .map((raw) => json.decode(raw as String) as Map<String, dynamic>);

  // ── Control methods ───────────────────────────────────────────────────────

  Future<void> startSound() async {
    try { await _control.invokeMethod('startSound'); } catch (_) {}
  }

  Future<void> stopSound() async {
    try { await _control.invokeMethod('stopSound'); } catch (_) {}
  }

  Future<void> startMind() async {
    try { await _control.invokeMethod('startMind'); } catch (_) {}
  }

  Future<void> stopMind() async {
    try { await _control.invokeMethod('stopMind'); } catch (_) {}
  }

  Future<Map<String, bool>> isEnabled() async {
    try {
      final res = await _control.invokeMethod<Map>('isEnabled');
      return {
        'sound': (res?['sound'] as bool?) ?? false,
        'mind': (res?['mind'] as bool?) ?? false,
      };
    } catch (_) {
      return {'sound': false, 'mind': false};
    }
  }

  Future<String?> getFcmToken() async {
    try {
      return await _control.invokeMethod<String>('getFcmToken');
    } catch (_) {
      return null;
    }
  }
}
