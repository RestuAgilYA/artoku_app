import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'welcome_screen.dart';
import 'dashboard_screen.dart';
import 'app_lock_screen.dart';
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
bool _themeChanged = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();

  // [BARU] Load .env
  try {
    await dotenv.load(fileName: ".env");
    // ignore: avoid_print
    print("Env loaded successfully");
  } catch (e) {
    // ignore: avoid_print
    print("Error loading .env: $e");
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    // Baca key 'isDarkMode', jika null anggap saja false (Light mode)
    final bool isDarkMode = prefs.getBool('isDarkMode') ?? false;

    // Update value notifier sesuai data yang disimpan
    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    // ignore: avoid_print
    print("Tema dimuat: ${isDarkMode ? 'Dark' : 'Light'}");
  } catch (e) {
    // ignore: avoid_print
    print("Gagal memuat tema: $e");
  }

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

          // TEMA TERANG
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

          // TEMA GELAP
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
                return _AppLockWrapper(child: DashboardScreen());
              }
              return const WelcomeScreen();
            },
          ),
        );
      },
    );
  }
}

class _AppLockWrapper extends StatefulWidget {
  final Widget child;

  const _AppLockWrapper({required this.child});

  @override
  State<_AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<_AppLockWrapper>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  DateTime? _pausedTime;
  DateTime? _lastThemeChange;
  DateTime? _lastUnlockTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeNotifier.addListener(_onThemeChanged); 
    _checkAppLockStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Hapus listener saat dispose untuk mencegah memory leak
    themeNotifier.removeListener(_onThemeChanged); 
    super.dispose();
  }

  Future<void> _checkAppLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('appLockEnabled') ?? false;
    if (isEnabled) {
      setState(() => _isLocked = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_lastThemeChange != null) {
        final sinceTheme = DateTime.now().difference(_lastThemeChange!);
        if (sinceTheme.inSeconds < 2) {
          return;
        }
      }
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  // Fungsi ini akan dipanggil ketika themeNotifier berubah
  void _onThemeChanged() {
    // Catat waktu theme change dan set flag
    _themeChanged = true;
    _lastThemeChange = DateTime.now();
    
    // Reset pause time agar tidak salah deteksi sebagai "app pause lama"
    _pausedTime = null;
    
    // Reset unlock time untuk mencegah re-lock
    _lastUnlockTime = DateTime.now();
  }

  void _handleAppResume() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('appLockEnabled') ?? false;

    if (!isEnabled) {
      setState(() => _isLocked = false);
      return;
    }

    if (_lastUnlockTime != null) {
      final sinceUnlock = DateTime.now().difference(_lastUnlockTime!);
      if (sinceUnlock.inSeconds < 3) {
        return;
      }
    }

    if (_lastThemeChange != null) {
      final sinceTheme = DateTime.now().difference(_lastThemeChange!);
      if (sinceTheme.inSeconds < 5) {
        _themeChanged = false;
        return;
      }
    }

    // Check apakah app di-pause lebih dari 30 detik
    if (_pausedTime != null) {
      final duration = DateTime.now().difference(_pausedTime!);
      if (duration.inSeconds > 30) {
        setState(() => _isLocked = true);
      }
    } else {
      // Jika tidak ada pausedTime, kemungkinan app baru dibuka
      // JANGAN lock jika baru theme change
      if (!_themeChanged) {
        setState(() => _isLocked = true);
      }
    }
    
    // Reset flag theme changed setelah handle
    _themeChanged = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return AppLockScreen(
        onUnlockSuccess: () {
          setState(() {
            _isLocked = false;
            _lastUnlockTime = DateTime.now(); // Catat waktu unlock 
            _pausedTime = null; // Reset pause time
          });
        },
      );
    }
    return widget.child;
  }
}