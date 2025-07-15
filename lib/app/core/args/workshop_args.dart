class WorkshopArgs {
  WorkshopArgs(
    this.workshopId, {
    this.workshopName,
    this.serviceId,
    this.serviceName,
    this.openingHours,
  });

  String workshopId;
  String? workshopName;
  String? serviceId;
  String? serviceName;
  String? openingHours;
}
