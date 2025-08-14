import 'package:json_annotation/json_annotation.dart';

part 'filter_query_workshop.g.dart';

@JsonSerializable()
class FilterQueryWorkshop {
  FilterQueryWorkshop({
    this.page,
    this.limit,
    this.search,
    this.serviceTypes,
    this.priceRangeInitial,
    this.priceRangeFinal,
    this.rating,
    this.distance,
    this.latUser,
    this.longUser,
    this.dataBlocked,
    this.created,
    this.workshopName,
  });

  factory FilterQueryWorkshop.fromJson(Map<String, dynamic> json) =>
      _$FilterQueryWorkshopFromJson(json);

  int? page;
  int? limit;
  @JsonKey(includeIfNull: false)
  String? search;
  @JsonKey(includeIfNull: false)
  List<String>? serviceTypes;
  @JsonKey(includeIfNull: false)
  double? priceRangeInitial;
  @JsonKey(includeIfNull: false)
  double? priceRangeFinal;
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
  @JsonKey(includeIfNull: false)
  String? workshopName;

  Map<String, dynamic> toJson() => _$FilterQueryWorkshopToJson(this);
}
