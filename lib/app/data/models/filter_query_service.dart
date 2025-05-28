import 'package:json_annotation/json_annotation.dart';

part 'filter_query_service.g.dart';

@JsonSerializable()
class FilterQueryService {
  FilterQueryService({
    this.page,
    this.limit,
    this.name,
    this.serviceTypes,
    this.rating,
    this.distance,
    this.latUser,
    this.longUser,
    this.dataBlocked,
    this.created,
  });

  factory FilterQueryService.fromJson(Map<String, dynamic> json) =>
      _$FilterQueryServiceFromJson(json);

  int? page;
  int? limit;
  String? name;
  List<String>? serviceTypes;
  @JsonKey(includeIfNull: false)
  int? rating;
  @JsonKey(includeIfNull: false)
  int? distance;
  @JsonKey(includeIfNull: false)
  double? latUser;
  @JsonKey(includeIfNull: false)
  double? longUser;
  int? dataBlocked;
  @JsonKey(includeIfNull: false)
  int? created;

  Map<String, dynamic> toJson() => _$FilterQueryServiceToJson(this);
}
