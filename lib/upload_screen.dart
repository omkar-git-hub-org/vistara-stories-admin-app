import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'aws_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _eventNameController = TextEditingController();
  File? _coverPhoto;
  List<File> _shootPhotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // 1 Cover Photo select karne ke liye
  Future<void> _pickCoverPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _coverPhoto = File(image.path);
      });
    }
  }

  // Multiple (Max 10) photos select karne ke liye
  Future<void> _pickShootPhotos() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        // Sirf top 10 photos ko hi limit karna agar user zyada select karle
        _shootPhotos = images.take(10).map((img) => File(img.path)).toList();
      });
    }
  }

  // Upload trigger karne ke liye
  Future<void> _uploadAll() async {
    final String eventName = _eventNameController.text.trim();
    if (eventName.isEmpty || _coverPhoto == null || _shootPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sab details fill karein aur photos select karein!")),
      );
      return;
    }

    setState(() => _isUploading = true);

    // Event Name ko formatting dena (e.g. "My Wedding" -> "my-wedding")
    final String eventId = eventName.toLowerCase().replaceAll(' ', '-');

    try {
      // 1. Cover Photo upload karna
      await AWSService.uploadToS3(
        file: _coverPhoto!,
        eventId: eventId,
        folderType: "Cover-Photo",
        fileName: "cover.jpg",
      );

      // 2. Shoot Photos upload karna
      for (int i = 0; i < _shootPhotos.length; i++) {
        await AWSService.uploadToS3(
          file: _shootPhotos[i],
          eventId: eventId,
          folderType: "Shoot-Photos",
          fileName: "photo_${i + 1}.jpg",
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event successfully upload ho gaya! DynamoDB check karein.")),
      );

      // UI reset karna
      _eventNameController.clear();
      setState(() {
        _coverPhoto = null;
        _shootPhotos = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Event Upload")),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Photos S3 par ja rahi hain, please wait...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _eventNameController,
                    decoration: const InputDecoration(
                      labelText: "Event Name (e.g., Shadi Rahul)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickCoverPhoto,
                    icon: const Icon(Icons.image),
                    label: const Text("Select 1 Cover Photo"),
                  ),
                  if (_coverPhoto != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Cover Selected: ${_coverPhoto!.path.split('/').last}", style: const TextStyle(color: Colors.green)),
                    ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _pickShootPhotos,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Select Shoot Photos (Max 10)"),
                  ),
                  if (_shootPhotos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("${_shootPhotos.length} Photos Selected", style: const TextStyle(color: Colors.green)),
                    ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _uploadAll,
                    child: const Text("Upload to AWS", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}