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
  // Toggle Tab Index: 0 = Event Portfolio, 1 = Hero Banner, 2 = Photographer Photo
  int _selectedTabIndex = 0;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _eventNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Tab 0: Event Upload State
  String _selectedEventType = 'Wedding';
  File? _coverPhoto;
  final List<File> _shootPhotos = [];

  // Tab 1: Hero Banner State
  File? _heroPhoto;

  // Tab 2: Photographer Photo State
  File? _photographerPhoto;

  // Upload Status & Progress States
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

  // ---------------- IMAGE PICKERS ----------------
  Future<void> _pickCoverPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _coverPhoto = File(pickedFile.path));
    }
  }

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

  Future<void> _pickHeroPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _heroPhoto = File(pickedFile.path));
    }
  }

  Future<void> _pickPhotographerPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _photographerPhoto = File(pickedFile.path));
    }
  }

  String _sanitizeEventId(String rawText) {
    return rawText
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  // ---------------- UPLOAD PROCESSES ----------------
  
  // 1. Event Portfolio Upload
  Future<void> _startEventUpload() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverPhoto == null) {
      _showSnackBar("Please select a Cover Photo!", Colors.orangeAccent);
      return;
    }

    if (_shootPhotos.isEmpty) {
      _showSnackBar("Please add at least 1 Shoot Photo!", Colors.orangeAccent);
      return;
    }

    final String eventId = _sanitizeEventId(_eventNameController.text);
    final int totalFiles = 1 + _shootPhotos.length;
    int uploadedCount = 0;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Starting event upload...';
    });

    try {
      // Upload Cover Photo
      setState(() => _statusMessage = 'Uploading Cover Photo...');
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
      if (mounted) setState(() => _uploadProgress = uploadedCount / totalFiles);

      // Upload Shoot Photos
      for (int i = 0; i < _shootPhotos.length; i++) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'Uploading Shoot Photo ${i + 1} of ${_shootPhotos.length}...';
          });
        }

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
        if (mounted) setState(() => _uploadProgress = uploadedCount / totalFiles);
      }

      if (mounted) setState(() => _statusMessage = 'Updating gallery...');
      await ref.read(eventProvider.notifier).getEvents();

      if (mounted) {
        _showSnackBar('Event uploaded successfully! 🎉', Colors.green);
        _resetEventForm();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Upload failed: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 2. Hero Banner Upload
  Future<void> _startHeroUpload() async {
    if (_heroPhoto == null) {
      _showSnackBar("Please select a Hero Banner image!", Colors.orangeAccent);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.5;
      _statusMessage = 'Uploading Hero Banner to website...';
    });

    try {
      bool success = await AWSService.uploadHeroImage(_heroPhoto!);
      if (mounted) {
        if (success) {
          await ref.read(eventProvider.notifier).getEvents();
          _showSnackBar("Hero Banner updated on website! 🎉", Colors.green);
          setState(() {
            _heroPhoto = null;
            _uploadProgress = 1.0;
          });
        } else {
          _showSnackBar("Failed to upload Hero Banner", Colors.redAccent);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("Upload error: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 3. Photographer Photo Upload
  Future<void> _startPhotographerPhotoUpload() async {
    if (_photographerPhoto == null) {
      _showSnackBar("Please select Photographer photo!", Colors.orangeAccent);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.5;
      _statusMessage = 'Uploading Photographer Profile photo...';
    });

    try {
      bool success = await AWSService.uploadPhotographerPhoto(_photographerPhoto!);

      if (mounted) {
        if (success) {
          await ref.read(eventProvider.notifier).getEvents();
          _showSnackBar("Photographer Photo updated on website! 🎉", Colors.green);
          setState(() {
            _photographerPhoto = null;
            _uploadProgress = 1.0;
          });
        } else {
          _showSnackBar("Failed to upload Photographer photo", Colors.redAccent);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("Upload error: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetEventForm() {
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
        title: const Text('Admin Upload Console', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161622),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopToggleBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSelectedTabContent(),
                ),
              ),
            ],
          ),
          if (_isUploading) _buildProgressOverlay(),
        ],
      ),
    );
  }

  // ---------------- TOP TOGGLE BAR ----------------
  Widget _buildTopToggleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleItem(0, "Event Portfolio"),
          _buildToggleItem(1, "Hero Banner"),
          _buildToggleItem(2, "Photographer Photo"),
        ],
      ),
    );
  }

  Widget _buildToggleItem(int index, String title) {
    final bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amberAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TAB ROUTER ----------------
  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 1:
        return _buildHeroBannerForm();
      case 2:
        return _buildPhotographerPhotoForm();
      case 0:
      default:
        return _buildEventPortfolioForm();
    }
  }

  // ---------------- TAB 0: EVENT PORTFOLIO FORM ----------------
  Widget _buildEventPortfolioForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Event Name", style: _headingStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _eventNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("e.g. Rahul & Ananya Wedding"),
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

          const Text("Event Type", style: _headingStyle),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedEventType,
            dropdownColor: const Color(0xFF1E1E2C),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: _inputDecoration("Select Event Type"),
            items: _eventTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedEventType = val);
            },
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Cover Photo (Main Card)", style: _headingStyle),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Shoot Photos (${_shootPhotos.length})", style: _headingStyle),
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

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isUploading ? null : _startEventUpload,
              child: const Text(
                "UPLOAD EVENT TO CLOUD",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------- TAB 1: HERO BANNER FORM ----------------
  Widget _buildHeroBannerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Upload Website Hero Banner", style: _headingStyle),
        const SizedBox(height: 4),
        const Text(
          "This photo will be displayed as the main big banner on top of the website home page.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildSingleImagePicker(
          imageFile: _heroPhoto,
          onTap: _pickHeroPhoto,
          onRemove: () => setState(() => _heroPhoto = null),
          label: "Tap to select Hero Banner Image (Landscape recommended)",
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isUploading ? null : _startHeroUpload,
            child: const Text(
              "PUBLISH HERO BANNER",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- TAB 2: PHOTOGRAPHER PHOTO FORM ----------------
  Widget _buildPhotographerPhotoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Upload Photographer Photo", style: _headingStyle),
        const SizedBox(height: 4),
        const Text(
          "This photo will be displayed in the 'About Me / Photographer Profile' section on your website.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildSingleImagePicker(
          imageFile: _photographerPhoto,
          onTap: _pickPhotographerPhoto,
          onRemove: () => setState(() => _photographerPhoto = null),
          label: "Tap to select Photographer Profile Photo",
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isUploading ? null : _startPhotographerPhotoUpload,
            child: const Text(
              "PUBLISH PHOTOGRAPHER PHOTO",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- HELPER UI WIDGETS ----------------
  Widget _buildSingleImagePicker({
    required File? imageFile,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required String label,
  }) {
    if (imageFile != null) {
      return Stack(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: FileImage(imageFile), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.amberAccent),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPhotoSection() {
    if (_coverPhoto != null) {
      return Stack(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: FileImage(_coverPhoto!), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _coverPhoto = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
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
            Text("Tap to select Event Cover Photo", style: TextStyle(color: Colors.white70)),
            Text("(Required)", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ),
      ),
    );
  }

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
          child: Text("No shoot photos selected yet", style: TextStyle(color: Colors.grey)),
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
                onTap: () => setState(() => _shootPhotos.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 8),
              const Text("Please don't close the app...", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

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