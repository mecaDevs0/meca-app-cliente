import 'package:mega_commons_dependencies/mega_commons_dependencies.dart';
import 'package:mega_features/mega_features.dart';
import 'package:mega_payment/mega_payment.dart';

import '../core/middleware/auth_middleware.dart';

import '../modules/change_password/views/change_password_view.dart';
import '../modules/complete_registration/bindings/complete_registration_binding.dart';
import '../modules/complete_registration/views/complete_registration_view.dart';
import '../modules/forgot_password/views/forgot_password_view.dart';
import '../modules/forgot_password/views/password_confirmation.dart';
import '../modules/help_center/bindings/help_center_binding.dart';
import '../modules/help_center/views/help_center_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/views/login_view.dart';
import '../modules/mechanic_workshop_details/bindings/mechanic_workshop_details_binding.dart';
import '../modules/mechanic_workshop_details/views/mechanic_workshop_details_view.dart';
import '../modules/mechanic_workshop_reviews/bindings/mechanic_workshop_reviews_binding.dart';
import '../modules/mechanic_workshop_reviews/views/mechanic_workshop_reviews_view.dart';
import '../modules/mechanic_workshops/bindings/mechanic_workshops_binding.dart';
import '../modules/mechanic_workshops/views/mechanic_workshops_view.dart';
import '../modules/my_vehicles/bindings/my_vehicles_binding.dart';
import '../modules/my_vehicles/views/my_vehicles_view.dart';
import '../modules/my_vehicles/views/vehicle_details_view.dart';
import '../modules/notification/bindings/notification_binding.dart';
import '../modules/notification/views/notification_details_view.dart';
import '../modules/notification/views/notification_view.dart';
import '../modules/order_details/bindings/order_details_binding.dart';
import '../modules/order_details/views/budget_details_view.dart';
import '../modules/order_details/views/order_details_view.dart';
import '../modules/orders_placed/bindings/orders_placed_binding.dart';
import '../modules/orders_placed/views/orders_placed_view.dart';
import '../modules/payment/bindings/payment_binding.dart';
import '../modules/payment/views/payment_view.dart';
import '../modules/register/bindings/register_binding.dart';
import '../modules/register/views/register_view.dart';
import '../modules/register_vehicle/bindings/register_vehicle_binding.dart';
import '../modules/register_vehicle/views/edit_vehicle_view.dart';
import '../modules/register_vehicle/views/register_vehicle_view.dart';
import '../modules/request_appointment/bindings/request_appointment_binding.dart';
import '../modules/request_appointment/views/request_appointment_view.dart';
import '../modules/service_details/bindings/service_details_binding.dart';
import '../modules/service_details/view/service_details_view.dart';
import '../modules/service_failed/bindings/service_failed_binding.dart';
import '../modules/service_failed/views/service_failed_view.dart';
import '../modules/services/bindings/services_binding.dart';
import '../modules/services/views/services_view.dart';
import '../modules/user_profile/bindings/user_profile_binding.dart';
import '../modules/user_profile/views/edit_profile_view.dart';
import '../modules/user_profile/views/user_profile_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();
  static const initial = Routes.login;
  static final routes = [
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(
        homeRoute: Routes.home,
      ),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: ForgotPasswordBinding(),
    ),
    GetPage(
      name: _Paths.forgotPasswordConfirmation,
      page: () => const PasswordConfirmationView(),
      binding: ForgotPasswordBinding(),
    ),
    GetPage(
      name: _Paths.changePassword,
      page: () => const ChangePasswordView(),
      binding: ChangePasswordBinding(),
    ),
    GetPage(
      name: _Paths.notifications,
      page: () => const NotificationView(),
      binding: NotificationsBinding(),
    ),
    GetPage(
      name: _Paths.register,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: _Paths.userProfile,
      page: () => UserProfileView(),
      bindings: [
        UserProfileBinding(),
        FormAddressBindings(),
      ],
    ),
    GetPage(
      name: _Paths.editProfile,
      page: () => const EditProfileView(),
      bindings: [
        UserProfileBinding(),
        FormAddressBindings(),
      ],
    ),
    GetPage(
      name: _Paths.helpCenter,
      page: () => HelpCenterView(),
      binding: HelpCenterBinding(),
    ),
    GetPage(
      name: _Paths.services,
      page: () => ServicesView(),
      binding: ServicesBinding(),
    ),
    GetPage(
      name: _Paths.serviceDetails,
      page: () => const ServiceDetailsView(),
      binding: ServiceDetailsBinding(),
    ),
    GetPage(
      name: _Paths.mechanicWorkshops,
      page: () => MechanicWorkshopsView(),
      binding: MechanicWorkshopsBinding(),
    ),
    GetPage(
      name: _Paths.notificationDetails,
      page: () => const NotificationDetailsView(),
      binding: NotificationsBinding(),
    ),
    GetPage(
      name: _Paths.mechanicWorkshopReviews,
      page: () => const MechanicWorkshopReviewsView(),
      binding: MechanicWorkshopReviewsBinding(),
    ),
    GetPage(
      name: _Paths.ordersPlaced,
      page: () => const OrdersPlacedView(),
      binding: OrdersPlacedBinding(),
    ),
    GetPage(
      name: _Paths.completeRegistration,
      page: () => CompleteRegistrationView(),
      bindings: [
        CompleteRegistrationBinding(),
        FormAddressBindings(),
      ],
    ),
    GetPage(
      name: _Paths.myVehicles,
      page: () => MyVehiclesView(),
      binding: MyVehiclesBinding(),
    ),
    GetPage(
      name: _Paths.vehicleDetails,
      page: () => const VehicleDetailsView(),
      binding: MyVehiclesBinding(),
    ),
    GetPage(
      name: _Paths.registerVehicle,
      page: () => const RegisterVehicleView(),
      binding: RegisterVehicleBinding(),
    ),
    GetPage(
      name: _Paths.myVehicles,
      page: () => MyVehiclesView(),
      binding: MyVehiclesBinding(),
    ),
    GetPage(
      name: _Paths.vehicleDetails,
      page: () => const VehicleDetailsView(),
      binding: MyVehiclesBinding(),
    ),
    GetPage(
      name: _Paths.registerVehicle,
      page: () => const RegisterVehicleView(),
      binding: RegisterVehicleBinding(),
    ),
    GetPage(
      name: _Paths.myVehicles,
      page: () => MyVehiclesView(),
      binding: MyVehiclesBinding(),
    ),
    GetPage(
      name: _Paths.vehicleDetails,
      page: () => const VehicleDetailsView(),
      binding: MyVehiclesBinding(),
    ),
    GetPage(
      name: _Paths.registerVehicle,
      page: () => const RegisterVehicleView(),
      binding: RegisterVehicleBinding(),
    ),
    GetPage(
      name: _Paths.editVehicle,
      page: () => const EditVehicleView(),
      binding: RegisterVehicleBinding(),
    ),
    GetPage(
      name: _Paths.payment,
      page: () => const PaymentView(),
      bindings: [PaymentBinding(), StripeBinding()],
    ),
    GetPage(
      name: _Paths.requestAppointment,
      page: () => RequestAppointmentView(),
      binding: RequestAppointmentBinding(),
    ),
    GetPage(
      name: _Paths.mechanicWorkshopDetails,
      page: () => const MechanicWorkshopDetailsView(),
      binding: MechanicWorkshopDetailsBinding(),
    ),
    GetPage(
      name: _Paths.orderDetails,
      page: () => const OrderDetailsView(),
      binding: OrderDetailsBinding(),
    ),
    GetPage(
      name: _Paths.serviceFailed,
      page: () => const ServiceFailedView(),
      binding: ServiceFailedBinding(),
    ),
    GetPage(
      name: _Paths.budgetDetails,
      page: () => const BudgetDetailsView(),
      binding: OrderDetailsBinding(),
    ),
  ];
}
