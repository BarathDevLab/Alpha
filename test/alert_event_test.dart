// test/alert_event_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha/models/alert_event.dart';

void main() {
  group('AlertEvent', () {
    const sampleJson = {
      'id': 'abc-123',
      'type': 'sound',
      'label': 'Siren',
      'level': 2,
      'confidence': 0.87,
      'db': '72.3 approx',
      'geohash': 'ttnem',
      'ts': '2026-10-13T13:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final e = AlertEvent.fromJson(sampleJson);
      expect(e.id, 'abc-123');
      expect(e.type, 'sound');
      expect(e.label, 'Siren');
      expect(e.level, 2);
      expect(e.confidence, closeTo(0.87, 0.001));
      expect(e.db, '72.3 approx');
      expect(e.geohash, 'ttnem');
      expect(e.ts, DateTime.parse('2026-10-13T13:00:00.000Z'));
    });

    test('toJson round-trips correctly', () {
      final e = AlertEvent.fromJson(sampleJson);
      final out = e.toJson();
      expect(out['id'], sampleJson['id']);
      expect(out['type'], sampleJson['type']);
      expect(out['label'], sampleJson['label']);
      expect(out['level'], sampleJson['level']);
      expect(out['db'], sampleJson['db']);
      expect(out['geohash'], sampleJson['geohash']);
    });

    test('levelLabel returns correct string', () {
      final mk = (int lvl) => AlertEvent.fromJson({...sampleJson, 'level': lvl});
      expect(mk(1).levelLabel, 'Low');
      expect(mk(2).levelLabel, 'Medium');
      expect(mk(3).levelLabel, 'High');
    });

    test('optional fields are nullable', () {
      final json = {...sampleJson}..remove('db')..remove('geohash');
      final e = AlertEvent.fromJson(json);
      expect(e.db, isNull);
      expect(e.geohash, isNull);
    });

    test('toJson omits null optional fields', () {
      final json = {...sampleJson}..remove('db')..remove('geohash');
      final out = AlertEvent.fromJson(json).toJson();
      expect(out.containsKey('db'), isFalse);
      expect(out.containsKey('geohash'), isFalse);
    });
  });
}
