import 'package:flutter/material.dart';
import '../app/routes.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  // ألوان هوية ZEINA
  static const Color _backgroundColor = Color(0xFF4D192B);
  static const Color _primaryColor = Color(0xFF70263D);
  static const Color _selectedColor = Color(0xFFC5A15A);
  static const Color _textColor = Color(0xFFFAF5EC);
  static const Color _mutedTextColor = Color(0xFFDCC9C0);

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    // تحديد الصفحة الحالية حسب مسار التنقل الفعلي.
    final isDashboardSelected = currentRoute == AppRoutes.dashboard;

    return Container(
      width: 280,
      color: _backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    _menuItem(
                      context: context,
                      icon: Icons.dashboard_outlined,
                      title: 'لوحة التحكم',
                      selected: isDashboardSelected,
                      onTap: () => _navigate(context, AppRoutes.dashboard),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.people_outline,
                      title: 'المسوقون',
                      selected: currentRoute == AppRoutes.marketers,
                      onTap: () => _navigate(context, AppRoutes.marketers),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.account_tree_outlined,
                      title: 'شجرة المسوقين',
                      selected: currentRoute == AppRoutes.marketerTree,
                      onTap: () => _navigate(context, AppRoutes.marketerTree),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.inventory_2_outlined,
                      title: 'المنتجات والمخزون',
                      selected:
                          currentRoute == AppRoutes.products ||
                          currentRoute == AppRoutes.addProduct,
                      onTap: () => _navigate(context, AppRoutes.products),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.point_of_sale_outlined,
                      title: 'المبيعات',
                      selected: currentRoute == AppRoutes.sales,
                      onTap: () => _navigate(context, AppRoutes.sales),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.receipt_long_outlined,
                      title: 'سجل فواتير المبيعات',
                      selected: currentRoute == AppRoutes.salesHistory,
                      onTap: () => _navigate(context, AppRoutes.salesHistory),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.payments_outlined,
                      title: 'المصروفات',
                      selected: currentRoute == AppRoutes.expenses,
                      onTap: () => _navigate(context, AppRoutes.expenses),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.bar_chart_outlined,
                      title: 'التقارير',
                      selected: currentRoute == AppRoutes.reports,
                      onTap: () => _navigate(context, AppRoutes.reports),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.manage_history_outlined,
                      title: 'سجل التدقيق',
                      selected: currentRoute == AppRoutes.auditLogs,
                      onTap: () => _navigate(context, AppRoutes.auditLogs),
                    ),

                    _menuItem(
                      context: context,
                      icon: Icons.archive_outlined,
                      title: 'الأرشيف',
                      selected: currentRoute == AppRoutes.archive,
                      onTap: () => _navigate(context, AppRoutes.archive),
                    ),

                    const SizedBox(height: 12),

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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    final navigator = Navigator.of(context);

    // إغلاق القائمة الجانبية أولاً.
    if (navigator.canPop()) {
      navigator.pop();
    }

    // فتح الصفحة المطلوبة.
    navigator.pushNamed(route);
  }

  Widget _buildHeader() {
    return Container(
      height: 110,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_primaryColor, _backgroundColor],
        ),
        border: Border(bottom: BorderSide(color: _selectedColor, width: 1.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ZEINA',
            style: TextStyle(
              color: _selectedColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'نظام الإدارة',
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'إدارة المسوقين والمبيعات',
            style: TextStyle(color: _mutedTextColor, fontSize: 11),
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
        color: selected
            ? _selectedColor.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: selected
            ? Border.all(
                color: _selectedColor.withValues(alpha: 0.75),
                width: 1,
              )
            : Border.all(color: Colors.transparent, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        leading: Icon(
          icon,
          color: selected ? _selectedColor : _mutedTextColor,
          size: 21,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected ? _textColor : _mutedTextColor,
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: selected
            ? Container(
                width: 4,
                height: 23,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        onTap:
            onTap ??
            () {
              Navigator.of(context).pop();
            },
      ),
    );
  }
}
