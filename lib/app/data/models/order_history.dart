import 'package:json_annotation/json_annotation.dart';

part 'order_history.g.dart';

@JsonSerializable()
class OrderHistory {
  OrderHistory({
    this.id,
    this.statusTitle,
    this.status,
    this.schedulingId,
    this.disabled,
    this.dataBlocked,
    this.created,
  });

  OrderHistory.empty()
      : id = '',
        status = 0,
        description = '',
        schedulingId = '',
        disabled = 0,
        created = 0,
        dataBlocked = 0;

  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    return _$OrderHistoryFromJson(json);
  }

  String? id;
  int? statusTitle;
  int? status;
  String? description;
  String? schedulingId;
  int? disabled;
  int? dataBlocked;
  int? created;

  Map<String, dynamic> toJson() => _$OrderHistoryToJson(this);
}
