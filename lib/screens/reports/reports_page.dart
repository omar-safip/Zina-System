import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

const Color _zeinaBurgundy = Color(0xFF70263D);
const Color _zeinaDarkBurgundy = Color(0xFF4D192B);
const Color _zeinaGold = Color(0xFFC5A15A);
const Color _zeinaBeige = Color(0xFFFAF5EC);
const Color _zeinaLightBeige = Color(0xFFF2E7D5);
const Color _zeinaBorder = Color(0xFFE8DCCB);

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _zeinaBurgundy,
              onPrimary: Colors.white,
              surface: _zeinaBeige,
              onSurface: _zeinaDarkBurgundy,
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _zeinaBurgundy,
              onPrimary: Colors.white,
              surface: _zeinaBeige,
              onSurface: _zeinaDarkBurgundy,
            ),
          ),
          child: child!,
        );
      },
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

  // ==================================================
  // الشريط العلوي
  // ==================================================

  Widget _buildTopBar() {
    return Builder(
      builder: (context) {
        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _zeinaBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 27),
                color: _zeinaBurgundy,
                tooltip: 'القائمة',
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'التقارير',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _zeinaDarkBurgundy,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                color: _zeinaBurgundy,
                tooltip: 'تحديث التقرير',
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================================================
  // اختيار الفترة الزمنية
  // ==================================================

  Widget _buildPeriodSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('الفترة الزمنية', Icons.calendar_month_outlined),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReportPeriod>(
            value: _period,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'حدد فترة التقرير',
              prefixIcon: Icon(Icons.date_range_rounded),
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectStartDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text('من ${_formatDate(_dateToString(_startDate))}'),
                  style: _dateButtonStyle(),
                ),
                OutlinedButton.icon(
                  onPressed: _selectEndDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text('إلى ${_formatDate(_dateToString(_endDate))}'),
                  style: _dateButtonStyle(),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _zeinaBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _zeinaBurgundy,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'من ${_formatDate(_dateToString(_effectiveStart))} '
                    'إلى ${_formatDate(_dateToString(_effectiveEnd))}',
                    style: const TextStyle(
                      color: _zeinaDarkBurgundy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _dateButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _zeinaBurgundy,
      side: const BorderSide(color: _zeinaBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  // ==================================================
  // بطاقة إحصائية
  // ==================================================

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _zeinaDarkBurgundy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _zeinaDarkBurgundy,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================================================
  // الإحصائيات
  // ==================================================

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
            icon: Icons.point_of_sale_rounded,
            color: _zeinaBurgundy,
          ),
          _buildStatCard(
            title: 'إجمالي الربح',
            value: _money(totalProfit),
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF26734D),
            subtitle: 'قبل خصم العمولات والمصروفات',
          ),
          _buildStatCard(
            title: 'العمولات الشخصية',
            value: _money(commissions),
            icon: Icons.person_outline_rounded,
            color: _zeinaGold,
          ),
          _buildStatCard(
            title: 'عمولات التبعية',
            value: _money(referralCommissions),
            icon: Icons.account_tree_outlined,
            color: const Color(0xFF77549A),
          ),
          _buildStatCard(
            title: 'المصروفات',
            value: _money(expenses),
            icon: Icons.payments_outlined,
            color: const Color(0xFFB54747),
          ),
          _buildStatCard(
            title: 'صافي الربح التقديري',
            value: _money(netProfit),
            icon: Icons.account_balance_wallet_outlined,
            color: netProfit >= 0
                ? const Color(0xFF26734D)
                : const Color(0xFFB54747),
            subtitle: 'بعد خصم العمولات والمصروفات',
          ),
          _buildStatCard(
            title: 'عدد الفواتير',
            value: salesCount.toString(),
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF64748B),
          ),
          _buildStatCard(
            title: 'متوسط الفاتورة',
            value: _money(salesCount > 0 ? totalSales / salesCount : 0),
            icon: Icons.calculate_outlined,
            color: const Color(0xFF5966A8),
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

  // ==================================================
  // ملخص النظام
  // ==================================================

  Widget _buildGeneralInformation() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('ملخص النظام', Icons.analytics_outlined),
          const SizedBox(height: 18),
          _infoRow(
            'المسوقون النشطون',
            _toInt(_summary['active_marketers']).toString(),
            Icons.people_outline_rounded,
          ),
          const Divider(height: 26, color: _zeinaBorder),
          _infoRow(
            'المنتجات النشطة',
            _toInt(_summary['active_products']).toString(),
            Icons.inventory_2_outlined,
          ),
          const Divider(height: 26, color: _zeinaBorder),
          _infoRow(
            'منتجات وصلت للحد الأدنى للمخزون',
            _lowStockCount.toString(),
            Icons.warning_amber_rounded,
            valueColor: _lowStockCount > 0
                ? const Color(0xFFB54747)
                : const Color(0xFF26734D),
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
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _zeinaLightBeige,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _zeinaBurgundy, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: _zeinaDarkBurgundy),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? _zeinaDarkBurgundy,
          ),
        ),
      ],
    );
  }

  // ==================================================
  // عنوان القسم
  // ==================================================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _zeinaLightBeige,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _zeinaBurgundy, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _zeinaDarkBurgundy,
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================
  // جدول الفواتير
  // ==================================================

  Widget _buildSalesTable() {
    if (_sales.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _zeinaBorder),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 46,
              color: _zeinaGold,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد فواتير في الفترة المحددة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _zeinaDarkBurgundy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'جرّب اختيار فترة زمنية أخرى',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zeinaBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(_zeinaLightBeige),
            headingTextStyle: const TextStyle(
              color: _zeinaDarkBurgundy,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(
              color: _zeinaDarkBurgundy,
              fontSize: 12,
            ),
            dividerThickness: 0.6,
            horizontalMargin: 16,
            columnSpacing: 22,
            columns: const [
              DataColumn(label: Text('الفاتورة')),
              DataColumn(label: Text('المسوق')),
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('المبيعات')),
              DataColumn(label: Text('الربح')),
            ],
            rows: _sales.map((sale) {
              final marketerName =
                  sale['marketer_name']?.toString().trim() ?? '';

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      '#${sale['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _zeinaBurgundy,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(marketerName.isNotEmpty ? marketerName : 'غير محدد'),
                  ),
                  DataCell(Text(_formatDate(sale['created_at']?.toString()))),
                  DataCell(Text(_money(sale['total_amount']))),
                  DataCell(Text(_money(sale['total_profit']))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // بناء الصفحة
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: baseTheme.copyWith(
          scaffoldBackgroundColor: _zeinaBeige,
          colorScheme: baseTheme.colorScheme.copyWith(
            primary: _zeinaBurgundy,
            secondary: _zeinaGold,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: _zeinaDarkBurgundy),
            prefixIconColor: _zeinaBurgundy,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _zeinaBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _zeinaBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _zeinaBurgundy, width: 1.6),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _zeinaBurgundy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        child: Scaffold(
          drawer: const Drawer(backgroundColor: _zeinaBeige, child: Sidebar()),
          body: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _zeinaBurgundy),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: _zeinaBurgundy,
                                size: 46,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _zeinaDarkBurgundy,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadReport,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: _zeinaBurgundy,
                        backgroundColor: Colors.white,
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _zeinaDarkBurgundy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ملخص المبيعات والأرباح والعمولات والمصروفات',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _buildPeriodSelector(),
                              const SizedBox(height: 20),
                              _buildStatistics(),
                              const SizedBox(height: 22),
                              _buildGeneralInformation(),
                              const SizedBox(height: 26),
                              _buildSectionTitle(
                                'فواتير الفترة المحددة',
                                Icons.receipt_long_outlined,
                              ),
                              const SizedBox(height: 14),
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
      ),
    );
  }
}
