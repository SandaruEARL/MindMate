// sleep_record.dart
//
// One session's worth of sleep data.
// Stored as JSON in SharedPreferences via SleepRepository.

class SleepRecord {
  const SleepRecord({
    required this.id,
    required this.date,
    this.quality,       // 1-5, null until user rates
    required this.issue,
    required this.bedtime,
    required this.wakeTime,
    this.tools = const [],
  });

  final String       id;        // UUID-ish: date string + ms
  final DateTime     date;
  final int?         quality;   // 1 (very poor) → 5 (great)
  final String       issue;     // 'onset' | 'maintenance' | 'early' | 'quality'
  final String       bedtime;
  final String       wakeTime;
  final List<String> tools;     // 'relax' | 'winddown' | 'pmr'

  // ── Copy with ──────────────────────────────────────────────────────────────

  SleepRecord copyWith({int? quality, List<String>? tools}) => SleepRecord(
    id:       id,
    date:     date,
    quality:  quality ?? this.quality,
    issue:    issue,
    bedtime:  bedtime,
    wakeTime: wakeTime,
    tools:    tools ?? this.tools,
  );

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':       id,
    'date':     date.toIso8601String(),
    'quality':  quality,
    'issue':    issue,
    'bedtime':  bedtime,
    'wakeTime': wakeTime,
    'tools':    tools,
  };

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
    id:       json['id']       as String,
    date:     DateTime.parse(json['date'] as String),
    quality:  json['quality']  as int?,
    issue:    json['issue']    as String? ?? '',
    bedtime:  json['bedtime']  as String? ?? '',
    wakeTime: json['wakeTime'] as String? ?? '',
    tools:    List<String>.from(json['tools'] as List? ?? []),
  );

  // ── Factory for new sessions ───────────────────────────────────────────────

  factory SleepRecord.newSession({
    required String issue,
    required String bedtime,
    required String wakeTime,
  }) {
    final now = DateTime.now();
    return SleepRecord(
      id:       '${now.toIso8601String()}_${now.millisecondsSinceEpoch}',
      date:     now,
      issue:    issue,
      bedtime:  bedtime,
      wakeTime: wakeTime,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get isToday {
    final now = DateTime.now();
    return date.year  == now.year  &&
        date.month == now.month &&
        date.day   == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year  == yesterday.year  &&
        date.month == yesterday.month &&
        date.day   == yesterday.day;
  }

  String get qualityLabel {
    switch (quality) {
      case 1: return 'Very poor';
      case 2: return 'Poor';
      case 3: return 'Okay';
      case 4: return 'Good';
      case 5: return 'Great';
      default: return 'Not rated';
    }
  }
}