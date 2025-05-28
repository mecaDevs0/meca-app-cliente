import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../data/models/profile.dart';

class AppInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final profile = Profile.fromCache();
    if (options.method == 'GET' && profile.id != null) {
      options.queryParameters['profileId'] = profile.id;
    }
    options.queryParameters['dataBlocked'] = 0;
    handler.next(options);
  }
}
