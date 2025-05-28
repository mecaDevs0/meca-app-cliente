import 'package:mega_commons/mega_commons.dart';

import '../../core/core.dart';
import '../models/profile.dart';

class CompleteRegistrationProvider {
  CompleteRegistrationProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Profile> onCompleteRegistration(Profile profile, String id) async {
    final response = await _restClientDio.patch(
      '${BaseUrls.profile}/$id',
      data: profile.toJson(),
    );
    return Profile.fromJson(response.data);
  }
}
