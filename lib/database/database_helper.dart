import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  DatabaseHelper._internal();

  // ==================================================
  // الوصول إلى قاعدة البيانات
  // ==================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  // ==================================================
  // إنشاء / فتح قاعدة البيانات
  // ==================================================

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'marketer_system.db');

    return openDatabase(
      path,

      // الإصدار 10: بيانات فاتورة الزبون وسجل التحصيل.
      version: 10,

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        await _createTables(db);
        await _ensureReferralCommissionColumns(db);
        await _upgradeToVersion9(db);
        await _upgradeToVersion10(db, isNewDatabase: true);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTables(db);
          await db.execute('DROP TABLE IF EXISTS test');
        }

        if (oldVersion < 3) {
          await _upgradeMarketersTable(db);
        }

        if (oldVersion < 4) {
          await _upgradeToVersion4(db);
        }

        if (oldVersion < 5) {
          await _upgradeToVersion5(db);
        }

        if (oldVersion < 6) {
          await _upgradeToVersion6(db);
        }

        if (oldVersion < 7) {
          await _upgradeToVersion7(db);
        }

        if (oldVersion < 8) {
          await _upgradeToVersion8(db);
        }

        if (oldVersion < 9) {
          await _upgradeToVersion9(db);
        }

        if (oldVersion < 10) {
          await _upgradeToVersion10(db);
        }
      },
    );
  }

  // ==================================================
  // إنشاء جميع الجداول
  // ==================================================

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marketer_number INTEGER NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE,
        marketer_id INTEGER UNIQUE,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (marketer_id)
          REFERENCES marketers (id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS marketers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        phone TEXT,
        parent_id INTEGER,
        commission_rate REAL NOT NULL DEFAULT 0,
        receives_referral_commission INTEGER NOT NULL DEFAULT 0,
        referral_commission_rate REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (parent_id)
          REFERENCES marketers (id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT UNIQUE,
        description TEXT,
        purchase_price REAL NOT NULL DEFAULT 0,
        selling_price REAL NOT NULL DEFAULT 0,
        stock_quantity REAL NOT NULL DEFAULT 0,
        min_stock_quantity REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'قطعة',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id)
          REFERENCES products (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marketer_id INTEGER,
        total_amount REAL NOT NULL DEFAULT 0,
        total_profit REAL NOT NULL DEFAULT 0,
        commission_amount REAL NOT NULL DEFAULT 0,
        referral_commission_amount REAL NOT NULL DEFAULT 0,
        referral_commission_marketer_id INTEGER,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (marketer_id)
          REFERENCES marketers (id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        purchase_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        profit REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (sale_id)
          REFERENCES sales (id)
          ON DELETE CASCADE,
        FOREIGN KEY (product_id)
          REFERENCES products (id)
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        customer_location TEXT,
        order_note TEXT,
        total_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id)
          REFERENCES orders (id)
          ON DELETE CASCADE,
        FOREIGN KEY (product_id)
          REFERENCES products (id)
          ON DELETE SET NULL
      )
    ''');
  }

  // ==================================================
  // ترقية جدول المسوقين من الإصدارات القديمة
  // ==================================================

  Future<void> _upgradeMarketersTable(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      final columns = await db.rawQuery('PRAGMA table_info(marketers)');
      final hasCode = columns.any((column) => column['name'] == 'code');

      await db.execute('DROP TABLE IF EXISTS marketers_new');

      await db.execute('''
        CREATE TABLE marketers_new (
          id INTEGER PRIMARY KEY,
          name TEXT,
          phone TEXT,
          code TEXT UNIQUE,
          parent_id INTEGER,
          commission_rate REAL NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          FOREIGN KEY (parent_id)
            REFERENCES marketers_new (id)
            ON DELETE SET NULL
        )
      ''');

      if (hasCode) {
        await db.execute('''
          INSERT OR IGNORE INTO marketers_new (
            id, name, phone, code, parent_id,
            commission_rate, is_active, created_at, updated_at
          )
          SELECT
            id, name, phone, code, parent_id,
            commission_rate, is_active, created_at, updated_at
          FROM marketers
        ''');
      } else {
        await db.execute('''
          INSERT OR IGNORE INTO marketers_new (
            id, name, phone, parent_id,
            commission_rate, is_active, created_at, updated_at
          )
          SELECT
            id, name, phone, parent_id,
            commission_rate, is_active, created_at, updated_at
          FROM marketers
        ''');
      }

      await db.execute('DROP TABLE marketers');
      await db.execute('ALTER TABLE marketers_new RENAME TO marketers');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // ==================================================
  // ترقية الإصدار 3 → 4
  // ==================================================

  Future<void> _upgradeToVersion4(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS codes (
          marketer_id INTEGER PRIMARY KEY,
          code TEXT UNIQUE NOT NULL,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');

      final columns = await db.rawQuery('PRAGMA table_info(marketers)');
      final hasCode = columns.any((column) => column['name'] == 'code');

      if (hasCode) {
        final oldCodes = await db.query(
          'marketers',
          columns: ['id', 'code', 'created_at'],
          where: 'code IS NOT NULL AND code != ?',
          whereArgs: [''],
        );

        for (final row in oldCodes) {
          final marketerId = row['id'];
          final code = row['code'];

          if (marketerId != null && code != null) {
            await db.insert('codes', {
              'marketer_id': marketerId,
              'code': code,
              'created_at':
                  row['created_at'] ?? DateTime.now().toIso8601String(),
              'is_active': 1,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      await db.execute('DROP TABLE IF EXISTS marketers_new');

      await db.execute('''
        CREATE TABLE marketers_new (
          id INTEGER PRIMARY KEY,
          name TEXT,
          phone TEXT,
          parent_id INTEGER,
          commission_rate REAL NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          FOREIGN KEY (parent_id)
            REFERENCES marketers_new (id)
            ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO marketers_new (
          id, name, phone, parent_id, commission_rate,
          is_active, created_at, updated_at
        )
        SELECT
          id, name, phone, parent_id, commission_rate,
          is_active, created_at, updated_at
        FROM marketers
      ''');

      await db.execute('DROP TABLE marketers');
      await db.execute('ALTER TABLE marketers_new RENAME TO marketers');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // ==================================================
  // ترقية الإصدار 4 → 5
  // ==================================================

  Future<void> _upgradeToVersion5(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        customer_location TEXT,
        order_note TEXT,
        total_amount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id)
          REFERENCES orders (id)
          ON DELETE CASCADE,
        FOREIGN KEY (product_id)
          REFERENCES products (id)
          ON DELETE SET NULL
      )
    ''');
  }

  // ==================================================
  // ترقية الإصدار 5 → 6
  // ==================================================

  Future<void> _upgradeToVersion6(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      final oldCodesExists = await _tableExists(db, 'codes');
      final oldMarketersExists = await _tableExists(db, 'marketers');

      final oldCodes = oldCodesExists
          ? await db.query('codes', orderBy: 'marketer_id ASC')
          : <Map<String, dynamic>>[];

      final oldMarketers = oldMarketersExists
          ? await db.query('marketers', orderBy: 'id ASC')
          : <Map<String, dynamic>>[];

      await db.execute('DROP TABLE IF EXISTS codes_new');
      await db.execute('DROP TABLE IF EXISTS marketers_new');

      await db.execute('''
        CREATE TABLE marketers_new (
          id INTEGER PRIMARY KEY,
          name TEXT,
          phone TEXT,
          parent_id INTEGER,
          commission_rate REAL NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          FOREIGN KEY (parent_id)
            REFERENCES marketers_new (id)
            ON DELETE SET NULL
        )
      ''');

      for (final marketer in oldMarketers) {
        await db.insert('marketers_new', {
          'id': marketer['id'],
          'name': marketer['name'],
          'phone': marketer['phone'],
          'parent_id': marketer['parent_id'],
          'commission_rate': marketer['commission_rate'] ?? 0,
          'is_active': marketer['is_active'] ?? 1,
          'created_at':
              marketer['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': marketer['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await db.execute('''
        CREATE TABLE codes_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          marketer_number INTEGER NOT NULL UNIQUE,
          code TEXT NOT NULL UNIQUE,
          marketer_id INTEGER UNIQUE,
          created_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (marketer_id)
            REFERENCES marketers_new (id)
            ON DELETE SET NULL
        )
      ''');

      for (final oldCode in oldCodes) {
        final oldMarketerId = oldCode['marketer_id'];
        final code = oldCode['code'];

        if (oldMarketerId == null ||
            code == null ||
            code.toString().trim().isEmpty) {
          continue;
        }

        final marketerId = oldMarketerId as int;

        await db.insert('codes_new', {
          'marketer_number': marketerId,
          'code': code.toString().trim(),
          'marketer_id': marketerId,
          'created_at':
              oldCode['created_at'] ?? DateTime.now().toIso8601String(),
          'is_active': oldCode['is_active'] ?? 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      if (oldCodesExists) {
        await db.execute('DROP TABLE codes');
      }

      if (oldMarketersExists) {
        await db.execute('DROP TABLE marketers');
      }

      await db.execute('ALTER TABLE marketers_new RENAME TO marketers');
      await db.execute('ALTER TABLE codes_new RENAME TO codes');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS
        idx_codes_marketer_id ON codes(marketer_id)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS
        idx_codes_marketer_number ON codes(marketer_number)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS
        idx_codes_code ON codes(code)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS
        idx_marketers_parent_id ON marketers(parent_id)
      ''');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // ==================================================
  // ترقية الإصدار 6 → 7
  // ==================================================

  Future<void> _upgradeToVersion7(Database db) async {
    await _ensureReferralCommissionColumns(db);
  }

  // ==================================================
  // ترقية الإصدار 7 → 8
  // ==================================================

  Future<void> _upgradeToVersion8(Database db) async {
    await _ensureReferralCommissionColumns(db);
  }

  // ==================================================
  // ترقية الإصدار 8 → 9
  // إنشاء سجل التدقيق
  // ==================================================

  Future<void> _upgradeToVersion9(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        description TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_audit_logs_created_at
      ON audit_logs(created_at)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_audit_logs_entity
      ON audit_logs(entity_type, entity_id)
    ''');
  }

  // ==================================================
  // الإصدار 10: بيانات فواتير الزبائن والتحصيل
  // ==================================================

  Future<void> _upgradeToVersion10(
    Database db, {
    bool isNewDatabase = false,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info(sales)');
    final existing = columns.map((row) => row['name'].toString()).toSet();
    final additions = <String, String>{
      'customer_name': 'TEXT',
      'customer_phone': 'TEXT',
      'delivery_fee': 'REAL NOT NULL DEFAULT 0',
      'payment_status': "TEXT NOT NULL DEFAULT 'unpaid'",
      'payment_updated_at': 'TEXT',
      'fully_paid_at': 'TEXT',
    };

    for (final entry in additions.entries) {
      if (!existing.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }

    // المبيعات القديمة لا نملك دليلًا على حالة تحصيلها.
    if (!isNewDatabase) {
      await db.update('sales', {'payment_status': 'legacy'});
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sale_payments_sale_id
      ON sale_payments(sale_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sales_payment_status
      ON sales(payment_status)
    ''');
  }

  // ==================================================
  // التحقق من أعمدة عمولة التبعية
  // ==================================================

  Future<void> _ensureReferralCommissionColumns(Database db) async {
    if (await _tableExists(db, 'marketers')) {
      final columns = await db.rawQuery('PRAGMA table_info(marketers)');

      final hasReferralEnabled = columns.any(
        (column) => column['name'] == 'receives_referral_commission',
      );

      final hasReferralRate = columns.any(
        (column) => column['name'] == 'referral_commission_rate',
      );

      if (!hasReferralEnabled) {
        await db.execute('''
          ALTER TABLE marketers
          ADD COLUMN receives_referral_commission
          INTEGER NOT NULL DEFAULT 0
        ''');
      }

      if (!hasReferralRate) {
        await db.execute('''
          ALTER TABLE marketers
          ADD COLUMN referral_commission_rate
          REAL NOT NULL DEFAULT 0
        ''');
      }
    }

    if (await _tableExists(db, 'sales')) {
      final columns = await db.rawQuery('PRAGMA table_info(sales)');

      final hasReferralAmount = columns.any(
        (column) => column['name'] == 'referral_commission_amount',
      );

      final hasReferralMarketerId = columns.any(
        (column) => column['name'] == 'referral_commission_marketer_id',
      );

      if (!hasReferralAmount) {
        await db.execute('''
          ALTER TABLE sales
          ADD COLUMN referral_commission_amount
          REAL NOT NULL DEFAULT 0
        ''');
      }

      if (!hasReferralMarketerId) {
        await db.execute('''
          ALTER TABLE sales
          ADD COLUMN referral_commission_marketer_id INTEGER
        ''');
      }
    }
  }

  // ==================================================
  // التحقق من وجود جدول
  // ==================================================

  Future<bool> _tableExists(DatabaseExecutor executor, String tableName) async {
    final result = await executor.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name = ?
      LIMIT 1
      ''',
      [tableName],
    );

    return result.isNotEmpty;
  }

  // ==================================================
  // سجل التدقيق: إضافة سجل
  // ==================================================

  Future<int> addAuditLog({
    required String action,
    required String entityType,
    int? entityId,
    required String description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    final db = await database;

    return db.insert('audit_logs', {
      'action': action.trim(),
      'entity_type': entityType.trim(),
      'entity_id': entityId,
      'description': description.trim(),
      'old_values': oldValues == null ? null : jsonEncode(oldValues),
      'new_values': newValues == null ? null : jsonEncode(newValues),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================================================
  // سجل التدقيق: جلب السجلات مع خيارات التصفية
  // ==================================================

  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? entityType,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (entityType != null && entityType.trim().isNotEmpty) {
      conditions.add('entity_type = ?');
      arguments.add(entityType.trim());
    }

    if (action != null && action.trim().isNotEmpty) {
      conditions.add('action = ?');
      arguments.add(action.trim());
    }

    if (startDate != null) {
      conditions.add('created_at >= ?');
      arguments.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      conditions.add('created_at <= ?');
      arguments.add(endDate.toIso8601String());
    }

    return db.query(
      'audit_logs',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'created_at DESC, id DESC',
      limit: limit < 1 ? 1 : limit,
      offset: offset < 0 ? 0 : offset,
    );
  }

  // ==================================================
  // سجل التدقيق: جلب سجل محدد
  // ==================================================

  Future<Map<String, dynamic>?> getAuditLog(int id) async {
    final db = await database;

    final rows = await db.query(
      'audit_logs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  // ==================================================
  // سجل التدقيق: عدد السجلات
  // ==================================================

  Future<int> getAuditLogsCount({String? entityType, String? action}) async {
    final db = await database;

    final conditions = <String>[];
    final arguments = <Object?>[];

    if (entityType != null && entityType.trim().isNotEmpty) {
      conditions.add('entity_type = ?');
      arguments.add(entityType.trim());
    }

    if (action != null && action.trim().isNotEmpty) {
      conditions.add('action = ?');
      arguments.add(action.trim());
    }

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM audit_logs
      ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
      ''', arguments);

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // ==================================================
  // الطلبات
  // ==================================================

  Future<int> addOrder({
    required String customerName,
    String? customerPhone,
    String? customerLocation,
    String? orderNote,
    String? status,
  }) async {
    final db = await database;
    final name = customerName.trim();

    if (name.isEmpty) {
      throw Exception('اسم العميل لا يمكن أن يكون فارغًا');
    }

    return db.insert('orders', {
      'customer_name': name,
      'customer_phone': customerPhone?.trim(),
      'customer_location': customerLocation?.trim(),
      'order_note': orderNote?.trim(),
      'total_amount': 0,
      'status': status ?? 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================================================
  // إضافة منتج إلى الطلب
  // ==================================================

  Future<int> addOrderItem({
    required int orderId,
    int? productId,
    required String productName,
    required double quantity,
    required double unitPrice,
  }) async {
    final db = await database;
    final cleanName = productName.trim();

    if (cleanName.isEmpty) {
      throw Exception('اسم المنتج لا يمكن أن يكون فارغًا');
    }

    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    final itemTotal = quantity * unitPrice;

    final itemId = await db.insert('order_items', {
      'order_id': orderId,
      'product_id': productId,
      'product_name': cleanName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': itemTotal,
    });

    await _recalculateOrderTotal(db, orderId);
    return itemId;
  }

  Future<void> _recalculateOrderTotal(Database db, int orderId) async {
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS total
      FROM order_items
      WHERE order_id = ?
      ''',
      [orderId],
    );

    final total = (result.first['total'] as num?)?.toDouble() ?? 0;

    await db.update(
      'orders',
      {'total_amount': total, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await database;
    return db.query('orders', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getOrder(int orderId) async {
    final db = await database;
    final rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getOrderForPrinting(int orderId) async {
    final db = await database;

    final orderRows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );

    if (orderRows.isEmpty) return null;

    final items = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );

    return {'order': orderRows.first, 'items': items};
  }

  Future<int> updateOrder({
    required int orderId,
    required String customerName,
    String? customerPhone,
    String? customerLocation,
    String? orderNote,
    String? status,
  }) async {
    final db = await database;
    final name = customerName.trim();

    if (name.isEmpty) {
      throw Exception('اسم العميل لا يمكن أن يكون فارغًا');
    }

    final data = <String, dynamic>{
      'customer_name': name,
      'customer_phone': customerPhone?.trim(),
      'customer_location': customerLocation?.trim(),
      'order_note': orderNote?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status != null) data['status'] = status;

    return db.update('orders', data, where: 'id = ?', whereArgs: [orderId]);
  }

  Future<int> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    final db = await database;

    return db.update(
      'orders',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> deleteOrder(int orderId) async {
    final db = await database;
    return db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }

  // ==================================================
  // أرقام وأكواد المسوقين
  // ==================================================

  Future<void> _validateCodePair(
    DatabaseExecutor executor, {
    required int marketerNumber,
    required String code,
    int? excludeId,
  }) async {
    if (marketerNumber <= 0) {
      throw Exception('رقم المسوق يجب أن يكون أكبر من صفر');
    }

    if (code.trim().isEmpty) {
      throw Exception('كود المسوق لا يمكن أن يكون فارغًا');
    }

    final numberMatches = await executor.query(
      'codes',
      columns: ['id'],
      where: 'marketer_number = ?${excludeId == null ? '' : ' AND id != ?'}',
      whereArgs: [marketerNumber, if (excludeId != null) excludeId],
      limit: 1,
    );

    final codeMatches = await executor.query(
      'codes',
      columns: ['id'],
      where: 'code = ?${excludeId == null ? '' : ' AND id != ?'}',
      whereArgs: [code.trim(), if (excludeId != null) excludeId],
      limit: 1,
    );

    if (numberMatches.isNotEmpty && codeMatches.isNotEmpty) {
      throw Exception('رقم المسوق والكود مستخدمان بالفعل');
    }

    if (numberMatches.isNotEmpty) {
      throw Exception('رقم المسوق مستخدم بالفعل');
    }

    if (codeMatches.isNotEmpty) {
      throw Exception('كود المسوق مستخدم بالفعل');
    }
  }

  Future<int> addMarketerCode({
    required int marketerNumber,
    required String code,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      await _validateCodePair(txn, marketerNumber: marketerNumber, code: code);

      return txn.insert('codes', {
        'marketer_number': marketerNumber,
        'code': code.trim(),
        'marketer_id': null,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': 1,
      });
    });
  }

  Future<int> updateMarketerCode({
    required int id,
    required int marketerNumber,
    required String code,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final existing = await txn.query(
        'codes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        throw Exception('رقم المسوق والكود غير موجودين');
      }

      if (existing.first['marketer_id'] != null) {
        throw Exception('لا يمكن تعديل رقم وكود محجوزين لمسوق حاليًا');
      }

      if (existing.first['is_active'] != 1) {
        throw Exception('لا يمكن تعديل رقم وكود معطلين');
      }

      await _validateCodePair(
        txn,
        marketerNumber: marketerNumber,
        code: code,
        excludeId: id,
      );

      return txn.update(
        'codes',
        {'marketer_number': marketerNumber, 'code': code.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> deleteMarketerCode(int codeId) async {
    final db = await database;

    final existing = await db.query(
      'codes',
      where: 'id = ?',
      whereArgs: [codeId],
      limit: 1,
    );

    if (existing.isEmpty) {
      throw Exception('رقم المسوق والكود غير موجودين');
    }

    if (existing.first['marketer_id'] != null) {
      throw Exception(
        'لا يمكن حذف الرقم والكود لأنهما مرتبطان بمسوق. قم بفصل المسوق أولًا.',
      );
    }

    return db.delete('codes', where: 'id = ?', whereArgs: [codeId]);
  }

  Future<int> setMarketerCodeActive({
    required int codeId,
    required bool isActive,
  }) async {
    final db = await database;

    final existing = await db.query(
      'codes',
      where: 'id = ?',
      whereArgs: [codeId],
      limit: 1,
    );

    if (existing.isEmpty) {
      throw Exception('رقم المسوق والكود غير موجودين');
    }

    if (!isActive && existing.first['marketer_id'] != null) {
      throw Exception('لا يمكن تعطيل رقم مرتبط بمسوق حاليًا');
    }

    return db.update(
      'codes',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [codeId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllCodes() async {
    final db = await database;

    return db.rawQuery('''
      SELECT
        c.id, c.marketer_number, c.code, c.marketer_id,
        c.created_at, c.is_active,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.is_active AS marketer_is_active
      FROM codes c
      LEFT JOIN marketers m ON m.id = c.marketer_id
      ORDER BY c.marketer_number ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAvailableMarketerCodes() async {
    final db = await database;

    return db.query(
      'codes',
      where: 'marketer_id IS NULL AND is_active = 1',
      orderBy: 'marketer_number ASC',
    );
  }

  Future<Map<String, dynamic>?> getMarketerCode(int codeId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id, c.marketer_number, c.code, c.marketer_id,
        c.created_at, c.is_active,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.is_active AS marketer_is_active
      FROM codes c
      LEFT JOIN marketers m ON m.id = c.marketer_id
      WHERE c.id = ?
      LIMIT 1
      ''',
      [codeId],
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getCodeByMarketerNumber(
    int marketerNumber,
  ) async {
    final db = await database;

    final rows = await db.query(
      'codes',
      where: 'marketer_number = ?',
      whereArgs: [marketerNumber],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getCodeByValue(String code) async {
    final db = await database;

    final rows = await db.query(
      'codes',
      where: 'code = ?',
      whereArgs: [code.trim()],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<void> assignCodeToMarketer({
    required int codeId,
    required int marketerId,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final codeResult = await txn.query(
        'codes',
        where: 'id = ?',
        whereArgs: [codeId],
        limit: 1,
      );

      if (codeResult.isEmpty) {
        throw Exception('رقم المسوق والكود غير موجودين');
      }

      final codeRow = codeResult.first;

      if (codeRow['is_active'] != 1) {
        throw Exception('رقم المسوق والكود غير فعالين');
      }

      final existingMarketerId = codeRow['marketer_id'];

      if (existingMarketerId != null && existingMarketerId != marketerId) {
        throw Exception('هذا الرقم والكود محجوزان لمسوق آخر');
      }

      final marketerResult = await txn.query(
        'marketers',
        where: 'id = ? AND is_active = 1',
        whereArgs: [marketerId],
        limit: 1,
      );

      if (marketerResult.isEmpty) {
        throw Exception('المسوق غير موجود أو غير نشط');
      }

      final currentCode = await txn.query(
        'codes',
        where: 'marketer_id = ? AND id != ?',
        whereArgs: [marketerId, codeId],
        limit: 1,
      );

      if (currentCode.isNotEmpty) {
        throw Exception('هذا المسوق مرتبط بالفعل برقم وكود آخر');
      }

      await txn.update(
        'codes',
        {'marketer_id': marketerId},
        where: 'id = ?',
        whereArgs: [codeId],
      );
    });
  }

  Future<void> releaseCodeFromMarketer(int marketerId) async {
    final db = await database;

    await db.update(
      'codes',
      {'marketer_id': null},
      where: 'marketer_id = ?',
      whereArgs: [marketerId],
    );
  }

  Future<List<Map<String, dynamic>>> searchMarketers(String query) async {
    final db = await database;
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) return getAllMarketers();

    return db.rawQuery(
      '''
      SELECT
        m.id, c.id AS code_id, c.marketer_number, c.code,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.is_active, m.created_at, m.updated_at
      FROM marketers m
      LEFT JOIN codes c ON c.marketer_id = m.id
      WHERE m.is_active = 1
        AND (
          m.name LIKE ?
          OR c.code LIKE ?
          OR CAST(c.marketer_number AS TEXT) LIKE ?
        )
      ORDER BY c.marketer_number ASC
      ''',
      ['%$cleanQuery%', '%$cleanQuery%', '%$cleanQuery%'],
    );
  }

  // التوافق مع الاستدعاءات القديمة.
  Future<int> addCode({required int marketerId, required String code}) {
    return addMarketerCode(marketerNumber: marketerId, code: code);
  }

  Future<Map<String, dynamic>?> getCode(int marketerId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        c.id, c.marketer_number, c.code, c.marketer_id,
        c.created_at, c.is_active,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.is_active AS marketer_is_active
      FROM codes c
      LEFT JOIN marketers m ON m.id = c.marketer_id
      WHERE c.marketer_id = ?
      LIMIT 1
      ''',
      [marketerId],
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<int> deleteCode(int marketerId) async {
    final db = await database;

    final codeResult = await db.query(
      'codes',
      where: 'marketer_id = ?',
      whereArgs: [marketerId],
      limit: 1,
    );

    if (codeResult.isEmpty) return 0;

    final codeId = codeResult.first['id'];

    await db.update(
      'codes',
      {'marketer_id': null},
      where: 'id = ?',
      whereArgs: [codeId],
    );

    return 1;
  }

  // ==================================================
  // المسوقون
  // ==================================================

  Future<int> addMarketer({
    required int marketerId,
    required String name,
    String? phone,
    int? parentId,
    double commissionRate = 0,
  }) async {
    final db = await database;

    final existing = await db.query(
      'marketers',
      where: 'id = ?',
      whereArgs: [marketerId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw Exception(
        'هذا المعرف الداخلي يخص مسوقًا سابقًا ولا يجوز إعادة استخدامه',
      );
    }

    if (name.trim().isEmpty) {
      throw Exception('اسم المسوق مطلوب');
    }

    if (commissionRate < 0 || commissionRate > 100) {
      throw Exception('نسبة العمولة يجب أن تكون بين 0 و100');
    }

    return db.insert('marketers', {
      'id': marketerId,
      'name': name.trim(),
      'phone': phone?.trim(),
      'parent_id': parentId,
      'commission_rate': commissionRate,
      'receives_referral_commission': 0,
      'referral_commission_rate': 0,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getMarketer(int marketerId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT
        m.id, c.id AS code_id, c.marketer_number, c.code,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.receives_referral_commission, m.referral_commission_rate,
        m.is_active, m.created_at, m.updated_at
      FROM marketers m
      LEFT JOIN codes c ON c.marketer_id = m.id
      WHERE m.id = ?
      LIMIT 1
      ''',
      [marketerId],
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllMarketers() async {
    final db = await database;

    return db.rawQuery('''
      SELECT
        m.id, c.id AS code_id, c.marketer_number, c.code,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.receives_referral_commission, m.referral_commission_rate,
        m.is_active, m.created_at, m.updated_at
      FROM marketers m
      LEFT JOIN codes c ON c.marketer_id = m.id
      WHERE m.is_active = 1
      ORDER BY
        CASE WHEN c.marketer_number IS NULL THEN 1 ELSE 0 END,
        c.marketer_number ASC
    ''');
  }

  Future<int> updateMarketer({
    required int marketerId,
    required String name,
    String? phone,
    int? parentId,
    required double commissionRate,
    bool receivesReferralCommission = false,
    double referralCommissionRate = 0,
  }) async {
    final db = await database;

    if (parentId == marketerId) {
      throw Exception('لا يمكن للمسوق أن يكون هو الشخص الذي دعاه');
    }

    if (name.trim().isEmpty) {
      throw Exception('اسم المسوق مطلوب');
    }

    if (commissionRate < 0 || commissionRate > 100) {
      throw Exception('نسبة العمولة يجب أن تكون بين 0 و100');
    }

    if (referralCommissionRate < 0 || referralCommissionRate > 100) {
      throw Exception('نسبة عمولة التبعية يجب أن تكون بين 0 و100');
    }

    final existing = await db.query(
      'marketers',
      where: 'id = ?',
      whereArgs: [marketerId],
      limit: 1,
    );

    if (existing.isEmpty) {
      throw Exception('المسوق غير موجود');
    }

    return db.update(
      'marketers',
      {
        'name': name.trim(),
        'phone': phone?.trim(),
        'parent_id': parentId,
        'commission_rate': commissionRate,
        'receives_referral_commission': receivesReferralCommission ? 1 : 0,
        'referral_commission_rate': referralCommissionRate,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [marketerId],
    );
  }

  Future<int> detachMarketer(int marketerId) async {
    final db = await database;

    return db.transaction((txn) async {
      final existing = await txn.query(
        'marketers',
        where: 'id = ?',
        whereArgs: [marketerId],
        limit: 1,
      );

      if (existing.isEmpty) {
        throw Exception('المسوق غير موجود');
      }

      await txn.update(
        'codes',
        {'marketer_id': null},
        where: 'marketer_id = ?',
        whereArgs: [marketerId],
      );

      return txn.update(
        'marketers',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [marketerId],
      );
    });
  }

  Future<List<int>> getInvitedMarketerIds(int marketerId) async {
    final db = await database;

    final result = await db.query(
      'marketers',
      columns: ['id'],
      where: 'parent_id = ? AND is_active = 1',
      whereArgs: [marketerId],
      orderBy: 'id ASC',
    );

    return result.map((row) => row['id'] as int).toList();
  }

  Future<List<Map<String, dynamic>>> getInvitedMarketers(int marketerId) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT
        m.id, c.id AS code_id, c.marketer_number, c.code,
        m.name, m.phone, m.parent_id, m.commission_rate,
        m.receives_referral_commission, m.referral_commission_rate,
        m.is_active
      FROM marketers m
      LEFT JOIN codes c ON c.marketer_id = m.id
      WHERE m.parent_id = ? AND m.is_active = 1
      ORDER BY c.marketer_number ASC
      ''',
      [marketerId],
    );
  }

  Future<int> getMarketerSalesCount(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sales WHERE marketer_id = ?',
      [marketerId],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<double> getMarketerTotalProfit(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_profit), 0) AS total_profit
      FROM sales WHERE marketer_id = ?
      ''',
      [marketerId],
    );

    return (result.first['total_profit'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getMarketerTotalCommission(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(commission_amount), 0) AS total_commission
      FROM sales WHERE marketer_id = ?
      ''',
      [marketerId],
    );

    return (result.first['total_commission'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getMarketerTotalReferralCommission(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(referral_commission_amount), 0)
        AS total_referral_commission
      FROM sales
      WHERE referral_commission_marketer_id = ?
      ''',
      [marketerId],
    );

    return (result.first['total_referral_commission'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getMarketerSales(int marketerId) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT
        s.id AS sale_id,
        s.total_amount,
        s.total_profit,
        s.commission_amount,
        s.referral_commission_amount,
        s.referral_commission_marketer_id,
        s.created_at,
        si.product_id,
        p.name AS product_name,
        si.quantity,
        si.unit_price,
        si.purchase_price,
        si.total_amount AS item_total,
        si.profit
      FROM sales s
      INNER JOIN sale_items si ON si.sale_id = s.id
      INNER JOIN products p ON p.id = si.product_id
      WHERE s.marketer_id = ?
      ORDER BY s.created_at DESC
      ''',
      [marketerId],
    );
  }

  // ==================================================
  // فواتير الزبائن: تسجيل بيانات الفاتورة والدفعات
  // ملاحظة: total_amount هو إجمالي المنتجات، والتوصيل منفصل.
  // ==================================================

  Future<void> setSaleInvoiceDetails({
    required int saleId,
    required String customerName,
    required String customerPhone,
    double deliveryFee = 0,
    double initialPayment = 0,
  }) async {
    final name = customerName.trim();
    final phone = customerPhone.trim();
    if (name.isEmpty || phone.isEmpty) {
      throw Exception('اسم الزبون ورقم هاتفه مطلوبان');
    }
    if (!deliveryFee.isFinite ||
        deliveryFee < 0 ||
        !initialPayment.isFinite ||
        initialPayment < 0) {
      throw Exception('قيمة التوصيل والدفعة يجب أن تكونا صحيحتين وغير سالبتين');
    }
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('عملية البيع غير موجودة');
      final sale = rows.first;
      if (sale['payment_status'] != 'unpaid') {
        throw Exception(
          'لا يمكن إعادة تهيئة فاتورة سبق تسجيل دفعاتها أو فاتورة قديمة',
        );
      }
      final prior =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM sale_payments WHERE sale_id = ?',
              [saleId],
            ),
          ) ??
          0;
      if (prior != 0 || sale['customer_name'] != null) {
        throw Exception('تم إعداد هذه الفاتورة مسبقًا');
      }
      final total = (sale['total_amount'] as num).toDouble() + deliveryFee;
      if (initialPayment > total + 0.000001) {
        throw Exception('المبلغ المقدم أكبر من إجمالي الفاتورة');
      }
      final now = DateTime.now().toIso8601String();
      if (initialPayment > 0) {
        await txn.insert('sale_payments', {
          'sale_id': saleId,
          'amount': initialPayment,
          'note': 'الدفعة الأولى',
          'created_at': now,
        });
      }
      final status = total - initialPayment <= 0.000001
          ? 'paid'
          : initialPayment > 0
          ? 'partial'
          : 'unpaid';
      await txn.update(
        'sales',
        {
          'customer_name': name,
          'customer_phone': phone,
          'delivery_fee': deliveryFee,
          'payment_status': status,
          'payment_updated_at': now,
          'fully_paid_at': status == 'paid' ? now : null,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<Map<String, dynamic>?> getSaleInvoice(int saleId) async {
    final db = await database;
    final sales = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (sales.isEmpty) return null;
    final items = await db.rawQuery(
      '''
      SELECT si.*, p.name AS product_name
      FROM sale_items si LEFT JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ? ORDER BY si.id ASC
    ''',
      [saleId],
    );
    final payments = await db.query(
      'sale_payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'created_at ASC, id ASC',
    );
    final sale = sales.first;
    final total =
        (sale['total_amount'] as num).toDouble() +
        ((sale['delivery_fee'] as num?)?.toDouble() ?? 0);
    final paid = payments.fold<double>(
      0,
      (sum, row) => sum + (row['amount'] as num).toDouble(),
    );
    return {
      'sale': sale,
      'items': items,
      'payments': payments,
      'invoice_total': total,
      'paid_amount': paid,
      'remaining_amount': (total - paid).clamp(0.0, double.infinity).toDouble(),
    };
  }

  Future<void> addSalePayment({
    required int saleId,
    required double amount,
    String? note,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('أدخل مبلغًا أكبر من صفر');
    }
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('عملية البيع غير موجودة');
      final sale = rows.first;
      if (sale['customer_name'] == null || sale['payment_status'] == 'legacy') {
        throw Exception('يجب تجهيز فاتورة الزبون أولًا');
      }
      if (sale['payment_status'] == 'paid') {
        throw Exception('الفاتورة مسددة بالكامل');
      }
      final result = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS paid FROM sale_payments WHERE sale_id = ?',
        [saleId],
      );
      final paid = (result.first['paid'] as num).toDouble();
      final total =
          (sale['total_amount'] as num).toDouble() +
          (sale['delivery_fee'] as num).toDouble();
      final remaining = total - paid;
      if (sale['payment_status'] == 'paid') {
        throw Exception('الدفعة أكبر من المبلغ المتبقي');
      }
      final now = DateTime.now().toIso8601String();
      await txn.insert('sale_payments', {
        'sale_id': saleId,
        'amount': amount,
        'note': note?.trim(),
        'created_at': now,
      });
      final completed = remaining - amount <= 0.000001;
      await txn.update(
        'sales',
        {
          'payment_status': completed ? 'paid' : 'partial',
          'payment_updated_at': now,
          'fully_paid_at': completed ? now : null,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );
      await txn.insert('audit_logs', {
        'action': 'add_payment',
        'entity_type': 'sale',
        'entity_id': saleId,
        'description': 'تسجيل دفعة على فاتورة بيع',
        'old_values': jsonEncode({'paid_amount': paid}),
        'new_values': jsonEncode({
          'payment_amount': amount,
          'paid_amount': paid + amount,
        }),
        'created_at': now,
      });
    });
  }

  Future<List<Map<String, dynamic>>> getOutstandingSaleInvoices() async {
    final db = await database;
    return db.rawQuery('''
      SELECT s.*, (s.total_amount + s.delivery_fee) AS invoice_total,
        COALESCE((SELECT SUM(sp.amount) FROM sale_payments sp WHERE sp.sale_id = s.id), 0) AS paid_amount,
        (s.total_amount + s.delivery_fee - COALESCE(
          (SELECT SUM(sp.amount) FROM sale_payments sp WHERE sp.sale_id = s.id), 0
        )) AS remaining_amount
      FROM sales s
      WHERE s.payment_status IN ('unpaid', 'partial') AND s.customer_name IS NOT NULL
      ORDER BY s.created_at ASC, s.id ASC
    ''');
  }
  // ==================================================
  // المصروفات وصافي الأرباح
  // ==================================================

  /// إجمالي جميع المصروفات المسجلة
  Future<double> getTotalExpenses() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) AS total
    FROM expenses
  ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// إجمالي أرباح المبيعات قبل خصم المصروفات
  Future<double> getTotalSalesProfit() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT COALESCE(SUM(total_profit), 0) AS total
    FROM sales
  ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// صافي الأرباح بعد خصم المصروفات
  Future<double> getNetProfit() async {
    final salesProfit = await getTotalSalesProfit();
    final expenses = await getTotalExpenses();

    return salesProfit - expenses;
  }
}
