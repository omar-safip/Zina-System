import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

class MarketerReportPage extends StatefulWidget {
  final int marketerId;
  final String marketerName;

  const MarketerReportPage({
    super.key,
    required this.marketerId,
    required this.marketerName,
  });

  @override
  State<MarketerReportPage> createState() => _MarketerReportPageState();
}

class _MarketerReportPageState extends State<MarketerReportPage> {
  static const Color _primary = Color(0xFF70263D);
  static const Color _darkPrimary = Color(0xFF542033);
  static const Color _gold = Color(0xFFC5A15A);
  static const Color _background = Color(0xFFFAF5EC);
  static const Color _softBeige = Color(0xFFF5EBDD);
  static const Color _border = Color(0xFFE8DCCB);

  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  Map<String, dynamic>? _marketer;
  List<Map<String, dynamic>> _ownSales = [];
  List<Map<String, dynamic>> _referralSales = [];

  double _totalSales = 0;
  double _totalProfit = 0;
  double _personalCommission = 0;
  double _referralCommission = 0;
  double _deliveryFees = 0;

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _money(dynamic value) {
    return NumberFormat('#,##0.00', 'en_US').format(_toDouble(value));
  }

  String _date(dynamic value) {
    if (value == null || value.toString().isEmpty) return '-';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    return DateFormat('yyyy/MM/dd - HH:mm').format(parsed);
  }

  String _invoiceNumber(Map<String, dynamic> sale) {
    return sale['id']?.toString() ?? '-';
  }

  String _customerName(Map<String, dynamic> sale) {
    final name = sale['customer_name']?.toString().trim() ?? '';
    return name.isEmpty ? 'عميل غير مسجل' : name;
  }

  double _invoiceTotal(Map<String, dynamic> sale) {
    return _toDouble(sale['total_amount']) + _toDouble(sale['delivery_fee']);
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
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

      final marketerRows = await db.rawQuery(
        '''
        SELECT
          m.*,
          (
            SELECT c.code
            FROM codes c
            WHERE c.marketer_id = m.id
              AND c.is_active = 1
            ORDER BY c.id DESC
            LIMIT 1
          ) AS code,
          parent.name AS parent_name
        FROM marketers m
        LEFT JOIN marketers parent ON parent.id = m.parent_id
        WHERE m.id = ?
        LIMIT 1
        ''',
        [widget.marketerId],
      );

      if (marketerRows.isEmpty) {
        throw Exception('لم يتم العثور على بيانات هذا المسوق');
      }

      final ownSales = await db.query(
        'sales',
        where: 'marketer_id = ?',
        whereArgs: [widget.marketerId],
        orderBy: 'created_at DESC, id DESC',
      );

      final referralSales = await db.query(
        'sales',
        where: 'referral_commission_marketer_id = ?',
        whereArgs: [widget.marketerId],
        orderBy: 'created_at DESC, id DESC',
      );

      // تحميل المنتجات لكل فاتورة دون تكرار إجمالي الفاتورة.
      final preparedOwnSales = <Map<String, dynamic>>[];

      for (final sale in ownSales) {
        final saleId = _toInt(sale['id']);

        final items = await db.rawQuery(
          '''
          SELECT
            sale_items.id,
            sale_items.product_id,
            sale_items.quantity,
            sale_items.unit_price,
            sale_items.purchase_price,
            sale_items.total_amount,
            sale_items.profit,
            products.name AS product_name
          FROM sale_items
          LEFT JOIN products ON products.id = sale_items.product_id
          WHERE sale_items.sale_id = ?
          ORDER BY sale_items.id ASC
          ''',
          [saleId],
        );

        preparedOwnSales.add({...sale, '_items': items});
      }

      final preparedReferralSales = referralSales.map((sale) {
        return Map<String, dynamic>.from(sale);
      }).toList();

      double totalSales = 0;
      double totalProfit = 0;
      double personalCommission = 0;
      double referralCommission = 0;
      double deliveryFees = 0;

      // كل فاتورة تُحسب مرة واحدة من جدول sales.
      for (final sale in preparedOwnSales) {
        totalSales += _toDouble(sale['total_amount']);
        totalProfit += _toDouble(sale['total_profit']);
        personalCommission += _toDouble(sale['commission_amount']);
        deliveryFees += _toDouble(sale['delivery_fee']);
      }

      // عمولات التبعية مستقلة عن مبيعات المسوق الشخصية.
      for (final sale in preparedReferralSales) {
        referralCommission += _toDouble(sale['referral_commission_amount']);
      }

      if (!mounted) return;

      setState(() {
        _marketer = marketerRows.first;
        _ownSales = preparedOwnSales;
        _referralSales = preparedReferralSales;
        _totalSales = totalSales;
        _totalProfit = totalProfit;
        _personalCommission = personalCommission;
        _referralCommission = referralCommission;
        _deliveryFees = deliveryFees;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_marketer == null || _isExporting) return;

    setState(() => _isExporting = true);

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/Cairo-VariableFont_slnt,wght.ttf',
      );

      final arabicFont = pw.Font.ttf(fontData);
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
      );

      final marketer = _marketer!;
      final reportDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

