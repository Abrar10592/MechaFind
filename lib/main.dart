import 'package:flutter/material.dart';
import 'package:mechfind/home.dart';
import 'package:mechfind/mechanic/mechanic.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'landing.dart';
import 'signup.dart';
import 'signin.dart';
import 'role.dart';
import 'user_home.dart';
import 'find_mechanics.dart';

import 'screens/history/history_page.dart';
import 'screens/messages/messages_page.dart';
import 'screens/settings/settings_profile_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedLocale = prefs.getString('lang_code') ?? 'en';

  await Supabase.initialize(
    url: 'https://ygmvmhsbxipuykpjrfgj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlnbXZtaHNieGlwdXlrcGpyZmdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEwMjU5OTIsImV4cCI6MjA2NjYwMTk5Mn0.0FwAnum-j6Js5y8IPNL8cjSZchgFBcUabvhdIE_iwfI',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('bn')],
      path: 'zob_assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: Locale(savedLocale),
      child: MechFindApp(),
    ),
  );
}

class MechFindApp extends StatefulWidget {
  const MechFindApp({super.key});

  @override
  _MechFindAppState createState() => _MechFindAppState();
}

class _MechFindAppState extends State<MechFindApp> {
  late StreamSubscription _deepLinkSubscription;
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _setupDeepLinkHandling();
  }

  @override
  void dispose() {
    _deepLinkSubscription.cancel();
    super.dispose();
  }

  Future<void> _setupDeepLinkHandling() async {
    final appLinks = AppLinks();

    // Handle initial deep link
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      
      _handleDeepLink(initialLink);
    }

    // Listen for incoming deep links
    _deepLinkSubscription = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print('Received deep link: $uri');
        _handleDeepLink(uri);
      }
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Handle Supabase verification URL
    if (uri.host.contains('ygmvmhsbxipuykpjrfgj.supabase.co') && uri.path == '/auth/v1/verify') {
      final token = uri.queryParameters['token'];
      final type = uri.queryParameters['type'];
      final redirectTo = uri.queryParameters['redirect_to'];
      final email = uri.queryParameters['email'];

      print('Verification URL: token=$token, type=$type, redirect_to=$redirectTo, email=$email');

      if (token != null && type == 'signup') {
        try {
          final response = await supabase.auth.verifyOTP(
            type: OtpType.signup,
            token: token,
            email: email ?? '',
          );
          if (response.user != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email verified successfully!')),
            );
            Navigator.pushReplacementNamed(context, '/signin');
          }
        } on AuthException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
          print('Verification error: ${e.message}');
        }
      }
    }
    // Handle direct deep link
    else if (uri.scheme == 'mechfind' && uri.host == 'signin') {
      final token = uri.queryParameters['token'];
      final type = uri.queryParameters['type'];
      final email = uri.queryParameters['email'];

      print('Direct deep link: token=$token, type=$type, email=$email');

      if (token != null && type == 'signup') {
        try {
          final response = await supabase.auth.verifyOTP(
            type: OtpType.signup,
            token: token,
            email: email ?? '',
          );
          if (response.user != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email verified successfully!')),
            );
            Navigator.pushReplacementNamed(context, '/signin');
          }
        } on AuthException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
          print('Verification error: ${e.message}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechFind',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          headlineLarge: AppTextStyles.heading,
          bodyMedium: AppTextStyles.body,
          labelLarge: AppTextStyles.label,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/': (context) => const LandingPage(),
        '/signup': (context) => SignUpPage(),
        '/signin': (context) => SignInPage(),
        '/role': (context) => RoleSelectionPage(),
        '/userHome': (context) => UserHomePage(),
        '/mechanicHome': (context) => Mechanic(),
        '/home': (context) => WelcomePage(),
        '/find-mechanics': (context) => const FindMechanicsPage(),
        '/messages': (context) => const MessagesPage(),
        '/history': (context) => const HistoryPage(),
        '/settings': (context) => const SettingsProfileScreen(),
      },
    );
  }
}