import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

const Color _zeinaBurgundy = Color(0xFF70263D);
const Color _zeinaDarkBurgundy = Color(0xFF4D192B);
const Color _zeinaGold = Color(0xFFC5A15A);
const Color _zeinaBeige = Color(0xFFFAF5EC);
const Color _zeinaLightBeige = Color(0xFFF2E7D5);
const Color _zeinaBorder = Color(0xFFE8DCCB);

class StockMovementsPage extends StatefulWidget {
  final int productId;
  final String productName;

  const StockMovementsPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  String _movementType = 'in';

  double _currentStock = 0;
  List<Map<String, dynamic>> _movements = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ==================================================
  // تحميل البيانات
  // ==================================================

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final productResult = await db.query(
        'products',
        columns: ['stock_quantity'],
        where: 'id = ?',
        whereArgs: [widget.productId],
        limit: 1,
      );

      if (productResult.isEmpty) {
        throw Exception('المنتج غير موجود');
      }

      final movements = await db.query(
        'stock_movements',
        where: 'product_id = ?',
        whereArgs: [widget.productId],
        orderBy: 'id DESC',
      );

      final stock =
          (productResult.first['stock_quantity'] as num?)?.toDouble() ?? 0;

      if (!mounted) return;

      setState(() {
        _currentStock = stock;
        _movements = movements;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('حدث خطأ أثناء تحميل حركة المخزون: $e', isError: true);
    }
  }

  // ==================================================
  // رسائل التنبيه
  // ==================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _zeinaDarkBurgundy : _zeinaBurgundy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ==================================================
  // إضافة / خصم المخزون
  // ==================================================

  Future<void> _saveMovement() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final normalizedQuantity = _quantityController.text.trim().replaceAll(
      ',',
      '.',
    );
    final quantity = double.tryParse(normalizedQuantity) ?? 0;

