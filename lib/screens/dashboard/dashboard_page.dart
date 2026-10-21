import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';
import '../../widgets/stat_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color _burgundy = Color(0xFF70263D);
  static const Color _gold = Color(0xFFC5A15A);
  static const Color _background = Color(0xFFFAF5EC);
  static const Color _border = Color(0xFFE8DCCB);
  static const Color _softBeige = Color(0xFFF5EBDD);

  bool _isLoading = true;
  String? _errorMessage;

  double _totalSales = 0;
  double _totalProfit = 0;
  int _marketersCount = 0;
  int _productsCount = 0;

  List<Map<String, dynamic>> _recentSales = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatAmount(dynamic value) {
    final amount = _toDouble(value);
    return '${amount.toStringAsFixed(0)} ريال';
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'غير محدد';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$year/$month/$day';
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      // إجمالي المبيعات وأرباح المبيعات قبل خصم المصروفات.
      final salesSummary = await db.rawQuery('''
        SELECT
          COALESCE(SUM(total_amount), 0) AS total_sales,
          COALESCE(SUM(total_profit), 0) AS total_profit
        FROM sales
      ''');

      // إجمالي المصروفات المسجلة.
      final expensesSummary = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total_expenses
        FROM expenses
      ''');

      // عدد المسوقين النشطين.
      final marketersSummary = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM marketers
        WHERE is_active = 1
      ''');

      // عدد المنتجات النشطة.
      final productsSummary = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM products
        WHERE is_active = 1
      ''');

      // أحدث خمس فواتير.
      final recentSales = await db.rawQuery('''
        SELECT
          sales.id,
          sales.total_amount,
          sales.total_profit,
          sales.created_at,
          sales.marketer_id,
          COALESCE(marketers.name, 'مسوق غير معروف') AS marketer_name
        FROM sales
        LEFT JOIN marketers
          ON marketers.id = sales.marketer_id
        ORDER BY sales.id DESC
        LIMIT 5
      ''');

      if (!mounted) return;

      final salesData = salesSummary.isNotEmpty
          ? salesSummary.first
          : <String, dynamic>{};

      final expensesData = expensesSummary.isNotEmpty
          ? expensesSummary.first
          : <String, dynamic>{};

      final marketersData = marketersSummary.isNotEmpty
          ? marketersSummary.first
          : <String, dynamic>{};

      final productsData = productsSummary.isNotEmpty
          ? productsSummary.first
          : <String, dynamic>{};

      final totalProfitBeforeExpenses = _toDouble(salesData['total_profit']);
      final totalExpenses = _toDouble(expensesData['total_expenses']);

      setState(() {
        _totalSales = _toDouble(salesData['total_sales']);

        // صافي الأرباح بعد خصم المصروفات.
        _totalProfit = totalProfitBeforeExpenses - totalExpenses;

        _marketersCount = _toInt(marketersData['total']);
        _productsCount = _toInt(productsData['total']);
        _recentSales = recentSales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات لوحة التحكم.';
      });

      debugPrint('Dashboard loading error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _burgundy,
            secondary: _gold,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: _background,
          appBarTheme: const AppBarTheme(
            backgroundColor: _burgundy,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: _burgundy,
          ),
        ),
        child: Scaffold(
          backgroundColor: _background,
          drawer: const Drawer(child: Sidebar()),
          appBar: AppBar(
            title: const Text(
              'لوحة التحكم',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _burgundy,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: _loadDashboardData,
                tooltip: 'تحديث البيانات',
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: RefreshIndicator(
            color: _burgundy,
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نظرة عامة على أداء النظام',
                    style: TextStyle(
                      color: Colors.brown.shade400,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 16),
                  ],
                  _buildStatistics(),
                  const SizedBox(height: 24),
                  _buildRecentSales(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return GridView.count(
      crossAxisCount: 1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCard(
          title: 'إجمالي المبيعات',
          value: _isLoading ? '...' : _formatAmount(_totalSales),
          icon: Icons.point_of_sale,
        ),
        StatCard(
          title: 'صافي الأرباح',
          value: _isLoading ? '...' : _formatAmount(_totalProfit),
          icon: Icons.trending_up,
        ),
        StatCard(
          title: 'عدد المسوقين',
          value: _isLoading ? '...' : _marketersCount.toString(),
          icon: Icons.people_outline,
        ),
        StatCard(
          title: 'المنتجات',
          value: _isLoading ? '...' : _productsCount.toString(),
          icon: Icons.inventory_2_outlined,
        ),
      ],
    );
  }

  Widget _buildRecentSales() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر عمليات البيع',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _burgundy,
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading && _recentSales.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_recentSales.isEmpty)
            _buildEmptySales()
          else
            ..._recentSales.map(_buildSaleItem),
        ],
      ),
    );
  }

  Widget _buildSaleItem(Map<String, dynamic> sale) {
    final id = _toInt(sale['id']);
    final marketerName = sale['marketer_name']?.toString() ?? 'مسوق غير معروف';
    final totalAmount = _formatAmount(sale['total_amount']);
    final date = _formatDate(sale['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: _softBeige,
            foregroundColor: _burgundy,
            child: Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فاتورة رقم $id',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _burgundy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  marketerName,
                  style: TextStyle(color: Colors.brown.shade700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(color: Colors.brown.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              totalAmount,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: _burgundy,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySales() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 50,
              color: _gold.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 10),
            Text(
              'لا توجد عمليات بيع حتى الآن',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.brown.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: _loadDashboardData,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
