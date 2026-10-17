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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMarketers();
    _searchController.addListener(_filterMarketers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMarketers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketers() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final marketers = await db.rawQuery('''
        SELECT
          marketers.id,
          marketers.name,
          marketers.phone,
          marketers.parent_id,
          parent_codes.marketer_number AS parent_number,
          parent_codes.code AS parent_code,
          marketers.commission_rate,
          marketers.receives_referral_commission,
          marketers.referral_commission_rate,
          marketers.is_active,
          marketers.created_at,
          marketers.updated_at,
          codes.id AS code_id,
          codes.marketer_number,
          codes.code
        FROM marketers
        LEFT JOIN codes
          ON marketers.id = codes.marketer_id
          AND codes.is_active = 1
        LEFT JOIN marketers AS parent_marketers
          ON marketers.parent_id = parent_marketers.id
        LEFT JOIN codes AS parent_codes
          ON parent_marketers.id = parent_codes.marketer_id
          AND parent_codes.is_active = 1
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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل المسوقين: $e')),
      );
    }
  }

  void _filterMarketers() {
    setState(() {});
  }

  List<Map<String, dynamic>> get _filteredMarketers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _marketers;

    return _marketers.where((marketer) {
      final name = marketer['name']?.toString().toLowerCase() ?? '';
      final phone = marketer['phone']?.toString().toLowerCase() ?? '';
      final number =
          marketer['marketer_number']?.toString().toLowerCase() ?? '';
      final code = marketer['code']?.toString().toLowerCase() ?? '';
      final parentNumber =
          marketer['parent_number']?.toString().toLowerCase() ?? '';
      final parentCode =
          marketer['parent_code']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          phone.contains(query) ||
          number.contains(query) ||
          code.contains(query) ||
          parentNumber.contains(query) ||
          parentCode.contains(query);
    }).toList();
  }

  Future<void> _addMarketer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _MarketerDialog(),
    );
    if (result == true) await _loadMarketers();
  }

  Future<void> _openCodesManagement() async {
    await showDialog(
      context: context,
      builder: (context) => const _CodesManagementDialog(),
    );
    if (mounted) await _loadMarketers();
  }

  Future<void> _editMarketer(Map<String, dynamic> marketer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _MarketerDialog(marketer: marketer),
    );
    if (result == true) await _loadMarketers();
  }

  Future<void> _deactivateMarketer(Map<String, dynamic> marketer) async {
    final marketerId = marketer['id'];
    if (marketerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل المسوق'),
        content: Text(
          'هل تريد تعطيل المسوق "${marketer['name'] ?? '-'}"؟\n\n'
          'سيتم تحرير رقم وكود المسوق ليصبحا متاحين لمسوق آخر، '
          'لكن بيانات المسوق ستبقى محفوظة.',
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
      ),
    );

    if (confirmed != true) return;

    try {
      final oldValues = Map<String, dynamic>.from(marketer);

      await DatabaseHelper.instance.detachMarketer(marketerId as int);

      // تسجيل التعطيل بعد نجاح العملية الأساسية.
      try {
        await DatabaseHelper.instance.addAuditLog(
          action: 'deactivate',
          entityType: 'marketer',
          entityId: marketerId,
          description:
              'تعطيل المسوق: ${marketer['name'] ?? '-'} '
              'وتحرير رقمه وكوده',
          oldValues: oldValues,
          newValues: {
            ...oldValues,
            'is_active': 0,
            'code_id': null,
            'marketer_number': null,
            'code': null,
            'code_released': true,
          },
        );
      } catch (auditError) {
        debugPrint('تعذر تسجيل تدقيق تعطيل المسوق: $auditError');
      }

      await _loadMarketers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعطيل المسوق وتحرير رقمه وكوده بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تعطيل المسوق: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMarketers = _filteredMarketers;

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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'بحث بالاسم أو رقم المسوق أو الكود أو رقم الداعي أو كوده',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredMarketers.isEmpty
                          ? _buildEmptyState(
                              isSearchResult: _searchController.text
                                  .trim()
                                  .isNotEmpty,
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredMarketers.length,
                              itemBuilder: (context, index) =>
                                  _buildMarketerCard(filteredMarketers[index]),
                            ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'manage_codes',
              onPressed: _openCodesManagement,
              icon: const Icon(Icons.numbers_outlined),
              label: const Text('إدارة الأرقام'),
            ),
            FloatingActionButton.extended(
              heroTag: 'add_marketer',
              onPressed: _addMarketer,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('إضافة مسوق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isSearchResult = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 80),
        Icon(
          isSearchResult ? Icons.search_off : Icons.people_outline,
          size: 70,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            isSearchResult ? 'لا توجد نتائج' : 'لا يوجد مسوقون حتى الآن',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            isSearchResult
                ? 'جرّب البحث باسم أو رقم أو كود مختلف'
                : 'اضغط على "إضافة مسوق" لإنشاء أول مسوق',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketerCard(Map<String, dynamic> marketer) {
    final name = marketer['name']?.toString() ?? '-';
    final phone = marketer['phone']?.toString() ?? '-';
    final marketerNumber = marketer['marketer_number']?.toString() ?? '-';
    final code = marketer['code']?.toString() ?? '-';

    final parentId = marketer['parent_id'];
    final parentNumber = marketer['parent_number']?.toString();
    final parentCode = marketer['parent_code']?.toString();

    final hasParent = parentId != null;
    final parentIdentifier = hasParent
        ? '${parentNumber ?? '-'} - ${parentCode ?? '-'}'
        : '';

    final commission = (marketer['commission_rate'] as num?)?.toDouble() ?? 0;
    final receivesReferralCommission =
        (marketer['receives_referral_commission'] as num?)?.toInt() == 1;
    final referralCommissionRate =
        (marketer['referral_commission_rate'] as num?)?.toDouble() ?? 0;

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
            color: Colors.black.withValues(alpha: 0.03),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                        Expanded(
                          child: Text(
                            phone,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasParent) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.account_tree_outlined,
                            size: 15,
                            color: Color(0xFF1E4FA3),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'الداعي: $parentIdentifier',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 5),
                      Text(
                        'مسوق رئيسي',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
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
                  icon: Icons.numbers_outlined,
                  title: 'رقم المسوق',
                  value: marketerNumber,
                ),
              ),
              Container(width: 1, height: 35, color: const Color(0xFFE5E7EB)),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.badge_outlined,
                  title: 'الكود',
                  value: code,
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
          if (!hasParent && receivesReferralCommission) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    color: Color(0xFF2E7D32),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عمولة التبعية مفعّلة: '
                      '${_formatNumber(referralCommissionRate)}% من إجمالي '
                      'مبيعات التابع المباشر',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

// ============================================================================
// نافذة إدارة أرقام المسوقين والأكواد
// ============================================================================

class _CodesManagementDialog extends StatefulWidget {
  const _CodesManagementDialog();

  @override
  State<_CodesManagementDialog> createState() => _CodesManagementDialogState();
}

class _CodesManagementDialogState extends State<_CodesManagementDialog> {
  List<Map<String, dynamic>> _codes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCodes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  Future<void> _loadCodes() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final codes = await db.rawQuery('''
        SELECT
          codes.id,
          codes.marketer_number,
          codes.code,
          codes.marketer_id,
          codes.created_at,
          codes.is_active,
          marketers.name AS marketer_name
        FROM codes
        LEFT JOIN marketers ON marketers.id = codes.marketer_id
        WHERE codes.is_active = 1
        ORDER BY codes.marketer_number ASC
      ''');

      if (!mounted) return;
      setState(() {
        _codes = codes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل الأرقام: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredCodes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _codes;

    return _codes.where((item) {
      final number = item['marketer_number']?.toString().toLowerCase() ?? '';
      final code = item['code']?.toString().toLowerCase() ?? '';
      final marketerName =
          item['marketer_name']?.toString().toLowerCase() ?? '';
      return number.contains(query) ||
          code.contains(query) ||
          marketerName.contains(query);
    }).toList();
  }

  Future<void> _addCode() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _CodeDialog(),
    );
    if (result == true) await _loadCodes();
  }

  Future<void> _editCode(Map<String, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _CodeDialog(codeItem: item),
    );
    if (result == true) await _loadCodes();
  }

  Future<void> _deactivateCode(Map<String, dynamic> item) async {
    if (item['marketer_id'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تعطيل رقم وكود مستخدم من قبل مسوق.'),
        ),
      );
      return;
    }

    final id = item['id'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل الرقم والكود'),
        content: Text(
          'هل تريد تعطيل الرقم "${item['marketer_number']}" '
          'والكود "${item['code']}"؟',
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
      ),
    );

    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.setMarketerCodeActive(
        codeId: id as int,
        isActive: false,
      );

      // تسجيل تعطيل الرقم والكود.
      try {
        await DatabaseHelper.instance.addAuditLog(
          action: 'deactivate',
          entityType: 'marketer_code',
          entityId: id,
          description:
              'تعطيل رقم المسوق ${item['marketer_number']} '
              'والكود ${item['code']}',
          oldValues: {
            'marketer_number': item['marketer_number'],
            'code': item['code'],
            'marketer_id': item['marketer_id'],
            'is_active': item['is_active'],
          },
          newValues: {
            'marketer_number': item['marketer_number'],
            'code': item['code'],
            'marketer_id': null,
            'is_active': 0,
          },
        );
      } catch (auditError) {
        debugPrint('تعذر تسجيل تدقيق تعطيل الرقم والكود: $auditError');
      }

      await _loadCodes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعطيل الرقم والكود بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تعطيل الرقم والكود: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCodes = _filteredCodes;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        child: SizedBox(
          width: 700,
          height: 600,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'إدارة أرقام المسوقين',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 420) {
                      return Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'بحث بالرقم أو الكود أو اسم المسوق',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.clear),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: _addCode,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة'),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'بحث بالرقم أو الكود أو اسم المسوق',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.clear),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _addCode,
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredCodes.isEmpty
                    ? _buildCodesEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredCodes.length,
                        itemBuilder: (context, index) =>
                            _buildCodeCard(filteredCodes[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodesEmptyState() {
    final searching = _searchController.text.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.numbers_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            Text(
              searching ? 'لا توجد نتائج' : 'لا توجد أرقام مسوقين',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'جرّب البحث برقم أو كود مختلف'
                  : 'اضغط على "إضافة" لإنشاء أول رقم وكود',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> item) {
    final number = item['marketer_number']?.toString() ?? '-';
    final code = item['code']?.toString() ?? '-';
    final marketerId = item['marketer_id'];
    final marketerName = item['marketer_name']?.toString();
    final isUsed = marketerId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: isUsed ? Colors.grey.shade100 : const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.badge_outlined,
              color: isUsed ? Colors.grey : const Color(0xFF1E4FA3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('-', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (isUsed)
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          marketerName ?? 'مسوق مستخدم',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'متاح',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: isUsed ? Colors.blue.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isUsed ? 'مستخدم' : 'متاح',
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUsed ? Colors.blue.shade700 : Colors.green.shade700,
              ),
            ),
          ),
          if (!isUsed)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') {
                  _editCode(item);
                } else if (value == 'delete') {
                  _deactivateCode(item);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 19),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 19, color: Colors.red),
                      SizedBox(width: 8),
                      Text('تعطيل'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// نافذة إضافة / تعديل رقم وكود
// ============================================================================

class _CodeDialog extends StatefulWidget {
  final Map<String, dynamic>? codeItem;

  const _CodeDialog({this.codeItem});

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.codeItem != null;

  @override
  void initState() {
    super.initState();
    if (widget.codeItem != null) {
      _numberController.text =
          widget.codeItem!['marketer_number']?.toString() ?? '';
      _codeController.text = widget.codeItem!['code']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final number = int.parse(_numberController.text.trim());
      final code = _codeController.text.trim();

      if (_isEditing) {
        final oldValues = Map<String, dynamic>.from(widget.codeItem!);
        final codeId = widget.codeItem!['id'] as int;

        await DatabaseHelper.instance.updateMarketerCode(
          id: codeId,
          marketerNumber: number,
          code: code,
        );

        // تسجيل تعديل الرقم والكود بعد نجاح التعديل.
        try {
          await DatabaseHelper.instance.addAuditLog(
            action: 'update',
            entityType: 'marketer_code',
            entityId: codeId,
            description:
                'تعديل الرقم والكود من '
                '${oldValues['marketer_number']} - ${oldValues['code']} '
                'إلى $number - $code',
            oldValues: oldValues,
            newValues: {...oldValues, 'marketer_number': number, 'code': code},
          );
        } catch (auditError) {
          debugPrint('تعذر تسجيل تدقيق تعديل الرقم والكود: $auditError');
        }
      } else {
        final codeId = await DatabaseHelper.instance.addMarketerCode(
          marketerNumber: number,
          code: code,
        );

        // تسجيل إضافة رقم وكود جديدين.
        try {
          await DatabaseHelper.instance.addAuditLog(
            action: 'create',
            entityType: 'marketer_code',
            entityId: codeId,
            description: 'إضافة رقم مسوق جديد: $number - $code',
            newValues: {
              'id': codeId,
              'marketer_number': number,
              'code': code,
              'marketer_id': null,
              'is_active': 1,
            },
          );
        } catch (auditError) {
          debugPrint('تعذر تسجيل تدقيق إضافة الرقم والكود: $auditError');
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String message = e.toString();
      if (message.contains('UNIQUE constraint failed')) {
        message = 'رقم المسوق أو الكود مستخدم بالفعل.';
      } else {
        message = message.replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: $message')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          _isEditing ? 'تعديل رقم وكود' : 'إضافة رقم وكود',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم المسوق',
                    hintText: 'مثال: 1001',
                    prefixIcon: Icon(Icons.numbers_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'رقم المسوق مطلوب';
                    }
                    final number = int.tryParse(value.trim());
                    if (number == null) return 'أدخل رقمًا صحيحًا';
                    if (number <= 0) return 'يجب أن يكون الرقم أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'الكود',
                    hintText: 'مثال: ABC123',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الكود مطلوب';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
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
}

// ============================================================================
// نافذة إضافة / تعديل المسوق
// ============================================================================

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
  final _commissionController = TextEditingController();
  final _referralCommissionController = TextEditingController();

  bool _receivesReferralCommission = false;
  bool _isSaving = false;
  bool _isLoadingCodes = true;
  List<Map<String, dynamic>> _codes = [];

  bool _isLoadingMarketers = true;
  List<Map<String, dynamic>> _availableParents = [];
  int? _selectedParentId;
  int? _selectedCodeId;

  bool get _isEditing => widget.marketer != null;

  @override
  void initState() {
    super.initState();

    final marketer = widget.marketer;
    if (marketer != null) {
      _nameController.text = marketer['name']?.toString() ?? '';
      _phoneController.text = marketer['phone']?.toString() ?? '';

      final commission = (marketer['commission_rate'] as num?)?.toDouble() ?? 0;
      _commissionController.text = _formatNumber(commission);

      _receivesReferralCommission =
          (marketer['receives_referral_commission'] as num?)?.toInt() == 1;

      final referralCommission =
          (marketer['referral_commission_rate'] as num?)?.toDouble() ?? 0;
      _referralCommissionController.text = _formatNumber(referralCommission);

      final currentCodeId = marketer['code_id'];
      if (currentCodeId != null) {
        _selectedCodeId = int.tryParse(currentCodeId.toString());
      }

      final parentId = marketer['parent_id'];
      if (parentId != null) {
        _selectedParentId = int.tryParse(parentId.toString());
      }
    } else {
      _referralCommissionController.text = '0';
    }

    _loadAvailableCodes();
    _loadAvailableParents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commissionController.dispose();
    _referralCommissionController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableCodes() async {
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> codes;

      if (_isEditing) {
        final marketerId = widget.marketer!['id'];
        codes = await db.rawQuery(
          '''
          SELECT id, marketer_number, code, marketer_id, is_active
          FROM codes
          WHERE is_active = 1
            AND (marketer_id IS NULL OR marketer_id = ?)
          ORDER BY marketer_number ASC
          ''',
          [marketerId],
        );
      } else {
        codes = await db.rawQuery('''
          SELECT id, marketer_number, code, marketer_id, is_active
          FROM codes
          WHERE is_active = 1 AND marketer_id IS NULL
          ORDER BY marketer_number ASC
        ''');
      }

      if (!mounted) return;
      setState(() {
        _codes = codes;
        _isLoadingCodes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCodes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل أرقام المسوقين: $e')),
      );
    }
  }

  // تحميل المسوقين المتاحين للدعوة مع رقم كل مسوق وكوده.
  // نستبعد المسوق الحالي وجميع المسوقين الموجودين تحته لتجنب الدورات.
  Future<void> _loadAvailableParents() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final allMarketers = await db.rawQuery('''
        SELECT
          marketers.id,
          marketers.name,
          marketers.parent_id,
          marketers.is_active,
          codes.marketer_number,
          codes.code
        FROM marketers
        LEFT JOIN codes
          ON marketers.id = codes.marketer_id
          AND codes.is_active = 1
        WHERE marketers.is_active = 1
        ORDER BY codes.marketer_number ASC
      ''');

      final currentId = _isEditing
          ? int.tryParse(widget.marketer!['id'].toString())
          : null;

      final childrenByParent = <int, List<int>>{};
      for (final item in allMarketers) {
        final id = int.tryParse(item['id'].toString());
        final parentId = item['parent_id'] == null
            ? null
            : int.tryParse(item['parent_id'].toString());

        if (id != null && parentId != null) {
          childrenByParent.putIfAbsent(parentId, () => []).add(id);
        }
      }

      final excludedIds = <int>{};
      if (currentId != null) {
        excludedIds.add(currentId);

        final pending = <int>[currentId];
        while (pending.isNotEmpty) {
          final parent = pending.removeLast();
          for (final child in childrenByParent[parent] ?? <int>[]) {
            if (excludedIds.add(child)) {
              pending.add(child);
            }
          }
        }
      }

      final parents = allMarketers.where((item) {
        final id = int.tryParse(item['id'].toString());
        return id != null && !excludedIds.contains(id);
      }).toList();

      if (!mounted) return;
      setState(() {
        _availableParents = parents;
        _isLoadingMarketers = false;

        if (_selectedParentId != null &&
            !parents.any(
              (item) => item['id'].toString() == _selectedParentId.toString(),
            )) {
          _selectedParentId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMarketers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل قائمة الداعين: $e')),
      );
    }
  }

  // تحقق إضافي داخل معاملة الحفظ لمنع ربط المسوق بأحد أحفاده.
  Future<void> _validateParentSelection(
    dynamic txn,
    int? currentMarketerId,
  ) async {
    if (_selectedParentId == null) return;

    if (currentMarketerId != null && _selectedParentId == currentMarketerId) {
      throw Exception('لا يمكن اختيار المسوق نفسه داعيًا.');
    }

    final rows = await txn.query(
      'marketers',
      columns: ['id', 'parent_id', 'is_active'],
    );

    final byId = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = int.tryParse(row['id'].toString());
      if (id != null) byId[id] = row;
    }

    final selectedParent = byId[_selectedParentId];
    if (selectedParent == null || selectedParent['is_active'] != 1) {
      throw Exception('المسوق الداعي المحدد غير متاح.');
    }

    if (currentMarketerId == null) return;

    var ancestorId = _selectedParentId!;
    final visited = <int>{};

    while (true) {
      if (ancestorId == currentMarketerId) {
        throw Exception(
          'لا يمكن اختيار أحد المسوقين التابعين لهذا المسوق داعيًا.',
        );
      }

      if (!visited.add(ancestorId)) {
        throw Exception(
          'توجد علاقة دائرية في تسلسل الداعين. '
          'صحح التسلسل قبل تعديل هذا المسوق.',
        );
      }

      final ancestor = byId[ancestorId];
      if (ancestor == null || ancestor['parent_id'] == null) break;

      final int? nextId = int.tryParse(ancestor['parent_id'].toString());

      if (nextId == null) break;
      ancestorId = nextId;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCodeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب اختيار رقم وكود المسوق')),
      );
      return;
    }

    final referralText = _referralCommissionController.text.trim();
    final referralCommission = referralText.isEmpty
        ? 0.0
        : double.tryParse(referralText);

    if (referralCommission == null ||
        referralCommission < 0 ||
        referralCommission > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نسبة عمولة التبعية يجب أن تكون بين 0 و100'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final name = _nameController.text.trim();
      final phoneText = _phoneController.text.trim();
      final phone = phoneText.isEmpty ? null : phoneText;
      final commission =
          double.tryParse(_commissionController.text.trim()) ?? 0;
      final now = DateTime.now().toIso8601String();

      // الاحتفاظ بالبيانات القديمة قبل تعديلها.
      final Map<String, dynamic>? oldValues = _isEditing
          ? Map<String, dynamic>.from(widget.marketer!)
          : null;

      // سيتم تعيينه عند الإضافة أو التعديل لتسجيل العملية لاحقًا.
      int? savedMarketerId;

      await db.transaction((txn) async {
        final int? currentMarketerId = _isEditing
            ? int.tryParse(widget.marketer!['id'].toString())
            : null;

        await _validateParentSelection(txn, currentMarketerId);

        if (_isEditing) {
          final marketerId = currentMarketerId!;
          savedMarketerId = marketerId;

          final oldCodeId = widget.marketer!['code_id'];
          final oldCodeIdInt = oldCodeId == null
              ? null
              : int.tryParse(oldCodeId.toString());

          await txn.update(
            'marketers',
            {
              'name': name,
              'phone': phone,
              'parent_id': _selectedParentId,
              'commission_rate': commission,
              'receives_referral_commission': _receivesReferralCommission
                  ? 1
                  : 0,
              'referral_commission_rate': referralCommission,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [marketerId],
          );

          if (oldCodeIdInt != _selectedCodeId) {
            final available = await txn.query(
              'codes',
              columns: ['id', 'marketer_id'],
              where: 'id = ? AND is_active = 1',
              whereArgs: [_selectedCodeId],
              limit: 1,
            );

            if (available.isEmpty) {
              throw Exception('زوج رقم وكود المسوق غير متاح حاليًا.');
            }

            final assignedTo = available.first['marketer_id'];
            if (assignedTo != null &&
                assignedTo.toString() != marketerId.toString()) {
              throw Exception('هذا الرقم والكود مستخدم لمسوق آخر.');
            }

            if (oldCodeIdInt != null) {
              await txn.update(
                'codes',
                {'marketer_id': null},
                where: 'id = ?',
                whereArgs: [oldCodeIdInt],
              );
            }

            await txn.update(
              'codes',
              {'marketer_id': marketerId},
              where: 'id = ?',
              whereArgs: [_selectedCodeId],
            );
          }
        } else {
          final available = await txn.query(
            'codes',
            columns: ['id', 'marketer_id'],
            where: 'id = ? AND is_active = 1',
            whereArgs: [_selectedCodeId],
            limit: 1,
          );

          if (available.isEmpty) {
            throw Exception('زوج رقم وكود المسوق غير متاح حاليًا.');
          }

          if (available.first['marketer_id'] != null) {
            throw Exception('هذا الرقم والكود مستخدم لمسوق آخر.');
          }

          final marketerId = await txn.rawInsert(
            '''
            INSERT INTO marketers (
              name,
              phone,
              parent_id,
              commission_rate,
              receives_referral_commission,
              referral_commission_rate,
              is_active,
              created_at,
              updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              name,
              phone,
              _selectedParentId,
              commission,
              _receivesReferralCommission ? 1 : 0,
              referralCommission,
              1,
              now,
              now,
            ],
          );

          savedMarketerId = marketerId;

          await txn.update(
            'codes',
            {'marketer_id': marketerId},
            where: 'id = ?',
            whereArgs: [_selectedCodeId],
          );
        }
      });

      // تسجيل العملية بعد نجاح المعاملة بالكامل.
      // يشمل السجل تغيير رقم وكود المسوق عند التعديل.
      // فشل التدقيق لا يلغي نجاح حفظ المسوق.
      try {
        final marketerId = savedMarketerId;

        if (marketerId != null) {
          final updatedMarketer = await DatabaseHelper.instance.getMarketer(
            marketerId,
          );

          await DatabaseHelper.instance.addAuditLog(
            action: _isEditing ? 'update' : 'create',
            entityType: 'marketer',
            entityId: marketerId,
            description: _isEditing
                ? 'تعديل بيانات المسوق: $name'
                : 'إضافة مسوق جديد: $name',
            oldValues: oldValues,
            newValues:
                updatedMarketer ??
                {
                  'id': marketerId,
                  'name': name,
                  'phone': phone,
                  'parent_id': _selectedParentId,
                  'commission_rate': commission,
                  'receives_referral_commission': _receivesReferralCommission
                      ? 1
                      : 0,
                  'referral_commission_rate': referralCommission,
                  'code_id': _selectedCodeId,
                  'is_active': 1,
                },
          );
        }
      } catch (auditError) {
        debugPrint('تعذر تسجيل تدقيق حفظ المسوق: $auditError');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String message = e.toString();
      if (message.contains('UNIQUE constraint failed')) {
        message = 'هذا الرقم أو الكود مستخدم بالفعل.';
      } else {
        message = message.replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ المسوق: $message')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
                  _buildCodeSelector(),
                  const SizedBox(height: 14),
                  _buildParentSelector(),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _commissionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'نسبة العمولة الشخصية',
                      hintText: 'مثال: 5',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'نسبة العمولة مطلوبة';
                      }
                      final number = double.tryParse(value.trim());
                      if (number == null) return 'أدخل رقمًا صحيحًا';
                      if (number < 0 || number > 100) {
                        return 'النسبة يجب أن تكون بين 0 و100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildReferralCommissionSection(),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
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

  Widget _buildReferralCommissionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _receivesReferralCommission
              ? const Color(0xFF1E4FA3)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                color: Color(0xFF1E4FA3),
                size: 21,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عمولة التبعية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'عند تفعيلها، يحصل هذا المسوق على نسبة من إجمالي مبيعات '
            'التابع المباشر قبل خصم تكلفة المنتجات. لا تشمل أحفاد المسوق.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'تفعيل استحقاق عمولة التبعية',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              _receivesReferralCommission
                  ? 'العمولة مفعّلة لهذا المسوق'
                  : 'لن تُحتسب له عمولة تبعية على المبيعات الجديدة',
              style: const TextStyle(fontSize: 11),
            ),
            value: _receivesReferralCommission,
            activeColor: const Color(0xFF1E4FA3),
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _receivesReferralCommission = value;
                    });
                  },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _referralCommissionController,
            enabled: _receivesReferralCommission && !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'نسبة عمولة التبعية',
              hintText: 'مثال: 2',
              prefixIcon: const Icon(Icons.percent),
              suffixText: '%',
              filled: true,
              fillColor: _receivesReferralCommission
                  ? Colors.white
                  : const Color(0xFFEEEEEE),
              helperText: 'تُحسب من إجمالي البيع، وليس من الربح.',
              helperMaxLines: 2,
            ),
            validator: (value) {
              if (!_receivesReferralCommission) return null;
              if (value == null || value.trim().isEmpty) {
                return 'أدخل نسبة عمولة التبعية';
              }
              final number = double.tryParse(value.trim());
              if (number == null) return 'أدخل نسبة صحيحة';
              if (number < 0 || number > 100) {
                return 'النسبة يجب أن تكون بين 0 و100';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParentSelector() {
    if (_isLoadingMarketers) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'المسوق الداعي',
          prefixIcon: Icon(Icons.account_tree_outlined),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(child: Text('جاري تحميل المسوقين...')),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedParentId ?? 0,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المسوق الداعي',
        hintText: 'اختر رقم وكود المسوق الداعي',
        prefixIcon: Icon(Icons.account_tree_outlined),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: 0,
          child: Text('بدون داعٍ (مسوق رئيسي)'),
        ),
        ..._availableParents.map((item) {
          final id = int.parse(item['id'].toString());
          final number = item['marketer_number']?.toString() ?? '-';
          final code = item['code']?.toString() ?? '-';

          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              '$number - $code',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: _isSaving
          ? null
          : (value) {
              setState(() {
                _selectedParentId = value == null || value == 0 ? null : value;
              });
            },
    );
  }

  Widget _buildCodeSelector() {
    if (_isLoadingCodes) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'رقم وكود المسوق',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(child: Text('جاري تحميل الأرقام...')),
          ],
        ),
      );
    }

    if (_codes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'لا توجد أرقام وأكواد متاحة.\n'
                'أضف رقمًا وكودًا من "إدارة الأرقام" أولًا.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCodeId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'رقم وكود المسوق',
        hintText: 'اختر رقم المسوق والكود',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: _codes.map((item) {
        final id = int.parse(item['id'].toString());
        final number = item['marketer_number']?.toString() ?? '-';
        final code = item['code']?.toString() ?? '-';
        final isCurrent =
            _isEditing &&
            item['marketer_id']?.toString() ==
                widget.marketer!['id']?.toString();

        return DropdownMenuItem<int>(
          value: id,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$number - $code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Text(
                  '(الحالي)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: _isSaving
          ? null
          : (value) => setState(() => _selectedCodeId = value),
      validator: (value) {
        if (value == null) return 'يجب اختيار رقم وكود المسوق';
        return null;
      },
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
