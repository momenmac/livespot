import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:mime/mime.dart';
import 'dart:convert';

class AttachmentsApi {
  final AccountProvider _accountProvider = AccountProvider();

  /// Upload a file (image, video, etc.) to the media API
  /// Returns the Firebase URL if successful, null if failed
  Future<String?> uploadFile(XFile file, {String contentType = 'image'}) async {
    try {
      await _accountProvider.initialize();
      final token = _accountProvider.token;

      if (token == null) {
        debugPrint('AttachmentsApi: No token available for upload');
        return null;
      }

      // Create the upload URL using the media-api path instead of media/upload
      final uploadUrl = Uri.parse('${ApiUrls.baseUrl}/media-api/upload/');

      // Determine MIME type
      String? mimeType;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        mimeType = lookupMimeType(file.path);
      }

      if (mimeType == null) {
        // Fallback mime type based on file extension
        final ext = file.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg'].contains(ext)) {
          mimeType = 'image/jpeg';
        } else if (ext == 'png') {
          mimeType = 'image/png';
        } else if (ext == 'gif') {
          mimeType = 'image/gif';
        } else if (ext == 'mp4') {
          mimeType = 'video/mp4';
        } else {
          mimeType = 'application/octet-stream';
        }
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', uploadUrl);

      // Add authorization header with JWT token - this should bypass CSRF requirements
      request.headers['Authorization'] = 'Bearer ${token.accessToken}';

      // Add file
      final bytes = await file.readAsBytes();
      final httpFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(httpFile);

      // Add content type field
      request.fields['content_type'] = contentType;

      // Send request
      debugPrint(
          'AttachmentsApi: Sending file upload request to ${uploadUrl.toString()}');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Handle response
      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        // Prioritize Firebase URL if available
        String? imageUrl = responseData['firebase_url'];

        // If Firebase URL is missing or empty, use the local URL but fix it
        if (imageUrl == null || imageUrl.isEmpty) {
          final String? localUrl = responseData['url'];

          if (localUrl != null && localUrl.isNotEmpty) {
            // Fix the URL based on platform
            if (localUrl.contains('localhost') || localUrl.startsWith('/')) {
              imageUrl = _fixLocalUrl(localUrl);
            } else {
              imageUrl = localUrl;
            }
          }
        }

        debugPrint('AttachmentsApi: Upload successful, URL: $imageUrl');
        return imageUrl;
      } else {
        debugPrint(
            'AttachmentsApi: Upload failed with status code ${response.statusCode}');
        debugPrint('AttachmentsApi: Response body: ${response.body}');

        // Retry with direct URL if you get CSRF error
        if (response.statusCode == 403 && response.body.contains('CSRF')) {
          return _uploadFileNoMultipart(file, contentType);
        }

        return null;
      }
    } catch (e) {
      debugPrint('AttachmentsApi: Error during upload: $e');
      return null;
    }
  }

  /// Alternative upload method that uses direct PUT request instead of multipart
  /// This might bypass certain CSRF issues on some server configurations
  Future<String?> _uploadFileNoMultipart(XFile file, String contentType) async {
    try {
      debugPrint('AttachmentsApi: Trying alternative upload method');
      await _accountProvider.initialize();
      final token = _accountProvider.token;

      if (token == null) return null;

      // Use the correct endpoint for direct upload
      final uploadUrl =
          Uri.parse('${ApiUrls.baseUrl}/media-api/direct-upload/');

      // Read file as bytes
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);

      // Send request with all data in JSON body
      final response = await http.post(
        uploadUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.accessToken}',
        },
        body: json.encode({
          'file_data': base64File,
          'file_name': file.name,
          'content_type': contentType,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);

        String? imageUrl = responseData['firebase_url'];
        if (imageUrl == null || imageUrl.isEmpty) {
          final String? localUrl = responseData['url'];

          if (localUrl != null && localUrl.isNotEmpty) {
            imageUrl = _fixLocalUrl(localUrl);
          }
        }

        debugPrint(
            'AttachmentsApi: Alternative upload successful, URL: $imageUrl');
        return imageUrl;
      } else {
        debugPrint(
            'AttachmentsApi: Alternative upload failed with status code ${response.statusCode}');
        debugPrint('AttachmentsApi: Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AttachmentsApi: Error during alternative upload: $e');
      return null;
    }
  }

  // Helper method to fix URLs returned from the server
  String _fixLocalUrl(String url) {
    // Remove any leading slash
    final String cleanUrl = url.startsWith('/') ? url.substring(1) : url;

    // If URL contains localhost or starts with a relative path, fix it
    if (url.contains('localhost') || url.startsWith('/')) {
      // URL without the domain part
      final String relativePath = cleanUrl.contains('localhost')
          ? cleanUrl.split('localhost:8000/').last
          : cleanUrl;

      // Use the platform-specific base URL
      return '${ApiUrls.baseUrl}/$relativePath';
    }

    return url;
  }
}
