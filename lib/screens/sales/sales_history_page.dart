import 'package:flutter/material.dart';

import '../../database/database_helper.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const Color _primary = Color(0xFF1E4FA3);
  static const Color _darkPrimary = Color(0xFF163D80);
  static const Color _background = Color(0xFFF5F7FB);

  List<Map<String, dynamic>> get _filteredSales {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _sales;

    return _sales.where((sale) {
      final id = sale['id']?.toString().toLowerCase() ?? '';
      final marketer = sale['marketer_name']?.toString().toLowerCase() ?? '';
      final note = sale['note']?.toString().toLowerCase() ?? '';
      final date = sale['created_at']?.toString().toLowerCase() ?? '';

      return id.contains(query) ||
          marketer.contains(query) ||
          note.contains(query) ||
          date.contains(query);
    }).toList();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatNumber(double value) {
    if (!value.isFinite) return '0';

    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  String _formatMoney(dynamic value) => _formatNumber(_number(value));

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.trim().isEmpty) {
      return 'غير محدد';
    }

    final date = DateTime.tryParse(raw);

    if (date == null) return raw;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year/$month/$day  $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final db = await _databaseHelper.database;

      final rows = await db.rawQuery('''
        SELECT
          s.id,
          s.marketer_id,
          s.total_amount,
          s.total_profit,
          s.commission_amount,
          s.referral_commission_amount,
          s.referral_commission_marketer_id,
          s.note,
          s.created_at,
          m.name AS marketer_name
        FROM sales AS s
        LEFT JOIN marketers AS m ON m.id = s.marketer_id
        ORDER BY s.id DESC
      ''');

      if (!mounted) return;

      setState(() {
        _sales = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('تعذر تحميل فواتير المبيعات: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showSaleDetails(Map<String, dynamic> sale) async {
    try {
      final db = await _databaseHelper.database;

      final items = await db.rawQuery(
        '''
        SELECT
          si.id,
          si.product_id,
          si.quantity,
          si.unit_price,
          si.purchase_price,
          si.total_amount,
          si.profit,
          p.name AS product_name,
          p.code AS product_code
        FROM sale_items AS si
        LEFT JOIN products AS p ON p.id = si.product_id
        WHERE si.sale_id = ?
        ORDER BY si.id ASC
        ''',
        [sale['id']],
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final totalAmount = _number(sale['total_amount']);
          final totalProfit = _number(sale['total_profit']);
          final commission = _number(sale['commission_amount']);
          final referralCommission = _number(
            sale['referral_commission_amount'],
          );
          final afterCommissions =
              totalProfit - commission - referralCommission;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: _primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('تفاصيل الفاتورة #${sale['id']}')),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _detailLine(
                        'المسوق',
                        sale['marketer_name']?.toString() ??
                            'مسوق #${sale['marketer_id']}',
                      ),
                      _detailLine(
                        'تاريخ الفاتورة',
                        _formatDate(sale['created_at']),
                      ),
                      if ((sale['note']?.toString() ?? '').trim().isNotEmpty)
                        _detailLine('الملاحظات', sale['note'].toString()),
                      const Divider(height: 24),
                      const Text(
                        'المنتجات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'لا توجد تفاصيل منتجات مسجلة لهذه الفاتورة.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...items.map((item) {
                          final name =
                              item['product_name']?.toString() ??
                              'منتج محذوف #${item['product_id']}';
                          final quantity = _number(item['quantity']);
                          final unitPrice = _number(item['unit_price']);
                          final itemTotal = _number(item['total_amount']);
                          final code = item['product_code']?.toString() ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE4E9F2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (code.isNotEmpty)
                                  Text(
                                    'الكود: $code',
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 6,
                                  children: [
                                    Text('الكمية: ${_formatNumber(quantity)}'),
                                    Text(
                                      'سعر الوحدة: ${_formatMoney(unitPrice)}',
                                    ),
                                    Text(
                                      'الإجمالي: ${_formatMoney(itemTotal)}',
                                      style: const TextStyle(
                                        color: _primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      const Divider(height: 24),
                      _detailLine(
                        'إجمالي البيع',
                        _formatMoney(totalAmount),
                        bold: true,
                      ),
                      _detailLine(
                        'الربح قبل العمولات',
                        _formatMoney(totalProfit),
                        valueColor: totalProfit >= 0
                            ? Colors.green.shade700
                            : Colors.red,
                      ),
                      _detailLine('عمولة المسوق', _formatMoney(commission)),
                      _detailLine(
                        'عمولة التبعية',
                        _formatMoney(referralCommission),
                      ),
                      const Divider(height: 20),
                      _detailLine(
                        'الربح بعد العمولات',
                        _formatMoney(afterCommissions),
                        bold: true,
                        valueColor: afterCommissions >= 0
                            ? Colors.green.shade700
                            : Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showMessage('تعذر تحميل تفاصيل الفاتورة: $e', isError: true);
    }
  }

  Widget _detailLine(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sales = _filteredSales;

    final totalSales = sales.fold<double>(
      0,
      (sum, sale) => sum + _number(sale['total_amount']),
    );

    final totalProfit = sales.fold<double>(
      0,
      (sum, sale) => sum + _number(sale['total_profit']),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'سجل فواتير المبيعات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _isLoading ? null : _loadSales,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadSales,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildHeading(),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث برقم الفاتورة أو المسوق أو التاريخ',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح البحث',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4E9F2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE4E9F2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  'عدد الفواتير',
                                  '${sales.length}',
                                  Icons.receipt_long_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  'إجمالي البيع',
                                  _formatMoney(totalSales),
                                  Icons.payments_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  'إجمالي الربح',
                                  _formatMoney(totalProfit),
                                  Icons.trending_up,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _statCard(
                                'عدد الفواتير',
                                '${sales.length}',
                                Icons.receipt_long_outlined,
                              ),
                              const SizedBox(height: 10),
                              _statCard(
                                'إجمالي البيع',
                                _formatMoney(totalSales),
                                Icons.payments_outlined,
                              ),
                              const SizedBox(height: 10),
                              _statCard(
                                'إجمالي الربح',
                                _formatMoney(totalProfit),
                                Icons.trending_up,
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'الفواتير المسجلة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${sales.length} فاتورة',
                              style: const TextStyle(color: Colors.blueGrey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sales.isEmpty)
                          _buildEmptyState()
                        else
                          ...sales.map(_buildSaleCard),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.history, color: _primary, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل المبيعات',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                'استعرض الفواتير المحفوظة وافتح أي فاتورة لمعرفة تفاصيلها.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final id = sale['id'];
    final totalAmount = _number(sale['total_amount']);
    final totalProfit = _number(sale['total_profit']);
    final commission = _number(sale['commission_amount']);
    final referralCommission = _number(sale['referral_commission_amount']);

    final marketerName = sale['marketer_name']?.toString().trim();
    final marketerLabel = marketerName == null || marketerName.isEmpty
        ? 'مسوق #${sale['marketer_id']}'
        : marketerName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8ECF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSaleDetails(sale),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فاتورة #$id',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          marketerLabel,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: Colors.blueGrey),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _saleValue('تاريخ الفاتورة', _formatDate(sale['created_at'])),
                  _saleValue(
                    'إجمالي البيع',
                    _formatMoney(totalAmount),
                    valueColor: _primary,
                  ),
                  _saleValue(
                    'الربح',
                    _formatMoney(totalProfit),
                    valueColor: totalProfit >= 0
                        ? Colors.green.shade700
                        : Colors.red,
                  ),
                  _saleValue(
                    'العمولات',
                    _formatMoney(commission + referralCommission),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'اضغط لعرض تفاصيل الفاتورة',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saleValue(String label, String value, {Color? valueColor}) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchQuery.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        children: [
          Icon(
            searching ? Icons.search_off : Icons.receipt_long_outlined,
            size: 48,
            color: Colors.blueGrey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            searching
                ? 'لا توجد فواتير تطابق البحث'
                : 'لا توجد فواتير مبيعات حتى الآن',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            searching
                ? 'جرّب رقم فاتورة أو اسم مسوق آخر.'
                : 'ستظهر هنا الفواتير بعد حفظ أول عملية بيع.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
