import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AWSService {
  static const String _bucketName = 'vistara-stories-1';
  static const String _region = 'ap-south-1';
  static const String baseUrl = 'https://7g8fmbuxjc.execute-api.ap-south-1.amazonaws.com/events';

  // ---------------- 📤 UPLOAD METHODS ----------------

  static Future<bool> uploadToS3({
    required File file,
    required String eventId,
    required String eventType,
    required String folderType,
    required String fileName,
  }) async {
    try {
      final String s3Key = 'events/$eventType/$eventId/$folderType/$fileName';
      final Uri s3Uri = Uri.parse('https://$_bucketName.s3.$_region.amazonaws.com/$s3Key');
      final Uint8List bytes = await file.readAsBytes();

      final response = await http.put(
        s3Uri,
        headers: {'Content-Type': 'image/jpeg'},
        body: bytes,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print("S3 Upload Error: $e");
      return false;
    }
  }

  /// Upload Hero Banner Image (folderType set to Cover-Photo so Lambda 1 populates coverPhoto)
  static Future<bool> uploadHeroImage(File file) async {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return await uploadToS3(
      file: file,
      eventId: 'hero-$timestamp',
      eventType: 'Hero',
      folderType: 'Cover-Photo',
      fileName: 'hero_banner_$timestamp.jpg',
    );
  }

  /// Upload Photographer Photo
  static Future<bool> uploadPhotographerPhoto(File file) async {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return await uploadToS3(
      file: file,
      eventId: 'photographer-$timestamp',
      eventType: 'Photographer',
      folderType: 'Cover-Photo',
      fileName: 'photographer_$timestamp.jpg',
    );
  }

  // ---------------- 📥 FETCH DATA ----------------

  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("Fetch Events Error: $e");
      return [];
    }
  }

  // ---------------- 🗑️ DELETE METHOD (FIXED) ----------------

  /// Direct Delete via Query Parameter + Body Fallback
  static Future<bool> deleteEvent(String eventId) async {
    try {
      // Query param added because API Gateway strips JSON body on DELETE
      final Uri uri = Uri.parse('$baseUrl?eventId=$eventId');
      
      final response = await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'eventId': eventId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print("Delete Error: $e");
      return false;
    }
  }
}