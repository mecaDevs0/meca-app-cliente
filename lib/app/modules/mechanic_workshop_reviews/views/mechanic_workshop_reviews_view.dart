import 'package:flutter/material.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/empty_list_indicator.dart';
import 'package:mega_commons/shared/widgets/exception_indicators/error_indicator.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_bar_custom.dart';
import '../../../data/models/rating.dart';
import '../controllers/mechanic_workshop_reviews_controller.dart';
import 'widgets/review_card/review_card.dart';

class MechanicWorkshopReviewsView
    extends GetView<MechanicWorkshopReviewsController> {
  const MechanicWorkshopReviewsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(
        iconColor: AppColors.whiteColor,
        title: 'Avaliações',
        backgroundColor: AppColors.primaryColor,
        titleColor: AppColors.whiteColor,
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.sync(
          () => controller.pagingController.refresh(),
        ),
        child: PagedListView<int, Rating>(
          shrinkWrap: true,
          pagingController: controller.pagingController,
          padding: const EdgeInsets.all(16),
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (context, item, index) => ReviewCard(review: item),
            firstPageErrorIndicatorBuilder: (context) => ErrorIndicator(
              error: controller.pagingController.error,
              onTryAgain: () => controller.pagingController.refresh(),
            ),
            noItemsFoundIndicatorBuilder: (context) => const EmptyListIndicator(
              iconColor: AppColors.primaryColor,
              message: 'Sem avaliações para exibir',
            ),
            firstPageProgressIndicatorBuilder: (context) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Carregando avaliações...',
                    style: TextStyle(
                      color: AppColors.abbey,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