      final ownInvoiceRows = <List<String>>[
        [
          'رقم الفاتورة',
          'التاريخ',
          'العميل',
          'إجمالي المنتجات',
          'التوصيل',
          'العمولة',
        ],
        ..._ownSales.map((sale) {
          return [
            _invoiceNumber(sale),
            _date(sale['created_at']),
            _customerName(sale),
            _money(sale['total_amount']),
            _money(sale['delivery_fee']),
            _money(sale['commission_amount']),
          ];
        }),
      ];

      final referralRows = <List<String>>[
        [
          'رقم الفاتورة',
          'التاريخ',
          'مسوق البيع',
          'قيمة المنتجات',
          'عمولة التبعية',
        ],
        ..._referralSales.map((sale) {
          return [
            _invoiceNumber(sale),
            _date(sale['created_at']),
            sale['marketer_id']?.toString() ?? '-',
            _money(sale['total_amount']),
            _money(sale['referral_commission_amount']),
          ];
        }),
      ];

      final summaryRows = <List<String>>[
        ['البيان', 'القيمة'],
        ['عدد الفواتير الشخصية', '${_ownSales.length}'],
        ['إجمالي قيمة المنتجات المباعة', _money(_totalSales)],
        ['إجمالي رسوم التوصيل', _money(_deliveryFees)],
        ['إجمالي ربح المبيعات قبل العمولات', _money(_totalProfit)],
        ['العمولة الشخصية المستحقة المسجلة', _money(_personalCommission)],
        ['عدد فواتير عمولات التبعية', '${_referralSales.length}'],
        ['عمولات التبعية المستحقة المسجلة', _money(_referralCommission)],
        [
          'إجمالي العمولات المسجلة',
          _money(_personalCommission + _referralCommission),
        ],
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
          build: (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'تقرير حساب المسوق',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#542033'),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'تاريخ إصدار التقرير: $reportDate',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: arabicFont, fontSize: 9),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#C5A15A')),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfText(
                          'اسم المسوق: ${marketer['name'] ?? '-'}',
                          arabicFont,
                          bold: true,
                        ),
                        _pdfText(
                          'رقم المسوق: ${marketer['id'] ?? '-'}',
                          arabicFont,
                        ),
                        _pdfText(
                          'رقم الهاتف: ${marketer['phone'] ?? '-'}',
                          arabicFont,
                        ),
                        _pdfText(
                          'الكود: ${marketer['code'] ?? '-'}',
                          arabicFont,
                        ),
                        _pdfText(
                          'المسوق الأب: ${marketer['parent_name'] ?? 'بدون'}',
                          arabicFont,
                        ),
                        _pdfText(
                          'نسبة العمولة الحالية: '
                          '${_money(marketer['commission_rate'])}%',
                          arabicFont,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  _pdfHeading('الملخص المالي', arabicFont),
                  _pdfTable(summaryRows, arabicFont),
                  pw.SizedBox(height: 18),
                  _pdfHeading('فواتير المبيعات الشخصية', arabicFont),
                  pw.Text(
                    'إجمالي المبيعات هنا يشمل قيمة المنتجات فقط؛ '
                    'وتظهر رسوم التوصيل في عمود مستقل. '
                    'كل فاتورة تظهر مرة واحدة.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  _pdfTable(ownInvoiceRows, arabicFont),
                  pw.SizedBox(height: 18),
                  _pdfHeading('عمولات التبعية المستحقة', arabicFont),
                  pw.Text(
                    'هذا القسم يعرض الفواتير التي سُجل للمسوق فيها '
                    'استحقاق عمولة تبعية، بصورة منفصلة عن مبيعاته الشخصية.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  _pdfTable(referralRows, arabicFont),
                  pw.SizedBox(height: 14),
                  pw.Divider(),
                  pw.Text(
                    'تم إعداد التقرير من البيانات المحفوظة في النظام. '
                    'العمولات المعروضة هي القيم المسجلة في الفواتير وقت البيع.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'marketer_report_${widget.marketerId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء التقرير: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  pw.Widget _pdfText(String text, pw.Font font, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfHeading(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#70263D'),
        ),
      ),
    );
  }

  pw.Widget _pdfTable(List<List<String>> rows, pw.Font font) {
    if (rows.length <= 1) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text(
          'لا توجد بيانات مسجلة.',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      data: rows,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5EBDD')),
      headerStyle: pw.TextStyle(
        font: font,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#542033'),
      ),
      cellStyle: pw.TextStyle(font: font, fontSize: 7),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#E8DCCB'),
        width: 0.5,
      ),
      cellPadding: const pw.EdgeInsets.all(4),
      headerCount: 1,
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    Color color = _primary,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.brown.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _darkPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _darkPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnSaleCard(Map<String, dynamic> sale) {
    final items =
        (sale['_items'] as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'فاتورة رقم ${_invoiceNumber(sale)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _darkPrimary,
                    ),
                  ),
                ),
                Text(
                  _money(_invoiceTotal(sale)),
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('العميل: ${_customerName(sale)}'),
            Text('التاريخ: ${_date(sale['created_at'])}'),
            Text('قيمة المنتجات: ${_money(sale['total_amount'])}'),
            Text('رسوم التوصيل: ${_money(sale['delivery_fee'])}'),
            Text('الربح المسجل: ${_money(sale['total_profit'])}'),
            Text(
              'العمولة الشخصية: ${_money(sale['commission_amount'])}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (items.isNotEmpty) ...[
              const Divider(height: 20, color: _border),
              const Text(
                'المنتجات:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _darkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              ...items.map((item) {
                final productName =
                    item['product_name']?.toString() ?? 'منتج غير متاح';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $productName | '
                    'الكمية: ${_money(item['quantity'])} | '
                    'الإجمالي: ${_money(item['total_amount'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> sale) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: _softBeige,
          child: Icon(Icons.account_tree_outlined, color: _primary),
        ),
        title: Text(
          'فاتورة رقم ${_invoiceNumber(sale)}',
          style: const TextStyle(
            color: _darkPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'التاريخ: ${_date(sale['created_at'])}\n'
          'رقم مسوق البيع: ${sale['marketer_id'] ?? '-'}\n'
          'قيمة المنتجات: ${_money(sale['total_amount'])}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('عمولة التبعية', style: TextStyle(fontSize: 10)),
            Text(
              _money(sale['referral_commission_amount']),
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketer = _marketer;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _primary,
            secondary: _gold,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: _background,
          appBarTheme: const AppBarTheme(
            backgroundColor: _darkPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: _primary,
          ),
        ),
        child: Scaffold(
          backgroundColor: _background,
          drawer: const Drawer(child: Sidebar()),
          appBar: AppBar(
            title: const Text(
              'تقرير المسوق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _darkPrimary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'تحديث التقرير',
                onPressed: _isLoading ? null : _loadReport,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _isLoading
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
                          size: 48,
                          color: Colors.red,
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
                  color: _primary,
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Card(
                        color: _softBeige,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: _border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _primary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _gold, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      marketer?['name']?.toString() ??
                                          widget.marketerName,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: _darkPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'رقم المسوق: '
                                      '${marketer?['id'] ?? widget.marketerId}',
                                    ),
                                    Text(
                                      'الهاتف: ${marketer?['phone'] ?? '-'}',
                                    ),
                                    Text('الكود: ${marketer?['code'] ?? '-'}'),
                                    Text(
                                      'المسوق الأب: '
                                      '${marketer?['parent_name'] ?? 'بدون'}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _sectionTitle('الملخص المالي', Icons.analytics_outlined),
                      _summaryCard(
                        title: 'عدد فواتير المبيعات الشخصية',
                        value: '${_ownSales.length}',
                        icon: Icons.receipt_long_outlined,
                      ),
                      _summaryCard(
                        title: 'إجمالي قيمة المنتجات المباعة',
                        value: _money(_totalSales),
                        icon: Icons.point_of_sale_outlined,
                      ),
                      _summaryCard(
                        title: 'إجمالي رسوم التوصيل',
                        value: _money(_deliveryFees),
                        icon: Icons.local_shipping_outlined,
                        color: _gold,
                      ),
                      _summaryCard(
                        title: 'إجمالي ربح المبيعات قبل العمولات',
                        value: _money(_totalProfit),
                        icon: Icons.trending_up_outlined,
                        color: Colors.teal,
                      ),
                      _summaryCard(
                        title: 'العمولة الشخصية المسجلة',
                        value: _money(_personalCommission),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.green,
                      ),
                      _summaryCard(
                        title: 'عمولات التبعية المسجلة',
                        value: _money(_referralCommission),
                        icon: Icons.account_tree_outlined,
                        color: _primary,
                      ),
                      _summaryCard(
                        title: 'إجمالي العمولات المسجلة',
                        value: _money(
                          _personalCommission + _referralCommission,
                        ),
                        icon: Icons.summarize_outlined,
                        color: _gold,
                      ),
                      _sectionTitle(
                        'فواتير المبيعات الشخصية (${_ownSales.length})',
                        Icons.receipt_long_outlined,
                      ),
                      if (_ownSales.isEmpty)
                        const Card(
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'لا توجد فواتير مبيعات شخصية لهذا المسوق.',
                            ),
                          ),
                        )
                      else
                        ..._ownSales.map(_buildOwnSaleCard),
                      _sectionTitle(
                        'عمولات التبعية (${_referralSales.length})',
                        Icons.account_tree_outlined,
                      ),
                      if (_referralSales.isEmpty)
                        const Card(
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'لا توجد عمولات تبعية مسجلة لهذا المسوق.',
                            ),
                          ),
                        )
                      else
                        ..._referralSales.map(_buildReferralCard),
                      const SizedBox(height: 16),
                      Text(
                        'ملاحظة: العمولة الشخصية وعمولة التبعية معروضتان '
                        'بشكل منفصل وفق القيم المسجلة في الفواتير وقت البيع.',
                        style: TextStyle(
                          color: Colors.brown.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: !_isLoading && _error == null
              ? SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportPdf,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _isExporting
                          ? 'جارٍ تجهيز التقرير...'
                          : 'تصدير التقرير PDF / معاينة الطباعة',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
