import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import '../../../../core/app_colors.dart';

class BuildTextField extends StatelessWidget {
  const BuildTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.blackPrimaryColor),
        ),
        const SizedBox(height: 2),
        MegaTextFieldWidget(
          controller,
          hintText: hint,
          isRequired: true,
          keyboardType: TextInputType.text,
          isReadOnly: false,
        ),
      ],
    );
  }
}
