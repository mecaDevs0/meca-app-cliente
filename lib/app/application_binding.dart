import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import 'core/core.dart';

class ApplicationBinding implements Bindings {
  @override
  void dependencies() {
    late final String baseUrl;

    // Limpar cache do EnvironmentUrl para forçar uso da nova URL
    final EnvironmentUrl? environmentData = EnvironmentUrl.fromCache();
    if (environmentData != null) {
      environmentData.remove();
    }
    
    // Sempre usar a URL corrigida
    baseUrl = BaseUrls.baseUrlProd;
    EnvironmentUrl.toProduction(baseUrl);

    Get.put<RestClientDio>(
      RestClientDio(
        baseUrl,
        customInterceptor: AppInterceptor(),
      ),
    );
  }
}
