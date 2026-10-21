import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  List<Map<String, dynamic>> _marketers = [];
  List<Map<String, dynamic>> _products = [];
  final List<_SaleCartItem> _cart = [];

  int? _selectedMarketerId;
  int? _selectedProductId;

  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _deliveryController = TextEditingController(
    text: '0',
  );
  final TextEditingController _initialPaymentController = TextEditingController(
    text: '0',
  );

  String _paymentChoice = 'paid';

  bool _isLoading = true;
  bool _isSaving = false;

  // ألوان هوية زينة ZEINA.
  static const Color _primary = Color(0xFF70263D);
  static const Color _darkPrimary = Color(0xFF4D192B);
  static const Color _background = Color(0xFFFAF5EC);
  static const Color _gold = Color(0xFFC5A15A);
  static const Color _lightBeige = Color(0xFFF2E7D5);
  static const Color _borderColor = Color(0xFFE8DCCB);
  static const Color _fieldBackground = Color(0xFFFFFCF7);

  double get _totalAmount =>
      _cart.fold(0, (total, item) => total + item.quantity * item.sellingPrice);

  double get _totalCost => _cart.fold(
    0,
    (total, item) => total + item.quantity * item.purchasePrice,
  );

  double get _totalProfit => _totalAmount - _totalCost;

  Map<String, dynamic>? get _selectedMarketer {
    for (final marketer in _marketers) {
      if (marketer['id'] == _selectedMarketerId) {
        return marketer;
      }
    }
    return null;
  }

  double get _commissionRate {
    final value = _selectedMarketer?['commission_rate'];
    return value is num ? value.toDouble() : 0;
  }

  double get _commissionAmount =>
      _totalProfit > 0 ? _totalProfit * _commissionRate / 100 : 0;

  int? get _selectedMarketerParentId {
    final value = _selectedMarketer?['parent_id'];
    return value is num ? value.toInt() : null;
  }

  Map<String, dynamic>? get _referralParent {
    final parentId = _selectedMarketerParentId;
    if (parentId == null) return null;

    for (final marketer in _marketers) {
      final id = marketer['id'];
      if (id is num && id.toInt() == parentId) {
        return marketer;
      }
    }

    return null;
  }

  bool get _hasReferralCommission {
    final parent = _referralParent;
    final enabled = parent?['receives_referral_commission'];
    final rate = parent?['referral_commission_rate'];

    return (enabled is num && enabled.toInt() == 1) &&
        rate is num &&
        rate.toDouble() > 0;
  }

  double get _referralCommissionRate {
    if (!_hasReferralCommission) return 0;

    final value = _referralParent?['referral_commission_rate'];
    return value is num ? value.toDouble() : 0;
  }

  double get _referralCommissionAmount =>
      _totalAmount > 0 ? _totalAmount * _referralCommissionRate / 100 : 0;

  double get _deliveryFee =>
      double.tryParse(_deliveryController.text.trim()) ?? 0;

  double get _invoiceTotal => _totalAmount + _deliveryFee;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deliveryController.dispose();
    _initialPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = await _databaseHelper.database;
      final marketers = await _databaseHelper.getAllMarketers();

      final products = await db.query(
        'products',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'name COLLATE NOCASE ASC',
      );

      if (!mounted) return;

      setState(() {
        _marketers = marketers;
        _products = products;

        if (_selectedMarketerId != null &&
            !_marketers.any((m) => m['id'] == _selectedMarketerId)) {
          _selectedMarketerId = null;
        }

        if (_selectedProductId != null &&
            !_products.any((p) => p['id'] == _selectedProductId)) {
          _selectedProductId = null;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('تعذر تحميل البيانات: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? _darkPrimary : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Map<String, dynamic>? _findProduct(int? id) {
    if (id == null) return null;

    for (final product in _products) {
      if (product['id'] == id) return product;
    }

    return null;
  }

  void _addProduct() {
    final product = _findProduct(_selectedProductId);

    if (product == null) {
      _showMessage('اختر منتجًا أولًا', isError: true);
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());

    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      _showMessage('أدخل كمية صحيحة أكبر من صفر', isError: true);
      return;
    }

    final stock = (product['stock_quantity'] as num?)?.toDouble() ?? 0;

    final existingIndex = _cart.indexWhere(
      (item) => item.productId == product['id'],
    );

    final existingQuantity = existingIndex == -1
        ? 0.0
        : _cart[existingIndex].quantity;

    if (existingQuantity + quantity > stock) {
      _showMessage(
        'الكمية المطلوبة تتجاوز المخزون المتاح (${_formatNumber(stock)})',
        isError: true,
      );
      return;
    }

    final sellingPrice = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final purchasePrice = (product['purchase_price'] as num?)?.toDouble() ?? 0;

    if (sellingPrice < 0 || purchasePrice < 0) {
      _showMessage('أسعار المنتج غير صحيحة', isError: true);
      return;
    }

    setState(() {
      if (existingIndex != -1) {
        _cart[existingIndex].quantity += quantity;
      } else {
        _cart.add(
          _SaleCartItem(
            productId: product['id'] as int,
            name: product['name']?.toString() ?? 'منتج',
            code: product['code']?.toString() ?? '',
            stockQuantity: stock,
            sellingPrice: sellingPrice,
            purchasePrice: purchasePrice,
            quantity: quantity,
          ),
        );
      }

      _quantityController.text = '1';
    });
  }

  void _changeQuantity(_SaleCartItem item, double change) {
    final newQuantity = item.quantity + change;

    if (newQuantity <= 0) {
      setState(() => _cart.remove(item));
      return;
    }

    if (newQuantity > item.stockQuantity) {
      _showMessage(
        'لا تتوفر هذه الكمية. المخزون المتاح: '
        '${_formatNumber(item.stockQuantity)}',
        isError: true,
      );
      return;
    }

    setState(() => item.quantity = newQuantity);
  }

  Future<void> _saveSale() async {
    if (_isSaving) return;

    if (_selectedMarketerId == null) {
      _showMessage('اختر المسوق المسؤول عن الفاتورة', isError: true);
      return;
    }

    if (_cart.isEmpty) {
      _showMessage('أضف منتجًا واحدًا على الأقل', isError: true);
      return;
    }

    final customerName = _customerNameController.text.trim();
    final customerPhone = _customerPhoneController.text.trim();
    final deliveryFee = double.tryParse(_deliveryController.text.trim());
    final enteredPayment = double.tryParse(
      _initialPaymentController.text.trim(),
    );

    if (customerName.isEmpty || customerPhone.isEmpty) {
      _showMessage('اسم الزبون ورقم هاتفه مطلوبان', isError: true);
      return;
    }

    if (deliveryFee == null || !deliveryFee.isFinite || deliveryFee < 0) {
      _showMessage(
        'أدخل قيمة توصيل صحيحة (صفر عند عدم وجود توصيل)',
        isError: true,
      );
      return;
    }

    if (_paymentChoice == 'partial' &&
        (enteredPayment == null ||
            !enteredPayment.isFinite ||
            enteredPayment <= 0 ||
            enteredPayment >= _totalAmount + deliveryFee)) {
      _showMessage(
        'المقدم يجب أن يكون أكبر من صفر وأقل من الإجمالي النهائي',
        isError: true,
      );
      return;
    }

    final initialPayment = _paymentChoice == 'paid'
        ? _totalAmount + deliveryFee
        : _paymentChoice == 'partial'
        ? enteredPayment!
        : 0.0;

    if (_totalAmount + deliveryFee <= 0) {
      _showMessage('يجب أن يكون إجمالي الفاتورة أكبر من صفر', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await _databaseHelper.database;
      final now = DateTime.now().toIso8601String();

      final saleId = await db.transaction<int>((txn) async {
        final marketerRows = await txn.query(
          'marketers',
          where: 'id = ? AND is_active = 1',
          whereArgs: [_selectedMarketerId],
          limit: 1,
        );

        if (marketerRows.isEmpty) {
          throw Exception('المسوق غير موجود أو غير نشط. حدّث البيانات.');
        }

        final marketer = marketerRows.first;
        final commissionRate =
            (marketer['commission_rate'] as num?)?.toDouble() ?? 0;

        if (!commissionRate.isFinite ||
            commissionRate < 0 ||
            commissionRate > 100) {
          throw Exception('نسبة عمولة المسوق غير صحيحة.');
        }

        // عمولة التبعية تخص المسوق الرئيسي المباشر فقط.
        final parentIdValue = marketer['parent_id'];
        final parentId = parentIdValue is num ? parentIdValue.toInt() : null;

        double referralCommissionRate = 0;
        int? referralCommissionMarketerId;

        if (parentId != null) {
          final parentRows = await txn.query(
            'marketers',
            columns: [
              'id',
              'receives_referral_commission',
              'referral_commission_rate',
            ],
            where: 'id = ?',
            whereArgs: [parentId],
            limit: 1,
          );

          if (parentRows.isNotEmpty) {
            final parent = parentRows.first;
            final enabled =
                (parent['receives_referral_commission'] as num?)?.toInt() == 1;

            final rate =
                (parent['referral_commission_rate'] as num?)?.toDouble() ?? 0;

            if (enabled) {
              if (!rate.isFinite || rate < 0 || rate > 100) {
                throw Exception('نسبة عمولة التبعية للمسوق الرئيسي غير صحيحة.');
              }

              if (rate > 0) {
                referralCommissionRate = rate;
                referralCommissionMarketerId = parentId;
              }
            }
          }
        }

        double totalAmount = 0;
        double totalCost = 0;
        final verifiedItems = <Map<String, dynamic>>[];

        for (final cartItem in _cart) {
          if (!cartItem.quantity.isFinite || cartItem.quantity <= 0) {
            throw Exception('توجد كمية غير صحيحة في الفاتورة.');
          }

          final rows = await txn.query(
            'products',
            where: 'id = ? AND is_active = 1',
            whereArgs: [cartItem.productId],
            limit: 1,
          );

          if (rows.isEmpty) {
            throw Exception(
              'المنتج "${cartItem.name}" غير موجود أو تم تعطيله.',
            );
          }

          final product = rows.first;
          final stock = (product['stock_quantity'] as num?)?.toDouble() ?? 0;
          final sellingPrice =
              (product['selling_price'] as num?)?.toDouble() ?? 0;
          final purchasePrice =
              (product['purchase_price'] as num?)?.toDouble() ?? 0;

          if (!stock.isFinite ||
              !sellingPrice.isFinite ||
              !purchasePrice.isFinite ||
              stock < 0 ||
              sellingPrice < 0 ||
              purchasePrice < 0) {
            throw Exception(
              'بيانات المخزون أو الأسعار غير صحيحة للمنتج "${cartItem.name}".',
            );
          }

          if (cartItem.quantity > stock) {
            throw Exception(
              'المخزون غير كافٍ للمنتج "${cartItem.name}". '
              'المتاح حاليًا: ${_formatNumber(stock)}',
            );
          }

          final itemTotal = cartItem.quantity * sellingPrice;
          final itemCost = cartItem.quantity * purchasePrice;

          totalAmount += itemTotal;
          totalCost += itemCost;

          verifiedItems.add({
            'product_id': cartItem.productId,
            'quantity': cartItem.quantity,
            'stock_quantity': stock,
            'unit_price': sellingPrice,
            'purchase_price': purchasePrice,
            'total_amount': itemTotal,
            'profit': itemTotal - itemCost,
            'name': product['name']?.toString() ?? cartItem.name,
          });
        }

        if (!totalAmount.isFinite || !totalCost.isFinite) {
          throw Exception('تعذر حساب إجمالي الفاتورة.');
        }

        final totalProfit = totalAmount - totalCost;

        // عمولة المسوق الشخصية من الربح الموجب فقط.
        final commissionAmount = totalProfit > 0
            ? totalProfit * commissionRate / 100
            : 0.0;

        // عمولة التبعية من إجمالي البيع.
        final referralCommissionAmount = referralCommissionMarketerId != null
            ? totalAmount * referralCommissionRate / 100
            : 0.0;

        final id = await txn.insert('sales', {
          'marketer_id': _selectedMarketerId,
          'total_amount': totalAmount,
          'total_profit': totalProfit,
          'commission_amount': commissionAmount,
          'referral_commission_amount': referralCommissionAmount,
          'referral_commission_marketer_id': referralCommissionMarketerId,
          'note': _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          'created_at': now,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'delivery_fee': deliveryFee,
          'payment_status':
              initialPayment >= totalAmount + deliveryFee - 0.000001
              ? 'paid'
              : initialPayment > 0
              ? 'partial'
              : 'unpaid',
          'payment_updated_at': now,
          'fully_paid_at':
              initialPayment >= totalAmount + deliveryFee - 0.000001
              ? now
              : null,
        });

        if (initialPayment > 0) {
          await txn.insert('sale_payments', {
            'sale_id': id,
            'amount': initialPayment,
            'note': 'الدفعة الأولى',
            'created_at': now,
          });
        }

        for (final item in verifiedItems) {
          await txn.insert('sale_items', {
            'sale_id': id,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'unit_price': item['unit_price'],
            'purchase_price': item['purchase_price'],
            'total_amount': item['total_amount'],
            'profit': item['profit'],
          });

          final newStock =
              (item['stock_quantity'] as double) - (item['quantity'] as double);

          final updated = await txn.update(
            'products',
            {'stock_quantity': newStock, 'updated_at': now},
            where: 'id = ? AND is_active = 1 AND stock_quantity >= ?',
            whereArgs: [item['product_id'], item['quantity']],
          );

          if (updated != 1) {
            throw Exception(
              'تغير مخزون "${item['name']}" أثناء الحفظ. حاول مجددًا.',
            );
          }

          await txn.insert('stock_movements', {
            'product_id': item['product_id'],
            'type': 'out',
            'quantity': item['quantity'],
            'note': 'صرف من فاتورة مبيعات رقم $id',
            'created_at': now,
          });
        }

        return id;
      });

      if (!mounted) return;

      setState(() {
        _cart.clear();
        _selectedMarketerId = null;
        _selectedProductId = null;
        _quantityController.text = '1';
        _noteController.clear();
        _customerNameController.clear();
        _customerPhoneController.clear();
        _deliveryController.text = '0';
        _initialPaymentController.text = '0';
        _paymentChoice = 'paid';
      });

      await _loadData();

      if (!mounted) return;

      _showMessage('تم حفظ فاتورة المبيعات رقم $saleId بنجاح');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatNumber(double value) {
    if (!value.isFinite) return '0';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatMoney(double value) => _formatNumber(value);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'فواتير المبيعات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: const Drawer(
          width: 280,
          backgroundColor: _background,
          child: Sidebar(),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
                color: _primary,
                onRefresh: _loadData,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final content = _buildSalesContent();

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: content),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 340,
                                      child: _buildSummary(),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    content,
                                    const SizedBox(height: 20),
                                    _buildSummary(),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildSalesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPageHeading(),
        const SizedBox(height: 20),
        _buildMarketerCard(),
        const SizedBox(height: 20),
        _buildProductCard(),
        const SizedBox(height: 20),
        _buildCartCard(),
        const SizedBox(height: 20),
        _buildCustomerPaymentCard(),
      ],
    );
  }

  Widget _buildPageHeading() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _lightBeige,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: const Icon(
            Icons.point_of_sale_outlined,
            color: _primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إنشاء فاتورة جديدة',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: _darkPrimary,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'اختر المسوق والمنتجات ثم راجع الإجمالي قبل الحفظ.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketerCard() {
    final parent = _referralParent;

    return _buildCard(
      title: 'بيانات المسوق',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المسوق المسؤول *',
            style: TextStyle(fontWeight: FontWeight.w600, color: _darkPrimary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedMarketerId,
            isExpanded: true,
            decoration: _inputDecoration('اختر المسوق'),
            items: _marketers.map((marketer) {
              final id = marketer['id'] as int;
              final name = marketer['name']?.toString().trim();
              final number = marketer['marketer_number'];

              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  [
                    if (number != null) 'رقم $number',
                    if (name != null && name.isNotEmpty) name,
                    if ((name == null || name.isEmpty) && number == null)
                      'مسوق #$id',
                  ].join(' - '),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _selectedMarketerId = value),
          ),
          if (_selectedMarketer != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عمولة المسوق: ${_formatNumber(_commissionRate)}%',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (parent != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'المسوق الرئيسي: '
                      '${parent['name']?.toString() ?? 'مسوق #${parent['id']}'}',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasReferralCommission
                          ? 'عمولة التبعية: '
                                '${_formatNumber(_referralCommissionRate)}% '
                                'من إجمالي البيع'
                          : 'عمولة التبعية غير مفعّلة لهذا المسوق الرئيسي',
                      style: TextStyle(
                        color: _hasReferralCommission
                            ? Colors.green.shade700
                            : Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_marketers.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'لا يوجد مسوقون نشطون. أضف مسوقًا أولًا.',
              style: TextStyle(color: _primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard() {
    final selectedProduct = _findProduct(_selectedProductId);
    final availableStock = selectedProduct == null
        ? null
        : (selectedProduct['stock_quantity'] as num?)?.toDouble() ?? 0;

    return _buildCard(
      title: 'إضافة المنتجات',
      icon: Icons.add_shopping_cart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'المنتج *',
            style: TextStyle(fontWeight: FontWeight.w600, color: _darkPrimary),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedProductId,
            isExpanded: true,
            decoration: _inputDecoration('اختر المنتج'),
            items: _products.map((product) {
              final id = product['id'] as int;
              final name = product['name']?.toString() ?? 'منتج';
              final stock =
                  (product['stock_quantity'] as num?)?.toDouble() ?? 0;
              final price = (product['selling_price'] as num?)?.toDouble() ?? 0;

              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  '$name — ${_formatMoney(price)} — المتوفر ${_formatNumber(stock)}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _selectedProductId = value),
          ),
          if (availableStock != null) ...[
            const SizedBox(height: 8),
            Text(
              'المخزون المتاح: ${_formatNumber(availableStock)}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration('الكمية'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving || _products.isEmpty
                      ? null
                      : _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_products.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'لا توجد منتجات نشطة لإضافتها إلى الفاتورة.',
              style: TextStyle(color: _primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartCard() {
    return _buildCard(
      title: 'المنتجات في الفاتورة',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 42, color: _gold),
                  SizedBox(height: 10),
                  Text(
                    'لم تتم إضافة منتجات بعد',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            )
          else
            ..._cart.map(_buildCartItem),
          const SizedBox(height: 12),
          const Text(
            'ملاحظات الفاتورة (اختياري)',
            style: TextStyle(fontWeight: FontWeight.w600, color: _darkPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            enabled: !_isSaving,
            maxLines: 2,
            maxLength: 300,
            decoration: _inputDecoration('أضف ملاحظة إن وجدت'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPaymentCard() {
    return _buildCard(
      title: 'بيانات الزبون والسداد',
      icon: Icons.person_pin_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _customerNameController,
            enabled: !_isSaving,
            decoration: _inputDecoration('اسم الزبون *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customerPhoneController,
            enabled: !_isSaving,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('رقم الزبون *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deliveryController,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('قيمة التوصيل (0 بدون توصيل)'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _lightBeige,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor),
            ),
            child: Text(
              'الإجمالي مع التوصيل: ${_formatMoney(_invoiceTotal)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _darkPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentChoice,
            isExpanded: true,
            decoration: _inputDecoration('طريقة السداد'),
            items: const [
              DropdownMenuItem(
                value: 'paid',
                child: Text('تم دفع المبلغ كاملًا'),
              ),
              DropdownMenuItem(
                value: 'partial',
                child: Text('دفع مقدم والباقي عند الاستلام'),
              ),
              DropdownMenuItem(
                value: 'unpaid',
                child: Text('المبلغ كاملًا عند الاستلام'),
              ),
            ],
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _paymentChoice = value ?? 'paid'),
          ),
          if (_paymentChoice == 'partial') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _initialPaymentController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('المبلغ المقدم *'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'المتبقي: ${_formatMoney(_paymentChoice == 'paid'
                ? 0
                : _paymentChoice == 'unpaid'
                ? _invoiceTotal
                : (_invoiceTotal - (double.tryParse(_initialPaymentController.text.trim()) ?? 0)).clamp(0, double.infinity).toDouble())}',
            style: const TextStyle(
              color: _darkPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'الفواتير غير المسددة ستظهر في سجل المبيعات حتى اكتمال التحصيل.',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSale,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'جارٍ حفظ الفاتورة...' : 'حفظ الفاتورة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(_SaleCartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _darkPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'حذف من الفاتورة',
                visualDensity: VisualDensity.compact,
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _cart.remove(item)),
                icon: const Icon(Icons.delete_outline, color: _primary),
              ),
            ],
          ),
          if (item.code.isNotEmpty)
            Text(
              'الكود: ${item.code}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('السعر: ${_formatMoney(item.sellingPrice)}'),
              Text(
                'الإجمالي: ${_formatMoney(item.quantity * item.sellingPrice)}',
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('الكمية:'),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _isSaving ? null : () => _changeQuantity(item, -1),
                icon: const Icon(Icons.remove_circle_outline, color: _primary),
              ),
              Text(
                _formatNumber(item.quantity),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _darkPrimary,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _isSaving ? null : () => _changeQuantity(item, 1),
                icon: const Icon(Icons.add_circle_outline, color: _primary),
              ),
              const Spacer(),
              Text(
                'المتوفر: ${_formatNumber(item.stockQuantity)}',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final totalAfterCommissions =
        _totalProfit - _commissionAmount - _referralCommissionAmount;

    return _buildCard(
      title: 'ملخص الفاتورة',
      icon: Icons.calculate_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryRow('عدد المنتجات', '${_cart.length}'),
          _summaryRow(
            'إجمالي الكميات',
            _formatNumber(
              _cart.fold<double>(0, (sum, item) => sum + item.quantity),
            ),
          ),
          const Divider(height: 24, color: _borderColor),
          _summaryRow(
            'إجمالي البيع',
            _formatMoney(_totalAmount),
            emphasized: true,
          ),
          _summaryRow('تكلفة المنتجات', _formatMoney(_totalCost)),
          _summaryRow(
            'الربح قبل العمولات',
            _formatMoney(_totalProfit),
            valueColor: _totalProfit >= 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          _summaryRow(
            'عمولة المسوق (${_formatNumber(_commissionRate)}%)',
            _formatMoney(_commissionAmount),
          ),
          if (_hasReferralCommission)
            _summaryRow(
              'عمولة المسوق الرئيسي (${_formatNumber(_referralCommissionRate)}%)',
              _formatMoney(_referralCommissionAmount),
              valueColor: _primary,
            ),
          const Divider(height: 24, color: _borderColor),
          _summaryRow(
            'الربح بعد العمولات',
            _formatMoney(totalAfterCommissions),
            emphasized: true,
            valueColor: totalAfterCommissions >= 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          const SizedBox(height: 12),
          const Text(
            'العمولة الشخصية محسوبة من الربح الموجب فقط، '
            'وعمولة المسوق الرئيسي من إجمالي البيع. '
            'تُسجّل عمولة التبعية للمسوق الرئيسي المباشر فقط.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasized = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasized ? 14 : 12,
                fontWeight: emphasized ? FontWeight.bold : FontWeight.normal,
                color: emphasized ? _darkPrimary : Colors.blueGrey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (emphasized ? _primary : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: _darkPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _lightBeige,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.blueGrey),
      filled: true,
      fillColor: _fieldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }
}

class _SaleCartItem {
  _SaleCartItem({
    required this.productId,
    required this.name,
    required this.code,
    required this.stockQuantity,
    required this.sellingPrice,
    required this.purchasePrice,
    required this.quantity,
  });

  final int productId;
  final String name;
  final String code;
  final double stockQuantity;
  final double sellingPrice;
  final double purchasePrice;
  double quantity;
}
