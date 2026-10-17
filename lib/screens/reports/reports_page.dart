import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

enum ReportPeriod { today, week, month, custom }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportPeriod _period = ReportPeriod.month;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _sales = [];
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime get _effectiveStart {
    final now = DateTime.now();

    switch (_period) {
      case ReportPeriod.today:
        return _dateOnly(now);

      case ReportPeriod.week:
        final today = _dateOnly(now);
        return today.subtract(Duration(days: today.weekday - 1));

      case ReportPeriod.month:
        return DateTime(now.year, now.month, 1);

      case ReportPeriod.custom:
        return _dateOnly(_startDate);
    }
  }

  DateTime get _effectiveEnd {
    if (_period == ReportPeriod.custom) {
      return _dateOnly(_endDate);
    }

    return _dateOnly(DateTime.now());
  }

  String _dateToString(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'غير محدد';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _toDouble(value);
    return '${amount.toStringAsFixed(2)} ريال';
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final db = await DatabaseHelper.instance.database;

      final start = _dateToString(_effectiveStart);
      final endExclusive = _dateToString(
        _effectiveEnd.add(const Duration(days: 1)),
      );

      final summaryResult = await db.rawQuery(
        '''
        SELECT
          COUNT(*) AS sales_count,
          COALESCE(SUM(total_amount), 0) AS total_sales,
          COALESCE(SUM(total_profit), 0) AS total_profit,
          COALESCE(SUM(commission_amount), 0) AS commissions,
          COALESCE(SUM(referral_commission_amount), 0)
            AS referral_commissions
        FROM sales
        WHERE created_at >= ?
          AND created_at < ?
        ''',
        [start, endExclusive],
      );

      final expenseResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total_expenses
        FROM expenses
        WHERE created_at >= ?
          AND created_at < ?
        ''',
        [start, endExclusive],
      );

      final salesResult = await db.rawQuery(
        '''
        SELECT
          s.id,
          s.marketer_id,
          s.total_amount,
          s.total_profit,
          s.commission_amount,
          s.referral_commission_amount,
          s.created_at,
          m.name AS marketer_name
        FROM sales s
        LEFT JOIN marketers m ON m.id = s.marketer_id
        WHERE s.created_at >= ?
          AND s.created_at < ?
        ORDER BY s.id DESC
        ''',
        [start, endExclusive],
      );

      final marketersResult = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM marketers
        WHERE is_active = 1
        ''');

      final productsResult = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM products
        WHERE is_active = 1
        ''');

      final lowStockResult = await db.rawQuery('''
        SELECT COUNT(*) AS total
        FROM products
        WHERE is_active = 1
          AND stock_quantity <= min_stock_quantity
        ''');

      final summary = Map<String, dynamic>.from(summaryResult.first);

      summary['total_expenses'] = expenseResult.isNotEmpty
          ? expenseResult.first['total_expenses']
          : 0;

      summary['active_marketers'] = marketersResult.first['total'] ?? 0;

      summary['active_products'] = productsResult.first['total'] ?? 0;

      final grossProfit = _toDouble(summary['total_profit']);
      final commissions = _toDouble(summary['commissions']);
      final referralCommissions = _toDouble(summary['referral_commissions']);
      final expenses = _toDouble(summary['total_expenses']);

      summary['net_profit'] =
          grossProfit - commissions - referralCommissions - expenses;

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _sales = salesResult;
        _lowStockCount = _toInt(lowStockResult.first['total']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر تحميل التقرير: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
      helpText: 'اختر بداية التقرير',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (selected == null) return;

    setState(() {
      _startDate = selected;
    });

    await _loadReport();
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      helpText: 'اختر نهاية التقرير',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (selected == null) return;

    setState(() {
      _endDate = selected;
    });

    await _loadReport();
  }

  void _changePeriod(ReportPeriod? value) {
    if (value == null) return;

    setState(() {
      _period = value;

      if (value == ReportPeriod.custom) {
        _startDate = _dateOnly(_startDate);
        _endDate = _dateOnly(_endDate);

        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      }
    });

    _loadReport();
  }

  Widget _buildTopBar() {
    return Builder(
      builder: (context) {
        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, size: 27),
                tooltip: 'القائمة',
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'التقارير',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث التقرير',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الفترة الزمنية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportPeriod>(
            value: _period,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: ReportPeriod.today, child: Text('اليوم')),
              DropdownMenuItem(
                value: ReportPeriod.week,
                child: Text('هذا الأسبوع'),
              ),
              DropdownMenuItem(
                value: ReportPeriod.month,
                child: Text('هذا الشهر'),
              ),
              DropdownMenuItem(
                value: ReportPeriod.custom,
                child: Text('فترة مخصصة'),
              ),
            ],
            onChanged: _changePeriod,
          ),
          if (_period == ReportPeriod.custom) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectStartDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('من ${_formatDate(_dateToString(_startDate))}'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectEndDate,
                  icon: const Icon(Icons.event),
                  label: Text('إلى ${_formatDate(_dateToString(_endDate))}'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'من ${_formatDate(_dateToString(_effectiveStart))} '
            'إلى ${_formatDate(_dateToString(_effectiveEnd))}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final totalSales = _toDouble(_summary['total_sales']);
    final totalProfit = _toDouble(_summary['total_profit']);
    final commissions = _toDouble(_summary['commissions']);
    final referralCommissions = _toDouble(_summary['referral_commissions']);
    final expenses = _toDouble(_summary['total_expenses']);
    final netProfit = _toDouble(_summary['net_profit']);
    final salesCount = _toInt(_summary['sales_count']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 550
            ? 2
            : 1;

        final cards = [
          _buildStatCard(
            title: 'إجمالي المبيعات',
            value: _money(totalSales),
            icon: Icons.point_of_sale,
            color: const Color(0xFF1E4FA3),
          ),
          _buildStatCard(
            title: 'إجمالي الربح',
            value: _money(totalProfit),
            icon: Icons.trending_up,
            color: Colors.green,
            subtitle: 'قبل خصم العمولات والمصروفات',
          ),
          _buildStatCard(
            title: 'العمولات الشخصية',
            value: _money(commissions),
            icon: Icons.person_outline,
            color: Colors.orange,
          ),
          _buildStatCard(
            title: 'عمولات التبعية',
            value: _money(referralCommissions),
            icon: Icons.account_tree_outlined,
            color: Colors.deepPurple,
          ),
          _buildStatCard(
            title: 'المصروفات',
            value: _money(expenses),
            icon: Icons.payments_outlined,
            color: Colors.red,
          ),
          _buildStatCard(
            title: 'صافي الربح التقديري',
            value: _money(netProfit),
            icon: Icons.account_balance_wallet_outlined,
            color: netProfit >= 0 ? Colors.teal : Colors.red,
            subtitle: 'بعد خصم العمولات والمصروفات',
          ),
          _buildStatCard(
            title: 'عدد الفواتير',
            value: salesCount.toString(),
            icon: Icons.receipt_long_outlined,
            color: Colors.blueGrey,
          ),
          _buildStatCard(
            title: 'متوسط الفاتورة',
            value: _money(salesCount > 0 ? totalSales / salesCount : 0),
            icon: Icons.calculate_outlined,
            color: Colors.indigo,
          ),
        ];

        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1
              ? 2.0
              : columns == 2
              ? 1.45
              : 1.35,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _buildGeneralInformation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص النظام',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _infoRow(
            'المسوقون النشطون',
            _toInt(_summary['active_marketers']).toString(),
            Icons.people_outline,
          ),
          const Divider(height: 24),
          _infoRow(
            'المنتجات النشطة',
            _toInt(_summary['active_products']).toString(),
            Icons.inventory_2_outlined,
          ),
          const Divider(height: 24),
          _infoRow(
            'منتجات وصلت للحد الأدنى للمخزون',
            _lowStockCount.toString(),
            Icons.warning_amber_outlined,
            valueColor: _lowStockCount > 0 ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E4FA3), size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTable() {
    if (_sales.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد فواتير في الفترة المحددة',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FB)),
          columns: const [
            DataColumn(label: Text('الفاتورة')),
            DataColumn(label: Text('المسوق')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('المبيعات')),
            DataColumn(label: Text('الربح')),
          ],
          rows: _sales.map((sale) {
            return DataRow(
              cells: [
                DataCell(Text('#${sale['id']}')),
                DataCell(
                  Text(
                    (sale['marketer_name'] as String?)?.trim().isNotEmpty ==
                            true
                        ? sale['marketer_name'].toString()
                        : 'غير محدد',
                  ),
                ),
                DataCell(Text(_formatDate(sale['created_at']?.toString()))),
                DataCell(Text(_money(sale['total_amount']))),
                DataCell(Text(_money(sale['total_profit']))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        drawer: const Drawer(child: Sidebar()),
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 44,
                            ),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadReport,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReport,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'التقارير المالية',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ملخص المبيعات والأرباح والعمولات والمصروفات',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildPeriodSelector(),
                            const SizedBox(height: 20),
                            _buildStatistics(),
                            const SizedBox(height: 20),
                            _buildGeneralInformation(),
                            const SizedBox(height: 24),
                            const Text(
                              'فواتير الفترة المحددة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSalesTable(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
