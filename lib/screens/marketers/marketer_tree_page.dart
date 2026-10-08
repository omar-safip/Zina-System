import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class MarketersPage extends StatefulWidget {
  const MarketersPage({super.key});

  @override
  State<MarketersPage> createState() => _MarketersPageState();
}

class _MarketersPageState extends State<MarketersPage> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  List<Map<String, dynamic>> _marketers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarketers();
  }

  Future<void> _loadMarketers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _database.database;

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

  Future<void> _openAddMarketer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _MarketerDialog(marketers: _marketers);
      },
    );

    if (result == true) {
      await _loadMarketers();
    }
  }

  Future<void> _openEditMarketer(Map<String, dynamic> marketer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _MarketerDialog(marketers: _marketers, marketer: marketer);
      },
    );

    if (result == true) {
      await _loadMarketers();
    }
  }

  Future<void> _deactivateMarketer(Map<String, dynamic> marketer) async {
    final marketerId = marketer['id'];

    if (marketerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعطيل المسوق'),
          content: Text(
            'هل تريد تعطيل المسوق "${marketer['name']}"؟\n\n'
            'لن يظهر المسوق في القائمة الحالية، '
            'لكن بياناته ستبقى محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تعطيل'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final db = await _database.database;

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('المسوقون')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddMarketer,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة مسوق'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _marketers.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadMarketers,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _marketers.length,
                  itemBuilder: (context, index) {
                    final marketer = _marketers[index];

                    return _buildMarketerCard(marketer);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 70, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد مسوقون حاليًا',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على "إضافة مسوق" لإضافة أول مسوق',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketerCard(Map<String, dynamic> marketer) {
    final name = marketer['name']?.toString() ?? '-';
    final phone = marketer['phone']?.toString() ?? '';
    final code = marketer['code']?.toString();
    final commission = (marketer['commission_rate'] as num?)?.toDouble() ?? 0;

    final parentId = marketer['parent_id'];

    String? parentName;

    if (parentId != null) {
      for (final item in _marketers) {
        if (item['id'] == parentId) {
          parentName = item['name']?.toString();
          break;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              child: Text(
                name.isNotEmpty ? name.characters.first : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (phone.isNotEmpty)
                    _InfoRow(icon: Icons.phone_outlined, text: phone),

                  _InfoRow(
                    icon: Icons.qr_code_2_outlined,
                    text: code == null || code.isEmpty
                        ? 'بدون كود'
                        : 'الكود: $code',
                  ),

                  _InfoRow(
                    icon: Icons.percent,
                    text: 'العمولة: ${commission.toStringAsFixed(2)}%',
                  ),

                  if (parentName != null)
                    _InfoRow(
                      icon: Icons.account_tree_outlined,
                      text: 'المسوق الأب: $parentName',
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditMarketer(marketer);
                } else if (value == 'deactivate') {
                  _deactivateMarketer(marketer);
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('تعطيل'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> marketers;
  final Map<String, dynamic>? marketer;

  const _MarketerDialog({required this.marketers, this.marketer});

  @override
  State<_MarketerDialog> createState() => _MarketerDialogState();
}

class _MarketerDialogState extends State<_MarketerDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _commissionController = TextEditingController();

  int? _selectedParentId;
  bool _isSaving = false;

  bool get _isEditing => widget.marketer != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final marketer = widget.marketer!;

      _nameController.text = marketer['name']?.toString() ?? '';

      _phoneController.text = marketer['phone']?.toString() ?? '';

      _codeController.text = marketer['code']?.toString() ?? '';

      _commissionController.text =
          ((marketer['commission_rate'] as num?)?.toDouble() ?? 0).toString();

      final parentId = marketer['parent_id'];

      if (parentId != null) {
        _selectedParentId = parentId is int
            ? parentId
            : int.tryParse(parentId.toString());
      }
    } else {
      _commissionController.text = '0';
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

  List<Map<String, dynamic>> get _parentOptions {
    final currentId = widget.marketer?['id'];

    return widget.marketers.where((marketer) {
      final id = marketer['id'];

      // لا تسمح للمسوق باختيار نفسه كأب
      if (currentId != null && id == currentId) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final codeText = _codeController.text.trim();
    final code = codeText.isEmpty ? null : codeText;

    final commission = double.tryParse(_commissionController.text.trim());

    if (commission == null || commission < 0 || commission > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نسبة العمولة يجب أن تكون بين 0 و100')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        if (_isEditing) {
          final marketerId = widget.marketer!['id'];

          await txn.update(
            'marketers',
            {
              'name': name,
              'phone': phone,
              'parent_id': _selectedParentId,
              'commission_rate': commission,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [marketerId],
          );

          // حذف الكود القديم
          await txn.delete(
            'codes',
            where: 'marketer_id = ?',
            whereArgs: [marketerId],
          );

          // إضافة الكود الجديد إذا تم إدخاله
          if (code != null) {
            await txn.insert('codes', {
              'marketer_id': marketerId,
              'code': code,
              'created_at': now,
              'is_active': 1,
            });
          }
        } else {
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
            [name, phone, _selectedParentId, commission, 1, now, now],
          );

          // إضافة الكود فقط إذا تم إدخاله
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

      setState(() {
        _isSaving = false;
      });

      String message = 'حدث خطأ أثناء حفظ المسوق';

      if (e.toString().contains('UNIQUE constraint failed')) {
        message = 'هذا الكود مستخدم بالفعل لمسوق آخر';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = _parentOptions;

    return AlertDialog(
      title: Text(_isEditing ? 'تعديل المسوق' : 'إضافة مسوق'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المسوق',
                    hintText: 'أدخل اسم المسوق',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'اسم المسوق مطلوب';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: 'اختياري',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'كود المسوق',
                    hintText: 'اختياري',
                    prefixIcon: Icon(Icons.qr_code_2_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<int?>(
                  value: _selectedParentId,
                  decoration: const InputDecoration(
                    labelText: 'المسوق الأب',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('بدون مسوق أب'),
                    ),
                    ...parentOptions.map((parent) {
                      final id = parent['id'];

                      final parentId = id is int
                          ? id
                          : int.tryParse(id.toString());

                      return DropdownMenuItem<int?>(
                        value: parentId,
                        child: Text(parent['name']?.toString() ?? '-'),
                      );
                    }),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedParentId = value;
                          });
                        },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller: _commissionController,
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة',
                    hintText: 'مثال: 5',
                    prefixIcon: Icon(Icons.percent),
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'نسبة العمولة مطلوبة';
                    }

                    final commission = double.tryParse(value.trim());

                    if (commission == null) {
                      return 'أدخل رقمًا صحيحًا';
                    }

                    if (commission < 0 || commission > 100) {
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
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade600),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
