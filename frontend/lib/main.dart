import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/theme_controller.dart';
import 'screens/splash_screen.dart';
import 'services/local_push_service.dart';
import 'services/push_service.dart';
import 'utils/navigator_key.dart';
import 'services/api_customer_service.dart';
import 'services/api_financer_service.dart';
import 'services/api_notification_service.dart';
import 'services/api_sale_financer_service.dart';
import 'services/api_sale_service.dart';
import 'services/api_user_service.dart';
import 'services/api_vehicle_service.dart';
import 'services/customer_service.dart';
import 'services/financer_service.dart';
import 'services/loan_service.dart';
import 'services/sale_financer_service.dart';
import 'services/notification_service.dart';
import 'services/pdf_service.dart';
import 'services/rental_service.dart';
import 'services/sale_service.dart';
import 'services/user_service.dart';
import 'services/vehicle_service.dart';
import 'theme/app_theme.dart';
import 'utils/no_scrollbar_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load Indian-locale date symbols before any DateFormat('…', 'en_IN') runs,
  // otherwise intl throws LocaleDataException on the first formatted date.
  Intl.defaultLocale = 'en_IN';
  await initializeDateFormatting('en_IN');
  await LocalPushService.init();
  // FCM push (reaches the app even when closed). Wrapped so platforms without
  // Firebase config (e.g. web/desktop review builds) still launch normally.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.init();
  } catch (_) {
    // Firebase not available on this platform — skip push, app runs fine.
  }
  final themeController = ThemeController();
  await themeController.load();
  runApp(SlvApp(themeController: themeController));
}

class SlvApp extends StatelessWidget {
  const SlvApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider(create: (_) => AuthController()),
        // Shared data layer (mock). Customers + vehicles are reused across the
        // Auto Sale and Rental modules. Firestore implementations swap in here
        // in Phase 7 without touching view models.
        ChangeNotifierProvider<CustomerService>(
          create: (_) => ApiCustomerService()..refresh(),
        ),
        ChangeNotifierProvider<VehicleService>(
          // Real backend service. Loads the vehicle list from the API on start.
          create: (_) => ApiVehicleService()..refresh(),
        ),
        ChangeNotifierProvider<FinancerService>(
          create: (_) => ApiFinancerService()..refresh(),
        ),
        ChangeNotifierProvider<SaleFinancerService>(
          create: (_) => ApiSaleFinancerService()..refresh(),
        ),
        ChangeNotifierProxyProvider<AuthController, SaleService>(
          create: (ctx) =>
              ApiSaleService(auth: ctx.read<AuthController>())..refresh(),
          update: (ctx, auth, previous) =>
              previous ?? ApiSaleService(auth: auth)..refresh(),
        ),
        ChangeNotifierProvider<RentalService>(
          create: (_) => MockRentalService(),
        ),
        ChangeNotifierProvider<LoanService>(
          create: (_) => MockLoanService(),
        ),
        ChangeNotifierProvider<UserService>(
          create: (_) => ApiUserService()..refresh(),
        ),
        ChangeNotifierProxyProvider<AuthController, NotificationFeed>(
          create: (ctx) => NotificationFeed(auth: ctx.read<AuthController>()),
          update: (ctx, auth, prev) {
            final feed = prev ?? NotificationFeed(auth: auth);
            if (auth.currentUserId != 0) feed.refresh();
            return feed;
          },
        ),
        // Stateless infrastructure services.
        Provider<NotificationService>(
          create: (_) => const MockNotificationService(),
        ),
        Provider<PdfService>(
          create: (_) => const RealPdfService(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'SLV Auto Consultant',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: theme.mode,
            scrollBehavior: const NoScrollbarBehavior(),
            builder: (context, child) {
              // Clamp text scaling to keep layouts intact (0.9–1.3).
              final mq = MediaQuery.of(context);
              final clamped = mq.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.3,
              );
              return MediaQuery(
                data: mq.copyWith(textScaler: clamped),
                child: child!,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
