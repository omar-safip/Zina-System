import 'package:flutter/material.dart';

import '../screens/dashboard/dashboard_page.dart';
import '../screens/login/login_page.dart';
import '../screens/products/products_page.dart';
import '../screens/products/add_product_page.dart';
import '../screens/marketers/marketers_page.dart';
import '../screens/marketers/marketer_tree_page.dart';
import '../screens/sales/sales_page.dart';
import '../screens/sales/sales_history_page.dart';
import '../screens/reports/reports_page.dart';
import '../screens/audit_logs/audit_logs_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String addProduct = '/add-product';
  static const String marketers = '/marketers';
  static const String marketerTree = '/marketer-tree';
  static const String sales = '/sales';
  static const String salesHistory = '/sales-history';
  static const String reports = '/reports';
  static const String auditLogs = '/audit-logs';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    dashboard: (context) => const DashboardPage(),
    products: (context) => const ProductsPage(),
    addProduct: (context) => const AddProductPage(),
    marketers: (context) => const MarketersPage(),
    marketerTree: (context) => const MarketerTreePage(),
    sales: (context) => const SalesPage(),
    salesHistory: (context) => const SalesHistoryPage(),
    reports: (context) => const ReportsPage(),
    auditLogs: (context) => const AuditLogsPage(),
  };
}
