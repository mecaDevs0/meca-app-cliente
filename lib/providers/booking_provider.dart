import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BookingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get bookings => _bookings;
  bool get isLoading => _isLoading;

  Future<void> loadBookings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getMyBookings();
      if (response.statusCode == 200) {
        _bookings = List<Map<String, dynamic>>.from(response.data['bookings'] ?? []);
      }
    } catch (e) {
      print('Load bookings error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createBooking(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.createBooking(data);
      if (response.statusCode == 201) {
        await loadBookings();
        return true;
      }
    } catch (e) {
      print('Create booking error: $e');
    }
    return false;
  }
}

