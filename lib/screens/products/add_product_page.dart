import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

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

      // الكود اختياري.
      // إذا كان فارغًا نحفظ NULL وليس String فارغ.
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

      await db.insert('products', {
        'name': name,
        'code': code,
        'description': description,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'stock_quantity': quantity,
        'min_stock_quantity': minQuantity,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة المنتج بنجاح')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إضافة المنتج: $e')));
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إضافة منتج',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('بيانات المنتج'),

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
                  icon: Icons.qr_code_2,
                ),

                const SizedBox(height: 14),

                _buildTextField(
                  controller: _descriptionController,
                  label: 'الوصف',
                  hint: 'وصف المنتج',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                _buildSectionTitle('الأسعار'),

                const SizedBox(height: 16),

                Row(
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

                const SizedBox(height: 24),

                _buildSectionTitle('المخزون'),

                const SizedBox(height: 16),

                Row(
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

                const SizedBox(height: 14),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        prefixIcon: const Icon(Icons.numbers),
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
