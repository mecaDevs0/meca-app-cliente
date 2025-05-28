import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../core.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label = '',
    this.hintText = '',
    this.isRequired = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.validator,
    this.isMultiLine = false,
    this.onTap,
    this.onTapInfo,
    this.labelIcon,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool isRequired;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool isMultiLine;
  final Function()? onTap;
  final Function()? onTapInfo;
  final String? labelIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTapInfo,
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.blackPrimaryColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 4),
              if (labelIcon != null)
                SvgPicture.asset(
                  labelIcon!,
                ),
            ],
          ),
        ),
        MegaTextFieldWidget(
          controller,
          onTap: onTap,
          hintText: hintText,
          isRequired: isRequired,
          isReadOnly: onTap != null,
          keyboardType: keyboardType,
          topPadding: 0,
          minLines: isMultiLine ? 4 : 1,
          maxLines: isMultiLine ? 4 : 1,
          validator: validator,
          textCapitalization: textCapitalization,
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: suffixIcon,
                )
              : null,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }
}
