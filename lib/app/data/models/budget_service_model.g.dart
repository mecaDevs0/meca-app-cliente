// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_service_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BudgetServiceModel _$BudgetServiceModelFromJson(Map<String, dynamic> json) =>
    BudgetServiceModel(
      title: json['title'] as String?,
      description: json['description'] as String?,
      value: (json['value'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$BudgetServiceModelToJson(BudgetServiceModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'value': instance.value,
    };
