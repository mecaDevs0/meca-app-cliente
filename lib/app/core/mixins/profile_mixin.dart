import 'package:get/get.dart';

import '../../data/models/profile.dart';

mixin ProfileMixin on GetxController {
  final Profile _user = Profile.fromCache();

  Profile get loggedUser {
    if (_user == null) {
      throw Exception('User not logged in');
    }
    return _user;
  }

  String get customerId => _user.externalId ?? '';
  String get email => _user.email ?? '';
}
