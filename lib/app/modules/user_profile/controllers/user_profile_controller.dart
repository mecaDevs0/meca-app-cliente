import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mega_commons/shared/models/address.dart';
import 'package:mega_commons/shared/models/auth_token.dart';
import 'package:mega_commons/shared/utils/mega_one_signal_config.dart';
import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons/shared/utils/mega_snackbar.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../../../core/core.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../../routes/app_pages.dart';
import '../../home/controllers/home_controller.dart';

class UserProfileController extends GetxController {
  UserProfileController({
    required UserProfileProvider userProfileProvider,
    required FormAddressController formAddressController,
  })  : _userProfileProvider = userProfileProvider,
        _formAddressController = formAddressController;

  final UserProfileProvider _userProfileProvider;
  final FormAddressController _formAddressController;
  final _profile = Rx<Profile>(Profile());
  final _isLoading = RxBool(false);
  final _isLoadingMessage = RxString('');
  final _filePhoto = Rxn<File>();

  final TextEditingController nameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final HomeController homeController = Get.find();

  Profile get profile => _profile.value;
  bool get isLoading => _isLoading.value;
  String get isLoadingMessage => _isLoadingMessage.value;
  File? get filePhoto => _filePhoto.value;

  @override
  void onInit() {
    _profile.value = Profile.fromCache();
    Profile.cacheBox.listenable().addListener(() {
      _profile.value = Profile.fromCache();
    });
    nameController.text = profile.fullName ?? '';
    emailController.text = profile.email ?? '';
    phoneController.text = profile.phone?.formattedPhone ?? '';
    _populateAddress();
    super.onInit();
  }

  Future<void> logout() async {
    await _removeDeviceId();
    await AuthToken.remove();
    Get.offAllNamed(Routes.login);
    await Future.delayed(const Duration(milliseconds: 500));
    await Profile().remove();
  }

  void _populateAddress() {
    _formAddressController.setAddress(
      Address(
        streetAddress: profile.streetAddress ?? '',
        number: profile.number ?? '',
        complement: profile.complement ?? '',
        neighborhood: profile.neighborhood ?? '',
        cityName: profile.cityName ?? '',
        stateName: profile.stateName ?? '',
        zipCode: profile.zipCode?.length == 8
            ? UtilBrasilFields.obterCep(profile.zipCode!)
            : profile.zipCode,
        cityId: profile.cityId ?? '',
        stateId: profile.stateId ?? '',
        stateUf: profile.stateUf ?? '',
      ),
    );
  }

  Future<void> _removeDeviceId() async {
    final deviceId = MegaOneSignalConfig.fromCache() ?? '';
    await MegaRequestUtils.load(
      action: () async {
        await _userProfileProvider.unregisterDeviceId(
          deviceId: deviceId,
        );
      },
    );
  }

  Future<bool> onEditProfile() async {
    bool isSuccess = false;
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final address = _formAddressController.address;

        final updatedProfile = profile.copyWith(
          fullName: nameController.text,
          email: emailController.text,
          phone: UtilBrasilFields.removeCaracteres(
            phoneController.text,
          ),
          zipCode: address.zipCode,
          streetAddress: address.streetAddress,
          number: address.number,
          complement: address.complement,
          neighborhood: address.neighborhood,
          stateId: address.stateId,
          stateName: address.stateName,
          cityId: address.cityId,
          cityName: address.cityName,
          stateUf: address.stateUf,
          typeProvider: 0,
        );
        final response = await _userProfileProvider.onUpdateProfile(
          updatedProfile,
          profile.id!,
        );
        isSuccess = true;
        await response.save();
      },
      onFinally: () => _isLoading.value = false,
    );
    return isSuccess;
  }

  Future<String?> onUploadFile(String path) async {
    final fileImage = File(path);
    final response = await _userProfileProvider.onUploadImage(fileImage);
    return response.fileName;
  }

  Future<void> updateUserImage(File file) async {
    await MegaRequestUtils.load(
      action: () async {
        final result = await _userProfileProvider.onUploadImage(file);
        if (result.fileName != null && profile.id != null) {
          await _userProfileProvider.updateImageProfile(
            image: result.fileName!,
            id: profile.id!,
          );
        }
        homeController.getProfileInfo();
      },
    );
  }

  void changePhoto(XFile file) {
    final convertedFile = File(file.path);
    _filePhoto.value = convertedFile;
    updateUserImage(convertedFile);
  }

  Future<bool> onRemoveAccount() async {
    if (profile.id == null) {
      MegaSnackbar.showErroSnackBar('Erro ao remover conta');
      return false;
    }
    bool isSuccess = false;
    _isLoading.value = true;
    _isLoadingMessage.value = 'Removendo conta ...';
    await MegaRequestUtils.load(
      action: () async {
        final String? deviceId = MegaOneSignalConfig.fromCache();
        if (deviceId != null) {
          await _userProfileProvider.onRegisterUnregister(
            deviceId: deviceId,
            isRegister: false,
          );
        }
        await _userProfileProvider.onRemoveAccount(
          profile.id!,
        );
        await AuthToken.remove();
        isSuccess = true;
      },
      onFinally: () => _isLoading.value = false,
    );
    return isSuccess;
  }
}
