import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/providers/help_center_provider.dart';

class HelpCenterController extends GetxController {
  HelpCenterController({required HelpCenterProvider helpCenterProvider})
      : _helpCenterProvider = helpCenterProvider;

  final HelpCenterProvider _helpCenterProvider;

  final _isLoading = RxBool(false);

  bool get isLoading => _isLoading.value;

  Future<bool> submitFaq({
    required String title,
    required String description,
  }) async {
    bool isSuccess = false;

    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        await _helpCenterProvider.onSubmitFaq(
          title: title,
          description: description,
        );
        isSuccess = true;
      },
      onFinally: () => _isLoading.value = false,
    );
    return isSuccess;
  }
}
