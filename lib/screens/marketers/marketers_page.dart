import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class MarketersPage extends StatefulWidget {
  const MarketersPage({super.key});

  @override
  State<MarketersPage> createState() => _MarketersPageState();
}

class _MarketersPageState extends State<MarketersPage> {
  List<Map<String, dynamic>> _marketers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarketers();
  }

  // =========================
  // تحميل المسوقين
  // =========================

  Future<void> _loadMarketers() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final marketers = await db.rawQuery('''
        SELECT
          marketers.id,
          marketers.name,
          marketers.phone,
          marketers.parent_id,
          marketers.commission_rate,
          marketers.is_active,
          marketers.created_at,
          marketers.updated_at,
          codes.code
        FROM marketers
        LEFT JOIN codes
          ON marketers.id = codes.marketer_id
          AND codes.is_active = 1
        WHERE marketers.is_active = 1
        ORDER BY marketers.id DESC
      ''');

      if (!mounted) return;

      setState(() {
        _marketers = marketers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل المسوقين: $e')),
      );
    }
  }

  // =========================
  // إضافة مسوق
  // =========================

  Future<void> _addMarketer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return const _MarketerDialog();
      },
    );

    if (result == true) {
      await _loadMarketers();
    }
  }

  // =========================
  // تعديل مسوق
  // =========================

  Future<void> _editMarketer(Map<String, dynamic> marketer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _MarketerDialog(marketer: marketer);
      },
    );

    if (result == true) {
      await _loadMarketers();
    }
  }

  // =========================
  // تعطيل مسوق
  // =========================

  Future<void> _deactivateMarketer(Map<String, dynamic> marketer) async {
    final marketerId = marketer['id'];

    if (marketerId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعطيل المسوق'),
          content: Text(
            'هل تريد تعطيل المسوق "${marketer['name'] ?? '-'}"؟\n\n'
            'لن يظهر المسوق في القائمة النشطة، '
            'لكن بياناته ستبقى محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('تعطيل'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;

      await db.update(
        'marketers',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [marketerId],
      );

      await _loadMarketers();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعطيل المسوق بنجاح')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تعطيل المسوق: $e')));
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
          title: const Text(
            'المسوقون',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadMarketers,
                child: _marketers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _marketers.length,
                        itemBuilder: (context, index) {
                          return _buildMarketerCard(_marketers[index]);
                        },
                      ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addMarketer,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('إضافة مسوق'),
        ),
      ),
    );
  }

  // =========================
  // الحالة الفارغة
  // =========================

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 80),

        Icon(Icons.people_outline, size: 70, color: Colors.grey.shade400),

        const SizedBox(height: 18),

        const Center(
          child: Text(
            'لا يوجد مسوقون حتى الآن',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Text(
            'اضغط على "إضافة مسوق" لإنشاء أول مسوق',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  // =========================
  // بطاقة المسوق
  // =========================

  Widget _buildMarketerCard(Map<String, dynamic> marketer) {
    final name = marketer['name']?.toString() ?? '-';

    final phone = marketer['phone']?.toString() ?? '-';

    final code = marketer['code']?.toString();

    final commission = (marketer['commission_rate'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF1E4FA3),
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
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          phone,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editMarketer(marketer);
                  } else if (value == 'deactivate') {
                    _deactivateMarketer(marketer);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 10),
                        Text('تعطيل'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(height: 1),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.badge_outlined,
                  title: 'الكود',
                  value: code == null || code.isEmpty ? 'بدون كود' : code,
                ),
              ),

              Container(width: 1, height: 35, color: const Color(0xFFE5E7EB)),

              Expanded(
                child: _buildInfoItem(
                  icon: Icons.percent,
                  title: 'العمولة',
                  value: '${_formatNumber(commission)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF1E4FA3)),

        const SizedBox(width: 7),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 2),

            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

// ============================================================
// نافذة إضافة / تعديل المسوق
// ============================================================

class _MarketerDialog extends StatefulWidget {
  final Map<String, dynamic>? marketer;

  const _MarketerDialog({this.marketer});

  @override
  State<_MarketerDialog> createState() => _MarketerDialogState();
}

class _MarketerDialogState extends State<_MarketerDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _commissionController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.marketer != null;

  @override
  void initState() {
    super.initState();

    final marketer = widget.marketer;

    if (marketer != null) {
      _nameController.text = marketer['name']?.toString() ?? '';

      _phoneController.text = marketer['phone']?.toString() ?? '';

      _codeController.text = marketer['code']?.toString() ?? '';

      final commission = (marketer['commission_rate'] as num?)?.toDouble() ?? 0;

      _commissionController.text = _formatNumber(commission);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _commissionController.dispose();

    super.dispose();
  }

  // =========================
  // حفظ المسوق
  // =========================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final name = _nameController.text.trim();

      final phoneText = _phoneController.text.trim();
      final phone = phoneText.isEmpty ? null : phoneText;

      final codeText = _codeController.text.trim();
      final code = codeText.isEmpty ? null : codeText;

      final commission =
          double.tryParse(_commissionController.text.trim()) ?? 0;

      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        // ====================================================
        // تعديل مسوق
        // ====================================================

        if (_isEditing) {
          final marketerId = widget.marketer!['id'];

          await txn.update(
            'marketers',
            {
              'name': name,
              'phone': phone,
              'commission_rate': commission,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [marketerId],
          );

          // حذف الكود القديم إذا كان موجودًا
          await txn.delete(
            'codes',
            where: 'marketer_id = ?',
            whereArgs: [marketerId],
          );

          // إضافة الكود الجديد فقط إذا تم إدخاله
          if (code != null) {
            await txn.insert('codes', {
              'marketer_id': marketerId,
              'code': code,
              'created_at': now,
              'is_active': 1,
            });
          }
        }
        // ====================================================
        // إضافة مسوق جديد
        // ====================================================
        else {
          final marketerId = await txn.rawInsert(
            '''
            INSERT INTO marketers (
              name,
              phone,
              parent_id,
              commission_rate,
              is_active,
              created_at,
              updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ''',
            [name, phone, null, commission, 1, now, now],
          );

          // إضافة الكود فقط إذا أدخله المستخدم
          if (code != null) {
            await txn.insert('codes', {
              'marketer_id': marketerId,
              'code': code,
              'created_at': now,
              'is_active': 1,
            });
          }
        }
      });

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      // معالجة تكرار الكود
      if (message.contains('UNIQUE constraint failed')) {
        message = 'هذا الكود مستخدم بالفعل، اختر كودًا آخر.';
      } else {
        message = message.replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ المسوق: $message')),
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
      child: AlertDialog(
        title: Text(
          _isEditing ? 'تعديل المسوق' : 'إضافة مسوق',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        content: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // =========================
                  // الاسم
                  // =========================
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المسوق',
                      hintText: 'أدخل اسم المسوق',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'اسم المسوق مطلوب';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // =========================
                  // الهاتف
                  // =========================
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: 'اختياري',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // =========================
                  // الكود
                  // =========================
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود المسوق',
                      hintText: 'اختياري',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'يمكنك ترك الكود فارغًا.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // =========================
                  // العمولة
                  // =========================
                  TextFormField(
                    controller: _commissionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'نسبة العمولة',
                      hintText: 'مثال: 5',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'نسبة العمولة مطلوبة';
                      }

                      final number = double.tryParse(value.trim());

                      if (number == null) {
                        return 'أدخل رقمًا صحيحًا';
                      }

                      if (number < 0 || number > 100) {
                        return 'النسبة يجب أن تكون بين 0 و100';
                      }

                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // =========================
        // الأزرار
        // =========================
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
                    Navigator.pop(context);
                  },
            child: const Text('إلغاء'),
          ),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,

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

            label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}
