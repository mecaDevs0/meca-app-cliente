import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/scheduling/scheduling.dart';

class RequestAppointmentProvider {
  RequestAppointmentProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Scheduling> onRegisterScheduling(Scheduling scheduling) async {
    final response = await _restClientDio.post(
      BaseUrls.scheduling,
      data: scheduling.toJson(),
    );

    return Scheduling.fromJson(response.data);
  }
}
