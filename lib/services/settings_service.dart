import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _pinataApiKey = 'pinata_api_key';
  static const String _pinataSecretApiKey = 'pinata_secret_api_key';
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

  Future<void> saveDefaultGateway(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultGatewayUrl, url);
  }

  Future<String?> loadDefaultGateway() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultGatewayUrl) ?? 'https://gateway.pinata.cloud'; // Default to Pinata gateway
  }
}

