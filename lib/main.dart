import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/setup_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Custom Error Widget (Avoids Red Screen of Death)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return MaterialApp(
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  const Text('Oops! Something went wrong.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(details.exceptionAsString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    };

    final setupService = SetupService();
    final bool isSetupComplete = await setupService.isSetupComplete();
    
    runApp(AutoMailApp(isSetupComplete: isSetupComplete));
  }, (error, stackTrace) {
    print('Global Error Caught: $error');
    // Here you would typically log to a service like Sentry or Firebase Crashlytics
  });
}

class AutoMailApp extends StatelessWidget {
  final bool isSetupComplete;
  
  const AutoMailApp({super.key, required this.isSetupComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Mail AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: isSetupComplete ? const HomeScreen() : const SetupScreen(),
    );
  }
}
