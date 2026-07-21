import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../aws_service.dart';

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

class EventNotifier extends StateNotifier<EventState> {
  EventNotifier() : super(EventState()) {
    getEvents();
  }

  Future<void> getEvents() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final fetchedData = await AWSService.fetchEvents();
      state = state.copyWith(events: fetchedData, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        errorMessage: "Error: $e"
      );
    }
  }

  // Delete Action Handling
  Future<bool> deleteEvent(String eventId) async {
    final success = await AWSService.deleteEvent(eventId);
    if (success) {
      final updatedList = state.events.where((e) => e['eventId'] != eventId).toList();
      state = state.copyWith(events: updatedList);
    }
    return success;
  }
}

final eventProvider = StateNotifierProvider<EventNotifier, EventState>((ref) {
  return EventNotifier();
});