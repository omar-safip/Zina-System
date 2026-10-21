import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _selectedCategory = 'marketers';
  late Future<Map<String, List<Map<String, dynamic>>>> _archiveFuture;

  // ألوان هوية زينة | ZEINA.
  static const Color _primary = Color(0xFF722F37);
  static const Color _gold = Color(0xFFC5A46D);
  static const Color _background = Color(0xFFFAF7F2);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE8DDD5);
  static const Color _lightPrimary = Color(0xFFF3E8E7);
  static const Color _lightGold = Color(0xFFF7F0E3);

  final List<Map<String, String>> _categories = const [
    {'value': 'marketers', 'label': 'المسوقون المعطّلون'},
    {'value': 'codes', 'label': 'الأرقام والأكواد المعطّلة'},
    {'value': 'products', 'label': 'المنتجات المعطّلة'},
    {'value': 'sales', 'label': 'سجل المبيعات'},
    {'value': 'orders', 'label': 'سجل الطلبات'},
    {'value': 'expenses', 'label': 'سجل المصروفات'},
    {'value': 'audit', 'label': 'سجل التدقيق'},
  ];

  @override
  void initState() {
    super.initState();
    _archiveFuture = _loadArchiveData();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadArchiveData() async {
    final db = await _databaseHelper.database;

    final marketers = await db.rawQuery('''
      SELECT
        m.id,
        m.name,
        m.phone,
        m.parent_id,
        m.commission_rate,
        m.is_active,
        m.created_at,
        m.updated_at,
        c.marketer_number,
        c.code
      FROM marketers m
      LEFT JOIN codes c ON c.marketer_id = m.id
      WHERE m.is_active = 0
      ORDER BY m.updated_at DESC, m.id DESC
    ''');

    final codes = await db.query(
      'codes',
      where: 'is_active = 0',
      orderBy: 'created_at DESC, id DESC',
    );

    final products = await db.query(
      'products',
      where: 'is_active = 0',
      orderBy: 'updated_at DESC, id DESC',
    );

    final sales = await db.rawQuery('''
      SELECT
        s.id,
        s.marketer_id,
        s.total_amount,
        s.total_profit,
        s.commission_amount,
        s.referral_commission_amount,
        s.note,
        s.created_at,
        m.name AS marketer_name
      FROM sales s
      LEFT JOIN marketers m ON m.id = s.marketer_id
      ORDER BY s.created_at DESC, s.id DESC
    ''');

    final orders = await db.query(
      'orders',
      orderBy: 'created_at DESC, id DESC',
    );

    final expenses = await db.query(
      'expenses',
      orderBy: 'created_at DESC, id DESC',
    );

    final auditLogs = await db.query(
      'audit_logs',
      orderBy: 'created_at DESC, id DESC',
      limit: 200,
    );

    return {
      'marketers': marketers,
      'codes': codes,
      'products': products,
      'sales': sales,
      'orders': orders,
      'expenses': expenses,
      'audit': auditLogs,
    };
  }

  Future<void> _refreshArchive() async {
    setState(() {
      _archiveFuture = _loadArchiveData();
    });

    await _archiveFuture;
  }

  Future<void> _restoreMarketer(Map<String, dynamic> marketer) async {
    final marketerId = marketer['id'] as int;
    final name = (marketer['name'] ?? 'بدون اسم').toString();

    final confirmed = await _confirmRestore(
      title: 'استعادة المسوق',
      message:
          'هل تريد إعادة تفعيل المسوق "$name"؟\n'
          'لن يُربط به رقم أو كود تلقائيًا.',
    );

    if (!confirmed || !mounted) return;

    try {
      final db = await _databaseHelper.database;

      await db.transaction((txn) async {
        await txn.update(
          'marketers',
          {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ? AND is_active = 0',
          whereArgs: [marketerId],
        );

        await txn.insert('audit_logs', {
          'action': 'restore',
          'entity_type': 'marketer',
          'entity_id': marketerId,
          'description': 'تمت استعادة تفعيل المسوق: $name',
          'old_values': '{"is_active":0}',
          'new_values': '{"is_active":1}',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      await _refreshArchive();
      _showMessage('تمت إعادة تفعيل المسوق بنجاح');
    } catch (error) {
      _showMessage('تعذرت استعادة المسوق: $error', isError: true);
    }
  }

  Future<void> _restoreCode(Map<String, dynamic> codeRow) async {
    final codeId = codeRow['id'] as int;
    final marketerNumber = codeRow['marketer_number'];
    final code = (codeRow['code'] ?? '').toString();

    if (codeRow['marketer_id'] != null) {
      _showMessage(
        'لا يمكن استعادة هذا الكود لأنه مرتبط بمسوق.',
        isError: true,
      );
      return;
    }

    final confirmed = await _confirmRestore(
      title: 'استعادة الرقم والكود',
      message: 'هل تريد إعادة تفعيل الرقم $marketerNumber والكود $code؟',
    );

    if (!confirmed || !mounted) return;

    try {
      final db = await _databaseHelper.database;

      await db.transaction((txn) async {
        final rows = await txn.query(
          'codes',
          where: 'id = ? AND is_active = 0 AND marketer_id IS NULL',
          whereArgs: [codeId],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw Exception('الرقم غير متاح للاستعادة أو تم تغييره.');
        }

        await txn.update(
          'codes',
          {'is_active': 1},
          where: 'id = ?',
          whereArgs: [codeId],
        );

        await txn.insert('audit_logs', {
          'action': 'restore',
          'entity_type': 'code',
          'entity_id': codeId,
          'description': 'تمت استعادة الرقم $marketerNumber والكود $code',
          'old_values': '{"is_active":0}',
          'new_values': '{"is_active":1}',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      await _refreshArchive();
      _showMessage('تمت استعادة الرقم والكود بنجاح');
    } catch (error) {
      _showMessage('تعذرت استعادة الرقم والكود: $error', isError: true);
    }
  }

  Future<void> _restoreProduct(Map<String, dynamic> product) async {
    final productId = product['id'] as int;
    final name = (product['name'] ?? 'بدون اسم').toString();

    final confirmed = await _confirmRestore(
      title: 'استعادة المنتج',
      message: 'هل تريد إعادة تفعيل المنتج "$name"؟',
    );

    if (!confirmed || !mounted) return;

    try {
      final db = await _databaseHelper.database;

      await db.transaction((txn) async {
        final rows = await txn.query(
          'products',
          where: 'id = ? AND is_active = 0',
          whereArgs: [productId],
          limit: 1,
        );

        if (rows.isEmpty) {
          throw Exception('المنتج غير موجود أو تم تفعيله مسبقًا.');
        }

        await txn.update(
          'products',
          {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [productId],
        );

        await txn.insert('audit_logs', {
          'action': 'restore',
          'entity_type': 'product',
          'entity_id': productId,
          'description': 'تمت استعادة تفعيل المنتج: $name',
          'old_values': '{"is_active":0}',
          'new_values': '{"is_active":1}',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      await _refreshArchive();
      _showMessage('تمت استعادة المنتج بنجاح');
    } catch (error) {
      _showMessage('تعذرت استعادة المنتج: $error', isError: true);
    }
  }

  Future<bool> _confirmRestore({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(color: _primary),
        ),
        content: Text(message, textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(color: _primary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: isError ? Colors.red.shade700 : _primary,
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    if (value is num) {
      return value % 1 == 0
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
    }
    return value.toString();
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'غير محدد';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    final date = parsed.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        drawer: const Drawer(child: Sidebar()),
        appBar: AppBar(
          title: const Text(
            'الأرشيف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'تحديث الأرشيف',
              onPressed: _refreshArchive,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _archiveFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }

            if (snapshot.hasError) {
              return _errorView(snapshot.error.toString());
            }

            final data = snapshot.data;

            if (data == null) {
              return _errorView('تعذر تحميل بيانات الأرشيف.');
            }

            final rows = data[_selectedCategory] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIntro(data),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'قسم الأرشيف',
                      labelStyle: const TextStyle(color: _primary),
                      prefixIcon: const Icon(
                        Icons.folder_open_outlined,
                        color: _primary,
                      ),
                      filled: true,
                      fillColor: _surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _gold, width: 1.5),
                      ),
                    ),
                    items: _categories.map((category) {
                      final key = category['value']!;
                      final count = data[key]?.length ?? 0;

                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text('${category['label']} ($count)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? _emptyView()
                      : RefreshIndicator(
                          color: _primary,
                          onRefresh: _refreshArchive,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildRecordCard(
                                _selectedCategory,
                                rows[index],
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro(Map<String, List<Map<String, dynamic>>> data) {
    final inactiveCount =
        (data['marketers']?.length ?? 0) +
        (data['codes']?.length ?? 0) +
        (data['products']?.length ?? 0);

    final historyCount =
        (data['sales']?.length ?? 0) +
        (data['orders']?.length ?? 0) +
        (data['expenses']?.length ?? 0) +
        (data['audit']?.length ?? 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.archive_outlined, color: _primary, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'السجلات المعطّلة والتاريخية',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'استعرض السجلات السابقة، واستعد العناصر المعطّلة التي تسمح '
            'قاعدة البيانات بإعادة تفعيلها. السجلات التاريخية للقراءة فقط.',
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  'عناصر معطّلة',
                  inactiveCount,
                  Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  'سجلات تاريخية',
                  historyCount,
                  Icons.history,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _lightGold,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String category, Map<String, dynamic> row) {
    switch (category) {
      case 'marketers':
        return _recordCard(
          icon: Icons.person_off_outlined,
          title: (row['name'] ?? 'مسوق بدون اسم').toString(),
          subtitle: [
            if (row['phone'] != null && row['phone'].toString().isNotEmpty)
              'الهاتف: ${row['phone']}',
            if (row['marketer_number'] != null)
              'رقم المسوق: ${row['marketer_number']}',
            if (row['code'] != null) 'الكود: ${row['code']}',
            'العمولة: ${_formatNumber(row['commission_rate'])}%',
            'تاريخ التعديل: ${_formatDate(row['updated_at'])}',
          ].join('\n'),
          actionLabel: 'استعادة',
          actionIcon: Icons.restore,
          onAction: () => _restoreMarketer(row),
        );

      case 'codes':
        final isUnassigned = row['marketer_id'] == null;

        return _recordCard(
          icon: Icons.qr_code_2,
          title: 'رقم ${row['marketer_number']}',
          subtitle: [
            'الكود: ${row['code']}',
            'تاريخ الإنشاء: ${_formatDate(row['created_at'])}',
            isUnassigned ? 'الحالة: غير مرتبط بمسوق' : 'الحالة: مرتبط بمسوق',
          ].join('\n'),
          actionLabel: isUnassigned ? 'استعادة' : 'غير متاح',
          actionIcon: isUnassigned ? Icons.restore : Icons.lock_outline,
          onAction: isUnassigned ? () => _restoreCode(row) : null,
        );

      case 'products':
        return _recordCard(
          icon: Icons.inventory_2_outlined,
          title: (row['name'] ?? 'منتج بدون اسم').toString(),
          subtitle: [
            'رمز المنتج: ${row['code'] ?? 'غير محدد'}',
            'سعر البيع: ${_formatNumber(row['selling_price'])}',
            'الكمية بالمخزون: ${_formatNumber(row['stock_quantity'])}',
            'تاريخ التعديل: ${_formatDate(row['updated_at'])}',
          ].join('\n'),
          actionLabel: 'استعادة',
          actionIcon: Icons.restore,
          onAction: () => _restoreProduct(row),
        );

      case 'sales':
        return _recordCard(
          icon: Icons.point_of_sale_outlined,
          title: 'فاتورة مبيعات رقم ${row['id']}',
          subtitle: [
            'المسوق: ${row['marketer_name'] ?? 'غير مرتبط بمسوق'}',
            'إجمالي البيع: ${_formatNumber(row['total_amount'])}',
            'الربح: ${_formatNumber(row['total_profit'])}',
            'عمولة المسوق: ${_formatNumber(row['commission_amount'])}',
            'عمولة التبعية: ${_formatNumber(row['referral_commission_amount'])}',
            'التاريخ: ${_formatDate(row['created_at'])}',
            if (row['note'] != null && row['note'].toString().isNotEmpty)
              'ملاحظات: ${row['note']}',
          ].join('\n'),
        );

      case 'orders':
        return _recordCard(
          icon: Icons.receipt_long_outlined,
          title: 'طلب رقم ${row['id']} — ${row['customer_name']}',
          subtitle: [
            if (row['customer_phone'] != null)
              'الهاتف: ${row['customer_phone']}',
            if (row['customer_location'] != null)
              'الموقع: ${row['customer_location']}',
            'الإجمالي: ${_formatNumber(row['total_amount'])}',
            'الحالة: ${row['status']}',
            'التاريخ: ${_formatDate(row['created_at'])}',
            if (row['order_note'] != null &&
                row['order_note'].toString().isNotEmpty)
              'ملاحظات: ${row['order_note']}',
          ].join('\n'),
        );

      case 'expenses':
        return _recordCard(
          icon: Icons.payments_outlined,
          title: (row['title'] ?? 'مصروف').toString(),
          subtitle: [
            'المبلغ: ${_formatNumber(row['amount'])}',
            if (row['note'] != null && row['note'].toString().isNotEmpty)
              'ملاحظات: ${row['note']}',
            'التاريخ: ${_formatDate(row['created_at'])}',
            'رقم السجل: ${row['id']}',
          ].join('\n'),
        );

      case 'audit':
        return _recordCard(
          icon: Icons.manage_history_outlined,
          title: (row['description'] ?? 'سجل تدقيق').toString(),
          subtitle: [
            'العملية: ${row['action']}',
            'نوع السجل: ${row['entity_type']}',
            'معرف السجل: ${row['entity_id'] ?? 'غير محدد'}',
            'التاريخ: ${_formatDate(row['created_at'])}',
          ].join('\n'),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _recordCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Card(
      elevation: 0,
      color: _surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _lightPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _primary.withValues(alpha: 0.12)),
                  ),
                  child: Icon(icon, color: _primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                height: 1.8,
                color: Colors.black54,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _gold),
                  ),
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.restore, size: 18),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    final label = _categories.firstWhere(
      (category) => category['value'] == _selectedCategory,
    )['label'];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 54, color: _gold),
            const SizedBox(height: 12),
            Text(
              'لا توجد سجلات في قسم $label',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _primary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _primary, size: 42),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل الأرشيف',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: _primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _refreshArchive,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
