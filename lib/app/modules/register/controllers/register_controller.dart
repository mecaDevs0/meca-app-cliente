import 'package:mega_commons/shared/data/mega_data_cache.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../data/models/profile.dart';
import '../../../data/providers/register_provider.dart';

class RegisterController extends GetxController {
  RegisterController({required RegisterProvider registerProvider})
      : _registerProvider = registerProvider;

  final RegisterProvider _registerProvider;

  final _hasAcceptTerms = RxBool(false);
  final _isLoadingUser = RxBool(false);
  final _isButtonEnabled = RxBool(true); // Variável para controlar o estado do botão
  final accessTokenBox = MegaDataCache.box<AuthToken>();

  bool get hasAcceptTerms => _hasAcceptTerms.value;
  bool get loadingUser => _isLoadingUser.value;
  bool get isButtonEnabled => _isButtonEnabled.value;

  void setHasAcceptTerms(bool value) {
    _hasAcceptTerms.value = value;
  }

  Future<bool> createUserProfile(Profile profile) async {
    // Previne cliques duplicados
    if (!_isButtonEnabled.value || _isLoadingUser.value) return false;

    _isButtonEnabled.value = false;
    _isLoadingUser.value = true;

    bool isSuccess = false;
    await MegaRequestUtils.load(
      action: () async {
        final result = await _registerProvider.registerUser(profile);
        isSuccess = true;
        await accessTokenBox.put(
          AuthToken.cacheBoxKey,
          result,
        );
      },
      onFinally: () {
        _isLoadingUser.value = false;
        Future.delayed(const Duration(seconds: 2), () {
          _isButtonEnabled.value = true;
        });
      },
    );

    return isSuccess;
  }
}
