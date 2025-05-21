import 'package:flutter/material.dart';
import 'package:ipfs_app/services/performance_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with SingleTickerProviderStateMixin {
  final PerformanceService _performanceService = PerformanceService();
  List<PerformanceEntry> _performanceLogs = [];
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPerformanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPerformanceData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final logs = await _performanceService.getPerformanceLogs();
      final summary = await _performanceService.getPerformanceSummary();
      setState(() {
        _performanceLogs = logs;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading performance data: $e')),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Clear'),
          content: const Text(
              'Are you sure you want to clear all performance logs?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Clear'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _performanceService.clearPerformanceLogs();
      _loadPerformanceData();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Performance logs cleared!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Metrics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformanceData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details', icon: Icon(Icons.list)),
            Tab(text: 'Summary', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDetailedLogsView(),
                _buildSummaryView(),
              ],
            ),
    );
  }

  Widget _buildDetailedLogsView() {
    if (_performanceLogs.isEmpty) {
      return Center(
        child: Text(
          'No performance logs yet.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPerformanceData,
      child: ListView.builder(
        itemCount: _performanceLogs.length,
        itemBuilder: (context, index) {
          final entry = _performanceLogs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ExpansionTile(
              leading: Icon(
                entry.type.startsWith('Upload')
                    ? Icons.upload_file
                    : Icons.download_for_offline,
                color: entry.status == 'Success' ? Colors.green : Colors.red,
              ),
              title: Text(
                '${entry.type}: ${entry.target}',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Service: ${entry.service}\nStatus: ${entry.status}\nTime: ${entry.formattedTimestamp}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('File Size: ${entry.formattedFileSize}'),
                      Text('Duration: ${entry.durationMs} ms'),
                      if (entry.status == 'Success' && entry.fileSize > 0)
                        Text('Speed: ${entry.formattedSpeed}'),
                      if (entry.gateway != null)
                        Text('Gateway: ${entry.gateway}'),
                      const Divider(),
                      Text('Device Info:',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Platform: ${entry.platform}'),
                      if (entry.deviceModel != null)
                        Text('Device: ${entry.deviceModel}'),
                      if (entry.osVersion != null)
                        Text('OS Version: ${entry.osVersion}'),
                      const Divider(),
                      if (entry.error != null)
                        Text('Error: ${entry.error}',
                            style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryView() {
    if (_performanceLogs.isEmpty) {
      return Center(
        child: Text(
          'No data to display.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPerformanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildPlatformComparisonCard(),
            const SizedBox(height: 16),
            _buildServiceComparisonCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Total Operations: ${_summary['totalOperations']}'),
            Text(
                'Success Rate: ${_summary['successRate'].toStringAsFixed(1)}%'),
            Text(
                'Average Duration: ${_summary['avgDuration'].toStringAsFixed(0)} ms'),
            if (_summary['avgSpeed'] > 0)
              Text(
                  'Average Speed: ${_summary['avgSpeed'].toStringAsFixed(2)} KB/s'),
            const SizedBox(height: 8),
            Text('Operations by Platform:'),
            Row(
              children: [
                Text('Android: ${_summary['androidCount']}'),
                const SizedBox(width: 16),
                Text('iOS: ${_summary['iosCount']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformComparisonCard() {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _performanceService.getPlatformStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final platformStats = snapshot.data!;
        final androidData = platformStats['Android']!;
        final iosData = platformStats['iOS']!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform Comparison',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPlatformStat(
                        'Android',
                        androidData,
                        Colors.green.shade100,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPlatformStat(
                        'iOS',
                        iosData,
                        Colors.blue.shade100,
                      ),
                    ),
                  ],
                ),
                if (androidData['count'] > 0 || iosData['count'] > 0) ...[
                  const SizedBox(height: 24),
                  Text('Duration Comparison by Platform',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _buildPlatformDurationChart(platformStats),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      'Note: Lower duration times indicate better performance.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceComparisonCard() {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _performanceService.getServiceStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final serviceStats = snapshot.data!;
        if (serviceStats.isEmpty) {
          return const SizedBox();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Performance',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: serviceStats.length,
                  itemBuilder: (context, index) {
                    final service = serviceStats.keys.elementAt(index);
                    final stats = serviceStats[service]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                            'Operations: ${stats['count']} | Success: ${stats['successRate'].toStringAsFixed(1)}%'),
                        Text(
                            'Avg Duration: ${stats['avgDuration'].toStringAsFixed(0)} ms'),
                        if (index < serviceStats.length - 1)
                          const Divider(height: 24),
                      ],
                    );
                  },
                ),
                if (serviceStats.length >= 2) ...[
                  const SizedBox(height: 24),
                  Text('Success Rate by Service',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: _buildServiceSuccessRateChart(serviceStats),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlatformStat(
      String platform, Map<String, dynamic> stats, Color bgColor) {
    final count = stats['count'] as int;
    if (count == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(platform,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('No data'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(platform,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Operations: ${stats['count']}'),
          Text('Success Rate: ${stats['successRate'].toStringAsFixed(1)}%'),
          Text('Avg Duration: ${stats['avgDuration'].toStringAsFixed(0)} ms'),
        ],
      ),
    );
  }

  Widget _buildPlatformDurationChart(
      Map<String, Map<String, dynamic>> platformStats) {
    final androidData = platformStats['Android']!;
    final iosData = platformStats['iOS']!;

    final androidCount = androidData['count'] as int;
    final iosCount = iosData['count'] as int;

    if (androidCount == 0 && iosCount == 0) {
      return const Center(child: Text('No data available'));
    }

    final barGroups = <BarChartGroupData>[];

    if (androidCount > 0) {
      barGroups.add(
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: androidData['avgDuration'] as double,
              color: Colors.green,
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }

    if (iosCount > 0) {
      barGroups.add(
        BarChartGroupData(
          x: 1,
          barRods: [
            BarChartRodData(
              toY: iosData['avgDuration'] as double,
              color: Colors.blue,
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }

    double maxY = 0;
    if (androidCount > 0) {
      maxY = max(maxY, androidData['avgDuration'] as double);
    }
    if (iosCount > 0) {
      maxY = max(maxY, iosData['avgDuration'] as double);
    }
    maxY = maxY * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text('Android');
                  case 1:
                    return const Text('iOS');
                  default:
                    return const Text('');
                }
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()} ms');
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(
          show: true,
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String platform;
              if (group.x == 0) {
                platform = 'Android';
              } else {
                platform = 'iOS';
              }
              return BarTooltipItem(
                '$platform\n${rod.toY.toStringAsFixed(0)} ms',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildServiceSuccessRateChart(
      Map<String, Map<String, dynamic>> serviceStats) {
    final barGroups = <BarChartGroupData>[];

    int index = 0;
    for (var entry in serviceStats.entries) {
      final service = entry.key;
      final stats = entry.value;
      final count = stats['count'] as int;

      if (count > 0) {
        barGroups.add(
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: stats['successRate'] as double,
                color: service.contains('Pinata') ? Colors.purple : Colors.teal,
                width: 22,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
            showingTooltipIndicators: [0],
          ),
        );
        index++;
      }
    }

    if (barGroups.isEmpty) {
      return const Center(child: Text('No service data available'));
    }

    return BarChart(
      BarChartData(
        maxY: 100,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int idx = 0;
                for (var entry in serviceStats.entries) {
                  if (entry.value['count'] > 0) {
                    if (idx == value.toInt()) {
                      return Text(
                        entry.key,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      );
                    }
                    idx++;
                  }
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}%');
              },
              interval: 20,
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
        ),
        borderData: FlBorderData(
          show: true,
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              int idx = 0;
              String service = '';
              for (var entry in serviceStats.entries) {
                if (entry.value['count'] > 0) {
                  if (idx == group.x.toInt()) {
                    service = entry.key;
                    break;
                  }
                  idx++;
                }
              }
              return BarTooltipItem(
                '$service\n${rod.toY.toStringAsFixed(1)}%',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
