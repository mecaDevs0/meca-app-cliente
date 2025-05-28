import 'package:json_annotation/json_annotation.dart';

part 'budget_service_model.g.dart';

@JsonSerializable()
class BudgetServiceModel {
  BudgetServiceModel({
    this.title,
    this.description,
    this.value,
    this.isApproved = false,
  });

  factory BudgetServiceModel.fromJson(Map<String, dynamic> json) {
    return _$BudgetServiceModelFromJson(json);
  }
  String? title;
  String? description;
  double? value;
  @JsonKey(includeToJson: false, includeFromJson: false)
  bool isApproved;

  Map<String, dynamic> toJson() => _$BudgetServiceModelToJson(this);
}
