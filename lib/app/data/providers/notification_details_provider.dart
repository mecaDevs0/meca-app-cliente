import 'package:mega_commons/mega_commons.dart';

class NotificationDetailsProvider {
  NotificationDetailsProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<MegaResponse> onSubmitRequest() async {
    final response = await _restClientDio.get('');
    return response;
  }
}
