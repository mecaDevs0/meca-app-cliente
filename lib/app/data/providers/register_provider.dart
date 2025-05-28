import 'package:mega_commons/mega_commons.dart';
import 'package:mega_features/mega_features.dart';

import '../models/profile.dart';

class RegisterProvider {
  RegisterProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<AuthToken> registerUser(Profile profile) async {
    final response = await _restClientDio.post(
      Urls.register,
      data: profile.toJson(),
    );

    return AuthToken.fromJson(response.data);
  }
}
