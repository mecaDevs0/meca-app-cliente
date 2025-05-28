import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/car_detail_model.dart';
import '../models/vehicle.dart';

class RegisterVehicleProvider {
  RegisterVehicleProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Vehicle> onEditVehicle(Vehicle vehicle) async {
    final response = await _restClientDio.patch(
      '${BaseUrls.vehicles}/${vehicle.id}',
      data: vehicle.toJson(),
    );

    return Vehicle.fromJson(response.data);
  }

  Future<Vehicle> onRegisterVehicle(Vehicle vehicle) async {
    final response = await _restClientDio.post(
      BaseUrls.vehicles,
      data: vehicle.toJson(),
    );

    return Vehicle.fromJson(response.data);
  }

  Future<CarDetailModel> searchPlate(String plate) async {
    final response = await _restClientDio.get(
      '${BaseUrls.getInfoByPlate}/$plate',
    );
    return CarDetailModel.fromJson(response.data);
  }
}
