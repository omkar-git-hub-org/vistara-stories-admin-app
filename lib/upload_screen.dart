import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../aws_service.dart';
import '../providers/event_provider.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _eventNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedEventType = 'Wedding';
  File? _coverPhoto;
  List<File> _shootPhotos = [];

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _statusMessage = '';

  final List<String> _eventTypes = [
    'Wedding',
    'Pre-Wedding',
    'Birthday',
    'Corporate',
    'Fashion',
    'Maternity',
    'Other'
  ];

  @override
  void dispose() {
    _eventNameController.dispose();
    super.dispose();
  }

  // Cover Photo Picker
  Future<void> _pickCoverPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // Performance & bandwidth optimization
    );
    if (pickedFile != null) {
      setState(() {
        _coverPhoto = File(pickedFile.path);
      });
    }
  }

  // Shoot Photos Picker (Multiple)
  Future<void> _pickShootPhotos() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 85,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _shootPhotos.addAll(pickedFiles.map((x) => File(x.path)).toList());
      });
    }
  }

  // Sanitize Event Name to S3 & DynamoDB safe ID
  String _sanitizeEventId(String rawText) {
    return rawText
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // Special chars remove
        .replaceAll(RegExp(r'\s+'), '-'); // Space to hyphen
  }

  // Upload Logic with Validations
  Future<void> _startUploadProcess() async {
    // 1. Form Validation Check
    if (!_formKey.currentState!.validate()) return;

    // 2. Cover Photo Validation
    if (_coverPhoto == null) {
      _showSnackBar("Please select a Cover Photo!", Colors.orangeAccent);
      return;
    }

    // 3. Shoot Photos Validation
    if (_shootPhotos.isEmpty) {
      _showSnackBar("Please add at least 1 Shoot Photo!", Colors.orangeAccent);
      return;
    }

    final String eventId = _sanitizeEventId(_eventNameController.text);
    final int totalFiles = 1 + _shootPhotos.length; // Cover + Shoot Photos
    int uploadedCount = 0;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Starting upload process...';
    });

    try {
      // Step A: Upload Cover Photo
      setState(() {
        _statusMessage = 'Uploading Cover Photo...';
      });

      final String coverFileName =
          'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';

      bool coverSuccess = await AWSService.uploadToS3(
        file: _coverPhoto!,
        eventId: eventId,
        eventType: _selectedEventType,
        folderType: 'Cover-Photo',
        fileName: coverFileName,
      );

      if (!coverSuccess) throw Exception("Failed to upload Cover Photo");

      uploadedCount++;
      setState(() {
        _uploadProgress = uploadedCount / totalFiles;
      });

      // Step B: Upload Shoot Photos
      for (int i = 0; i < _shootPhotos.length; i++) {
        setState(() {
          _statusMessage =
              'Uploading Shoot Photo ${i + 1} of ${_shootPhotos.length}...';
        });

        final String shootFileName =
            'shoot_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        bool shootSuccess = await AWSService.uploadToS3(
          file: _shootPhotos[i],
          eventId: eventId,
          eventType: _selectedEventType,
          folderType: 'Shoot-Photos',
          fileName: shootFileName,
        );

        if (!shootSuccess) throw Exception("Failed uploading photo ${i + 1}");

        uploadedCount++;
        setState(() {
          _uploadProgress = uploadedCount / totalFiles;
        });
      }

      // Step C: Complete & Refresh
      setState(() {
        _statusMessage = 'Finishing up... Updating gallery!';
      });

      // Riverpod Provider Refresh
      await ref.read(eventProvider.notifier).getEvents();

      if (mounted) {
        _showSnackBar('Event uploaded successfully! 🎉', Colors.green);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Upload failed: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _resetForm() {
    _eventNameController.clear();
    setState(() {
      _coverPhoto = null;
      _shootPhotos.clear();
      _selectedEventType = 'Wedding';
      _uploadProgress = 0.0;
    });
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F15),
      appBar: AppBar(
        title: const Text('Create New Event', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161622),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Event Name Input
                  const Text("Event Name", style: _headingStyle),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _eventNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("e.g. Rahul & Ananya's Wedding"),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Event name is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Event name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 2. Event Type Dropdown
                  const Text("Event Type", style: _headingStyle),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedEventType,
                    dropdownColor: const Color(0xFF1E1E2C),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: _inputDecoration("Select Event Type"),
                    items: _eventTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedEventType = val);
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Cover Photo Picker Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Cover Photo (Main)", style: _headingStyle),
                      if (_coverPhoto != null)
                        TextButton.icon(
                          onPressed: _pickCoverPhoto,
                          icon: const Icon(Icons.edit, size: 16, color: Colors.amberAccent),
                          label: const Text("Change", style: TextStyle(color: Colors.amberAccent)),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildCoverPhotoSection(),
                  const SizedBox(height: 24),

                  // 4. Shoot Photos Picker Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Shoot Photos (${_shootPhotos.length})",
                        style: _headingStyle,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E2C),
                          foregroundColor: Colors.amberAccent,
                        ),
                        onPressed: _pickShootPhotos,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text("Add Photos"),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildShootPhotosGrid(),
                  const SizedBox(height: 32),

                  // 5. Submit Upload Button
                  SizedBox(),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isUploading ? null : _startUploadProcess,
                      child: const Text(
                        "UPLOAD EVENT TO CLOUD",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 6. Upload Progress Modal Overlay
          if (_isUploading) _buildProgressOverlay(),
        ],
      ),
    );
  }

  // Cover Photo Box
  Widget _buildCoverPhotoSection() {
    if (_coverPhoto != null) {
      return Stack(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(_coverPhoto!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _coverPhoto = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickCoverPhoto,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.amberAccent),
            SizedBox(height: 8),
            Text("Tap to select Cover Photo", style: TextStyle(color: Colors.white70)),
            Text("(Required)", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Shoot Photos Grid
  Widget _buildShootPhotosGrid() {
    if (_shootPhotos.isEmpty) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            "No shoot photos selected yet",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _shootPhotos.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_shootPhotos[index], fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _shootPhotos.removeAt(index);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Full Screen Upload Progress Overlay
  Widget _buildProgressOverlay() {
    final percentageText = (_uploadProgress * 100).toStringAsFixed(0);

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: _uploadProgress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      color: Colors.amberAccent,
                    ),
                  ),
                  Text(
                    "$percentageText%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please don't close the app...",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Styles & Input Decoration Constants
  static const TextStyle _headingStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF1E1E2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amberAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}