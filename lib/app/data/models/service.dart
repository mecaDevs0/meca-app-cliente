import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable()
class Service {
  Service({
    this.id,
    this.name,
    this.quickService,
    this.minTimeWorkshopAgenda,
    this.description,
    this.photo,
  });

  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);

  String? id;
  String? name;
  bool? quickService;
  @JsonKey(name: 'minTimeScheduling')
  double? minTimeWorkshopAgenda;
  String? description;
  String? photo;

  Map<String, dynamic> toJson() => _$ServiceToJson(this);
}
