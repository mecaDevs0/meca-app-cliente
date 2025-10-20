import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VehicleProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get vehicles => _vehicles;
  bool get isLoading => _isLoading;

  Future<void> loadVehicles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getVehicles();
      if (response.statusCode == 200) {
        _vehicles = List<Map<String, dynamic>>.from(response.data['vehicles'] ?? []);
      }
    } catch (e) {
      print('Load vehicles error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> lookupByPlate(String plate) async {
    try {
      final response = await _apiService.lookupVehicleByPlate(plate);
      if (response.statusCode == 200) {
        return response.data['vehicle'];
      }
    } catch (e) {
      print('Lookup error: $e');
    }
    return null;
  }

  Future<bool> addVehicle(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.createVehicle(data);
      if (response.statusCode == 201) {
        await loadVehicles();
        return true;
      }
    } catch (e) {
      print('Add vehicle error: $e');
    }
    return false;
  }

  Future<bool> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.updateVehicle(id, data);
      if (response.statusCode == 200) {
        await loadVehicles();
        return true;
      }
    } catch (e) {
      print('Update vehicle error: $e');
    }
    return false;
  }

  Future<bool> deleteVehicle(String id) async {
    try {
      final response = await _apiService.deleteVehicle(id);
      if (response.statusCode == 200) {
        await loadVehicles();
        return true;
      }
    } catch (e) {
      print('Delete vehicle error: $e');
    }
    return false;
  }
}

