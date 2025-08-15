class WorkshopArgs {
  WorkshopArgs(
    this.workshopId, {
    this.workshopName,
    this.serviceId,
    this.serviceName,
    this.openingHours,
    this.selectedService,
  });

  String workshopId;
  String? workshopName;
  String? serviceId;
  String? serviceName;
  String? openingHours;
  dynamic selectedService; // Pode ser Service ou WorkshopService

  factory WorkshopArgs.fromJson(Map<String, dynamic> json) {
    return WorkshopArgs(
      json['workshopId'] as String,
      workshopName: json['workshopName'] as String?,
      serviceId: json['serviceId'] as String?,
      serviceName: json['serviceName'] as String?,
      openingHours: json['openingHours'] as String?,
      selectedService: json['selectedService'],
    );
  }
}
