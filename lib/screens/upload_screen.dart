import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ipfs_app/services/ipfs_service.dart';
import 'package:ipfs_app/services/settings_service.dart';
import 'package:ipfs_app/services/performance_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final IpfsService _ipfsService = IpfsService();
  final SettingsService _settingsService = SettingsService();
  final PerformanceService _performanceService = PerformanceService();

  File? _selectedFile;
  String _statusMessage = '';
  bool _isUploading = false;
  String _ipfsHash = '';
  String _selectedService = 'Pinata';
  final List<String> _serviceOptions = ['Pinata', 'Filebase'];

  Future<void> _pickFile() async {
    setState(() {
      _statusMessage = '';
      _ipfsHash = '';
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      setState(() {
        _statusMessage = 'Please select a file first.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading...';
      _ipfsHash = '';
    });

    final stopwatch = Stopwatch()..start();
    String uploadStatus = 'Failure';
    String? ipfsHash;
    String? errorMessage;

    try {
      if (_selectedService == 'Pinata') {
        final pinataKeys = await _settingsService.loadPinataKeys();
        final apiKey = pinataKeys['apiKey'];
        final apiSecret = pinataKeys['apiSecret'];

        if (apiKey == null ||
            apiKey.isEmpty ||
            apiSecret == null ||
            apiSecret.isEmpty) {
          setState(() {
            _statusMessage = 'Pinata API Key or Secret is not set in Settings.';
            _isUploading = false;
          });
          return;
        }

        ipfsHash = await _ipfsService.uploadToPinata(
            _selectedFile!, apiKey, apiSecret);
      } else if (_selectedService == 'Filebase') {
        final filebaseKeys = await _settingsService.loadFilebaseKeys();
        final ipfsToken = filebaseKeys['apiKey'];
        final ipfsEndpoint = filebaseKeys['ipfsEndpoint'];

        if (ipfsToken == null || ipfsToken.isEmpty) {
          setState(() {
            _statusMessage =
                'Filebase IPFS RPC API Token is not set in Settings.';
            _isUploading = false;
          });
          return;
        }

        if (ipfsEndpoint == null || ipfsEndpoint.isEmpty) {
          setState(() {
            _statusMessage = 'Filebase IPFS Endpoint is not set in Settings.';
            _isUploading = false;
          });
          return;
        }

        ipfsHash = await _ipfsService.uploadToFilebaseIPFS(
            _selectedFile!, ipfsToken, "", ipfsEndpoint);
      }

      stopwatch.stop();

      if (ipfsHash != null) {
        setState(() {
          _statusMessage = 'File uploaded successfully!';
          _ipfsHash = ipfsHash ?? '';
          uploadStatus = 'Success';
        });
      } else {
        setState(() {
          _statusMessage = 'Upload failed. Check console for details.';
          errorMessage = 'No hash returned from service';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _statusMessage = 'Error uploading file: $e';
        errorMessage = e.toString();
      });
    } finally {
      final fileSize = await _selectedFile!.length();

      await _performanceService.logOperation(
        'Upload to $_selectedService',
        _selectedFile!.path.split('/').last,
        stopwatch.elapsedMilliseconds,
        uploadStatus,
        _selectedService,
        fileSize,
        error: errorMessage,
      );

      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload to IPFS ($_selectedService)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Service',
                border: OutlineInputBorder(),
              ),
              value: _selectedService,
              items: _serviceOptions.map((String service) {
                return DropdownMenuItem<String>(
                  value: service,
                  child: Text(service),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedService = newValue;

                    _ipfsHash = '';
                    _statusMessage = '';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Select File'),
              onPressed: _pickFile,
            ),
            const SizedBox(height: 10),
            if (_selectedFile != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected File:',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(_selectedFile!.path.split('/').last),
                      FutureBuilder<int>(
                        future: _selectedFile!.length(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            return Text(
                                'Size: ${(snapshot.data! / 1024).toStringAsFixed(2)} KB');
                          }
                          return const Text('Size: calculating...');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_selectedFile != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: Text('Upload to $_selectedService'),
                onPressed: _isUploading ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            const SizedBox(height: 20),
            if (_isUploading) const Center(child: CircularProgressIndicator()),
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
            if (_ipfsHash.isNotEmpty)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IPFS Hash (CID):',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      SelectableText(_ipfsHash),
                      const SizedBox(height: 8),
                      Text(
                          'You can access your file via a public gateway, e.g.:',
                          style: Theme.of(context).textTheme.bodySmall),
                      SelectableText(
                          _selectedService == 'Pinata'
                              ? 'https://gateway.pinata.cloud/ipfs/$_ipfsHash'
                              : 'https://gateway.filebase.io/ipfs/$_ipfsHash',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.blue)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
