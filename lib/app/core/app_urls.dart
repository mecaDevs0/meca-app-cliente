class BaseUrls {
  BaseUrls._();
  static String baseUrlDev = 'https://apidev.megaleios.com/ApiMecaDev/';
  static String baseUrlHml = 'https://apihom.megaleios.com/ApiMecaHml/';
  static String baseUrlProd = 'https://api-meca.megaleios.com/';

  static String profile = 'api/v1/Profile';
  static String login = '$profile/Token';
  static String forgotPassword = '$profile/ForgotPassword';
  static String changePassword = '$profile/ChangePassword';
  static String services = 'api/v1/ServicesDefault';
  static String workshops = 'api/v1/Workshop';
  static String workshopServices = 'api/v1/WorkshopServices';
  static String vehicles = 'api/v1/Vehicle';
  static String profileInfo = '$profile/GetInfo';
  static String registerDevice = '$profile/RegisterUnRegisterDeviceId';
  static String rating = 'api/v1/Rating';
  static String notification = 'api/v1/Notification';
  static String faq = '/api/v1/Faq';
  static String scheduling = 'api/v1/Scheduling';
  static String schedulingHistory = 'api/v1/SchedulingHistory';
  static String confirmService = '$scheduling/ConfirmService';
  static String confirmBudget = '$scheduling/ConfirmBudget';
  static String finishPayment = '/api/v1/FinancialHistory/Payment';
  static String confirmNewSchedule = '$scheduling/ConfirmScheduling';
  static String suggestFreeRepair = '$scheduling/RegisterRepairAppointment';
  static String workshopSchedule = 'api/v1/WorkshopAgenda';
  static String sendPaymentIntent = '/api/v1/FinancialHistory/Payment';
  static String getInfoByPlate = 'api/v1/Vehicle/GetInfoVehicleByPlate';
}
