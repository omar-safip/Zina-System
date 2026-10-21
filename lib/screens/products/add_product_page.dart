import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

const Color _zeinaBurgundy = Color(0xFF70263D);
const Color _zeinaDarkBurgundy = Color(0xFF4D192B);
const Color _zeinaGold = Color(0xFFC5A15A);
const Color _zeinaBeige = Color(0xFFFAF5EC);
const Color _zeinaLightBeige = Color(0xFFF2E7D5);
const Color _zeinaBorder = Color(0xFFE8DCCB);

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final name = _nameController.text.trim();

      // الكود اختياري؛ إذا كان فارغًا نحفظ NULL.
      final codeText = _codeController.text.trim();
      final code = codeText.isEmpty ? null : codeText;

      final descriptionText = _descriptionController.text.trim();
      final description = descriptionText.isEmpty ? null : descriptionText;

      final purchasePrice =
          double.tryParse(_purchasePriceController.text.trim()) ?? 0;

      final sellingPrice =
          double.tryParse(_sellingPriceController.text.trim()) ?? 0;

      final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;

      final minQuantity =
          double.tryParse(_minQuantityController.text.trim()) ?? 0;

      final now = DateTime.now().toIso8601String();

      final productId = await db.insert('products', {
        'name': name,
        'code': code,
        'description': description,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'stock_quantity': quantity,
        'min_stock_quantity': minQuantity,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // فشل تسجيل التدقيق لا يلغي نجاح إضافة المنتج.
      try {
        await DatabaseHelper.instance.addAuditLog(
          action: 'create',
          entityType: 'product',
          entityId: productId,
          description: 'تمت إضافة المنتج: $name',
          newValues: {
            'id': productId,
            'name': name,
            'code': code,
            'description': description,
            'purchase_price': purchasePrice,
            'selling_price': sellingPrice,
            'stock_quantity': quantity,
            'min_stock_quantity': minQuantity,
            'is_active': 1,
          },
        );
      } catch (auditError) {
        debugPrint('تعذر تسجيل إضافة المنتج في سجل التدقيق: $auditError');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إضافة المنتج بنجاح'),
          backgroundColor: _zeinaBurgundy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إضافة المنتج: $e'),
          backgroundColor: _zeinaDarkBurgundy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: _zeinaBeige,
          colorScheme: theme.colorScheme.copyWith(
            primary: _zeinaBurgundy,
            secondary: _zeinaGold,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: _zeinaBurgundy,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
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
          appBar: AppBar(
            title: const Text('إضافة منتج'),
            actions: [
              IconButton(
                tooltip: 'القائمة الجانبية',
                icon: const Icon(Icons.menu_rounded, size: 28),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
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
                      onPressed: _isSaving ? null : _saveProduct,
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
                      label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ المنتج'),
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
              Icons.add_box_outlined,
              color: _zeinaGold,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة منتج جديد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'أدخل بيانات المنتج والأسعار والمخزون',
                  style: TextStyle(color: _zeinaLightBeige, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.numbers_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'مطلوب';
        }

        final number = double.tryParse(value.trim());

        if (number == null) {
          return 'رقم غير صحيح';
        }

        if (number < 0) {
          return 'لا يمكن أن يكون سالبًا';
        }

        return null;
      },
    );
  }
}
