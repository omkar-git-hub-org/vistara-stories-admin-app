import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../aws_service.dart';

// Event state models ko track karne ke liye state class
class EventState {
  final List<Map<String, dynamic>> events;
  final bool isLoading;
  final String? errorMessage;

  EventState({
    this.events = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EventState copyWith({
    List<Map<String, dynamic>>? events,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EventState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// StateNotifier jo actual fetch logic handle karega
class EventNotifier extends StateNotifier<EventState> {
  EventNotifier() : super(EventState()) {
    getEvents(); // Initialize hote hi automatic fetch karega
  }

  Future<void> getEvents() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final fetchedData = await AWSService.fetchEvents();
      state = state.copyWith(events: fetchedData, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        errorMessage: "Kuch gadbad ho gayi: $e"
      );
    }
  }
}

// Global provider jise hum UI me watch karenge
final eventProvider = StateNotifierProvider<EventNotifier, EventState>((ref) {
  return EventNotifier();
});