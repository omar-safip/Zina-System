import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _outstandingInvoices = [];

  bool _isLoading = true;
  bool _isExporting = false;
  String _searchQuery = '';

  static const Color _primary = Color(0xFF70263D);
  static const Color _darkPrimary = Color(0xFF4D192B);
  static const Color _background = Color(0xFFFAF5EC);
  static const Color _zeinaGold = Color(0xFFC5A15A);
  static const Color _zeinaLightBeige = Color(0xFFF2E7D5);
  static const Color _zeinaBorder = Color(0xFFE8DCCB);

  static const String _zeinaLogoUrl =
      'https://i.ibb.co/B5PbCqKp/photo-2026-10-18-22-46-04.jpg';

  static const PdfColor _zeinaBurgundy = PdfColor.fromInt(0xFF581E2D);
  static const PdfColor _zeinaGoldPdf = PdfColor.fromInt(0xFFB09A6A);
  static const PdfColor _zeinaBeige = PdfColor.fromInt(0xFFF7F3E8);

  Map<String, dynamic>? _outstandingForSale(dynamic saleId) {
    for (final invoice in _outstandingInvoices) {
      final invoiceSaleId =
          invoice['sale_id'] ?? invoice['id'] ?? invoice['saleId'];

      if (invoiceSaleId?.toString() == saleId?.toString()) {
        return invoice;
      }
    }

    return null;
  }

  double _paidAmount(Map<String, dynamic> sale) {
    final invoice = _outstandingForSale(sale['id']);
    if (invoice != null) {
      return _number(invoice['paid_amount']);
    }
    return 0;
  }

  double _remainingAmount(Map<String, dynamic> sale) {
    final invoice = _outstandingForSale(sale['id']);
    if (invoice != null) {
      return _number(invoice['remaining_amount']);
    }
    return 0;
  }

  List<Map<String, dynamic>> get _filteredSales {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _sales;

    return _sales.where((sale) {
      final id = sale['id']?.toString().toLowerCase() ?? '';
      final marketer = sale['marketer_name']?.toString().toLowerCase() ?? '';
      final note = sale['note']?.toString().toLowerCase() ?? '';
      final date = sale['created_at']?.toString().toLowerCase() ?? '';
      final customer = sale['customer_name']?.toString().toLowerCase() ?? '';
      final phone = sale['customer_phone']?.toString().toLowerCase() ?? '';

      return id.contains(query) ||
          marketer.contains(query) ||
          note.contains(query) ||
          date.contains(query) ||
          customer.contains(query) ||
          phone.contains(query);
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

  String _paymentStatus(Map<String, dynamic> sale) {
    final status = sale['payment_status']?.toString() ?? 'legacy';

    switch (status) {
      case 'paid':
        return 'مدفوعة بالكامل';
      case 'partial':
        return 'مدفوعة جزئيًا';
      case 'unpaid':
        return 'غير مدفوعة';
      case 'legacy':
      default:
        return 'مبيعة قديمة - غير محددة التحصيل';
    }
  }

  Color _paymentStatusColor(Map<String, dynamic> sale) {
    final status = sale['payment_status']?.toString() ?? 'legacy';

    switch (status) {
      case 'paid':
        return Colors.green.shade700;
      case 'partial':
        return Colors.orange.shade800;
      case 'unpaid':
        return Colors.red.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  bool _hasInvoiceDetails(Map<String, dynamic> sale) {
    final name = sale['customer_name']?.toString().trim() ?? '';
    final phone = sale['customer_phone']?.toString().trim() ?? '';
    return name.isNotEmpty && phone.isNotEmpty;
  }

  bool _isLegacy(Map<String, dynamic> sale) {
    return sale['payment_status']?.toString() == 'legacy';
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
          s.customer_name,
          s.customer_phone,
          s.delivery_fee,
          s.payment_status,
          s.payment_updated_at,
          s.fully_paid_at,
          m.name AS marketer_name
        FROM sales AS s
        LEFT JOIN marketers AS m ON m.id = s.marketer_id
        ORDER BY s.id DESC
      ''');

      final outstanding = await _databaseHelper.getOutstandingSaleInvoices();

      if (!mounted) return;

      setState(() {
        _sales = rows;
        _outstandingInvoices = List<Map<String, dynamic>>.from(outstanding);
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

  Future<List<Map<String, dynamic>>> _loadSaleItems(
    Map<String, dynamic> sale,
  ) async {
    final db = await _databaseHelper.database;

    return db.rawQuery(
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
  }

  Future<pw.Font> _loadPdfFont() async {
    final fontData = await rootBundle.load(
      'assets/fonts/Cairo-VariableFont_slnt,wght.ttf',
    );
    return pw.Font.ttf(fontData);
  }

  Future<Uint8List?> _loadZeinaLogo() async {
    try {
      final response = await http
          .get(Uri.parse(_zeinaLogoUrl))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _prepareInvoice(Map<String, dynamic> sale) async {
    if (_isLegacy(sale) || !_hasInvoiceDetails(sale)) {
      final initialized = await _showInvoiceSetupDialog(sale);

      if (!initialized || !mounted) return;

      await _loadSales();
      if (!mounted) return;

      final updatedSale = _sales.firstWhere(
        (item) => item['id'].toString() == sale['id'].toString(),
        orElse: () => sale,
      );

      if (!_hasInvoiceDetails(updatedSale)) return;

      await _exportSalePdf(updatedSale);
      return;
    }

    await _exportSalePdf(sale);
  }

  Future<bool> _showInvoiceSetupDialog(Map<String, dynamic> sale) async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InvoiceSetupDialog(
        sale: sale,
        databaseHelper: _databaseHelper,
        number: _number,
      ),
    );

    return result ?? false;
  }

  Future<Map<String, dynamic>?> _getInvoiceData(
    Map<String, dynamic> sale,
  ) async {
    final invoice = await _databaseHelper.getSaleInvoice(sale['id'] as int);

    if (invoice == null || invoice['sale'] == null) {
      return null;
    }

    return invoice;
  }

  Future<void> _exportSalePdf(Map<String, dynamic> sale) async {
    if (_isExporting) return;

    if (!_hasInvoiceDetails(sale)) {
      _showMessage('أدخل بيانات العميل أولًا.', isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final invoice = await _getInvoiceData(sale);

      if (invoice == null) {
        throw Exception(
          'لم يتم العثور على بيانات الفاتورة. '
          'افتح إعداد الفاتورة واحفظ بيانات العميل ومبلغ الدفعة أولًا.',
        );
      }

      final items = List<Map<String, dynamic>>.from(invoice['items'] as List);
      final payments = List<Map<String, dynamic>>.from(
        invoice['payments'] as List,
      );
      final invoiceSale = Map<String, dynamic>.from(invoice['sale'] as Map);

      final cairoFont = await _loadPdfFont();
      final logoBytes = await _loadZeinaLogo();

      final pw.MemoryImage? logo = logoBytes == null
          ? null
          : pw.MemoryImage(logoBytes);

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: cairoFont, bold: cairoFont),
      );

      final saleId = invoiceSale['id']?.toString() ?? '0';
      final customerName = invoiceSale['customer_name']?.toString() ?? '';
      final customerPhone = invoiceSale['customer_phone']?.toString() ?? '';
      final saleDate = _formatDate(invoiceSale['created_at']);
      final deliveryFee = _number(invoiceSale['delivery_fee']);
      final invoiceTotal = _number(invoice['invoice_total']);
      final paidAmount = _number(invoice['paid_amount']);
      final remainingAmount = _number(invoice['remaining_amount']);
      final status = invoiceSale['payment_status']?.toString() ?? 'unpaid';
      final fullyPaidAt = invoiceSale['fully_paid_at'];

      String statusText;
      if (status == 'paid') {
        statusText = 'مدفوعة بالكامل';
      } else if (status == 'partial') {
        statusText = 'مدفوعة جزئيًا';
      } else {
        statusText = 'الدفع عند الاستلام / غير مدفوعة';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: cairoFont, bold: cairoFont),
          margin: const pw.EdgeInsets.all(30),
          footer: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _zeinaGoldPdf, width: 0.7),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ZEINA | زينة',
                  style: pw.TextStyle(
                    color: _zeinaBurgundy,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'فاتورة #$saleId  |  ${context.pageNumber}/${context.pagesCount}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: _zeinaBeige,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: _zeinaGoldPdf, width: 1),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null)
                    pw.Container(
                      width: 76,
                      height: 76,
                      margin: const pw.EdgeInsets.only(left: 14),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'زينة | ZEINA',
                          style: pw.TextStyle(
                            color: _zeinaBurgundy,
                            fontSize: 23,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'فاتورة مبيعات',
                          style: pw.TextStyle(
                            color: _zeinaBurgundy,
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'رقم الفاتورة: #$saleId',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            _pdfSectionTitle('بيانات العميل'),
            pw.SizedBox(height: 8),
            _pdfInfoRow('اسم العميل', customerName),
            _pdfInfoRow('رقم الهاتف', customerPhone),
            _pdfInfoRow('تاريخ الفاتورة', saleDate),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('تفاصيل المنتجات'),
            pw.SizedBox(height: 10),
            if (items.isEmpty)
              pw.Text('لا توجد منتجات مسجلة لهذه الفاتورة.')
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: const PdfColor.fromInt(0xFFE2D9C7),
                  width: 0.6,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3.2),
                  1: const pw.FlexColumnWidth(1.1),
                  2: const pw.FlexColumnWidth(1.6),
                  3: const pw.FlexColumnWidth(1.7),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _zeinaBeige),
                    children: [
                      _pdfCell('المنتج', header: true),
                      _pdfCell('الكمية', header: true),
                      _pdfCell('سعر الوحدة', header: true),
                      _pdfCell('الإجمالي', header: true),
                    ],
                  ),
                  ...items.map((item) {
                    final productName = item['product_name']?.toString().trim();
                    final displayName =
                        (productName == null || productName.isEmpty)
                        ? 'منتج #${item['product_id']}'
                        : productName;

                    return pw.TableRow(
                      children: [
                        _pdfCell(displayName),
                        _pdfCell(_formatNumber(_number(item['quantity']))),
                        _pdfCell(_formatMoney(item['unit_price'])),
                        _pdfCell(_formatMoney(item['total_amount'])),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 18),
            _pdfSectionTitle('ملخص الفاتورة'),
            pw.SizedBox(height: 8),
            _pdfInfoRow(
              'إجمالي المنتجات',
              _formatMoney(invoiceSale['total_amount']),
            ),
            _pdfInfoRow('رسوم التوصيل', _formatMoney(deliveryFee)),
            pw.Divider(color: _zeinaGoldPdf),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _zeinaBeige,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: _pdfInfoRow(
                'الإجمالي النهائي',
                _formatMoney(invoiceTotal),
                bold: true,
                color: _zeinaBurgundy,
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfInfoRow('المبلغ المدفوع', _formatMoney(paidAmount)),
            _pdfInfoRow(
              'المبلغ المتبقي',
              _formatMoney(remainingAmount),
              bold: true,
              color: remainingAmount > 0 ? _zeinaBurgundy : PdfColors.green800,
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _zeinaGoldPdf),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: _pdfInfoRow(
                'حالة السداد',
                statusText,
                bold: true,
                color: status == 'paid' ? PdfColors.green800 : _zeinaBurgundy,
              ),
            ),
            if (status == 'paid' && fullyPaidAt != null) ...[
              pw.SizedBox(height: 5),
              _pdfInfoRow('تاريخ إتمام السداد', _formatDate(fullyPaidAt)),
            ],
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _pdfSectionTitle('سجل الدفعات'),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: const PdfColor.fromInt(0xFFE2D9C7),
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _zeinaBeige),
                    children: [
                      _pdfCell('الدفعة', header: true),
                      _pdfCell('التاريخ', header: true),
                      _pdfCell('ملاحظة', header: true),
                    ],
                  ),
                  ...payments.map((payment) {
                    final paymentNote =
                        payment['note']?.toString().trim() ?? '';

                    return pw.TableRow(
                      children: [
                        _pdfCell(_formatMoney(payment['amount'])),
                        _pdfCell(_formatDate(payment['created_at'])),
                        _pdfCell(paymentNote.isEmpty ? '—' : paymentNote),
                      ],
                    );
                  }),
                ],
              ),
            ],
            pw.SizedBox(height: 24),
            pw.Center(
              child: pw.Text(
                status == 'paid'
                    ? 'شكرًا لثقتكم بنا. تم سداد هذه الفاتورة بالكامل.'
                    : 'شكرًا لاختياركم زينة.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: _zeinaBurgundy,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ZEINA_invoice_$saleId.pdf',
      );
    } catch (e) {
      _showMessage('تعذر إنشاء فاتورة PDF: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _zeinaBeige,
        border: pw.Border(
          right: pw.BorderSide(color: _zeinaBurgundy, width: 3),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: _zeinaBurgundy,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfInfoRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String value, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? _zeinaBurgundy : PdfColors.black,
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(Map<String, dynamic> sale) async {
    if (_isLegacy(sale) || !_hasInvoiceDetails(sale)) {
      _showMessage(
        'يجب تجهيز بيانات الفاتورة أولًا قبل تسجيل التحصيل.',
        isError: true,
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentDialog(
        sale: sale,
        databaseHelper: _databaseHelper,
        number: _number,
      ),
    );

    if (result == true && mounted) {
      await _loadSales();
      if (mounted) _showMessage('تم تسجيل الدفعة بنجاح.');
    }
  }

  Future<void> _showPaymentHistory(Map<String, dynamic> sale) async {
    try {
      final invoice = await _getInvoiceData(sale);

      if (!mounted) return;

      if (invoice == null) {
        _showMessage('لا توجد بيانات فاتورة لهذه المبيعة.', isError: true);
        return;
      }

      final payments = List<Map<String, dynamic>>.from(
        invoice['payments'] as List,
      );

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'سجل الدفعات',
            style: TextStyle(color: _darkPrimary, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 450,
            child: payments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لم يتم تسجيل أي دفعات حتى الآن.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: _zeinaBorder),
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      final note = payment['note']?.toString().trim() ?? '';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: _zeinaLightBeige,
                          child: Icon(Icons.payments_outlined, color: _primary),
                        ),
                        title: Text(
                          '${_formatMoney(payment['amount'])} ريال',
                          style: const TextStyle(
                            color: _darkPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatDate(payment['created_at'])}'
                          '${note.isEmpty ? '' : '\n$note'}',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق', style: TextStyle(color: _primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر تحميل سجل الدفعات: $e', isError: true);
      }
    }
  }

  Future<void> _showSaleDetails(Map<String, dynamic> sale) async {
    try {
      final items = await _loadSaleItems(sale);

      if (!mounted) return;

      final paid = _paidAmount(sale);
      final remaining = _remainingAmount(sale);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'تفاصيل المبيعة #${sale['id']}',
            style: const TextStyle(
              color: _darkPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailLine('المسوّق', sale['marketer_name'] ?? 'غير محدد'),
                  _detailLine('تاريخ المبيعة', _formatDate(sale['created_at'])),
                  _detailLine('العميل', sale['customer_name'] ?? 'غير مسجل'),
                  _detailLine('الهاتف', sale['customer_phone'] ?? 'غير مسجل'),
                  _detailLine(
                    'إجمالي المبيعة',
                    _formatMoney(sale['total_amount']),
                  ),
                  _detailLine(
                    'رسوم التوصيل',
                    _formatMoney(sale['delivery_fee']),
                  ),
                  _detailLine('المبلغ المدفوع', _formatMoney(paid)),
                  _detailLine('المبلغ المتبقي', _formatMoney(remaining)),
                  _detailLine('حالة السداد', _paymentStatus(sale)),
                  if ((sale['note']?.toString().trim() ?? '').isNotEmpty)
                    _detailLine('ملاحظات', sale['note']),
                  const SizedBox(height: 16),
                  const Text(
                    'المنتجات',
                    style: TextStyle(
                      color: _darkPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text('لا توجد تفاصيل للمنتجات.')
                  else
                    ...items.map((item) {
                      final productName = item['product_name']
                          ?.toString()
                          .trim();
                      final name = (productName == null || productName.isEmpty)
                          ? 'منتج #${item['product_id']}'
                          : productName;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _zeinaBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${_formatNumber(_number(item['quantity']))}'
                              ' × ${_formatMoney(item['unit_price'])}',
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatMoney(item['total_amount']),
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق', style: TextStyle(color: _primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage('تعذر عرض تفاصيل المبيعة: $e', isError: true);
      }
    }
  }

  Widget _detailLine(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'غير محدد',
              style: const TextStyle(
                color: _darkPrimary,
                fontWeight: FontWeight.w600,
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        drawer: const Drawer(backgroundColor: _background, child: Sidebar()),
        appBar: AppBar(
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.white,
          title: const Text(
            'سجل فواتير المبيعات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _isLoading ? null : _loadSales,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: _primary,
          onRefresh: _loadSales,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeading(),
                    const SizedBox(height: 16),
                    if (_outstandingInvoices.isNotEmpty)
                      _buildCollectionAlert(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText:
                            'ابحث برقم الفاتورة أو اسم العميل أو المسوّق...',
                        prefixIcon: const Icon(Icons.search, color: _primary),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _zeinaBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _zeinaBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: _primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statCard(
                          'عدد المبيعات',
                          '${_sales.length}',
                          Icons.receipt_long_outlined,
                        ),
                        _statCard(
                          'إجمالي المبيعات',
                          _formatMoney(
                            _sales.fold<double>(
                              0,
                              (sum, sale) =>
                                  sum + _number(sale['total_amount']),
                            ),
                          ),
                          Icons.account_balance_wallet_outlined,
                        ),
                        _statCard(
                          'الفواتير غير المسددة',
                          '${_outstandingInvoices.length}',
                          Icons.pending_actions_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (sales.isEmpty)
                      _buildEmptyState()
                    else
                      ...sales.map(_buildSaleCard),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCollectionAlert() {
    final outstandingTotal = _outstandingInvoices.fold<double>(
      0,
      (sum, invoice) => sum + _number(invoice['remaining_amount']),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _zeinaLightBeige,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zeinaGold),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: _darkPrimary,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'توجد مبالغ متبقية للتحصيل',
                  style: TextStyle(
                    color: _darkPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_outstandingInvoices.length} فاتورة غير مسددة بالكامل',
                  style: const TextStyle(color: _darkPrimary),
                ),
              ],
            ),
          ),
          Text(
            _formatMoney(outstandingTotal),
            style: const TextStyle(
              color: _darkPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _zeinaLightBeige,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: _primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سجل المبيعات والفواتير',
                style: TextStyle(
                  color: _darkPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'عرض الفواتير ومتابعة التحصيل والدفعات',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: _darkPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final paid = _paidAmount(sale);
    final remaining = _remainingAmount(sale);
    final legacy = _isLegacy(sale);
    final statusColor = _paymentStatusColor(sale);
    final customerName = sale['customer_name']?.toString().trim() ?? '';
    final customerPhone = sale['customer_phone']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zeinaBorder),
        boxShadow: [
          BoxShadow(
            color: _darkPrimary..withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _zeinaLightBeige,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فاتورة #${sale['id']}',
                        style: const TextStyle(
                          color: _darkPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(sale['created_at']),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor..withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _paymentStatus(sale),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: _zeinaBorder),
            _saleValue('المسوّق', sale['marketer_name'] ?? 'غير محدد'),
            if (customerName.isNotEmpty) _saleValue('العميل', customerName),
            if (customerPhone.isNotEmpty)
              _saleValue('رقم العميل', customerPhone),
            _saleValue(
              'إجمالي المبيعة',
              '${_formatMoney(sale['total_amount'])} ريال',
            ),
            if (!legacy) ...[
              _saleValue('المبلغ المدفوع', '${_formatMoney(paid)} ريال'),
              _saleValue(
                'المبلغ المتبقي',
                '${_formatMoney(remaining)} ريال',
                valueColor: remaining > 0 ? _primary : Colors.green.shade700,
              ),
            ],
            if ((sale['note']?.toString().trim() ?? '').isNotEmpty)
              _saleValue('ملاحظات', sale['note']),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSaleDetails(sale),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('التفاصيل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _zeinaBorder),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _prepareInvoice(sale),
                  icon: Icon(
                    _isExporting
                        ? Icons.hourglass_empty
                        : Icons.picture_as_pdf_outlined,
                    size: 18,
                  ),
                  label: const Text('فاتورة PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _zeinaBorder),
                  ),
                ),
                if (!legacy && remaining > 0)
                  ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(sale),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('تسجيل تحصيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (!legacy)
                  OutlinedButton.icon(
                    onPressed: () => _showPaymentHistory(sale),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('سجل الدفعات'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _zeinaBorder),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _saleValue(String label, dynamic value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'غير محدد',
              style: TextStyle(
                color: valueColor ?? _darkPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 55, color: _zeinaGold),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? 'لا توجد مبيعات مسجلة حتى الآن'
                : 'لا توجد نتائج مطابقة للبحث',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _darkPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ستظهر الفواتير هنا بعد تسجيل المبيعات.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _InvoiceSetupDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final DatabaseHelper databaseHelper;
  final double Function(dynamic) number;

  const _InvoiceSetupDialog({
    required this.sale,
    required this.databaseHelper,
    required this.number,
  });

  @override
  State<_InvoiceSetupDialog> createState() => _InvoiceSetupDialogState();
}

class _InvoiceSetupDialogState extends State<_InvoiceSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _deliveryFeeController;
  late final TextEditingController _initialPaymentController;

  bool _isSaving = false;

  static const Color _primary = Color(0xFF70263D);
  static const Color _darkPrimary = Color(0xFF4D192B);
  static const Color _background = Color(0xFFFAF5EC);

  @override
  void initState() {
    super.initState();

    _customerNameController = TextEditingController(
      text: widget.sale['customer_name']?.toString() ?? '',
    );
    _customerPhoneController = TextEditingController(
      text: widget.sale['customer_phone']?.toString() ?? '',
    );
    _deliveryFeeController = TextEditingController(
      text: widget.number(widget.sale['delivery_fee']).toString(),
    );
    _initialPaymentController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deliveryFeeController.dispose();
    _initialPaymentController.dispose();
    super.dispose();
  }

  double _parseAmount(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final deliveryFee = _parseAmount(_deliveryFeeController.text);
    final initialPayment = _parseAmount(_initialPaymentController.text);

    if (deliveryFee < 0 || initialPayment < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يمكن إدخال مبلغ سالب.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.databaseHelper.setSaleInvoiceDetails(
        saleId: widget.sale['id'] as int,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        deliveryFee: deliveryFee,
        initialPayment: initialPayment,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ بيانات الفاتورة: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'تجهيز فاتورة العميل',
          style: TextStyle(color: _darkPrimary, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم العميل',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل اسم العميل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف العميل',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل رقم هاتف العميل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deliveryFeeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'رسوم التوصيل',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount < 0) {
                        return 'أدخل رسوم توصيل صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _initialPaymentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المدفوع الآن',
                      helperText: 'اكتب صفرًا إذا لم يستلم أي مبلغ.',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount < 0) {
                        return 'أدخل مبلغًا صحيحًا';
                      }

                      final total =
                          widget.number(widget.sale['total_amount']) +
                          _parseAmount(_deliveryFeeController.text);

                      if (amount > total) {
                        return 'الدفعة أكبر من إجمالي الفاتورة';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'سيتم إنشاء الفاتورة وحساب المتبقي بناءً على إجمالي المبيعة ورسوم التوصيل والدفعة الأولية.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('حفظ وتجهيز الفاتورة'),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final Map<String, dynamic> sale;
  final DatabaseHelper databaseHelper;
  final double Function(dynamic) number;

  const _PaymentDialog({
    required this.sale,
    required this.databaseHelper,
    required this.number,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSaving = false;

  static const Color _primary = Color(0xFF70263D);
  static const Color _darkPrimary = Color(0xFF4D192B);
  static const Color _background = Color(0xFFFAF5EC);

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    setState(() => _isSaving = true);

    try {
      await widget.databaseHelper.addSalePayment(
        saleId: widget.sale['id'] as int,
        amount: amount,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تسجيل الدفعة: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'تسجيل تحصيل',
          style: TextStyle(color: _darkPrimary, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ التحصيل',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');

                    if (amount == null || amount <= 0) {
                      return 'أدخل مبلغًا أكبر من صفر';
                    }

                    final remaining = widget.number(
                      widget.sale['total_amount'],
                    );

                    if (amount > remaining) {
                      return 'المبلغ أكبر من إجمالي المبيعة';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('حفظ الدفعة'),
          ),
        ],
      ),
    );
  }
}
