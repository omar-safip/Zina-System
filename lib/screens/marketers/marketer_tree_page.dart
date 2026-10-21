import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../widgets/sidebar.dart';
import 'marketer_report_page.dart';

class MarketerTreePage extends StatefulWidget {
  const MarketerTreePage({super.key});

  @override
  State<MarketerTreePage> createState() => _MarketersPageState();
}

class _MarketersPageState extends State<MarketerTreePage> {
  static const Color _burgundy = Color(0xFF70263D);
  static const Color _darkBurgundy = Color(0xFF4E192C);
  static const Color _gold = Color(0xFFC5A15A);
  static const Color _beige = Color(0xFFFAF5EC);
  static const Color _lightBeige = Color(0xFFF2E7D5);
  static const Color _borderColor = Color(0xFFE8DCCB);

  final DatabaseHelper _database = DatabaseHelper.instance;

  List<Map<String, dynamic>> _marketers = [];
  final Set<int> _expandedMarketers = {};
  bool _isLoading = true;

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _loadMarketers();
  }

  Future<void> _loadMarketers() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

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
          (
            SELECT codes.code
            FROM codes
            WHERE codes.marketer_id = marketers.id
              AND codes.is_active = 1
            ORDER BY codes.id DESC
            LIMIT 1
          ) AS code
        FROM marketers
        WHERE marketers.is_active = 1
        ORDER BY marketers.id DESC
      ''');

      if (!mounted) return;

      final activeIds = marketers
          .map((item) => _toInt(item['id']))
          .whereType<int>()
          .toSet();

      setState(() {
        _marketers = marketers;
        _expandedMarketers.removeWhere((id) => !activeIds.contains(id));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل المسوقين: $e')),
      );
    }
  }

  Future<void> _openReport(Map<String, dynamic> marketer) async {
    final marketerId = _toInt(marketer['id']);
    if (marketerId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketerReportPage(
          marketerId: marketerId,
          marketerName: marketer['name']?.toString() ?? 'المسوق',
        ),
      ),
    );
  }

  Future<void> _openAddMarketer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _MarketerDialog(marketers: _marketers),
    );

    if (result == true) {
      await _loadMarketers();
    }
  }

  Future<void> _openEditMarketer(Map<String, dynamic> marketer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _MarketerDialog(marketers: _marketers, marketer: marketer),
    );

    if (result == true) {
      await _loadMarketers();
    }
  }

  Future<void> _deactivateMarketer(Map<String, dynamic> marketer) async {
    final marketerId = _toInt(marketer['id']);
    if (marketerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل المسوق'),
        content: Text(
          'هل تريد تعطيل المسوق "${marketer['name']}"؟\n\n'
          'ستبقى بياناته محفوظة في قاعدة البيانات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _burgundy,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تعطيل'),
          ),
        ],
      ),
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

  List<Map<String, dynamic>> _childrenOf(int parentId) {
    return _marketers.where((marketer) {
      return _toInt(marketer['parent_id']) == parentId;
    }).toList();
  }

  List<Map<String, dynamic>> get _rootMarketers {
    final activeIds = _marketers
        .map((marketer) => _toInt(marketer['id']))
        .whereType<int>()
        .toSet();

    final roots = _marketers.where((marketer) {
      final parentId = _toInt(marketer['parent_id']);
      return parentId == null || !activeIds.contains(parentId);
    }).toList();

    return roots.isEmpty && _marketers.isNotEmpty ? _marketers : roots;
  }

  void _toggleExpanded(int marketerId) {
    setState(() {
      if (_expandedMarketers.contains(marketerId)) {
        _expandedMarketers.remove(marketerId);
      } else {
        _expandedMarketers.add(marketerId);
      }
    });
  }

  Widget _buildTreeNode(
    Map<String, dynamic> marketer, {
    int depth = 0,
    Set<int> ancestors = const {},
  }) {
    final id = _toInt(marketer['id']);
    if (id == null) return const SizedBox.shrink();

    if (ancestors.contains(id)) {
      return const SizedBox.shrink();
    }

    final children = _childrenOf(id);
    final hasChildren = children.any(
      (child) => !ancestors.contains(_toInt(child['id'])),
    );
    final isExpanded = _expandedMarketers.contains(id);

    final name = marketer['name']?.toString() ?? '-';
    final phone = marketer['phone']?.toString() ?? '';
    final code = marketer['code']?.toString() ?? '';
    final commission = (marketer['commission_rate'] as num?)?.toDouble() ?? 0;

    final nextAncestors = <int>{...ancestors, id};

    return Padding(
      padding: EdgeInsets.only(right: depth == 0 ? 0 : 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.white,
            margin: EdgeInsets.zero,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: depth == 0
                    ? _burgundy.withValues(alpha: 0.30)
                    : _borderColor,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openReport(marketer),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasChildren)
                      IconButton(
                        tooltip: isExpanded ? 'طيّ الفرع' : 'عرض التابعين',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleExpanded(id),
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_left,
                          color: _burgundy,
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                    CircleAvatar(
                      backgroundColor: depth == 0 ? _burgundy : _lightBeige,
                      foregroundColor: depth == 0 ? Colors.white : _burgundy,
                      child: Text(
                        name.isNotEmpty ? name.characters.first : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _darkBurgundy,
                            ),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _InfoRow(icon: Icons.phone_outlined, text: phone),
                          ],
                          const SizedBox(height: 4),
                          _InfoRow(
                            icon: Icons.qr_code_2_outlined,
                            text: code.isEmpty ? 'بدون كود' : 'الكود: $code',
                          ),
                          const SizedBox(height: 4),
                          _InfoRow(
                            icon: Icons.percent,
                            text: 'العمولة: ${commission.toStringAsFixed(2)}%',
                          ),
                          if (hasChildren) ...[
                            const SizedBox(height: 5),
                            Text(
                              'عدد المسوقين التابعين: ${children.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          const Text(
                            'اضغط لعرض التقرير',
                            style: TextStyle(
                              fontSize: 11,
                              color: _burgundy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'إجراءات المسوق',
                      iconColor: _burgundy,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openEditMarketer(marketer);
                        } else if (value == 'deactivate') {
                          _deactivateMarketer(marketer);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: _burgundy),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'deactivate',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('تعطيل'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasChildren && isExpanded)
            ...children.map(
              (child) => _buildTreeNode(
                child,
                depth: depth + 1,
                ancestors: nextAncestors,
              ),
            ),
        ],
      ),
    );
  }

  void _expandAll() {
    setState(() {
      _expandedMarketers.addAll(
        _marketers
            .where(
              (marketer) =>
                  _childrenOf(_toInt(marketer['id']) ?? -1).isNotEmpty,
            )
            .map((marketer) => _toInt(marketer['id']))
            .whereType<int>(),
      );
    });
  }

  void _collapseAll() {
    setState(() => _expandedMarketers.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _beige,
        drawer: const Drawer(child: Sidebar()),
        appBar: AppBar(
          backgroundColor: _darkBurgundy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'شجرة المسوقين',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'توسيع الفروع',
              onPressed: _marketers.isEmpty ? null : _expandAll,
              icon: const Icon(Icons.account_tree_outlined),
            ),
            IconButton(
              tooltip: 'طيّ الفروع',
              onPressed: _collapseAll,
              icon: const Icon(Icons.unfold_less),
            ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _burgundy,
          foregroundColor: Colors.white,
          onPressed: _openAddMarketer,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('إضافة مسوق'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _burgundy))
            : _marketers.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                color: _burgundy,
                onRefresh: _loadMarketers,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _lightBeige,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _burgundy),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'إجمالي المسوقين النشطين: ${_marketers.length}. '
                              'اضغط على بطاقة المسوق لعرض تقريره، '
                              'وعلى السهم لعرض التابعين.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: _darkBurgundy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._rootMarketers.map(
                      (marketer) => _buildTreeNode(marketer),
                    ),
                  ],
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
          const Icon(Icons.people_outline, size: 70, color: _gold),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد مسوقون حاليًا',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _darkBurgundy,
            ),
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
}

class _MarketerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> marketers;
  final Map<String, dynamic>? marketer;

  const _MarketerDialog({required this.marketers, this.marketer});

  @override
  State<_MarketerDialog> createState() => _MarketerDialogState();
}

class _MarketerDialogState extends State<_MarketerDialog> {
  static const Color _burgundy = Color(0xFF70263D);
  static const Color _darkBurgundy = Color(0xFF4E192C);

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _commissionController = TextEditingController();

  int? _selectedParentId;
  bool _isSaving = false;

  bool get _isEditing => widget.marketer != null;

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Set<int> _descendantIds(int marketerId) {
    final descendants = <int>{};

    void visit(int parentId) {
      for (final item in widget.marketers) {
        if (_toInt(item['parent_id']) == parentId) {
          final childId = _toInt(item['id']);

          if (childId != null && descendants.add(childId)) {
            visit(childId);
          }
        }
      }
    }

    visit(marketerId);
    return descendants;
  }

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

      _selectedParentId = _toInt(marketer['parent_id']);
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
    final currentId = _toInt(widget.marketer?['id']);
    final forbiddenIds = <int>{};

    if (currentId != null) {
      forbiddenIds.add(currentId);
      forbiddenIds.addAll(_descendantIds(currentId));
    }

    return widget.marketers.where((marketer) {
      final id = _toInt(marketer['id']);
      return id != null && !forbiddenIds.contains(id);
    }).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

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

    final currentId = _toInt(widget.marketer?['id']);

    if (currentId != null &&
        (_selectedParentId == currentId ||
            _descendantIds(currentId).contains(_selectedParentId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن اختيار المسوق نفسه أو أحد أبنائه كمسوق أب'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.transaction((txn) async {
        if (_isEditing) {
          final marketerId = currentId!;

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

          await txn.update(
            'codes',
            {'is_active': 0},
            where: 'marketer_id = ? AND is_active = 1',
            whereArgs: [marketerId],
          );

          if (code != null) {
            final existingCode = await txn.query(
              'codes',
              columns: ['id'],
              where: 'code = ? AND is_active = 1',
              whereArgs: [code],
              limit: 1,
            );

            if (existingCode.isNotEmpty) {
              throw Exception('DUPLICATE_CODE');
            }

            await txn.insert('codes', {
              'marketer_id': marketerId,
              'code': code,
              'created_at': now,
              'is_active': 1,
            });
          }
        } else {
          if (code != null) {
            final existingCode = await txn.query(
              'codes',
              columns: ['id'],
              where: 'code = ? AND is_active = 1',
              whereArgs: [code],
              limit: 1,
            );

            if (existingCode.isNotEmpty) {
              throw Exception('DUPLICATE_CODE');
            }
          }

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

      setState(() => _isSaving = false);

      final message =
          e.toString().contains('DUPLICATE_CODE') ||
              e.toString().contains('UNIQUE constraint failed')
          ? 'هذا الكود مستخدم بالفعل لمسوق آخر'
          : 'حدث خطأ أثناء حفظ المسوق: $e';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = _parentOptions;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _burgundy,
            secondary: const Color(0xFFC5A15A),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _burgundy, width: 1.5),
            ),
          ),
        ),
        child: AlertDialog(
          title: Text(
            _isEditing ? 'تعديل المسوق' : 'إضافة مسوق',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _darkBurgundy,
            ),
          ),
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
                          final parentId = _toInt(parent['id']);

                          return DropdownMenuItem<int?>(
                            value: parentId,
                            child: Text(parent['name']?.toString() ?? '-'),
                          );
                        }),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _selectedParentId = value);
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
              onPressed: _isSaving ? null : () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _burgundy,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF70263D)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
