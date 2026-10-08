import 'package:flutter/material.dart';
import '../screens/dashboard/dashboard_page.dart';
import '../screens/login/login_page.dart';
import '../screens/products/products_page.dart';
import '../screens/products/add_product_page.dart';
import '../screens/marketers/marketers_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String addProduct = '/add-product';
  static const String marketers = '/marketers';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    dashboard: (context) => const DashboardPage(),
    products: (context) => const ProductsPage(),
    addProduct: (context) => const AddProductPage(),
    marketers: (context) => const MarketersPage(),
  };
}
