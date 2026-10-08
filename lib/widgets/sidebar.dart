import 'package:flutter/material.dart';
import '../app/routes.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF173F82),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            const SizedBox(height: 20),

            _menuItem(
              context: context,
              icon: Icons.dashboard_outlined,
              title: 'لوحة التحكم',
              selected: true,
              onTap: () {
                Navigator.of(context).pop();
              },
            ),

            _menuItem(
              context: context,
              icon: Icons.people_outline,
              title: 'المسوقون',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, AppRoutes.marketers);
              },
            ),

            _menuItem(
              context: context,
              icon: Icons.account_tree_outlined,
              title: 'شجرة المسوقين',
            ),

            _menuItem(
              context: context,
              icon: Icons.inventory_2_outlined,
              title: 'المنتجات والمخزون',
              onTap: () {
                Navigator.of(context).pop();

                Navigator.pushNamed(context, AppRoutes.products);
              },
            ),

            _menuItem(
              context: context,
              icon: Icons.point_of_sale_outlined,
              title: 'المبيعات',
            ),

            _menuItem(
              context: context,
              icon: Icons.bar_chart_outlined,
              title: 'التقارير',
            ),

            _menuItem(
              context: context,
              icon: Icons.archive_outlined,
              title: 'الأرشيف',
            ),

            const Spacer(),

            _menuItem(
              context: context,
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
            ),

            _menuItem(
              context: context,
              icon: Icons.logout,
              title: 'تسجيل الخروج',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'نظام الإدارة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 4),

          Text(
            'إدارة المسوقين والمبيعات',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 21),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        onTap:
            onTap ??
            () {
              Navigator.of(context).pop();
            },
      ),
    );
  }
}
