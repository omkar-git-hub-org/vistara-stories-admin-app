import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AWSService {
  static const String bucketName = "vistara-stories-1";
  static const String region = "ap-south-1";

  // S3 me image upload karne ka function
  static Future<bool> uploadToS3({
    required File file,
    required String eventId,
    required String folderType, // 'Cover-Photo' ya 'Shoot-Photos'
    required String fileName,
  }) async {
    final String s3Url = 
        "https://$bucketName.s3.$region.amazonaws.com/events/$eventId/$folderType/$fileName";

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

  // DynamoDB se events list lane ke liye
  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    const String apiUrl = "https://7g8fmbuxjc.execute-api.ap-south-1.amazonaws.com/events";
    
    try {
      final response = await http.get(Uri.parse(apiUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> decodedList = json.decode(response.body);
        return decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        print("Fetch Error: Server responded with status ${response.statusCode}");
      }
    } catch (e) {
      print("Fetch Error details: $e");
    }
    return [];
  }
}