import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/Home/screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MindMateApp()));
}

class MindMateApp extends StatelessWidget {
  const MindMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindMate 2.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF63A4FF),
          brightness: Brightness.light,
        ),

        // IMPORTANT: prevents grey/black Material overlays
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,

        useMaterial3: true,
      ),

      home: const HomePage(),

      // GLOBAL BACKGROUND
      builder: (context, child) {
        return Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.asset(
                'assets/images/app_background.png',
                fit: BoxFit.cover,
              ),
            ),

            // App content
            child ?? const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}
