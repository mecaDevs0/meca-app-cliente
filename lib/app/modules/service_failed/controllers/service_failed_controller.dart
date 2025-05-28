import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mega_commons/shared/utils/mega_request_utils.dart';
import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';

import '../../../core/core.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/service_failed_provider.dart';

class ServiceFailedController extends GetxController {
  ServiceFailedController({
    required ServiceFailedProvider serviceFailedProvider,
  }) : _serviceFailedProvider = serviceFailedProvider;

  final ServiceFailedProvider _serviceFailedProvider;

  final _isLoadingDetails = RxBool(false);
  final _isLoading = RxBool(false);
  final _orderDetails = Rx<Order?>(Order.empty());
  final _selectedImages = RxList<File>.empty();

  bool get isLoadingDetails => _isLoadingDetails.value;
  bool get isLoading => _isLoading.value;
  Order? get orderDetails => _orderDetails.value;
  List<File> get selectedImages => _selectedImages.toList();

  final reasonController = TextEditingController();
  late String orderId;
  int maxImages = 5;

  @override
  Future<void> onInit() async {
    final order = Get.arguments as OrderArgs;
    orderId = order.id;
    await getServiceDetails();
    if (orderDetails?.status != 19 &&
        orderDetails?.status == 20 &&
        orderDetails!.reasonDisapproval!.isNotEmpty) {
      reasonController.text = orderDetails!.reasonDisapproval!;
    }
    super.onInit();
  }

  Future<void> getServiceDetails() async {
    _isLoadingDetails.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final orderDetails =
            await _serviceFailedProvider.onRequestOrderDetails(id: orderId);

        _orderDetails.value = orderDetails;
      },
      onFinally: () => _isLoadingDetails.value = false,
    );
  }

  Future<bool> reproverOrder(
    String reasonDisapproval,
  ) async {
    bool isSuccess = false;
    _isLoading.value = true;
    await MegaRequestUtils.load(
      action: () async {
        final provider = _serviceFailedProvider;
        final uploadedImages = await provider.uploadFiles(selectedImages);
        await provider.reproveOrder(
          orderId,
          reasonDisapproval,
          uploadedImages,
        );
        isSuccess = true;
      },
      onFinally: () async {
        await getServiceDetails();
        _isLoading.value = false;
      },
    );
    return isSuccess;
  }

  void addImages(List<File>? file) {
    if (_selectedImages.length >= maxImages) {
      return;
    }
    if (file == null) {
      return;
    }
    for (final element in file) {
      if (_selectedImages.length >= maxImages) {
        break;
      }
      _selectedImages.add(element);
    }
  }

  void removeImage(File file) {
    _selectedImages.remove(file);
  }
}
