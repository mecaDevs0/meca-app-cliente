import 'package:json_annotation/json_annotation.dart';

import 'mechanic_workshop.dart';
import 'profile.dart';
import 'service.dart';
import 'vehicle.dart';

part 'rating.g.dart';

@JsonSerializable()
class Rating {
  Rating({
    this.id,
    this.attendanceQuality,
    this.serviceQuality,
    this.costBenefit,
    this.observations,
    this.schedulingId,
    this.profile,
    this.workshopService,
    this.workshop,
    this.vehicle,
    this.ratingAverage,
    this.created,
  });

  factory Rating.fromJson(Map<String, dynamic> json) => _$RatingFromJson(json);

  String? id;
  int? attendanceQuality;
  int? serviceQuality;
  int? costBenefit;
  String? observations;
  String? schedulingId;
  Profile? profile;
  Service? workshopService;
  MechanicWorkshop? workshop;
  Vehicle? vehicle;
  int? ratingAverage;
  int? created;

  Map<String, dynamic> toJson() => _$RatingToJson(this);
}
