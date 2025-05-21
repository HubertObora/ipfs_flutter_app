import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ipfs_app/services/ipfs_service.dart';
import 'package:ipfs_app/services/settings_service.dart';
import 'package:ipfs_app/services/performance_service.dart';
import 'package:path_provider/path_provider.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final IpfsService _ipfsService = IpfsService();
  final SettingsService _settingsService = SettingsService();
  final PerformanceService _performanceService = PerformanceService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _cidController;
  String? _selectedGateway;
  List<String> _gatewayOptions = [
    "Default Public Gateway"
  ]; // Will be populated
  String _statusMessage = '';
  bool _isDownloading = false;
  String _downloadPath = '';

  @override
  void initState() {
    super.initState();
    _cidController = TextEditingController();
    _loadGatewayOptions();
  }

  Future<void> _loadGatewayOptions() async {
    final defaultGateway = await _settingsService.loadDefaultGateway();
    setState(() {
      _gatewayOptions = [
        defaultGateway ?? 'https://gateway.pinata.cloud', // Default if null
        'https://ipfs.io',
        'https://cloudflare-ipfs.com',
        'https://fleek.co/ipfs/', // Fleek's gateway often has /ipfs/ suffix in base
        // User can also use the one from settings directly
      ];
      // Remove duplicates and ensure the default from settings is the first selectable option if not already present
      _gatewayOptions = _gatewayOptions.toSet().toList();
      if (defaultGateway != null && !_gatewayOptions.contains(defaultGateway)) {
        _gatewayOptions.insert(0, defaultGateway);
      }
      _selectedGateway = _gatewayOptions.isNotEmpty ? _gatewayOptions[0] : null;
    });
  }

  Future<void> _downloadFile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGateway == null || _selectedGateway!.isEmpty) {
      setState(() {
        _statusMessage =
            'Please select a gateway or set a default one in Settings.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Downloading...';
      _downloadPath = 'df';
    });

    final stopwatch = Stopwatch()..start();
    String downloadStatus = 'Failure';
    String cid = _cidController.text.trim();
    // Try to infer a filename from CID or use CID as filename
    String fileName = cid.length > 20 ? '${cid.substring(0, 20)}...' : cid;

    try {
      // Ensure the selected gateway is a valid URL for download
      String gatewayToUse = _selectedGateway!;
      if (_selectedGateway == "Default Public Gateway") {
        gatewayToUse =
            await _settingsService.loadDefaultGateway() ?? _gatewayOptions[0];
      }

      final success =
          await _ipfsService.downloadFromGateway(cid, gatewayToUse, fileName);
      stopwatch.stop();

      if (success) {
        final directory = await getApplicationDocumentsDirectory();
        setState(() {
          _statusMessage = 'File downloaded successfully!';
          _downloadPath = '${directory.path}/$fileName';
          downloadStatus = 'Success';
        });
      } else {
        setState(() {
          _statusMessage = 'Download failed. Check console for details.';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _statusMessage = 'Error downloading file: $e';
      });
    } finally {
      await _performanceService.logOperation(
        'Download',
        cid,
        stopwatch.elapsedMilliseconds,
        downloadStatus,
      );
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  void dispose() {
    _cidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download from IPFS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _cidController,
                decoration: const InputDecoration(
                  labelText: 'Enter IPFS CID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an IPFS CID';
                  }
                  // Basic CID validation (starts with Qm or bafy)
                  if (!value.startsWith('Qm') && !value.startsWith('bafy')) {
                    return 'Invalid IPFS CID format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_gatewayOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Gateway',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedGateway,
                  items: _gatewayOptions.map((String gateway) {
                    return DropdownMenuItem<String>(
                      value: gateway,
                      child: Text(gateway.length > 50
                          ? '${gateway.substring(0, 47)}...'
                          : gateway),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGateway = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Please select a gateway' : null,
                )
              else
                const Text(
                    "Loading gateway options... Set a default gateway in Settings."),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.downloading),
                label: const Text('Download File'),
                onPressed: _isDownloading ? null : _downloadFile,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 20),
              if (_isDownloading)
                const Center(child: CircularProgressIndicator()),
              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusMessage.contains('success') ||
                              _statusMessage.contains('successfully')
                          ? Colors.green
                          : _statusMessage.contains('failed') ||
                                  _statusMessage.contains('Error')
                              ? Colors.red
                              : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              if (_downloadPath.isNotEmpty)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Download Location:',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        SelectableText(_downloadPath),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
