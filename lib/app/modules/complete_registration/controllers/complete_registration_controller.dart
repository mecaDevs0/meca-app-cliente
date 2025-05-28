import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/app/modules/form_address/controllers/form_address_controller.dart';

import '../../../core/args/workshop_args.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/complete_registration_provider.dart';

class CompleteRegistrationController extends GetxController {
  CompleteRegistrationController({
    required CompleteRegistrationProvider completeRegistrationProvider,
    required FormAddressController formAddressController,
  })  : _completeRegistrationProvider = completeRegistrationProvider,
        _formAddressController = formAddressController;

  final CompleteRegistrationProvider _completeRegistrationProvider;
  final FormAddressController _formAddressController;

  final _isLoading = RxBool(false);
  final _profile = Rx<Profile>(Profile());

  bool get isLoading => _isLoading.value;
  Profile get profile => _profile.value;

  final TextEditingController nameController = TextEditingController();

  final TextEditingController cpfController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  late String workshopId;
  late String workshopName;

  @override
  void onInit() {
    final profile = Profile.fromCache();
    final workshop = Get.arguments as WorkshopArgs;
    workshopId = workshop.workshopId;
    workshopName = workshop.workshopName ?? '';

    _profile.value = profile;
    nameController.text = profile.fullName ?? '';
    cpfController.text = profile.cpf ?? '';
    emailController.text = profile.email ?? '';
    phoneController.text = profile.phone ?? '';
    _populateAddress(profile);
    super.onInit();
  }

  void _populateAddress(Profile profile) {
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

  Future<bool> completeRegistration() async {
    bool isSuccess = false;
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final address = _formAddressController.address;

        final updatedProfile = profile.copyWith(
          fullName: nameController.text,
          cpf: cpfController.text,
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
        await _completeRegistrationProvider.onCompleteRegistration(
          updatedProfile,
          profile.id!,
        );
        isSuccess = true;
      },
      onFinally: () => _isLoading.value = false,
    );

    return isSuccess;
  }
}
