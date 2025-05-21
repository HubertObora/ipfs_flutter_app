import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class PerformanceEntry {
  final String type; // "Upload" or "Download"
  final String target; // Filename or CID
  final int durationMs;
  final String status; // "Success" or "Failure"
  final DateTime timestamp;

  PerformanceEntry({
    required this.type,
    required this.target,
    required this.durationMs,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target,
        'durationMs': durationMs,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PerformanceEntry.fromJson(Map<String, dynamic> json) => PerformanceEntry(
        type: json['type'],
        target: json['target'],
        durationMs: json['durationMs'],
        status: json['status'],
        timestamp: DateTime.parse(json['timestamp']),
      );

  String get formattedTimestamp => DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
}

class PerformanceService {
  static const String _performanceLogKey = 'performance_log';
  static const int _maxLogEntries = 20; // Keep a reasonable number of logs

  Future<void> logOperation(String type, String target, int durationMs, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final newEntry = PerformanceEntry(
      type: type,
      target: target,
      durationMs: durationMs,
      status: status,
      timestamp: DateTime.now(),
    );

    List<PerformanceEntry> logs = await getPerformanceLogs();
    logs.insert(0, newEntry); // Add to the beginning

    if (logs.length > _maxLogEntries) {
      logs = logs.sublist(0, _maxLogEntries);
    }

    final List<String> logsJson = logs.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList(_performanceLogKey, logsJson);
  }

  Future<List<PerformanceEntry>> getPerformanceLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? logsJson = prefs.getStringList(_performanceLogKey);

    if (logsJson == null) {
      return [];
    }

    return logsJson.map((logString) => PerformanceEntry.fromJson(jsonDecode(logString))).toList();
  }

  Future<void> clearPerformanceLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_performanceLogKey);
  }
}

