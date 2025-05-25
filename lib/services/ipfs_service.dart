// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class IpfsService {
  int _lastDownloadedFileSize = 0;

  int get lastDownloadedFileSize => _lastDownloadedFileSize;

  Future<String?> uploadToPinata(
      File file, String apiKey, String apiSecret) async {
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

  Future<String?> uploadToFilebaseIPFS(File file, String ipfsApiToken,
      String unusedSecret, String ipfsEndpoint) async {
    try {
      if (ipfsEndpoint.isEmpty) {
        ipfsEndpoint = 'https://rpc.filebase.io';
      }

      if (ipfsEndpoint.endsWith('/')) {
        ipfsEndpoint = ipfsEndpoint.substring(0, ipfsEndpoint.length - 1);
      }

      final url = Uri.parse('$ipfsEndpoint/api/v0/add');

      final request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer $ipfsApiToken';

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedResponse = jsonDecode(responseBody);

        return decodedResponse['Hash'] ??
            decodedResponse['Cid'] ??
            decodedResponse['cid'] ??
            decodedResponse['hash'];
      } else {
        print('Filebase IPFS upload failed: ${response.statusCode}');
        print('Response: $responseBody');

        if (response.statusCode == 401 || response.statusCode == 403) {
          return await _uploadToFilebaseIPFSAlternative(
              file, ipfsApiToken, ipfsEndpoint);
        }

        return null;
      }
    } catch (e) {
      print('Error uploading to Filebase IPFS: $e');
      return null;
    }
  }

  Future<String?> _uploadToFilebaseIPFSAlternative(
      File file, String ipfsApiToken, String ipfsEndpoint) async {
    try {
      final url = Uri.parse('$ipfsEndpoint/api/v0/pin/add');

      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $ipfsApiToken';

      request.fields['arg'] = file.path;

      print('Próba alternatywnego API: $url');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Alternatywna metoda status code: ${response.statusCode}');
      print('Alternatywna metoda response body: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedResponse = jsonDecode(responseBody);
        return decodedResponse['Pins']?[0] ??
            decodedResponse['Hash'] ??
            decodedResponse['Cid'];
      } else {
        print('Alternatywna metoda nie zadziałała: ${response.statusCode}');
        print('Response: $responseBody');
        return null;
      }
    } catch (e) {
      print('Error w alternatywnej metodzie: $e');
      return null;
    }
  }

  Future<bool> downloadFromGateway(
      String cid, String gatewayUrl, String fileName) async {
    final downloadUrl = '$gatewayUrl/ipfs/$cid';
    try {
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        _lastDownloadedFileSize = response.bodyBytes.length;

        final directory = await getApplicationDocumentsDirectory();
        final savePath = '${directory.path}/$fileName';
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        print('File downloaded to: $savePath');
        print('File size: $_lastDownloadedFileSize bytes');
        return true;
      } else {
        print('IPFS download failed: ${response.statusCode}');
        print('Response: ${response.body}');
        _lastDownloadedFileSize = 0;
        return false;
      }
    } catch (e) {
      print('Error downloading from IPFS: $e');
      _lastDownloadedFileSize = 0;
      return false;
    }
  }
}
