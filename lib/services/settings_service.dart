import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _pinataApiKey = 'pinata_api_key';
  static const String _pinataSecretApiKey = 'pinata_secret_api_key';
  static const String _filebaseApiKey = 'filebase_api_key';
  static const String _filebaseApiSecret = 'filebase_api_secret';
  static const String _filebaseIpfsEndpoint = 'filebase_ipfs_endpoint';
  static const String _defaultGatewayUrl = 'default_gateway_url';

  Future<void> savePinataKeys(String apiKey, String apiSecret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinataApiKey, apiKey);
    await prefs.setString(_pinataSecretApiKey, apiSecret);
  }

  Future<Map<String, String?>> loadPinataKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiKey': prefs.getString(_pinataApiKey),
      'apiSecret': prefs.getString(_pinataSecretApiKey),
    };
  }

  Future<void> saveFilebaseKeys(
      String apiKey, String apiSecret, String ipfsEndpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filebaseApiKey, apiKey);
    await prefs.setString(_filebaseApiSecret, apiSecret);
    await prefs.setString(_filebaseIpfsEndpoint, ipfsEndpoint);
  }

  Future<Map<String, String?>> loadFilebaseKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiKey': prefs.getString(_filebaseApiKey),
      'apiSecret': prefs.getString(_filebaseApiSecret),
      'ipfsEndpoint': prefs.getString(_filebaseIpfsEndpoint) ??
          'https://api.filebase.io/v1/ipfs',
    };
  }

  Future<void> saveDefaultGateway(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultGatewayUrl, url);
  }

  Future<String?> loadDefaultGateway() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultGatewayUrl) ??
        'https://gateway.pinata.cloud';
  }
}
