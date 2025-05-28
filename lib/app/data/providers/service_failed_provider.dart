import 'dart:io';

import 'package:mega_commons/mega_commons.dart';

import '../../core/app_urls.dart';
import '../models/order.dart';

class ServiceFailedProvider {
  ServiceFailedProvider({
    required RestClientDio restClientDio,
  }) : _restClientDio = restClientDio;

  final RestClientDio _restClientDio;

  Future<Order> onRequestOrderDetails({
    required String id,
  }) async {
    final response = await _restClientDio.get('${BaseUrls.scheduling}/$id');
    return Order.fromJson(response.data);
  }

  Future<void> reproveOrder(
    String orderId,
    String reasonDisapproval,
    List<String> imagesDisapproval,
  ) async {
    await _restClientDio.post(
      BaseUrls.confirmService,
      data: {
        'schedulingId': orderId,
        'confirmServiceStatus': 1,
        'reasonDisapproval': reasonDisapproval,
        if (imagesDisapproval.isNotEmpty)
          'imagesDisapproval': imagesDisapproval,
      },
    );
  }

  Future<List<String>> uploadFiles(List<File> selectedImages) async {
    final response = await _restClientDio.uploadFiles(
      files: selectedImages,
      returnWithUrl: true,
    );

    if (response.fileNames?.isEmpty == true) {
      throw MegaResponse(
        message: 'Falha ao enviar as imagens',
      );
    }

    return response.fileNames!;
  }
}
