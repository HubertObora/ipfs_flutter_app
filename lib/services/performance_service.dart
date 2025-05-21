import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

class PerformanceEntry {
  final String type;
  final String target;
  final int durationMs;
  final String status;
  final DateTime timestamp;
  final String service;
  final int fileSize;
  final String? gateway;
  final String? error;
  final String platform;
  final String? deviceModel;
  final String? osVersion;

  PerformanceEntry({
    required this.type,
    required this.target,
    required this.durationMs,
    required this.status,
    required this.timestamp,
    required this.service,
    required this.fileSize,
    this.gateway,
    this.error,
    required this.platform,
    this.deviceModel,
    this.osVersion,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target,
        'durationMs': durationMs,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'service': service,
        'fileSize': fileSize,
        'gateway': gateway,
        'error': error,
        'platform': platform,
        'deviceModel': deviceModel,
        'osVersion': osVersion,
      };

  factory PerformanceEntry.fromJson(Map<String, dynamic> json) =>
      PerformanceEntry(
        type: json['type'],
        target: json['target'],
        durationMs: json['durationMs'],
        status: json['status'],
        timestamp: DateTime.parse(json['timestamp']),
        service: json['service'] ?? 'Unknown',
        fileSize: json['fileSize'] ?? 0,
        gateway: json['gateway'],
        error: json['error'],
        platform: json['platform'] ?? 'Unknown',
        deviceModel: json['deviceModel'],
        osVersion: json['osVersion'],
      );

  String get formattedTimestamp =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  double get speedKBps {
    return fileSize > 0 ? (fileSize / 1024) / (durationMs / 1000) : 0;
  }

  String get formattedSpeed {
    return '${speedKBps.toStringAsFixed(2)} KB/s';
  }
}

class PerformanceService {
  static const String _performanceLogKey = 'performance_log';
  static const int _maxLogEntries = 50;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, String?>> _getMobileDeviceInfo() async {
    String platform;
    String? deviceModel;
    String? osVersion;

    if (Platform.isAndroid) {
      platform = 'Android';
      final androidInfo = await _deviceInfo.androidInfo;
      deviceModel = androidInfo.model;
      osVersion = androidInfo.version.release;
    } else if (Platform.isIOS) {
      platform = 'iOS';
      final iosInfo = await _deviceInfo.iosInfo;
      deviceModel = iosInfo.model;
      osVersion = iosInfo.systemVersion;
    } else {
      platform = 'Other';
    }

    return {
      'platform': platform,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
    };
  }

  Future<void> logOperation(String type, String target, int durationMs,
      String status, String service, int fileSize,
      {String? gateway, String? error}) async {
    final prefs = await SharedPreferences.getInstance();

    final deviceInfo = await _getMobileDeviceInfo();

    final newEntry = PerformanceEntry(
      type: type,
      target: target,
      durationMs: durationMs,
      status: status,
      timestamp: DateTime.now(),
      service: service,
      fileSize: fileSize,
      gateway: gateway,
      error: error,
      platform: deviceInfo['platform'] ?? 'Unknown',
      deviceModel: deviceInfo['deviceModel'],
      osVersion: deviceInfo['osVersion'],
    );

    List<PerformanceEntry> logs = await getPerformanceLogs();
    logs.insert(0, newEntry);

    if (logs.length > _maxLogEntries) {
      logs = logs.sublist(0, _maxLogEntries);
    }

    final List<String> logsJson =
        logs.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList(_performanceLogKey, logsJson);
  }

  Future<List<PerformanceEntry>> getPerformanceLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? logsJson = prefs.getStringList(_performanceLogKey);

    if (logsJson == null) {
      return [];
    }

    return logsJson
        .map((logString) => PerformanceEntry.fromJson(jsonDecode(logString)))
        .toList();
  }

  Future<void> clearPerformanceLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_performanceLogKey);
  }

  Future<Map<String, dynamic>> getPerformanceSummary() async {
    final logs = await getPerformanceLogs();
    if (logs.isEmpty) {
      return {
        'totalOperations': 0,
        'successRate': 0,
        'avgDuration': 0,
        'avgSpeed': 0,
        'androidCount': 0,
        'iosCount': 0,
      };
    }

    int successCount = logs.where((e) => e.status == 'Success').length;
    double avgDuration =
        logs.fold(0, (sum, e) => sum + e.durationMs) / logs.length;
    double successRate = (successCount / logs.length) * 100;

    double avgSpeed = 0;
    final successfulOps = logs.where((e) => e.status == 'Success').toList();
    if (successfulOps.isNotEmpty) {
      avgSpeed = successfulOps.fold(0.0, (sum, e) => sum + e.speedKBps) /
          successfulOps.length;
    }

    int androidCount = logs.where((e) => e.platform == 'Android').length;
    int iosCount = logs.where((e) => e.platform == 'iOS').length;

    return {
      'totalOperations': logs.length,
      'successRate': successRate,
      'avgDuration': avgDuration,
      'avgSpeed': avgSpeed,
      'androidCount': androidCount,
      'iosCount': iosCount,
    };
  }

  Future<Map<String, Map<String, dynamic>>> getPlatformStats() async {
    final logs = await getPerformanceLogs();
    final Map<String, Map<String, dynamic>> stats = {
      'Android': {
        'count': 0,
        'success': 0,
        'totalDuration': 0,
        'avgDuration': 0,
        'successRate': 0,
      },
      'iOS': {
        'count': 0,
        'success': 0,
        'totalDuration': 0,
        'avgDuration': 0,
        'successRate': 0,
      }
    };

    for (var log in logs) {
      if (log.platform == 'Android' || log.platform == 'iOS') {
        stats[log.platform]!['count'] = stats[log.platform]!['count'] + 1;
        stats[log.platform]!['totalDuration'] =
            stats[log.platform]!['totalDuration'] + log.durationMs;

        if (log.status == 'Success') {
          stats[log.platform]!['success'] = stats[log.platform]!['success'] + 1;
        }
      }
    }

    for (var platform in ['Android', 'iOS']) {
      if (stats[platform]!['count'] > 0) {
        stats[platform]!['avgDuration'] =
            stats[platform]!['totalDuration'] / stats[platform]!['count'];
        stats[platform]!['successRate'] =
            (stats[platform]!['success'] / stats[platform]!['count']) * 100;
      }
    }

    return stats;
  }

  Future<Map<String, Map<String, dynamic>>> getServiceStats() async {
    final logs = await getPerformanceLogs();
    final Map<String, Map<String, dynamic>> stats = {};

    for (var log in logs) {
      if (!stats.containsKey(log.service)) {
        stats[log.service] = {
          'count': 0,
          'success': 0,
          'totalDuration': 0,
          'avgDuration': 0,
          'successRate': 0,
        };
      }

      stats[log.service]!['count'] = stats[log.service]!['count'] + 1;
      stats[log.service]!['totalDuration'] =
          stats[log.service]!['totalDuration'] + log.durationMs;

      if (log.status == 'Success') {
        stats[log.service]!['success'] = stats[log.service]!['success'] + 1;
      }
    }

    for (var service in stats.keys) {
      if (stats[service]!['count'] > 0) {
        stats[service]!['avgDuration'] =
            stats[service]!['totalDuration'] / stats[service]!['count'];
        stats[service]!['successRate'] =
            (stats[service]!['success'] / stats[service]!['count']) * 100;
      }
    }

    return stats;
  }
}
