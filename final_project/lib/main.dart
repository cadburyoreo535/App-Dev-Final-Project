import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/procurement_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/spoilage_screen.dart';
import 'screens/login_screen.dart'; 

void main() {
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
        fontFamily: 'Open Sans',
      ),
      initialRoute: '/', 
      routes: {
        '/': (context) => const DashboardScreen(),
        '/login': (context) => const LoginScreen(), 
        '/inventory': (context) => const InventoryScreen(),
        '/procurement': (context) => const ProcurementScreen(),
        '/recipes': (context) => const RecipesScreen(),
        '/spoilage': (context) => const SpoilageScreen(),
      },
    );
  }
}
