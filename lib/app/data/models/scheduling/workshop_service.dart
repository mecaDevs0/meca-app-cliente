import 'package:json_annotation/json_annotation.dart';

part 'workshop_service.g.dart';

@JsonSerializable()
class WorkshopService {
  WorkshopService({
    this.id,
    this.name,
    this.price,
    this.isApproved,
  });

  factory WorkshopService.fromJson(Map<String, dynamic> json) =>
      _$WorkshopServiceFromJson(json);

  String? id;
  String? name;
  double? price;
  bool? isApproved;

  Map<String, dynamic> toJson() => _$WorkshopServiceToJson(this);
}
