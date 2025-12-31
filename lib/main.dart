import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. IMPORT INI
import 'welcome_screen.dart';
import 'dashboard_screen.dart';
import 'notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. LOAD .ENV (WAJIB DI SINI)
  // Pastikan file .env ada di root folder project
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: File .env tidak ditemukan/gagal dimuat: $e");
  }

  await Firebase.initializeApp();
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ArtoKu App',

          // --- Setting TEMA TERANG ---
          theme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(),
            primaryColor: const Color(0xFF0F4C5C),
            scaffoldBackgroundColor: Colors.grey.shade50,
            cardColor: Colors.white,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F4C5C),
              brightness: Brightness.light,
            ),
          ),

          // --- Setting TEMA GELAP ---
          darkTheme: ThemeData(
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            primaryColor: const Color(0xFF0F4C5C),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            iconTheme: const IconThemeData(color: Colors.white70),
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F4C5C),
              brightness: Brightness.dark,
            ),
          ),

          themeMode: currentMode,

          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const DashboardScreen();
              }
              return const WelcomeScreen();
            },
          ),
        );
      },
    );
  }
}
