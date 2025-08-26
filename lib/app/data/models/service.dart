import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable()
class Service {
  @JsonKey(name: 'id')
  String? id;
  
  @JsonKey(name: 'name')
  String? name;
  
  @JsonKey(name: 'quickService')
  bool? quickService;
  
  @JsonKey(name: 'minTimeScheduling')
  double? minTimeWorkshopAgenda;
  
  @JsonKey(name: 'description')
  String? description;
  
  @JsonKey(name: 'photo')
  String? photo;
  
  @JsonKey(name: 'dataBlocked')
  dynamic dataBlocked;
  
  @JsonKey(name: 'disabled')
  dynamic disabled;
  
  @JsonKey(name: 'created')
  int? created;

  Service({
    this.id,
    this.name,
    this.quickService,
    this.minTimeWorkshopAgenda,
    this.description,
    this.photo,
    this.dataBlocked,
    this.disabled,
    this.created,
  });

  factory Service.fromJson(Map<String, dynamic> json) => _$ServiceFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceToJson(this);
}
