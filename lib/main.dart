import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'controllers/app_settings_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_mess_screen.dart';
import 'screens/waiting_approval_screen.dart';
import 'screens/setup_profile_screen.dart';
import 'services/auto_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background FCM message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB
  PaintingBinding.instance.imageCache.maximumSize = 1000;

  await EasyLocalization.ensureInitialized();
  await AppSettingsController.instance.loadSettings();

  await setupNotificationChannels();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('bn'),
        Locale('hi'),
        Locale('ar'),
        Locale('es'),
      ],
      path: 'assets/translations', 
      fallbackLocale: const Locale('en'),
      child: const MyApp(key: ValueKey('main_app')),
    ),
  );
}

// Android notification channel setup
Future<void> setupNotificationChannels() async {
  const AndroidNotificationChannel noticeChannel = AndroidNotificationChannel(
    'mess_notice_channel', 
    'Mess Notices', 
    description: 'Important notices from admin',
    importance: Importance.high,
  );

  const AndroidNotificationChannel mealChannel = AndroidNotificationChannel(
    'mess_meal_channel',
    'Meal Updates',
    description: 'Daily meal entry updates',
    importance: Importance.high,
  );

  const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
    'mess_payment_channel',
    'Payments & Bazaar',
    description: 'Bazaar and payment notifications',
    importance: Importance.high,
  );

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'mess_chat_channel',
    'Chat Messages',
    description: 'Notifications for new group chat messages',
    importance: Importance.high,
  );

  const AndroidNotificationChannel assignChannel = AndroidNotificationChannel(
    'mess_assign_channel',
    'Bazaar Assign & Duties',
    description: 'Notifications for bazaar duties and assignments',
    importance: Importance.high,
  );

  const AndroidNotificationChannel rentChannel = AndroidNotificationChannel(
    'mess_rent_channel',
    'Room Rent & Utilities',
    description: 'Room rent sheet and monthly bills updates',
    importance: Importance.high,
  );

  const AndroidNotificationChannel approvalChannel = AndroidNotificationChannel(
    'mess_approval_channel',
    'Account Approvals',
    description: 'Notifications for join requests and approvals',
    importance: Importance.high,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  await androidPlugin?.requestNotificationsPermission();

  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (_) {}

  await androidPlugin?.createNotificationChannel(noticeChannel);
  await androidPlugin?.createNotificationChannel(mealChannel);
  await androidPlugin?.createNotificationChannel(paymentChannel);
  await androidPlugin?.createNotificationChannel(chatChannel);
  await androidPlugin?.createNotificationChannel(assignChannel);
  await androidPlugin?.createNotificationChannel(rentChannel);
  await androidPlugin?.createNotificationChannel(approvalChannel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        final parts = payload.split('|');
        if (parts.length >= 2) {
          final messId = parts[0];
          final type = parts[1];
          AutoNotificationService.handleNotificationTap(
            messId,
            type,
            rootNavigatorKey.currentState,
          );
        }
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final isDark = AppSettingsController.instance.isDarkMode;

        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          title: 'MessFlow',
          debugShowCheckedModeBanner: false,
          
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B5E20),
              primary: const Color(0xFF1B5E20),
              surface: const Color(0xFFF8FAF9),
              surfaceTint: Colors.transparent,
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F8FA),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            cardTheme: CardThemeData(
              elevation: 0.5,
              shadowColor: Colors.black.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.8)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              brightness: Brightness.dark,
              seedColor: const Color(0xFF2E7D32),
              primary: const Color(0xFF4CAF50),
              surface: const Color(0xFF181A20),
              surfaceTint: Colors.transparent,
            ),
            scaffoldBackgroundColor: const Color(0xFF121417),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              color: const Color(0xFF1E2228),
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Color(0xFF181A20),
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
                );
              }
              
              final user = authSnapshot.data;
              if (user != null) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                  builder: (context, userDocSnapshot) {
                    if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
                      );
                    }

                    final userData = userDocSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final String messId = userData['messId'] ?? '';
                    final String status = userData['status'] ?? '';
                    final String phone = userData['phone']?.toString().trim() ?? '';

                    if (phone.isEmpty) {
                      return SetupProfileScreen(messId: messId);
                    }

                    if (messId.isEmpty) {
                      return const JoinMessScreen();
                    }

                    if (status == 'pending') {
                      return const WaitingApprovalScreen();
                    }

                    return HomeScreen(messId: messId);
                  },
                );
              }
              
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
