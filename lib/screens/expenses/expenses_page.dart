import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  static const Color _primary = Color(0xFF70263D);
  static const Color _darkPrimary = Color(0xFF542033);
  static const Color _gold = Color(0xFFC5A15A);
  static const Color _background = Color(0xFFFAF5EC);
  static const Color _softBeige = Color(0xFFF5EBDD);
  static const Color _border = Color(0xFFE8DCCB);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _expenses = [];

  bool _isLoading = true;
  bool _isSaving = false;

  double get _totalExpenses {
    return _expenses.fold<double>(
      0,
      (total, expense) =>
          total + ((expense['amount'] as num?)?.toDouble() ?? 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    try {
      final db = await _databaseHelper.database;

      final expenses = await db.query(
        'expenses',
        orderBy: 'created_at DESC, id DESC',
      );

      if (!mounted) return;

      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('تعذر تحميل المصروفات: $e', isError: true);
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

  String _formatNumber(double value) {
    if (!value.isFinite) return '0';

    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'التاريخ غير متوفر';

    try {
      final date = DateTime.tryParse(value.toString());

      if (date == null) return value.toString();

      return DateFormat('yyyy/MM/dd - hh:mm a', 'en').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _showExpenseDialog({Map<String, dynamic>? expense}) async {
    final isEditing = expense != null;

    _titleController.text = expense?['title']?.toString() ?? '';
    _amountController.text = expense?['amount']?.toString() ?? '';
    _noteController.text = expense?['note']?.toString() ?? '';

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: ui.TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFFFFFCF7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(
                  isEditing ? 'تعديل المصروف' : 'إضافة مصروف جديد',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _darkPrimary,
                  ),
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            enabled: !saving,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              'اسم المصروف *',
                              icon: Icons.shopping_bag_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'أدخل اسم المصروف';
                              }
                              if (value.trim().length > 150) {
                                return 'اسم المصروف طويل جدًا';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _amountController,
                            enabled: !saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              'المبلغ بالريال اليمني *',
                              icon: Icons.payments_outlined,
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                (value ?? '').trim(),
                              );

                              if (amount == null ||
                                  !amount.isFinite ||
                                  amount <= 0) {
                                return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _noteController,
                            enabled: !saving,
                            maxLines: 3,
                            maxLength: 300,
                            decoration: _inputDecoration(
                              'الملاحظات (اختياري)',
                              icon: Icons.notes_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: _darkPrimary),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            final title = _titleController.text.trim();
                            final amount = double.parse(
                              _amountController.text.trim(),
                            );
                            final note = _noteController.text.trim();
                            final now = DateTime.now().toIso8601String();

                            setDialogState(() => saving = true);

                            if (mounted) {
                              setState(() => _isSaving = true);
                            }

                            try {
                              final db = await _databaseHelper.database;

                              if (isEditing) {
                                await db.update(
                                  'expenses',
                                  {
                                    'title': title,
                                    'amount': amount,
                                    'note': note.isEmpty ? null : note,
                                  },
                                  where: 'id = ?',
                                  whereArgs: [expense['id']],
                                );
                              } else {
                                await db.insert('expenses', {
                                  'title': title,
                                  'amount': amount,
                                  'note': note.isEmpty ? null : note,
                                  'created_at': now,
                                });
                              }

                              // التحقق من صلاحية الصفحة والحوار بعد await.
                              if (!mounted || !dialogContext.mounted) {
                                return;
                              }

                              Navigator.of(dialogContext).pop();

                              await _loadExpenses();

                              if (!mounted) return;

                              _showMessage(
                                isEditing
                                    ? 'تم تعديل المصروف بنجاح'
                                    : 'تمت إضافة المصروف بنجاح',
                              );
                            } catch (e) {
                              // لا نحدّث حالة الحوار إذا كان قد أُغلق.
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }

                              if (!mounted) return;

                              _showMessage(
                                'تعذر حفظ المصروف: $e',
                                isError: true,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> expense) async {
    final title = expense['title']?.toString() ?? 'هذا المصروف';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFFFFFCF7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تأكيد الحذف',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _darkPrimary,
              ),
            ),
            content: Text(
              'هل تريد حذف المصروف "$title"؟\n'
              'سيؤثر ذلك على إجمالي المصروفات وصافي الربح في التقارير.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: _darkPrimary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final db = await _databaseHelper.database;

      await db.delete('expenses', where: 'id = ?', whereArgs: [expense['id']]);

      await _loadExpenses();

      if (!mounted) return;

      _showMessage('تم حذف المصروف');
    } catch (e) {
      _showMessage('تعذر حذف المصروف: $e', isError: true);
    }
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, color: _primary),
      filled: true,
      fillColor: _background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkPrimary, _primary],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.7), width: 1),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold.withValues(alpha: 0.7)),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFFE4C783),
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي المصروفات المسجلة',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_formatNumber(_totalExpenses)} ريال يمني',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'عدد المصروفات: ${_expenses.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final amount = (expense['amount'] as num?)?.toDouble() ?? 0;
    final title = expense['title']?.toString() ?? 'مصروف';
    final note = expense['note']?.toString() ?? '';
    final date = _formatDate(expense['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _softBeige,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.45)),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _darkPrimary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_formatNumber(amount)} ريال يمني',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF85796D),
                    fontSize: 11,
                  ),
                ),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'الملاحظات: $note',
                    style: const TextStyle(
                      color: Color(0xFF85796D),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'خيارات المصروف',
            iconColor: _primary,
            onSelected: (value) {
              if (value == 'edit') {
                _showExpenseDialog(expense: expense);
              } else if (value == 'delete') {
                _confirmDelete(expense);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 19, color: _primary),
                    SizedBox(width: 9),
                    Text('تعديل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 19),
                    SizedBox(width: 9),
                    Text('حذف'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 54,
            color: _gold.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 14),
          const Text(
            'لا توجد مصروفات مسجلة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkPrimary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'اضغط على «إضافة مصروف» لتسجيل أول مصروف.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF85796D), fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              'إدارة المصروفات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _darkPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _isLoading ? null : _loadExpenses,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 6),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isSaving ? null : () => _showExpenseDialog(),
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'إضافة مصروف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadExpenses,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 850;

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: _softBeige,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: _gold.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.payments_outlined,
                                          color: _primary,
                                          size: 27,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'المصروفات التشغيلية',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: _darkPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              'سجّل المشتريات والمبالغ المصروفة '
                                              'لمتابعة صافي الربح.',
                                              style: TextStyle(
                                                color: Color(0xFF85796D),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  _buildTotalCard(),
                                  const SizedBox(height: 25),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'سجل المصروفات',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: _darkPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${_expenses.length} مصروف',
                                        style: const TextStyle(
                                          color: Color(0xFF85796D),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if (_expenses.isEmpty)
                                    _buildEmptyState()
                                  else if (wide)
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 0,
                                      children: _expenses.map((expense) {
                                        return SizedBox(
                                          width: (constraints.maxWidth - 64)
                                              .clamp(280, 540)
                                              .toDouble(),
                                          child: _buildExpenseCard(expense),
                                        );
                                      }).toList(),
                                    )
                                  else
                                    ..._expenses.map(_buildExpenseCard),
                                  const SizedBox(height: 90),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
