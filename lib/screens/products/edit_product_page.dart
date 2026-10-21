import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

const Color _zeinaBurgundy = Color(0xFF70263D);
const Color _zeinaDarkBurgundy = Color(0xFF4D192B);
const Color _zeinaGold = Color(0xFFC5A15A);
const Color _zeinaBeige = Color(0xFFFAF5EC);
const Color _zeinaLightBeige = Color(0xFFF2E7D5);
const Color _zeinaBorder = Color(0xFFE8DCCB);

class EditProductPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minQuantityController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController.text = product['name']?.toString() ?? '';
    _codeController.text = product['code']?.toString() ?? '';
    _descriptionController.text = product['description']?.toString() ?? '';

    _purchasePriceController.text = _formatInitialNumber(
      product['purchase_price'],
    );

    _sellingPriceController.text = _formatInitialNumber(
      product['selling_price'],
    );

    _quantityController.text = _formatInitialNumber(product['stock_quantity']);

    _minQuantityController.text = _formatInitialNumber(
      product['min_stock_quantity'],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _minQuantityController.dispose();
    super.dispose();
  }

  // ==================================================
  // عرض رسائل للمستخدم
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
  // تحويل الرقم والتحقق منه
  // ==================================================

  double? _parseNumber(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final number = double.tryParse(normalized);

    if (number == null || !number.isFinite || number < 0) {
      return null;
    }

    return number;
  }

  // ==================================================
  // تجهيز بيانات المنتج لسجل التدقيق
  // ==================================================

  Map<String, dynamic> _productAuditValues(Map<String, dynamic> product) {
    return {
      'id': product['id'],
      'name': product['name'],
      'code': product['code'],
      'description': product['description'],
      'purchase_price': product['purchase_price'],
      'selling_price': product['selling_price'],
      'stock_quantity': product['stock_quantity'],
      'min_stock_quantity': product['min_stock_quantity'],
      'is_active': product['is_active'],
    };
  }

  // ==================================================
  // تحديث المنتج
  // ==================================================

  Future<void> _updateProduct() async {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final productIdValue = widget.product['id'];

    if (productIdValue is! int) {
      _showMessage('معرف المنتج غير صحيح', isError: true);
      return;
    }

    final name = _nameController.text.trim();
    final codeText = _codeController.text.trim();
    final descriptionText = _descriptionController.text.trim();

    final purchasePrice = _parseNumber(_purchasePriceController.text);

    final sellingPrice = _parseNumber(_sellingPriceController.text);

    final quantity = _parseNumber(_quantityController.text);

    final minQuantity = _parseNumber(_minQuantityController.text);

    if (name.isEmpty) {
      _showMessage('اسم المنتج مطلوب', isError: true);
      return;
    }

    if (purchasePrice == null ||
        sellingPrice == null ||
        quantity == null ||
        minQuantity == null) {
      _showMessage(
        'تأكد من إدخال أسعار وكميات صحيحة وغير سالبة',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      Map<String, dynamic>? oldProductForAudit;
      Map<String, dynamic>? newProductForAudit;

      await db.transaction((txn) async {
        // التأكد من وجود المنتج وقراءة بياناته القديمة.

        final existingProducts = await txn.query(
          'products',
          columns: [
            'id',
            'name',
            'code',
            'description',
            'purchase_price',
            'selling_price',
            'stock_quantity',
            'min_stock_quantity',
            'is_active',
          ],
          where: 'id = ?',
          whereArgs: [productIdValue],
          limit: 1,
        );

        if (existingProducts.isEmpty) {
          throw Exception('المنتج غير موجود في قاعدة البيانات');
        }

        final existingProduct = Map<String, dynamic>.from(
          existingProducts.first,
        );

        if ((existingProduct['is_active'] as num?)?.toInt() != 1) {
          throw Exception('لا يمكن تعديل منتج غير نشط');
        }

        // التحقق من عدم تكرار كود المنتج.

        if (codeText.isNotEmpty) {
          final duplicateCodes = await txn.query(
            'products',
            columns: ['id'],
            where: 'code = ? AND id != ?',
            whereArgs: [codeText, productIdValue],
            limit: 1,
          );

          if (duplicateCodes.isNotEmpty) {
            throw Exception('هذا الكود مستخدم بالفعل في منتج آخر');
          }
        }

        // قراءة الكمية الحالية من قاعدة البيانات.

        final oldQuantityValue = existingProduct['stock_quantity'];

        final oldQuantity = oldQuantityValue is num
            ? oldQuantityValue.toDouble()
            : double.tryParse(oldQuantityValue?.toString() ?? '') ?? 0;

        if (!oldQuantity.isFinite || oldQuantity < 0) {
          throw Exception('الكمية الحالية في قاعدة البيانات غير صحيحة');
        }

        // تجهيز البيانات القديمة والجديدة للتدقيق.

        oldProductForAudit = _productAuditValues(existingProduct);

        newProductForAudit = {
          'id': productIdValue,
          'name': name,
          'code': codeText.isEmpty ? null : codeText,
          'description': descriptionText.isEmpty ? null : descriptionText,
          'purchase_price': purchasePrice,
          'selling_price': sellingPrice,
          'stock_quantity': quantity,
          'min_stock_quantity': minQuantity,
          'is_active': 1,
        };

        // تحديث بيانات المنتج.

        final updatedRows = await txn.update(
          'products',
          {
            'name': name,
            'code': codeText.isEmpty ? null : codeText,
            'description': descriptionText.isEmpty ? null : descriptionText,
            'purchase_price': purchasePrice,
            'selling_price': sellingPrice,
            'stock_quantity': quantity,
            'min_stock_quantity': minQuantity,
            'updated_at': now,
          },
          where: 'id = ? AND is_active = 1',
          whereArgs: [productIdValue],
        );

        if (updatedRows == 0) {
          throw Exception('تعذر تحديث بيانات المنتج');
        }

        // تسجيل حركة مخزون إذا تغيرت الكمية.

        if (quantity != oldQuantity) {
          final difference = quantity - oldQuantity;
          final movementType = difference > 0 ? 'in' : 'out';
          final movementQuantity = difference.abs();

          await txn.insert('stock_movements', {
            'product_id': productIdValue,
            'type': movementType,
            'quantity': movementQuantity,
            'note': 'تعديل الكمية من صفحة تعديل المنتج',
            'created_at': now,
          });
        }
      });

      // تسجيل التعديل في سجل التدقيق بعد نجاح المعاملة.

      try {
        if (oldProductForAudit != null && newProductForAudit != null) {
          await DatabaseHelper.instance.addAuditLog(
            action: 'update',
            entityType: 'product',
            entityId: productIdValue,
            description: 'تم تعديل بيانات المنتج: $name',
            oldValues: oldProductForAudit,
            newValues: newProductForAudit,
          );
        }
      } catch (auditError, stackTrace) {
        // لا نعتبر تحديث المنتج فاشلاً إذا تعذر تسجيل التدقيق.
        debugPrint('تعذر تسجيل تعديل المنتج في سجل التدقيق: $auditError');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      _showMessage('تم تعديل المنتج وتحديث سجل المخزون بنجاح');

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final error = e.toString().replaceFirst('Exception: ', '');

      _showMessage('تعذر تعديل المنتج: $error', isError: true);
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('تعديل المنتج')),

          // زر القائمة الجانبية يظهر تلقائيًا في AppBar.
          drawer: const Drawer(backgroundColor: _zeinaBeige, child: Sidebar()),

          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(),

                  const SizedBox(height: 24),

                  _buildSectionTitle(
                    'بيانات المنتج',
                    Icons.inventory_2_outlined,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'اسم المنتج',
                    hint: 'أدخل اسم المنتج',
                    icon: Icons.inventory_2_outlined,
                    required: true,
                  ),

                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _codeController,
                    label: 'الكود / الباركود',
                    hint: 'اختياري',
                    icon: Icons.qr_code_2_rounded,
                  ),

                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _descriptionController,
                    label: 'الوصف',
                    hint: 'وصف المنتج',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 26),

                  _buildSectionTitle('الأسعار', Icons.payments_outlined),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          controller: _purchasePriceController,
                          label: 'سعر الشراء',
                          hint: '0',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          controller: _sellingPriceController,
                          label: 'سعر البيع',
                          hint: '0',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  _buildSectionTitle('المخزون', Icons.warehouse_outlined),

                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          controller: _quantityController,
                          label: 'الكمية الحالية',
                          hint: '0',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberField(
                          controller: _minQuantityController,
                          label: 'الحد الأدنى',
                          hint: '0',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _updateProduct,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'جاري الحفظ...' : 'حفظ التعديلات',
                      ),
                    ),
                  ),

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
  // رأس الصفحة
  // ==================================================

  Widget _buildPageHeader() {
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
            color: _zeinaBurgundy.withValues(alpha: 0.14),
            blurRadius: 14,
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
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _zeinaGold.withValues(alpha: 0.8)),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: _zeinaGold,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعديل بيانات المنتج',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'حدّث بيانات المنتج والأسعار والمخزون',
                  style: TextStyle(color: _zeinaLightBeige, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _zeinaDarkBurgundy,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: _zeinaBorder, thickness: 1)),
      ],
    );
  }

  // ==================================================
  // حقول النص
  // ==================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'هذا الحقل مطلوب';
              }

              return null;
            }
          : null,
    );
  }

  // ==================================================
  // حقول الأرقام
  // ==================================================

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isSaving,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.numbers_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'مطلوب';
        }

        final number = _parseNumber(value);

        if (number == null) {
          return 'أدخل رقمًا صحيحًا غير سالب';
        }

        return null;
      },
    );
  }

  // ==================================================
  // تنسيق الأرقام عند فتح الصفحة
  // ==================================================

  String _formatInitialNumber(dynamic value) {
    if (value == null) {
      return '0';
    }

    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }

      return value.toString();
    }

    return value.toString();
  }
}
