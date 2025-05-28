import 'package:json_annotation/json_annotation.dart';

part 'faq.g.dart';

@JsonSerializable()
class Faq {
  Faq({
    this.id,
    this.question,
    this.response,
  });

  factory Faq.fromJson(Map<String, dynamic> json) => _$FaqFromJson(json);

  String? id;
  String? question;
  String? response;

  Map<String, dynamic> toJson() => _$FaqToJson(this);
}
