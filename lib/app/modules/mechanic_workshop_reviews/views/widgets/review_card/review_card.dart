import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../data/models/rating.dart';
import 'rating_column.dart';
import 'review_name_row.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
  });

  final Rating review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(
          width: 1.0,
          color: AppColors.grayDarkBorderColor,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReviewNameRow(
            name: review.profile?.fullName ?? '',
            date: review.created ?? 0,
          ),
          const SizedBox(
            height: 5,
          ),
          RatingColumn(
            service: review.workshopService?.name ?? '',
            rating: review.ratingAverage ?? 0,
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            review.observations ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.fontRegularBlackColor,
            ),
            textAlign: TextAlign.justify,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
