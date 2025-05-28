import 'package:flutter/material.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';

import '../../controllers/complete_registration_controller.dart';

class AddressForm extends GetView<CompleteRegistrationController> {
  const AddressForm({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: const FormAddressView(
        isWithTitle: true,
        isAddressRequired: true,
      ),
    );
  }
}
