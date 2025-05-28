import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/args/workshop_args.dart';
import '../../../data/models/rating.dart';
import '../../../data/providers/mechanic_workshop_reviews_provider.dart';

class MechanicWorkshopReviewsController extends GetxController {
  MechanicWorkshopReviewsController({
    required MechanicWorkshopReviewsProvider mechanicWorkshopReviewsProvider,
  }) : _mechanicWorkshopReviewsProvider = mechanicWorkshopReviewsProvider;

  final MechanicWorkshopReviewsProvider _mechanicWorkshopReviewsProvider;

  final PagingController<int, Rating> pagingController =
      PagingController(firstPageKey: 1);

  final _ratingQuery = RxString('');

  String get ratingQuery => _ratingQuery.value;
  late String workshopId;

  final _limit = 30;

  @override
  void onInit() {
    final workshop = Get.arguments as WorkshopArgs;
    workshopId = workshop.workshopId;
    pagingController.addPageRequestListener(getWorkshopRating);
    super.onInit();
  }

  Future<void> getWorkshopRating(int page) async {
    await MegaRequestUtils.load(
      action: () async {
        final response =
            await _mechanicWorkshopReviewsProvider.onRequestWorkshopRating(
          page: page,
          limit: _limit,
          workshopId: workshopId,
        );

        final isLastPage = response.length < _limit;
        if (isLastPage) {
          pagingController.appendLastPage(response);
        } else {
          final nextPageKey = page + 1;
          pagingController.appendPage(response, nextPageKey);
        }
      },
    );
  }
}
