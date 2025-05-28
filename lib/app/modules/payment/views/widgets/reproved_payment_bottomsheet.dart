import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';

class ReprovedPaymentBottomsheet extends StatefulWidget {
  const ReprovedPaymentBottomsheet({
    super.key,
    required this.onTap,
  });
  final void Function() onTap;

  @override
  State<ReprovedPaymentBottomsheet> createState() =>
      _ApprovedPaymentBottomSheetState();
}

class _ApprovedPaymentBottomSheetState
    extends State<ReprovedPaymentBottomsheet> {
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
    Navigator.of(context).pop();
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
                SvgPicture.asset(AppImages.reprovedPurchase),
                const Text(
                  'Pagamento recusado!',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Parece que houve um problema. Confirme os dados do seu cartão ou utilize outra forma de pagamento.',
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Trocar forma de pagamento',
                    onButtonPress: _applyFilters,
                    textColor: AppColors.whiteColor,
                    buttonColor: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Tentar novamente',
                    onButtonPress: _applyFilters,
                    textColor: AppColors.primaryColor,
                    buttonColor: AppColors.whiteColor,
                    border:
                        Border.all(color: AppColors.primaryColor, width: 1.0),
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

void showReprovedPaymentBottomSheet({
  required BuildContext context,
  required void Function() onTap,
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
          ReprovedPaymentBottomsheet(onTap: onTap),
        ],
      );
    },
  );
}
