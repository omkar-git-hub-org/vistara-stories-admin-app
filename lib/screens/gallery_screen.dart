import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vistara_stories/upload_screen.dart';
import '../providers/event_provider.dart';
import 'event_detail_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  int _selectedTab = 0; // 0: Events, 1: Hero Banner, 2: Photographer Photo

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(eventProvider.notifier).getEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(eventProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F15),
      appBar: AppBar(
        title: const Text(
          'Vistara Stories',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: const Color(0xFF161622),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amberAccent),
            onPressed: () => ref.read(eventProvider.notifier).getEvents(),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildToggleBar(),
          const SizedBox(height: 8),
          Expanded(
            child: _buildBody(context, ref, eventState),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amberAccent,
        foregroundColor: Colors.black,
        elevation: 4,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadScreen(),
            ),
          );
          ref.read(eventProvider.notifier).getEvents();
        },
        icon: const Icon(Icons.add_a_photo, size: 22),
        label: const Text(
          'New Upload',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  // 🎛️ TOGGLE BAR WIDGET
  Widget _buildToggleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleButton(0, 'Events'),
          _toggleButton(1, 'Hero Banner'),
          _toggleButton(2, 'Photographer'),
        ],
      ),
    );
  }

  Widget _toggleButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  // 📱 BODY BUILDER WITH FIXED FILTERING
  Widget _buildBody(BuildContext context, WidgetRef ref, EventState state) {
    if (state.isLoading) {
      return _buildShimmerLoading();
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      );
    }

    // Tab 0: Pure Event Portfolio (Excludes Hero & Photographer items)
    if (_selectedTab == 0) {
      final eventsList = state.events.where((e) {
        final type = (e['type'] ?? '').toString().toLowerCase();
        final id = (e['eventId'] ?? '').toString().toLowerCase();
        
        return type != 'website' &&
            type != 'hero' &&
            type != 'photographer' &&
            !id.startsWith('hero-') &&
            !id.startsWith('photographer-') &&
            id != 'hero_banner' &&
            id != 'website-assets';
      }).toList();

      if (eventsList.isEmpty) return _buildEmptyState('No event portfolios uploaded yet');
      return _buildEventGrid(eventsList);
    }

    // Tab 1: Hero Banner
    if (_selectedTab == 1) {
      final heroEvents = state.events.where((e) {
        final type = (e['type'] ?? '').toString().toLowerCase();
        final id = (e['eventId'] ?? '').toString().toLowerCase();
        return type == 'hero' || id.startsWith('hero-') || id == 'hero_banner';
      }).toList();

      if (heroEvents.isEmpty) return _buildEmptyState('No Hero Banners uploaded yet');
      return _buildHeroGrid(heroEvents);
    }

    // Tab 2: Photographer Profile Photos
    final photographerEvents = state.events.where((e) {
      final type = (e['type'] ?? '').toString().toLowerCase();
      final id = (e['eventId'] ?? '').toString().toLowerCase();
      return type == 'website' || type == 'photographer' || id.startsWith('photographer-') || id == 'website-assets';
    }).toList();

    if (photographerEvents.isEmpty) return _buildEmptyState('No Photographer profile photos uploaded yet');
    return _buildPhotographerGrid(photographerEvents);
  }

  // 1️⃣ EVENT PORTFOLIO GRID
  Widget _buildEventGrid(List<Map<String, dynamic>> events) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final String eventId = event['eventId'] ?? 'Event';
          final String coverUrl = event['coverPhoto'] ?? '';
          final String eventType = event['type'] ?? 'General';
          final List<dynamic> photos = event['photos'] ?? [];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(
                    eventId: eventId,
                    coverPhoto: coverUrl,
                    photos: List<String>.from(photos),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1E1E2C),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _showDeleteConfirmation(context, ref, eventId, 'event'),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                eventType.toUpperCase(),
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              eventId.toUpperCase().replaceAll('-', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            Text(
                              '${photos.length} Photos',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 2️⃣ HERO BANNER GRID
  Widget _buildHeroGrid(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final String heroUrl = item['coverPhoto'] ?? item['heroUrl'] ?? (item['photos'] != null && item['photos'].isNotEmpty ? item['photos'][0] : '');
          final String id = item['eventId'] ?? 'hero_banner';

          return Container(
            height: 180,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF1E1E2C),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    heroUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _showDeleteConfirmation(context, ref, id, 'Hero Banner'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 3️⃣ PHOTOGRAPHER PHOTO GRID
  Widget _buildPhotographerGrid(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final String photoUrl = item['coverPhoto'] ?? (item['photos'] != null && item['photos'].isNotEmpty ? item['photos'][0] : '');
          final String id = item['eventId'] ?? 'photographer';

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF1E1E2C),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _showDeleteConfirmation(context, ref, id, 'Photographer Photo'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🗑️ DELETE CONFIRMATION DIALOG (FIXED UNIFIED DELETE LOGIC)
  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String eventId, String typeTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text('Delete $typeTitle?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this item? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);

              // Standard Direct Delete using eventId
              bool success = await ref.read(eventProvider.notifier).deleteEvent(eventId);

              // Auto-refresh state
              await ref.read(eventProvider.notifier).getEvents();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Deleted successfully! 🎉" : "Failed to delete."),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 70, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[900]!,
            highlightColor: Colors.grey[800]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}