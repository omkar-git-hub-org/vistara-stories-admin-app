import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AWSService {
  static const String bucketName = "vistara-stories-1";
  static const String region = "ap-south-1";
  static const String apiUrl = "https://7g8fmbuxjc.execute-api.ap-south-1.amazonaws.com/events";

  // S3 Image Upload (Path with eventType)
  static Future<bool> uploadToS3({
    required File file,
    required String eventId,
    required String eventType, // e.g. Wedding, PreWedding, Birthday
    required String folderType, // 'Cover-Photo' ya 'Shoot-Photos'
    required String fileName,
  }) async {
    // New S3 key format: events/eventType/eventId/folderType/fileName
    final String s3Url = 
        "https://$bucketName.s3.$region.amazonaws.com/events/$eventType/$eventId/$folderType/$fileName";

    try {
      final fileBytes = await file.readAsBytes();
      final response = await http.put(
        Uri.parse(s3Url),
        headers: {
          'Content-Type': 'image/jpeg',
        },
        body: fileBytes,
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Upload Error: $e");
      return false;
    }
  }

  // DynamoDB se Events Fetch karna (GET)
  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> decodedList = json.decode(response.body);
        return decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print("Fetch Error: Status code ${response.statusCode}");
      }
    } catch (e) {
      print("Fetch Error details: $e");
    }
    return [];
  }

  // DynamoDB se Event Delete karna (DELETE)
  static Future<bool> deleteEvent(String eventId) async {
    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'eventId': eventId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Delete Event Error: $e");
      return false;
    }
  }
}