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
  String? search;
  List<String>? serviceTypes;
  double? priceRangeInitial;
  double? priceRangeFinal;
  int? rating;
  int? distance;
  double? latUser;
  double? longUser;
  int? dataBlocked;
  int? created;
  String? workshopName;

  Map<String, dynamic> toJson() => _$FilterQueryWorkshopToJson(this);
}
