class WorkshopArgs {
  WorkshopArgs(
    this.workshopId, {
    this.workshopName,
    this.serviceId,
    this.serviceName,
  });

  String workshopId;
  String? workshopName;
  String? serviceId;
  String? serviceName;
}
