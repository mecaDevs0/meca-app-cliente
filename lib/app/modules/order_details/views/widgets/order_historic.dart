import 'package:flutter/material.dart';
import 'package:mega_commons/mega_commons.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../../core/widgets/expanded_widget.dart';
import '../../../../data/enums/service_history_type.dart';
import '../../../../data/models/order_history.dart';
import '../../controllers/order_details_controller.dart';
import 'item_service.dart';
import 'title_expanded.dart';

class OrderHistoric extends StatefulWidget {
  const OrderHistoric({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<OrderHistoric> createState() => _OrderHistoricState();
}

class _OrderHistoricState
    extends MegaState<OrderHistoric, OrderDetailsController> {
  @override
  Widget build(BuildContext context) {
    final List<GlobalKey> keys = List.generate(
      ServiceHistoryType.values.length,
      (index) => GlobalKey(),
    );

    Future<void> checkItemPosition(int index) async {
      final scrollBox = widget.scrollController.position.context.storageContext
          .findRenderObject()! as RenderBox;
      final scrollPosition = scrollBox.localToGlobal(Offset.zero);
      final scrollBottom = scrollPosition.dy + scrollBox.size.height;
      final itemBox =
          keys[index].currentContext!.findRenderObject()! as RenderBox;
      final itemPosition = itemBox.localToGlobal(Offset.zero);
      final buttonBottom = itemPosition.dy + itemBox.size.height;
      final diff = scrollBottom - buttonBottom;
      if (diff <= 80) {
        await Future.delayed(const Duration(milliseconds: 500));
        widget.scrollController
            .jumpTo(widget.scrollController.position.pixels + 80);
      }
    }

    return Obx(() {
      return Column(
        children: [
          ...controller.groupedData.entries.map((entry) {
            final int statusTitle = entry.key;
            final data = entry.value;
            final List<OrderHistory> items = data['items'];
            
            // Encontrar o ServiceHistoryType correto baseado no statusTitle
            ServiceHistoryType? serviceType;
            try {
              if (statusTitle >= 0 && statusTitle < ServiceHistoryType.values.length) {
                serviceType = ServiceHistoryType.values[statusTitle];
              } else {
                // Fallback para um tipo padrão se o índice for inválido
                serviceType = ServiceHistoryType.values.first;
              }
            } catch (e) {
              serviceType = ServiceHistoryType.values.first;
            }
            
            return Column(
              children: [
                TitleExpanded(
                  key: keys[statusTitle < keys.length ? statusTitle : 0],
                  quantity: data['count'],
                  serviceType: serviceType ?? ServiceHistoryType.values.first,
                  onTap: () {
                    checkItemPosition(statusTitle < keys.length ? statusTitle : 0);
                    controller.toggleServiceType(serviceType ?? ServiceHistoryType.values.first);
                  },
                ),
                ExpandedWidget(
                  expand: controller.isExpanded(serviceType ?? ServiceHistoryType.values.first),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ItemService(
                        order: item,
                      );
                    },
                  ),
                ),
              ],
            );
          }),
        ],
      );
    });
  }
}
