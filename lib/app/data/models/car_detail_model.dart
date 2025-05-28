import 'package:json_annotation/json_annotation.dart';

part 'car_detail_model.g.dart';

@JsonSerializable()
class CarDetailModel {
  CarDetailModel({
    this.plate = '',
    this.manufacturer = '',
    this.model = '',
    this.color = '',
    this.year = '',
  });

  factory CarDetailModel.fromJson(Map<String, dynamic> json) =>
      _$CarDetailModelFromJson(json);

  String plate;
  String manufacturer;
  String model;
  String color;
  String year;

  Map<String, dynamic> toJson() => _$CarDetailModelToJson(this);
}
