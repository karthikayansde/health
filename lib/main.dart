import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/dashboard_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/debug_screen.dart';
import 'controllers/health_controller.dart';
import 'services/health_connect_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  Get.put(HealthConnectService());
  Get.put(HealthController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Health Connect Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/permissions',
      getPages: [
        GetPage(name: '/permissions', page: () => const PermissionsScreen()),
        GetPage(name: '/dashboard', page: () => const DashboardScreen()),
        GetPage(name: '/debug', page: () => const DebugScreen()),
      ],
    );
  }
}