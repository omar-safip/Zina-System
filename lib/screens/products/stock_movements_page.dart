import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

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

  // =========================
  // تحميل البيانات
  // =========================

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل حركة المخزون: $e')),
      );
    }
  }

  // =========================
  // إضافة / خصم المخزون
  // =========================

  Future<void> _saveMovement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;

    if (quantity <= 0) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // قراءة المخزون الحالي من قاعدة البيانات
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

        double newStock;

        // إضافة
        if (_movementType == 'in') {
          newStock = currentStock + quantity;
        }
        // خصم
        else {
          if (quantity > currentStock) {
            throw Exception(
              'الكمية المطلوبة أكبر من المخزون الحالي ($currentStock)',
            );
          }

          newStock = currentStock - quantity;
        }

        final noteText = _noteController.text.trim();

        // تسجيل حركة المخزون
        await txn.insert('stock_movements', {
          'product_id': widget.productId,
          'type': _movementType,
          'quantity': quantity,
          'note': noteText.isEmpty ? null : noteText,
          'created_at': DateTime.now().toIso8601String(),
        });

        // تحديث كمية المنتج
        await txn.update(
          'products',
          {
            'stock_quantity': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [widget.productId],
        );
      });

      // تنظيف الحقول
      _quantityController.clear();
      _noteController.clear();

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _movementType == 'in'
                ? 'تمت إضافة الكمية بنجاح'
                : 'تم خصم الكمية بنجاح',
          ),
        ),
      );

      // نرجع true حتى تعرف products_page أن المخزون تغير
      // ولا نغلق الصفحة، لأن المستخدم قد يريد تسجيل حركة أخرى.
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================
  // الواجهة
  // =========================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'حركة المخزون',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
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
    );
  }

  // =========================
  // بطاقة المنتج
  // =========================

  Widget _buildProductHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E4FA3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المنتج',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 6),

          Text(
            widget.productName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Colors.white,
                size: 22,
              ),

              const SizedBox(width: 8),

              const Text(
                'المخزون الحالي:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(width: 8),

              Text(
                _formatNumber(_currentStock),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // نموذج الحركة
  // =========================

  Widget _buildMovementForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تسجيل حركة جديدة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _movementType,
            decoration: const InputDecoration(
              labelText: 'نوع الحركة',
              prefixIcon: Icon(Icons.swap_vert),
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الكمية',
              hintText: 'أدخل الكمية',
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'أدخل الكمية';
              }

              final number = double.tryParse(value.trim());

              if (number == null) {
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
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظة',
              hintText: 'اختياري',
              prefixIcon: Icon(Icons.note_outlined),
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
                  : Icon(_movementType == 'in' ? Icons.add : Icons.remove),
              label: Text(
                _isSaving
                    ? 'جاري الحفظ...'
                    : _movementType == 'in'
                    ? 'إضافة للمخزون'
                    : 'خصم من المخزون',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // عنوان السجل
  // =========================

  Widget _buildHistoryTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'سجل حركات المخزون',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        Text(
          '${_movements.length} حركة',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      ],
    );
  }

  // =========================
  // سجل الحركات
  // =========================

  Widget _buildMovementHistory() {
    if (_movements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.swap_vert_circle_outlined,
              size: 45,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد حركات مخزون حتى الآن',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _movements.map((movement) {
        return _buildMovementCard(movement);
      }).toList(),
    );
  }

  // =========================
  // بطاقة حركة
  // =========================

  Widget _buildMovementCard(Map<String, dynamic> movement) {
    final type = movement['type']?.toString() ?? '';

    final quantity = (movement['quantity'] as num?)?.toDouble() ?? 0;

    final note = movement['note']?.toString();

    final createdAt = movement['created_at']?.toString();

    final isIncoming = type == 'in';

    final title = isIncoming ? 'إضافة إلى المخزون' : 'خصم من المخزون';

    final icon = isIncoming
        ? Icons.add_circle_outline
        : Icons.remove_circle_outline;

    final quantityText = '${isIncoming ? '+' : '-'}${_formatNumber(quantity)}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isIncoming ? const Color(0xFF15803D) : Colors.red.shade600,
            size: 28,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),

                if (createdAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            quantityText,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isIncoming ? const Color(0xFF15803D) : Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // تنسيق الأرقام
  // =========================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  // =========================
  // تنسيق التاريخ
  // =========================

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);

      final localDate = date.toLocal();

      final day = localDate.day.toString().padLeft(2, '0');
      final month = localDate.month.toString().padLeft(2, '0');
      final year = localDate.year.toString();

      final hour = localDate.hour.toString().padLeft(2, '0');
      final minute = localDate.minute.toString().padLeft(2, '0');

      return '$year/$month/$day - $hour:$minute';
    } catch (_) {
      return value;
    }
  }
}
