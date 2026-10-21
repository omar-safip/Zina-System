import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';
import 'add_product_page.dart';
import 'edit_product_page.dart' as edit_product;
import 'stock_movements_page.dart' as stock_movements;

const Color _zeinaBurgundy = Color(0xFF70263D);
const Color _zeinaDarkBurgundy = Color(0xFF4D192B);
const Color _zeinaGold = Color(0xFFC5A15A);
const Color _zeinaBeige = Color(0xFFFAF5EC);
const Color _zeinaLightBeige = Color(0xFFF2E7D5);
const Color _zeinaBorder = Color(0xFFE8DCCB);

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final products = await db.query(
        'products',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'id DESC',
      );

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحميل المنتجات: $e'),
          backgroundColor: _zeinaDarkBurgundy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductPage()),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

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
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: _zeinaBurgundy,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _zeinaBurgundy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('المنتجات والمخزون')),
          drawer: const Drawer(backgroundColor: _zeinaBeige, child: Sidebar()),
          body: RefreshIndicator(
            color: _zeinaBurgundy,
            backgroundColor: Colors.white,
            onRefresh: _loadProducts,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    _buildLoading()
                  else if (_products.isEmpty)
                    _buildEmptyState()
                  else
                    _buildProductsList(),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddProduct,
            backgroundColor: _zeinaBurgundy,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'إضافة منتج',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // رأس الصفحة
  // ==================================================

  Widget _buildHeader() {
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
            color: _zeinaBurgundy.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _zeinaGold.withValues(alpha: 0.8)),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
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
                  'المنتجات والمخزون',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'إدارة المنتجات والكميات والأسعار',
                  style: TextStyle(color: _zeinaLightBeige, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // حالة التحميل
  // ==================================================

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _zeinaBorder),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _zeinaBurgundy),
      ),
    );
  }

  // ==================================================
  // حالة عدم وجود منتجات
  // ==================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _zeinaBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _zeinaLightBeige,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: _zeinaBurgundy,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'لا توجد منتجات حتى الآن',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _zeinaDarkBurgundy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على زر «إضافة منتج» لإضافة أول منتج.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.6),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول منتج'),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // قائمة المنتجات
  // ==================================================

  Widget _buildProductsList() {
    return Column(children: _products.map(_buildProductCard).toList());
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? '-';
    final code = product['code']?.toString() ?? '-';

    final purchasePrice = _toDouble(product['purchase_price']);
    final sellingPrice = _toDouble(product['selling_price']);
    final quantity = _toDouble(product['stock_quantity']);
    final minQuantity = _toDouble(product['min_stock_quantity']);

    final isLowStock = quantity <= minQuantity;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isLowStock ? _zeinaGold : _zeinaBorder,
          width: isLowStock ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _zeinaDarkBurgundy.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _zeinaLightBeige,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _zeinaBurgundy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _zeinaDarkBurgundy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'الكود: $code',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _zeinaLightBeige,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _zeinaGold.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: _zeinaDarkBurgundy,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'مخزون منخفض',
                              style: TextStyle(
                                color: _zeinaDarkBurgundy,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إجراءات المنتج',
                icon: const Icon(Icons.more_vert, color: _zeinaBurgundy),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditProduct(product);
                      break;
                    case 'deactivate':
                      _deactivateProduct(product);
                      break;
                    case 'stock':
                      _openStockMovements(product);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined, color: _zeinaBurgundy),
                      title: Text('تعديل المنتج'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'stock',
                    child: ListTile(
                      leading: Icon(
                        Icons.swap_vert_circle_outlined,
                        color: _zeinaBurgundy,
                      ),
                      title: Text('حركة المخزون'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'deactivate',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: _zeinaDarkBurgundy,
                      ),
                      title: Text('تعطيل المنتج'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: _zeinaBorder),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildInfo(
                  'سعر الشراء',
                  '${_formatNumber(purchasePrice)} ريال',
                ),
              ),
              Expanded(
                child: _buildInfo(
                  'سعر البيع',
                  '${_formatNumber(sellingPrice)} ريال',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _buildInfo('الكمية', _formatNumber(quantity))),
              Expanded(
                child: _buildInfo('الحد الأدنى', _formatNumber(minQuantity)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================================================
  // معلومات المنتج
  // ==================================================

  Widget _buildInfo(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _zeinaDarkBurgundy,
          ),
        ),
      ],
    );
  }

  // ==================================================
  // تحويل وتنسيق الأرقام
  // ==================================================

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  // ==================================================
  // تعديل المنتج
  // ==================================================

  Future<void> _openEditProduct(Map<String, dynamic> product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => edit_product.EditProductPage(product: product),
      ),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  // ==================================================
  // تعطيل المنتج
  // ==================================================

  Future<void> _deactivateProduct(Map<String, dynamic> product) async {
    final productId = product['id'];

    if (productId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _zeinaBeige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _zeinaBurgundy),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تعطيل المنتج',
                  style: TextStyle(
                    color: _zeinaDarkBurgundy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'هل تريد تعطيل المنتج "${product['name']}"؟\n\n'
            'لن يظهر المنتج في قائمة المنتجات النشطة، '
            'لكن بياناته ستبقى محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: _zeinaDarkBurgundy),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _zeinaBurgundy,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تعطيل'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final db = await DatabaseHelper.instance.database;

      final updatedCount = await db.update(
        'products',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND is_active = ?',
        whereArgs: [productId, 1],
      );

      if (!mounted) return;

      await _loadProducts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedCount > 0
                ? 'تم تعطيل المنتج بنجاح'
                : 'المنتج معطّل بالفعل أو لم يعد موجودًا',
          ),
          backgroundColor: _zeinaBurgundy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تعطيل المنتج: $e'),
          backgroundColor: _zeinaDarkBurgundy,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==================================================
  // حركة المخزون
  // ==================================================

  Future<void> _openStockMovements(Map<String, dynamic> product) async {
    final productId = product['id'];

    if (productId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => stock_movements.StockMovementsPage(
          productId: productId as int,
          productName: product['name']?.toString() ?? '-',
        ),
      ),
    );

    if (mounted) {
      await _loadProducts();
    }
  }
}
