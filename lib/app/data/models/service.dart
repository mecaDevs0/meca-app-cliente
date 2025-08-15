import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable()
class Service {
  Service({
    this.id,
    this.name,
    this.quickService,
    this.minTimeWorkshopAgenda,
    this.description,
    this.photo,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    print('🔧 [Service] JSON original: $json');
    print('🔧 [Service] Photo: ${json['photo']}');
    print('🔧 [Service] Name: ${json['name']}');
    
    final service = _$ServiceFromJson(json);
    
    print('🔧 [Service] Service criado: ID=${service.id}');
    print('🔧 [Service] Name: ${service.name}');
    print('🔧 [Service] Photo: ${service.photo}');
    
    return service;
  }

  String? id;
  String? name;
  bool? quickService;
  @JsonKey(name: 'minTimeScheduling')
  double? minTimeWorkshopAgenda;
  String? description;
  String? photo;

  Map<String, dynamic> toJson() => _$ServiceToJson(this);
}
