import 'package:json_annotation/json_annotation.dart';

import 'budget_service_model.dart';
import 'mechanic_workshop.dart';
import 'profile.dart';
import 'vehicle.dart';
import 'workshopService/workshop_service.dart';

part 'order.g.dart';

@JsonSerializable()
class Order {
  Order({
    this.id,
    this.created,
    this.observations,
    this.date,
    this.suggestedDate,
    this.status,
    this.budgetApprovalDate,
    this.estimatedTimeForCompletion,
    this.diagnosticValue,
    this.budgetImages,
    this.totalValue,
    this.workshopServices,
    this.maintainedBudgetServices,
    this.excludedBudgetServices,
    this.paymentDate,
    this.paymentStatus,
    this.lastUpdate,
    this.serviceStartDate,
    this.serviceEndDate,
    this.reasonDisapproval,
    this.imagesDisapproval,
    this.dispute,
    this.imagesDispute,
    this.freeRepair,
    this.serviceFinishedByAdmin,
    this.profile,
    this.workshop,
    this.vehicle,
    this.hasEvaluated,
    this.budgetServices,
  });
  Order.empty()
      : id = '',
        created = 0,
        observations = '',
        date = 0,
        suggestedDate = 0,
        status = 0,
        budgetApprovalDate = 0,
        estimatedTimeForCompletion = 0,
        diagnosticValue = 0,
        budgetImages = [],
        totalValue = 0,
        workshopServices = [],
        maintainedBudgetServices = [],
        excludedBudgetServices = [],
        paymentDate = 0,
        paymentStatus = 0,
        lastUpdate = 0,
        serviceStartDate = 0,
        serviceEndDate = 0,
        reasonDisapproval = '',
        imagesDisapproval = [],
        dispute = '',
        imagesDispute = [],
        freeRepair = false,
        serviceFinishedByAdmin = false,
        profile = Profile.empty(),
        workshop = MechanicWorkshop.empty(),
        vehicle = Vehicle.empty();

  factory Order.fromJson(Map<String, dynamic> json) {
    return _$OrderFromJson(json);
  }

  String? id;
  int? created;
  String? observations;
  int? date;
  int? suggestedDate;
  int? status;
  int? budgetApprovalDate;
  int? estimatedTimeForCompletion;
  double? diagnosticValue;
  @JsonKey(defaultValue: [])
  List<String>? budgetImages;
  double? totalValue;
  @JsonKey(defaultValue: [])
  List<WorkshopService>? workshopServices;
  @JsonKey(defaultValue: [])
  List<BudgetServiceModel>? maintainedBudgetServices;
  @JsonKey(defaultValue: [])
  List<BudgetServiceModel>? excludedBudgetServices;
  int? paymentDate;
  int? lastUpdate;
  int? paymentStatus;
  int? serviceStartDate;
  int? serviceEndDate;
  String? reasonDisapproval;
  @JsonKey(defaultValue: [])
  List<String>? imagesDisapproval;
  String? dispute;
  @JsonKey(defaultValue: [])
  List<String>? imagesDispute;
  bool? freeRepair;
  bool? serviceFinishedByAdmin;
  Profile? profile;
  MechanicWorkshop? workshop;
  Vehicle? vehicle;
  bool? hasEvaluated;
  List<BudgetServiceModel>? budgetServices;

  Map<String, dynamic> toJson() => _$OrderToJson(this);

  String get formattedAddress {
    if (workshop?.streetAddress != null && workshop?.zipCode != null) {
      return '${workshop?.streetAddress}, ${workshop?.number}, ${workshop?.neighborhood}, ${workshop?.cityName} - ${workshop?.stateUf}';
    }
    return 'Sem Endereço';
  }
}
