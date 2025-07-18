import 'package:json_annotation/json_annotation.dart';

import 'mechanic_workshop.dart';
import 'profile.dart';

part 'notification_model.g.dart';

@JsonSerializable()
class NotificationModel {
  NotificationModel({
    this.id,
    this.title,
    this.content,
    this.dateRead,
    this.workshop,
    this.profile,
    this.created,
    this.orderId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  String? id;
  String? title;
  String? content;
  int? dateRead;
  MechanicWorkshop? workshop;
  Profile? profile;
  int? created;
  String? orderId;

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);
}
