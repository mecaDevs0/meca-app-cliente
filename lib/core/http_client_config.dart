import 'package:dio/dio.dart';

import 'http_client_config_stub.dart'
    if (dart.library.io) 'http_client_config_io.dart' as impl;

/// Configura o Dio para produção. Em mobile usa trust store do sistema (evita
/// CERTIFICATE_VERIFY_FAILED em vários aparelhos); em web não altera.
void configureDioForProduction(Dio dio) {
  impl.configureDioForProduction(dio);
}
