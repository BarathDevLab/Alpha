// lib/models/alert_event.dart
//
// Canonical event schema:
// {id, type: "sound"|"mind", label, level: 1-3, confidence, db?, geohash?, ts}

class AlertEvent {
  final String id;
  final String type;       // "sound" | "mind"
  final String label;
  final int level;         // 1 = low, 2 = medium, 3 = high
  final double confidence;
  final String? db;        // approx dB string, e.g. "72.3 approx"
  final String? geohash;
  final DateTime ts;

  const AlertEvent({
    required this.id,
    required this.type,
    required this.label,
    required this.level,
    required this.confidence,
    this.db,
    this.geohash,
    required this.ts,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) => AlertEvent(
        id: json['id'] as String,
        type: json['type'] as String,
        label: json['label'] as String? ?? '',
        level: (json['level'] as num).toInt(),
        confidence: (json['confidence'] as num).toDouble(),
        db: json['db'] as String?,
        geohash: json['geohash'] as String?,
        ts: DateTime.parse(json['ts'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'level': level,
        'confidence': confidence,
        if (db != null) 'db': db,
        if (geohash != null) 'geohash': geohash,
        'ts': ts.toIso8601String(),
      };

  String get levelLabel => switch (level) {
        1 => 'Low',
        2 => 'Medium',
        3 => 'High',
        _ => 'Unknown',
      };

  @override
  String toString() => 'AlertEvent($type, $label, level=$level, ts=$ts)';
}
