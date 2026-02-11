import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Produção: usa certificados confiáveis do sistema (iOS/Android).
/// Evita CERTIFICATE_VERIFY_FAILED com Let's Encrypt em múltiplos aparelhos.
void configureDioForProduction(Dio dio) {
  if (dio.httpClientAdapter is IOHttpClientAdapter) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      return HttpClient(context: SecurityContext(withTrustedRoots: true));
    };
  }
}
