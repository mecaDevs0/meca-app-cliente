import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import 'core/core.dart';

class ApplicationBinding implements Bindings {
  @override
  void dependencies() {
    late final String baseUrl;

    final EnvironmentUrl? environmentData = EnvironmentUrl.fromCache();
    if (environmentData == null) {
      baseUrl = BaseUrls.baseUrlProd;
      EnvironmentUrl.toProduction(baseUrl);
    } else {
      baseUrl = environmentData.url;
    }

    Get.put<RestClientDio>(
      RestClientDio(
        baseUrl,
        customInterceptor: AppInterceptor(),
      ),
    );
  }
}
