import 'package:flutter/material.dart';
import 'theme.dart';
import 'routes.dart';

class MarketerApp extends StatelessWidget {
  const MarketerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'نظام إدارة المسوقين',

      theme: AppTheme.lightTheme,

      locale: const Locale('ar'),

      initialRoute: AppRoutes.dashboard,

      routes: AppRoutes.routes,
    );
  }
}
