import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class IpfsService {
  Future<String?> uploadToPinata(File file, String apiKey, String apiSecret) async {
    final url = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');
    final request = http.MultipartRequest('POST', url);

    request.headers['pinata_api_key'] = apiKey;
    request.headers['pinata_secret_api_key'] = apiSecret;

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(responseBody);
        return decodedResponse['IpfsHash'];
      } else {
        print('Pinata upload failed: ${response.statusCode}');
        print('Response: $responseBody');
        return null;
      }
    } catch (e) {
      print('Error uploading to Pinata: $e');
      return null;
    }
  }

  Future<bool> downloadFromGateway(String cid, String gatewayUrl, String fileName) async {
    final downloadUrl = '$gatewayUrl/ipfs/$cid';
    try {
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final savePath = '${directory.path}/$fileName';
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        print('File downloaded to: $savePath');
        return true;
      } else {
        print('IPFS download failed: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error downloading from IPFS: $e');
      return false;
    }
  }

  // Placeholder for Fleek integration if different from generic gateway download
  // For now, Fleek can be used as a public gateway in downloadFromGateway
  // If Fleek provides a specific upload API similar to Pinata, it would be added here.
  // For simplicity, we'll assume Fleek is used as one of the public gateway options for downloads.
}

