import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';

class QrCodePixBottomSheet extends StatefulWidget {
  const QrCodePixBottomSheet({
    super.key,
    required this.onTap,
  });
  final void Function() onTap;

  @override
  State<QrCodePixBottomSheet> createState() =>
      _ApprovedPaymentBottomSheetState();
}

class _ApprovedPaymentBottomSheetState extends State<QrCodePixBottomSheet> {
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
                const MegaCachedNetworkImage(
                  width: 178,
                  height: 178,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Codigo QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.blackPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Assim que o pagamento for confirmado, você receberá uma notificação.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.softBlackColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: ShapeDecoration(
                    color: AppColors.whiteColor,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: AppColors.grayDarkBorderColor,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '3e92c5a4-45f3-11eb-378-0242ac130002',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.softBlackColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Share.share(
                      '3e92c5a4-45f3-11eb-378-0242ac130002',
                    );
                  },
                  child: const Text(
                    'Compartilhar chave PIX',
                    style: TextStyle(
                      color: AppColors.softBlackColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: MegaBaseButton(
                    'Copiar chave pix',
                    onButtonPress: _applyFilters,
                    textColor: AppColors.whiteColor,
                    buttonColor: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void showQrCodePixBottomSheet({
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
          QrCodePixBottomSheet(onTap: onTap),
        ],
      );
    },
  );
}
