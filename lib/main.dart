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

// 🌟 নোটিফিকেশন প্লাগইন ইনস্ট্যান্স তৈরি করা হলো
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🌟 ফায়ারস্টোর অফলাইন ক্যাশ এনেবল করা হলো (Instant cache loading)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🌟 ইমেজ মেমোরি ক্যাশ অপটিমাইজেশন (স্ক্রোলিং ল্যাগ দূর করতে)
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
      // 🌟 ভাষা বদলানোর সাথে সাথে পুরো উইজেট ট্রি রিক্রিয়েট করার জন্য এই কী (Key) টি জরুরি
      child: const MyApp(key: ValueKey('main_app')),
    ),
  );
}

// 🌟 সিস্টেম নোটিফিকেশন চ্যানেল সেটআপ ফাংশন (প্রতিটি ফিচারের আলাদা ক্যাটাগরি দেখানোর জন্য)
Future<void> setupNotificationChannels() async {
  // ১. Mess Notices
  const AndroidNotificationChannel noticeChannel = AndroidNotificationChannel(
    'mess_notice_channel', 
    'Mess Notices', 
    description: 'Important notices from admin',
    importance: Importance.high,
  );

  // ২. Meal Updates
  const AndroidNotificationChannel mealChannel = AndroidNotificationChannel(
    'mess_meal_channel',
    'Meal Updates',
    description: 'Daily meal entry updates',
    importance: Importance.defaultImportance,
  );

  // ৩. Payments & Bazaar
  const AndroidNotificationChannel paymentChannel = AndroidNotificationChannel(
    'mess_payment_channel',
    'Payments & Bazaar',
    description: 'Bazaar and payment notifications',
    importance: Importance.high,
  );

  // ৪. Chat Messages
  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'mess_chat_channel',
    'Chat Messages',
    description: 'Notifications for new group chat messages',
    importance: Importance.high,
  );

  // ৫. Bazaar Assign & Duties
  const AndroidNotificationChannel assignChannel = AndroidNotificationChannel(
    'mess_assign_channel',
    'Bazaar Assign & Duties',
    description: 'Notifications for bazaar duties and assignments',
    importance: Importance.high,
  );

  // ৬. Room Rent & Utilities
  const AndroidNotificationChannel rentChannel = AndroidNotificationChannel(
    'mess_rent_channel',
    'Room Rent & Utilities',
    description: 'Room rent sheet and monthly bills updates',
    importance: Importance.high,
  );

  // ৭. Account Approval (Waiting Approval)
  const AndroidNotificationChannel approvalChannel = AndroidNotificationChannel(
    'mess_approval_channel',
    'Account Approvals',
    description: 'Notifications for join requests and approvals',
    importance: Importance.high,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  await androidPlugin?.requestNotificationsPermission();

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

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
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
          title: 'MessFlow',
          debugShowCheckedModeBanner: false,
          
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,

          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.green,
            scaffoldBackgroundColor: const Color(0xFFF6F8FA),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.green,
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