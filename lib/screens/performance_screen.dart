import 'package:flutter/material.dart';
import 'package:ipfs_app/services/performance_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final PerformanceService _performanceService = PerformanceService();
  List<PerformanceEntry> _performanceLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPerformanceLogs();
  }

  Future<void> _loadPerformanceLogs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final logs = await _performanceService.getPerformanceLogs();
      setState(() {
        _performanceLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Optionally show an error message
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading performance logs: $e')),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Clear'),
          content: const Text('Are you sure you want to clear all performance logs?'),
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
      _loadPerformanceLogs(); // Refresh the list
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
            onPressed: _loadPerformanceLogs,
            tooltip: 'Refresh Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _performanceLogs.isEmpty
              ? Center(
                  child: Text(
                    'No performance logs yet.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPerformanceLogs,
                  child: ListView.builder(
                    itemCount: _performanceLogs.length,
                    itemBuilder: (context, index) {
                      final entry = _performanceLogs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: ListTile(
                          leading: Icon(
                            entry.type == 'Upload' ? Icons.upload_file : Icons.download_for_offline,
                            color: entry.status == 'Success' ? Colors.green : Colors.red,
                          ),
                          title: Text('${entry.type}: ${entry.target}', overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              'Duration: ${entry.durationMs} ms\nStatus: ${entry.status}\nTime: ${entry.formattedTimestamp}'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

