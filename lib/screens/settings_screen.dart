import 'package:flutter/material.dart';
import 'package:ipfs_app/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();

  late TextEditingController _pinataApiKeyController;
  late TextEditingController _pinataSecretApiKeyController;
  late TextEditingController _filebaseApiKeyController;
  late TextEditingController _filebaseSecretApiKeyController;
  late TextEditingController _filebaseIpfsEndpointController;
  late TextEditingController _defaultGatewayUrlController;

  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _pinataApiKeyController = TextEditingController();
    _pinataSecretApiKeyController = TextEditingController();
    _filebaseApiKeyController = TextEditingController();
    _filebaseSecretApiKeyController = TextEditingController();
    _filebaseIpfsEndpointController = TextEditingController();
    _defaultGatewayUrlController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final pinataKeys = await _settingsService.loadPinataKeys();
    final filebaseKeys = await _settingsService.loadFilebaseKeys();
    final defaultGateway = await _settingsService.loadDefaultGateway();

    setState(() {
      _pinataApiKeyController.text = pinataKeys['apiKey'] ?? '';
      _pinataSecretApiKeyController.text = pinataKeys['apiSecret'] ?? '';
      _filebaseApiKeyController.text = filebaseKeys['apiKey'] ?? '';
      _filebaseSecretApiKeyController.text = filebaseKeys['apiSecret'] ?? '';
      _filebaseIpfsEndpointController.text =
          filebaseKeys['ipfsEndpoint'] ?? 'https://api.filebase.io/v1/ipfs';
      _defaultGatewayUrlController.text =
          defaultGateway ?? 'https://gateway.pinata.cloud';
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _settingsService.savePinataKeys(
        _pinataApiKeyController.text,
        _pinataSecretApiKeyController.text,
      );
      await _settingsService.saveFilebaseKeys(
        _filebaseApiKeyController.text,
        _filebaseSecretApiKeyController.text,
        _filebaseIpfsEndpointController.text,
      );
      await _settingsService
          .saveDefaultGateway(_defaultGatewayUrlController.text);
      setState(() {
        _statusMessage = 'Settings saved successfully!';
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
    } else {
      setState(() {
        _statusMessage = 'Please correct the errors in the form.';
      });
    }
  }

  @override
  void dispose() {
    _pinataApiKeyController.dispose();
    _pinataSecretApiKeyController.dispose();
    _filebaseApiKeyController.dispose();
    _filebaseSecretApiKeyController.dispose();
    _filebaseIpfsEndpointController.dispose();
    _defaultGatewayUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              Text('Pinata Configuration',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pinataApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Pinata API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pinataSecretApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Pinata Secret API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('Filebase Configuration',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextFormField(
                controller: _filebaseApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Filebase API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _filebaseSecretApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'Filebase Secret API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _filebaseIpfsEndpointController,
                decoration: const InputDecoration(
                  labelText: 'Filebase IPFS Endpoint',
                  hintText: 'e.g., https://api.filebase.io/v1/ipfs',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!Uri.tryParse(value)!.isAbsolute) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text('IPFS Gateway Configuration',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextFormField(
                controller: _defaultGatewayUrlController,
                decoration: const InputDecoration(
                  labelText: 'Default Public Gateway URL',
                  hintText:
                      'e.g., https://ipfs.io or https://gateway.filebase.io',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a gateway URL';
                  }
                  if (!Uri.tryParse(value)!.isAbsolute) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save Settings'),
              ),
              const SizedBox(height: 16),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('successfully')
                        ? Colors.green
                        : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
