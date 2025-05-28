import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';

class ConfirmPaymentBottomSheet extends StatefulWidget {
  const ConfirmPaymentBottomSheet({
    super.key,
    required this.onTap,
    required this.value,
  });
  final void Function() onTap;
  final double? value;

  @override
  State<ConfirmPaymentBottomSheet> createState() =>
      _ConfirmPaymentBottomSheetState();
}

class _ConfirmPaymentBottomSheetState extends State<ConfirmPaymentBottomSheet> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController expiryDateController = TextEditingController();
  final TextEditingController cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _applyFilters() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(AppImages.mobilePayments),
                Text(
                  'Confirma o pagamento no valor de ${widget.value?.moneyFormat() ?? 0.0}',
                  style: const TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Confirmar',
                    onButtonPress: _applyFilters,
                    textColor: AppColors.whiteColor,
                    buttonColor: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Não',
                    onButtonPress: () {
                      Get.back();
                    },
                    border: Border.all(
                      color: AppColors.primaryColor,
                      width: 1.0,
                    ),
                    textColor: AppColors.primaryColor,
                    buttonColor: AppColors.whiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void showConfirmPaymentBottomSheet({
  required BuildContext context,
  required void Function() onTap,
  required double? value,
}) {
  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    builder: (context) {
      return Wrap(
        children: [
          ConfirmPaymentBottomSheet(
            onTap: onTap,
            value: value,
          ),
        ],
      );
    },
  );
}
