import 'dart:convert';

import 'package:flutter/material.dart';

import '../../database/database_helper.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  static const Color _primary = Color(0xFF1E4FA3);
  static const Color _background = Color(0xFFF5F7FB);

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _selectedAction = 'all';
  String _selectedEntity = 'all';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLogs() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final db = await DatabaseHelper.instance.database;

      final result = await db.rawQuery('''
        SELECT
          id,
          action,
          entity_type,
          entity_id,
          description,
          old_values,
          new_values,
          created_at
        FROM audit_logs
        ORDER BY id DESC
      ''');

      if (!mounted) return;

      setState(() {
        _logs = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل سجل التدقيق: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final query = _searchController.text.trim().toLowerCase();

    return _logs.where((log) {
      final action = log['action']?.toString() ?? '';
      final entity = log['entity_type']?.toString() ?? '';
      final description = log['description']?.toString() ?? '';
      final entityId = log['entity_id']?.toString() ?? '';
      final logId = log['id']?.toString() ?? '';

      final matchesSearch =
          query.isEmpty ||
          description.toLowerCase().contains(query) ||
          entityId.contains(query) ||
          logId.contains(query) ||
          _actionName(action).contains(query) ||
          _entityName(entity).contains(query);

      final matchesAction =
          _selectedAction == 'all' || action == _selectedAction;

      final matchesEntity =
          _selectedEntity == 'all' || entity == _selectedEntity;

      bool matchesDate = true;

      if (_selectedDate != null) {
        final date = DateTime.tryParse(log['created_at']?.toString() ?? '');

        matchesDate =
            date != null &&
            date.year == _selectedDate!.year &&
            date.month == _selectedDate!.month &&
            date.day == _selectedDate!.day;
      }

      return matchesSearch && matchesAction && matchesEntity && matchesDate;
    }).toList();
  }

  String _actionName(String action) {
    switch (action) {
      case 'create':
        return 'إضافة';
      case 'update':
        return 'تعديل';
      case 'delete':
        return 'حذف';
      case 'deactivate':
        return 'تعطيل';
      case 'activate':
        return 'تفعيل';
      case 'login':
        return 'تسجيل دخول';
      case 'logout':
        return 'تسجيل خروج';
      default:
        return action.isEmpty ? 'غير محدد' : action;
    }
  }

  String _entityName(String entity) {
    switch (entity) {
      case 'marketer':
        return 'المسوقون';
      case 'marketer_code':
      case 'code':
        return 'الأرقام والأكواد';
      case 'product':
        return 'المنتجات';
      case 'sale':
        return 'المبيعات';
      case 'order':
        return 'الطلبات';
      case 'expense':
        return 'المصروفات';
      case 'stock':
      case 'stock_movement':
        return 'المخزون';
      case 'user':
        return 'المستخدمون';
      default:
        return entity.isEmpty ? 'غير محدد' : entity;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'deactivate':
        return Icons.block_outlined;
      case 'activate':
        return Icons.check_circle_outline;
      case 'login':
        return Icons.login_outlined;
      case 'logout':
        return Icons.logout_outlined;
      default:
        return Icons.history_outlined;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create':
      case 'activate':
        return const Color(0xFF2E7D32);
      case 'update':
        return _primary;
      case 'delete':
      case 'deactivate':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF616161);
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Map<String, dynamic>? _decodeValues(dynamic value) {
    if (value == null) return null;

    try {
      final decoded = value is String ? jsonDecode(value) : value;

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return {'value': value.toString()};
    }

    return null;
  }

  String _fieldName(String key) {
    switch (key) {
      case 'id':
        return 'المعرّف';
      case 'name':
        return 'الاسم';
      case 'phone':
        return 'رقم الهاتف';
      case 'parent_id':
        return 'معرّف الداعي';
      case 'parent_number':
        return 'رقم الداعي';
      case 'parent_code':
        return 'كود الداعي';
      case 'commission_rate':
        return 'العمولة الشخصية';
      case 'receives_referral_commission':
        return 'استحقاق عمولة التبعية';
      case 'referral_commission_rate':
        return 'نسبة عمولة التبعية';
      case 'marketer_number':
        return 'رقم المسوق';
      case 'code':
        return 'الكود';
      case 'code_id':
        return 'معرّف الرقم والكود';
      case 'marketer_id':
        return 'معرّف المسوق';
      case 'is_active':
        return 'حالة التفعيل';
      case 'code_released':
        return 'تحرير الرقم والكود';
      case 'created_at':
        return 'تاريخ الإنشاء';
      case 'updated_at':
        return 'تاريخ التعديل';
      case 'purchase_price':
        return 'سعر الشراء';
      case 'selling_price':
        return 'سعر البيع';
      case 'stock_quantity':
        return 'الكمية';
      case 'description':
        return 'الوصف';
      default:
        return key;
    }
  }

  String _formatValue(String key, dynamic value) {
    if (value == null) return 'لا يوجد';

    if (key == 'is_active' ||
        key == 'receives_referral_commission' ||
        key == 'code_released') {
      final enabled = value == true || value.toString() == '1';

      return enabled ? 'نعم' : 'لا';
    }

    if (value is bool) return value ? 'نعم' : 'لا';

    if (value is Map || value is List) {
      return jsonEncode(value);
    }

    return value.toString();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _selectedAction = 'all';
      _selectedEntity = 'all';
      _selectedDate = null;
    });
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final oldValues = _decodeValues(log['old_values']);
    final newValues = _decodeValues(log['new_values']);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.manage_history_outlined, color: _primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تفاصيل العملية',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow('رقم السجل', log['id']?.toString() ?? '-'),
                    _detailRow(
                      'نوع العملية',
                      _actionName(log['action']?.toString() ?? ''),
                    ),
                    _detailRow(
                      'القسم',
                      _entityName(log['entity_type']?.toString() ?? ''),
                    ),
                    _detailRow(
                      'معرّف العنصر',
                      log['entity_id']?.toString() ?? '-',
                    ),
                    _detailRow(
                      'التاريخ والوقت',
                      _formatDate(log['created_at']),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'وصف العملية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(log['description']?.toString() ?? '-'),
                    const SizedBox(height: 20),
                    _buildValuesSection(
                      title: 'البيانات قبل العملية',
                      values: oldValues,
                      color: const Color(0xFFC62828),
                    ),
                    const SizedBox(height: 14),
                    _buildValuesSection(
                      title: 'البيانات بعد العملية',
                      values: newValues,
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _buildValuesSection({
    required String title,
    required Map<String, dynamic>? values,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (values == null || values.isEmpty)
            const Text(
              'لا توجد بيانات مسجلة',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            )
          else
            ...values.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _fieldName(entry.key),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: SelectableText(
                        _formatValue(entry.key, entry.value),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final entityTypes =
        _logs
            .map((item) => item['entity_type']?.toString() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث في وصف العملية أو رقم السجل أو العنصر',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 550;

              final actionFilter = DropdownButtonFormField<String>(
                value: _selectedAction,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع العملية',
                  prefixIcon: Icon(Icons.tune_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('جميع العمليات')),
                  DropdownMenuItem(value: 'create', child: Text('إضافة')),
                  DropdownMenuItem(value: 'update', child: Text('تعديل')),
                  DropdownMenuItem(value: 'deactivate', child: Text('تعطيل')),
                  DropdownMenuItem(value: 'activate', child: Text('تفعيل')),
                  DropdownMenuItem(value: 'delete', child: Text('حذف')),
                  DropdownMenuItem(value: 'login', child: Text('تسجيل دخول')),
                  DropdownMenuItem(value: 'logout', child: Text('تسجيل خروج')),
                ],
                onChanged: (value) {
                  setState(() => _selectedAction = value ?? 'all');
                },
              );

              final entityFilter = DropdownButtonFormField<String>(
                value: _selectedEntity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'القسم',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('جميع الأقسام'),
                  ),
                  ...entityTypes.map(
                    (entity) => DropdownMenuItem(
                      value: entity,
                      child: Text(_entityName(entity)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedEntity = value ?? 'all');
                },
              );

              final dateFilter = OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _selectedDate == null
                      ? 'اختيار التاريخ'
                      : '${_selectedDate!.year}-'
                            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
                            '${_selectedDate!.day.toString().padLeft(2, '0')}',
                ),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actionFilter,
                    const SizedBox(height: 10),
                    entityFilter,
                    const SizedBox(height: 10),
                    dateFilter,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: actionFilter),
                  const SizedBox(width: 10),
                  Expanded(child: entityFilter),
                  const SizedBox(width: 10),
                  dateFilter,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('مسح الفلاتر'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action']?.toString() ?? '';
    final entity = log['entity_type']?.toString() ?? '';
    final color = _actionColor(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showLogDetails(log),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_actionIcon(action), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _entityName(entity),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _actionName(action),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      log['description']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 14,
                      runSpacing: 5,
                      children: [
                        _smallInfo(
                          Icons.access_time_outlined,
                          _formatDate(log['created_at']),
                        ),
                        _smallInfo(Icons.tag_outlined, 'سجل #${log['id']}'),
                        if (log['entity_id'] != null)
                          _smallInfo(
                            Icons.numbers_outlined,
                            'العنصر #${log['entity_id']}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallInfo(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_outlined,
              size: 65,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              'لا توجد عمليات لعرضها',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر هنا العمليات المسجلة التي تطابق خيارات البحث والتصفية.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'سجل التدقيق',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث السجل',
              onPressed: _isLoading ? null : _loadLogs,
              icon: const Icon(Icons.refresh_outlined),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadLogs,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFilters(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.manage_history_outlined,
                          color: _primary,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'العمليات المسجلة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${filteredLogs.length} عملية',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filteredLogs.isEmpty)
                      SizedBox(height: 250, child: _buildEmptyState())
                    else
                      ...filteredLogs.map(_buildLogCard),
                  ],
                ),
              ),
      ),
    );
  }
}