    if (!quantity.isFinite || quantity <= 0) {
      _showMessage('أدخل كمية صحيحة أكبر من صفر', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // قراءة المخزون الحالي من قاعدة البيانات.
        final productResult = await txn.query(
          'products',
          columns: ['stock_quantity'],
          where: 'id = ?',
          whereArgs: [widget.productId],
          limit: 1,
        );

        if (productResult.isEmpty) {
          throw Exception('المنتج غير موجود');
        }

        final currentStock =
            (productResult.first['stock_quantity'] as num?)?.toDouble() ?? 0;

        if (!currentStock.isFinite || currentStock < 0) {
          throw Exception('المخزون الحالي غير صحيح');
        }

        double newStock;

        // إضافة إلى المخزون.
        if (_movementType == 'in') {
          newStock = currentStock + quantity;

          if (!newStock.isFinite) {
            throw Exception('الكمية الناتجة أكبر من النطاق المسموح');
          }
        } else {
          // خصم من المخزون.
          if (quantity > currentStock) {
            throw Exception(
              'الكمية المطلوبة أكبر من المخزون الحالي '
              '(${_formatNumber(currentStock)})',
            );
          }

          newStock = currentStock - quantity;
        }

        final noteText = _noteController.text.trim();
        final now = DateTime.now().toIso8601String();

        // تسجيل حركة المخزون.
        await txn.insert('stock_movements', {
          'product_id': widget.productId,
          'type': _movementType,
          'quantity': quantity,
          'note': noteText.isEmpty ? null : noteText,
          'created_at': now,
        });

        // تحديث كمية المنتج.
        final updatedRows = await txn.update(
          'products',
          {'stock_quantity': newStock, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [widget.productId],
        );

        if (updatedRows == 0) {
          throw Exception('تعذر تحديث كمية المنتج');
        }
      });

      final savedMovementType = _movementType;

      _quantityController.clear();
      _noteController.clear();

      await _loadData();

      if (!mounted) return;

      _showMessage(
        savedMovementType == 'in'
            ? 'تمت إضافة الكمية بنجاح'
            : 'تم خصم الكمية بنجاح',
      );

      // تبقى الصفحة مفتوحة لتسجيل حركات إضافية.
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==================================================
  // الواجهة
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
          appBarTheme: const AppBarTheme(
            backgroundColor: _zeinaBurgundy,
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: _zeinaDarkBurgundy),
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIconColor: _zeinaBurgundy,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
              borderSide: const BorderSide(color: _zeinaBurgundy, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _zeinaBurgundy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _zeinaBurgundy.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('حركة المخزون')),
          drawer: const Drawer(backgroundColor: _zeinaBeige, child: Sidebar()),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _zeinaBurgundy),
                )
              : RefreshIndicator(
                  color: _zeinaBurgundy,
                  backgroundColor: Colors.white,
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductHeader(),
                        const SizedBox(height: 24),
                        _buildMovementForm(),
                        const SizedBox(height: 30),
                        _buildHistoryTitle(),
                        const SizedBox(height: 12),
                        _buildMovementHistory(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ==================================================
  // بطاقة المنتج
  // ==================================================

  Widget _buildProductHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_zeinaBurgundy, _zeinaDarkBurgundy],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _zeinaBurgundy..withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _zeinaGold.withValues(alpha: 0.8)),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _zeinaGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تفاصيل المنتج',
                style: TextStyle(color: _zeinaLightBeige, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.productName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white..withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warehouse_outlined,
                  color: _zeinaGold,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'المخزون الحالي',
                    style: TextStyle(color: _zeinaLightBeige, fontSize: 14),
                  ),
                ),
                Text(
                  _formatNumber(_currentStock),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // نموذج الحركة
  // ==================================================

  Widget _buildMovementForm() {
    final isIncoming = _movementType == 'in';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'تسجيل حركة جديدة',
              Icons.swap_vert_circle_outlined,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _movementType,
              decoration: const InputDecoration(
                labelText: 'نوع الحركة',
                prefixIcon: Icon(Icons.swap_vert_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'in', child: Text('إضافة إلى المخزون')),
                DropdownMenuItem(value: 'out', child: Text('خصم من المخزون')),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _movementType = value;
                      });
                    },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _quantityController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'الكمية',
                hintText: 'أدخل الكمية',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'أدخل الكمية';
                }

                final number = double.tryParse(
                  value.trim().replaceAll(',', '.'),
                );

                if (number == null || !number.isFinite) {
                  return 'أدخل رقمًا صحيحًا';
                }

                if (number <= 0) {
                  return 'يجب أن تكون الكمية أكبر من صفر';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteController,
              enabled: !_isSaving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظة',
                hintText: 'اختياري',
                prefixIcon: Icon(Icons.note_alt_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveMovement,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isIncoming
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                      ),
                label: Text(
                  _isSaving
                      ? 'جاري الحفظ...'
                      : isIncoming
                      ? 'إضافة للمخزون'
                      : 'خصم من المخزون',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // عنوان القسم
  // ==================================================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _zeinaLightBeige,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _zeinaBurgundy, size: 21),
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
  // عنوان سجل الحركات
  // ==================================================

  Widget _buildHistoryTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'سجل حركات المخزون',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _zeinaDarkBurgundy,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _zeinaLightBeige,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _zeinaBorder),
          ),
          child: Text(
            '${_movements.length} حركة',
            style: const TextStyle(
              color: _zeinaBurgundy,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ==================================================
  // سجل الحركات
  // ==================================================

  Widget _buildMovementHistory() {
    if (_movements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _zeinaBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.swap_vert_circle_outlined, size: 48, color: _zeinaGold),
            SizedBox(height: 12),
            Text(
              'لا توجد حركات مخزون حتى الآن',
              style: TextStyle(
                color: _zeinaDarkBurgundy,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'ستظهر عمليات الإضافة والخصم هنا',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(children: _movements.map(_buildMovementCard).toList());
  }

  // ==================================================
  // بطاقة حركة
  // ==================================================

  Widget _buildMovementCard(Map<String, dynamic> movement) {
    final type = movement['type']?.toString() ?? '';

    final quantity = (movement['quantity'] as num?)?.toDouble() ?? 0;

    final note = movement['note']?.toString();
    final createdAt = movement['created_at']?.toString();

    final isIncoming = type == 'in';

    final title = isIncoming ? 'إضافة إلى المخزون' : 'خصم من المخزون';

    final quantityText = '${isIncoming ? '+' : '-'}${_formatNumber(quantity)}';

    final movementColor = isIncoming ? const Color(0xFF26734D) : _zeinaBurgundy;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isIncoming ? const Color(0xFFE8F3EC) : _zeinaLightBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              color: movementColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _zeinaDarkBurgundy,
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quantityText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: movementColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // تنسيق الأرقام
  // ==================================================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  // ==================================================
  // تنسيق التاريخ
  // ==================================================

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$year/$month/$day - $hour:$minute';
    } catch (_) {
      return value;
    }
  }
}
