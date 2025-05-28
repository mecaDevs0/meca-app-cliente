part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const home = _Paths.home;
  static const login = _Paths.login;
  static const forgotPassword = _Paths.forgotPassword;
  static const forgotPasswordConfirmation = _Paths.forgotPasswordConfirmation;
  static const changePassword = _Paths.changePassword;
  static const notifications = _Paths.notifications;
  static const register = _Paths.register;
  static const userProfile = _Paths.userProfile;
  static const editProfile = _Paths.editProfile;
  static const helpCenter = _Paths.helpCenter;
  static const services = _Paths.services;
  static const serviceDetails = _Paths.serviceDetails;
  static const mechanicWorkshops = _Paths.mechanicWorkshops;
  static const notificationDetails = _Paths.notificationDetails;
  static const mechanicWorkshopReviews = _Paths.mechanicWorkshopReviews;
  static const ordersPlaced = _Paths.ordersPlaced;
  static const completeRegistration = _Paths.completeRegistration;
  static const myVehicles = _Paths.myVehicles;
  static const vehicleDetails = _Paths.vehicleDetails;
  static const registerVehicle = _Paths.registerVehicle;
  static const creditCard = _Paths.creditCard;
  static const editVehicle = _Paths.editVehicle;
  static const payment = _Paths.payment;
  static const requestAppointment = _Paths.requestAppointment;
  static const mechanicWorkshopDetails = _Paths.mechanicWorkshopDetails;
  static const orderDetails = _Paths.orderDetails;
  static const serviceFailed = _Paths.serviceFailed;
  static const budgetDetails = _Paths.budgetDetails;
}

abstract class _Paths {
  _Paths._();
  static const home = '/home';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const forgotPasswordConfirmation = '/password-confirmation';
  static const changePassword = '/change-password';
  static const notifications = '/notifications';
  static const register = '/register';
  static const userProfile = '/user-profile';
  static const editProfile = '/edit-profile';
  static const helpCenter = '/help-center';
  static const services = '/services';
  static const serviceDetails = '/service-details';
  static const mechanicWorkshops = '/mechanic-workshops';
  static const notificationDetails = '/notification-details';
  static const mechanicWorkshopReviews = '/mechanic-workshop-reviews';
  static const ordersPlaced = '/orders-placed';
  static const completeRegistration = '/complete-registration';
  static const myVehicles = '/my-vehicles';
  static const vehicleDetails = '/vehicle-details';
  static const registerVehicle = '/register-vehicle';
  static const creditCard = '/credit-card';
  static const editVehicle = '/edit-vehicle';
  static const payment = '/payment';
  static const requestAppointment = '/request-appointment';
  static const mechanicWorkshopDetails = '/mechanic-workshop-details';
  static const orderDetails = '/order-details';
  static const serviceFailed = '/service-failed';
  static const budgetDetails = '/budget-details';
}
