import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/faq.dart';

class HelpCenterProvider {
  HelpCenterProvider({required RestClientDio restClientDio})
      : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Faq> onSubmitFaq({
    required String title,
    required String description,
  }) async {
    final response = await _restClientDio.post(
      BaseUrls.faq,
      data: {
        'question': title,
        'response': description,
      },
    );
    return Faq.fromJson(response.data);
  }
}
