import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase/firebase_options.dart'; 
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/procurement_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/spoilage_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Spoilage Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
        fontFamily: 'Kedebideri',
      ),
      initialRoute: '/login',
      routes: {
        '/': (context) => const DashboardScreen(),
        '/login': (context) => const LoginScreen(),
        '/inventory': (context) => const InventoryScreen(),
        '/procurement': (context) => const ProcurementScreen(),
        '/recipes': (context) => const RecipesScreen(),
        '/spoilage': (context) => const SpoilageScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}
