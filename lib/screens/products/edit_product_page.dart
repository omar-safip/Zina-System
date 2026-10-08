import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

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

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final productId = widget.product['id'];

      if (productId == null) {
        throw Exception('معرف المنتج غير موجود');
      }

      final name = _nameController.text.trim();

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

      await db.update(
        'products',
        {
          'name': name,
          'code': code,
          'description': description,
          'purchase_price': purchasePrice,
          'selling_price': sellingPrice,
          'stock_quantity': quantity,
          'min_stock_quantity': minQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعديل المنتج بنجاح')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تعديل المنتج: $e')));
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
            'تعديل المنتج',
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

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
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
                    label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ التعديلات'),
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
