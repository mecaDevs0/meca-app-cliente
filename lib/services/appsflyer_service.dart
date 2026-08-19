import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show navigatorKey, deepLinkNavigated;

class AppsFlyerService {
  AppsFlyerService._();
  static final AppsFlyerService instance = AppsFlyerService._();

  AppsflyerSdk? _sdk;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final options = AppsFlyerOptions(
        afDevKey: 'EJgci2EGWpS69K5FNqdFcS',
        appId: '6743087361',
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 10,
      );

      _sdk = AppsflyerSdk(options);

      _sdk!.onInstallConversionData((data) {
        if (kDebugMode) print('[AppsFlyer] Install conversion: $data');
        _handleDeferredDeepLink(data);
      });

      _sdk!.onAppOpenAttribution((data) {
        if (kDebugMode) print('[AppsFlyer] App open attribution: $data');
      });

      _sdk!.onDeepLinking((result) {
        if (kDebugMode) print('[AppsFlyer] Deep link: ${result.toJson()}');
        _handleDeepLink(result);
      });

      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );

      _initialized = true;
      if (kDebugMode) print('[AppsFlyer] SDK initialized');
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] Init error: $e');
    }
  }

  void _handleDeepLink(DeepLinkResult result) {
    try {
      if (result.status != Status.FOUND) return;
      final deepLink = result.deepLink;
      if (deepLink == null) return;

      final screen = deepLink.getStringValue('screen');
      final id = deepLink.getStringValue('id');
      if (screen == null) return;

      _navigateToScreen(screen, id);
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] Deep link handling error: $e');
    }
  }

  void _handleDeferredDeepLink(Map? data) {
    try {
      if (data == null) return;
      final payload = data['payload'] as Map? ?? data;

      final isFirstLaunch = payload['is_first_launch'];
      if (isFirstLaunch != true && isFirstLaunch != 'true') return;

      final screen = payload['af_dp']?.toString() ?? payload['screen']?.toString();
      final id = payload['id']?.toString();
      if (screen == null) return;

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('af_deferred_screen', screen);
        if (id != null) prefs.setString('af_deferred_id', id);
      });
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] Deferred deep link error: $e');
    }
  }

  Future<void> applyDeferredDeepLink() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final screen = prefs.getString('af_deferred_screen');
      if (screen == null) return;

      final id = prefs.getString('af_deferred_id');
      await prefs.remove('af_deferred_screen');
      await prefs.remove('af_deferred_id');

      _navigateToScreen(screen, id);
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] Apply deferred deep link error: $e');
    }
  }

  void _navigateToScreen(String screen, String? id) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (screen) {
      case 'workshop':
        if (id != null) {
          deepLinkNavigated = true;
          nav.pushNamedAndRemoveUntil('/home', (route) => false);
          nav.pushNamed('/workshop-detail', arguments: {'id': id});
        }
        break;
      case 'booking':
        if (id != null) {
          nav.pushNamed('/order-detail', arguments: {'id': id});
        }
        break;
      case 'home':
        nav.pushNamedAndRemoveUntil('/home', (route) => false);
        break;
    }
  }

  // ── Customer User ID ──

  void setCustomerUserId(String id) {
    try {
      _sdk?.setCustomerUserId(id);
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] setCustomerUserId error: $e');
    }
  }

  void clearCustomerUserId() {
    try {
      _sdk?.setCustomerUserId('');
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] clearCustomerUserId error: $e');
    }
  }

  // ── Event helpers ──

  Future<void> _logEvent(String name, Map<String, dynamic> params) async {
    try {
      await _sdk?.logEvent(name, params);
      if (kDebugMode) print('[AppsFlyer] Event: $name $params');
    } catch (e) {
      if (kDebugMode) print('[AppsFlyer] Event error ($name): $e');
    }
  }

  // ── Typed events ──

  Future<void> logRegistration(String method, String customerId) =>
      _logEvent('af_complete_registration', {
        'af_registration_method': method,
        'customer_id': customerId,
      });

  Future<void> logLogin(String customerId) =>
      _logEvent('af_login', {
        'af_customer_user_id': customerId,
      });

  Future<void> logSearch(String term) =>
      _logEvent('af_search', {
        'af_search_string': term,
        'af_content_type': 'workshop',
      });

  Future<void> logWorkshopView(String workshopId, String workshopName) =>
      _logEvent('af_content_view', {
        'af_content_id': workshopId,
        'af_content_type': 'workshop',
        'workshop_name': workshopName,
      });

  Future<void> logServiceRequest(String bookingId, String serviceType, String workshopId) =>
      _logEvent('meca_service_request', {
        'af_content_id': bookingId,
        'service_type': serviceType,
        'workshop_id': workshopId,
      });

  Future<void> logBookingConfirmed(String bookingId, String workshopId, String date) =>
      _logEvent('meca_booking_confirmed', {
        'af_content_id': bookingId,
        'workshop_id': workshopId,
        'af_date_a': date,
      });

  Future<void> logInitiatedCheckout(String bookingId, double amount) =>
      _logEvent('af_initiated_checkout', {
        'af_content_id': bookingId,
        'af_revenue': amount,
        'af_currency': 'BRL',
      });

  Future<void> logPurchase(String bookingId, String paymentId, double amount, String paymentMethod) =>
      _logEvent('af_purchase', {
        'af_revenue': amount,
        'af_currency': 'BRL',
        'af_content_id': bookingId,
        'af_order_id': paymentId,
        'payment_method': paymentMethod,
      });

  Future<void> logRating(String bookingId, int rating) =>
      _logEvent('af_rate', {
        'af_rating_value': rating,
        'af_content_id': bookingId,
      });

  Future<void> logAddVehicle(String brand, String model) =>
      _logEvent('meca_add_vehicle', {
        'vehicle_brand': brand,
        'vehicle_model': model,
      });
}
