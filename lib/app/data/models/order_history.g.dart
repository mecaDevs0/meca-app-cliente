// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderHistory _$OrderHistoryFromJson(Map<String, dynamic> json) => OrderHistory(
      id: json['id'] as String?,
      statusTitle: (json['statusTitle'] as num?)?.toInt(),
      status: (json['status'] as num?)?.toInt(),
      schedulingId: json['schedulingId'] as String?,
      disabled: (json['disabled'] as num?)?.toInt(),
      dataBlocked: (json['dataBlocked'] as num?)?.toInt(),
      created: (json['created'] as num?)?.toInt(),
    )..description = json['description'] as String?;

Map<String, dynamic> _$OrderHistoryToJson(OrderHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'statusTitle': instance.statusTitle,
      'status': instance.status,
      'description': instance.description,
      'schedulingId': instance.schedulingId,
      'disabled': instance.disabled,
      'dataBlocked': instance.dataBlocked,
      'created': instance.created,
    };
