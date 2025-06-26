import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_images.dart';

class RatingOrderBottomSheet extends StatefulWidget {
  const RatingOrderBottomSheet({
    super.key,
    required this.onTap,
  });
  final void Function(
    int attendanceQuality,
    int serviceQuality,
    int costBenefit,
    String obs,
  ) onTap;

  @override
  State<RatingOrderBottomSheet> createState() => _RatingOrderBottomSheetState();
}

class _RatingOrderBottomSheetState extends State<RatingOrderBottomSheet> {
  final TextEditingController obsController = TextEditingController();

  int selectedRatingOne = 5;
  int selectedRatingTwo = 4;
  int selectedRatingThree = 3;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: context.height * 0.95,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: IconButton(
                      icon: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.close),
                      ),
                      iconSize: 44,
                      splashRadius: 24,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  10,
                  10,
                  MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Qualidade do atendimento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final Color starColor = index < selectedRatingOne
                            ? AppColors.favoritesYellowColor
                            : AppColors.favoritesGrayColor;

                        return Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: IconButton(
                            icon: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SvgPicture.asset(
                                AppImages.icFavorites,
                                colorFilter:
                                    ColorFilter.mode(starColor, BlendMode.srcIn),
                              ),
                            ),
                            iconSize: 44,
                            splashRadius: 24,
                            onPressed: () {
                              setState(() {
                                if (selectedRatingOne == index + 1) {
                                  selectedRatingOne = index;
                                } else {
                                  selectedRatingOne = index + 1;
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const Text(
                      'Qualidade do serviço',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final Color starColor = index < selectedRatingTwo
                            ? AppColors.favoritesYellowColor
                            : AppColors.favoritesGrayColor;

                        return Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: IconButton(
                            icon: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SvgPicture.asset(
                                AppImages.icFavorites,
                                colorFilter:
                                    ColorFilter.mode(starColor, BlendMode.srcIn),
                              ),
                            ),
                            iconSize: 44,
                            splashRadius: 24,
                            onPressed: () {
                              setState(() {
                                if (selectedRatingTwo == index + 1) {
                                  selectedRatingTwo = index;
                                } else {
                                  selectedRatingTwo = index + 1;
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const Text(
                      'Custo-Benefício',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final Color starColor = index < selectedRatingThree
                            ? AppColors.favoritesYellowColor
                            : AppColors.favoritesGrayColor;

                        return Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: IconButton(
                            icon: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SvgPicture.asset(
                                AppImages.icFavorites,
                                colorFilter:
                                    ColorFilter.mode(starColor, BlendMode.srcIn),
                              ),
                            ),
                            iconSize: 44,
                            splashRadius: 24,
                            onPressed: () {
                              setState(() {
                                if (selectedRatingThree == index + 1) {
                                  selectedRatingThree = index;
                                } else {
                                  selectedRatingThree = index + 1;
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Observações',
                      style: TextStyle(
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    MegaTextFieldWidget(
                      obsController,
                      hintText: 'Digite as observações sobre os serviços',
                      isRequired: true,
                      keyboardType: TextInputType.text,
                      minLines: 5,
                      maxLines: 7,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: MegaBaseButton(
                        'Avaliar',
                        onButtonPress: () {
                          if (obsController.text.isNotEmpty) {
                            widget.onTap(
                              selectedRatingOne,
                              selectedRatingTwo,
                              selectedRatingThree,
                              obsController.text,
                            );
                            Navigator.of(context).pop();
                          }
                        },
                        textColor: AppColors.whiteColor,
                        buttonColor: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showRatingOrderBottomSheet({
  required BuildContext context,
  required void Function(
    int attendanceQuality,
    int serviceQuality,
    int costBenefit,
    String obs,
  ) onTap,
}) {
  showModalBottomSheet(
    backgroundColor: Colors.white,
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return RatingOrderBottomSheet(onTap: onTap);
    },
  );
}
