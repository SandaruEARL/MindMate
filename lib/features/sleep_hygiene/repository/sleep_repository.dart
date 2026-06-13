// sleep_repository.dart
//
// Persists SleepRecord objects to SharedPreferences as a JSON list.
// All methods are static so no instance management is needed.
//
// Storage key: 'sleep_records'
// Format: JSON-encoded List<Map<String,dynamic>>
// Max records kept: 90 (≈3 months — older ones pruned on save)

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';


class SleepRepository {
  static const String _key     = 'sleep_records';
  static const int    _maxDays = 90;

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns all stored records, newest first.
  static Future<List<SleepRecord>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list  = jsonDecode(raw) as List<dynamic>;
      final records = list
          .map((e) => SleepRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.date.compareTo(a.date)); // newest first
      return records;
    } catch (_) {
      return [];
    }
  }

  /// Returns the last [days] days of records (oldest first — good for charts).
  static Future<List<SleepRecord>> loadLast({int days = 14}) async {
    final all   = await loadAll();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = all
        .where((r) => r.date.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // oldest first
    return recent;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Saves a new record. Skips if a record for today already exists
  /// (prevents duplicates when the user re-opens the screen mid-day).
  /// Returns the saved record (or the existing one if today's already there).
  static Future<SleepRecord> saveRecord(SleepRecord record) async {
    final all = await loadAll();

    // Deduplicate: if today already has a record, return it unchanged
    final existing = _todaysRecord(all);
    if (existing != null) return existing;

    all.insert(0, record); // newest first
    await _persist(_prune(all));
    return record;
  }

  /// Updates the quality rating on the most recent record.
  /// Call this after the user responds to the "how did you sleep?" question.
  static Future<void> updateQuality(int quality) async {
    assert(quality >= 1 && quality <= 5);
    final all = await loadAll();
    if (all.isEmpty) return;

    // Find yesterday's record (the one we're rating now)
    final idx = all.indexWhere((r) => r.isYesterday || r.isToday);
    if (idx == -1) return;

    all[idx] = all[idx].copyWith(quality: quality);
    await _persist(all);
  }

  /// Appends a tool tag to the current session's record.
  /// Safe to call multiple times with the same tag — deduplicates.
  static Future<void> logToolUsed(String tool) async {
    final all = await loadAll();
    if (all.isEmpty) return;

    final idx = all.indexWhere((r) => r.isToday);
    if (idx == -1) return;

    final current = all[idx];
    if (current.tools.contains(tool)) return; // already logged
    all[idx] = current.copyWith(tools: [...current.tools, tool]);
    await _persist(all);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static SleepRecord? _todaysRecord(List<SleepRecord> records) {
    try {
      return records.firstWhere((r) => r.isToday);
    } catch (_) {
      return null;
    }
  }

  static List<SleepRecord> _prune(List<SleepRecord> records) {
    if (records.length <= _maxDays) return records;
    return records.take(_maxDays).toList();
  }

  static Future<void> _persist(List<SleepRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  // ── Stats helpers (used by the graph screen) ───────────────────────────────

  /// Average quality over a list of records (ignores unrated ones).
  static double averageQuality(List<SleepRecord> records) {
    final rated = records.where((r) => r.quality != null).toList();
    if (rated.isEmpty) return 0;
    return rated.map((r) => r.quality!).reduce((a, b) => a + b) / rated.length;
  }

  /// 3-day centred moving average for quality.
  /// Returns a parallel list; null where there aren't enough neighbours.
  static List<double?> movingAverage(List<SleepRecord> records,
      {int window = 3}) {
    final result = List<double?>.filled(records.length, null);
    final half   = window ~/ 2;
    for (int i = half; i < records.length - half; i++) {
      final slice = records
          .sublist(i - half, i + half + 1)
          .where((r) => r.quality != null)
          .map((r) => r.quality!.toDouble())
          .toList();
      if (slice.length == window) {
        result[i] = slice.reduce((a, b) => a + b) / slice.length;
      }
    }
    return result;
  }

  /// Returns the streak of consecutive days with quality >= 3.
  static int goodSleepStreak(List<SleepRecord> records) {
    // records expected oldest-first
    int streak = 0;
    for (final r in records.reversed) {
      if ((r.quality ?? 0) >= 3) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}