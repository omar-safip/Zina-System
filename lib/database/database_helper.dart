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

    return await openDatabase(
      path,

      // الإصدار الحالي
      version: 5,

      // ==============================================

      // تفعيل العلاقات بين الجداول

      // ==============================================
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      // ==============================================

      // إنشاء قاعدة بيانات جديدة

      // ==============================================
      onCreate: (db, version) async {
        await _createTables(db);
      },

      // ==============================================

      // تحديث قاعدة بيانات قديمة

      // ==============================================
      onUpgrade: (db, oldVersion, newVersion) async {
        // ----------------------------------------------

        // الإصدار 1 → 2

        // ----------------------------------------------

        if (oldVersion < 2) {
          await _createTables(db);

          await db.execute('DROP TABLE IF EXISTS test');
        }

        // ----------------------------------------------

        // الإصدار 2 → 3

        // تعديل جدول المسوقين

        // ----------------------------------------------

        if (oldVersion < 3) {
          await _upgradeMarketersTable(db);
        }

        // ----------------------------------------------

        // الإصدار 3 → 4

        // إضافة جدول الأكواد وفصل الكود عن المسوق

        // ----------------------------------------------

        if (oldVersion < 4) {
          await _upgradeToVersion4(db);
        }

        if (oldVersion < 5) {
          await _upgradeToVersion5(db);
        }
      },
    );
  }

  // ==================================================

  // إنشاء جميع الجداول

  // ==================================================

  Future<void> _createTables(Database db) async {
    // ==================================================

    // 1. الأكواد

    // ==================================================

    await db.execute('''

      CREATE TABLE IF NOT EXISTS codes (

        marketer_id INTEGER PRIMARY KEY,

        code TEXT UNIQUE NOT NULL,

        created_at TEXT NOT NULL,

        is_active INTEGER NOT NULL DEFAULT 1

      )

    ''');

    // ==================================================

    // 2. المسوقون

    // ==================================================

    await db.execute('''

      CREATE TABLE IF NOT EXISTS marketers (

        id INTEGER PRIMARY KEY,



        name TEXT,



        phone TEXT,



        parent_id INTEGER,



        commission_rate REAL NOT NULL DEFAULT 0,



        is_active INTEGER NOT NULL DEFAULT 1,



        created_at TEXT NOT NULL,



        updated_at TEXT,



        FOREIGN KEY (id)

          REFERENCES codes (marketer_id)

          ON DELETE RESTRICT,



        FOREIGN KEY (parent_id)

          REFERENCES marketers (id)

          ON DELETE SET NULL

      )

    ''');

    // ==================================================

    // 3. المنتجات

    // ==================================================

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

    // ==================================================

    // 4. حركة المخزون

    // ==================================================

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

    // ==================================================

    // 5. المبيعات

    // ==================================================

    await db.execute('''

      CREATE TABLE IF NOT EXISTS sales (

        id INTEGER PRIMARY KEY AUTOINCREMENT,



        marketer_id INTEGER,



        total_amount REAL NOT NULL DEFAULT 0,



        total_profit REAL NOT NULL DEFAULT 0,



        commission_amount REAL NOT NULL DEFAULT 0,



        note TEXT,



        created_at TEXT NOT NULL,



        FOREIGN KEY (marketer_id)

          REFERENCES marketers (id)

          ON DELETE SET NULL

      )

    ''');

    // ==================================================

    // 6. تفاصيل المبيعات

    // ==================================================

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

    // ==================================================

    // 7. المصروفات

    // ==================================================

    await db.execute('''

      CREATE TABLE IF NOT EXISTS expenses (

        id INTEGER PRIMARY KEY AUTOINCREMENT,



        title TEXT NOT NULL,



        amount REAL NOT NULL,



        note TEXT,



        created_at TEXT NOT NULL

      )

    ''');

    // ==================================================

    // 8. الطلبات

    // ==================================================

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

    // ==================================================

    // 9. تفاصيل الطلبات

    // ==================================================

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

  // ترقية جدول المسوقين من الإصدار القديم

  // ==================================================

  Future<void> _upgradeMarketersTable(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      // معرفة أعمدة جدول marketers الحالي
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
          id,
          name,
          phone,
          code,
          parent_id,
          commission_rate,
          is_active,
          created_at,
          updated_at
        )
        SELECT
          id,
          name,
          phone,
          code,
          parent_id,
          commission_rate,
          is_active,
          created_at,
          updated_at
        FROM marketers
      ''');
      } else {
        await db.execute('''
        INSERT OR IGNORE INTO marketers_new (
          id,
          name,
          phone,
          parent_id,
          commission_rate,
          is_active,
          created_at,
          updated_at
        )
        SELECT
          id,
          name,
          phone,
          parent_id,
          commission_rate,
          is_active,
          created_at,
          updated_at
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

  // فصل الأكواد عن المسوقين

  // ==================================================

  Future<void> _upgradeToVersion4(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      // ==============================================
      // إنشاء جدول الأكواد
      // ==============================================

      await db.execute('''
      CREATE TABLE IF NOT EXISTS codes (
        marketer_id INTEGER PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

      // ==============================================
      // معرفة هل جدول marketers يحتوي على code
      // ==============================================

      final columns = await db.rawQuery('PRAGMA table_info(marketers)');

      final hasCode = columns.any((column) => column['name'] == 'code');

      // ==============================================
      // نقل الأكواد القديمة إذا كان code موجودًا
      // ==============================================

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
          final createdAt = row['created_at'];

          if (marketerId != null && code != null) {
            await db.insert('codes', {
              'marketer_id': marketerId,
              'code': code,
              'created_at': createdAt ?? DateTime.now().toIso8601String(),
              'is_active': 1,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      // ==============================================
      // إنشاء جدول المسوقين الجديد بدون code
      // ==============================================

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

      // ==============================================
      // نقل جميع المسوقين
      // ==============================================

      await db.execute('''
      INSERT OR IGNORE INTO marketers_new (
        id,
        name,
        phone,
        parent_id,
        commission_rate,
        is_active,
        created_at,
        updated_at
      )
      SELECT
        id,
        name,
        phone,
        parent_id,
        commission_rate,
        is_active,
        created_at,
        updated_at
      FROM marketers
    ''');

      // ==============================================
      // حذف القديم
      // ==============================================

      await db.execute('DROP TABLE marketers');

      await db.execute('ALTER TABLE marketers_new RENAME TO marketers');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // ==================================================

  // الأكواد

  // ==================================================

  // ==================================================

  // ترقية الإصدار 4 → 5

  // إضافة الطلبات وتفاصيل الطلبات

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

    return await db.insert('orders', {
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

  /// إضافة منتج إلى الطلب وحفظ السعر وقت إنشاء الطلب.

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

    return await db.query('orders', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getOrder(int orderId) async {
    final db = await database;

    final result = await db.query(
      'orders',

      where: 'id = ?',

      whereArgs: [orderId],

      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  /// جلب الطلب كاملًا مع تفاصيله لاستخدامه في شاشة الطباعة.

  Future<Map<String, dynamic>?> getOrderForPrinting(int orderId) async {
    final db = await database;

    final orderResult = await db.query(
      'orders',

      where: 'id = ?',

      whereArgs: [orderId],

      limit: 1,
    );

    if (orderResult.isEmpty) {
      return null;
    }

    final items = await db.query(
      'order_items',

      where: 'order_id = ?',

      whereArgs: [orderId],

      orderBy: 'id ASC',
    );

    return {'order': orderResult.first, 'items': items};
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

    if (status != null) {
      data['status'] = status;
    }

    return await db.update(
      'orders',

      data,

      where: 'id = ?',

      whereArgs: [orderId],
    );
  }

  Future<int> updateOrderStatus({
    required int orderId,

    required String status,
  }) async {
    final db = await database;

    return await db.update(
      'orders',

      {'status': status, 'updated_at': DateTime.now().toIso8601String()},

      where: 'id = ?',

      whereArgs: [orderId],
    );
  }

  Future<int> deleteOrder(int orderId) async {
    final db = await database;

    return await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }

  /// إضافة رقم مسوق + كود

  Future<int> addCode({required int marketerId, required String code}) async {
    final db = await database;

    final cleanCode = code.trim();

    if (cleanCode.isEmpty) {
      throw Exception('رقم الكود لا يمكن أن يكون فارغًا');
    }

    return await db.insert('codes', {
      'marketer_id': marketerId,

      'code': cleanCode,

      'created_at': DateTime.now().toIso8601String(),

      'is_active': 1,
    });
  }

  // ==================================================

  /// جلب جميع الأكواد

  Future<List<Map<String, dynamic>>> getAllCodes() async {
    final db = await database;

    return await db.rawQuery('''

      SELECT

        c.marketer_id,

        c.code,

        c.created_at,

        c.is_active,



        m.name,

        m.phone,

        m.parent_id,

        m.commission_rate,

        m.is_active AS marketer_is_active



      FROM codes c



      LEFT JOIN marketers m

        ON m.id = c.marketer_id



      ORDER BY c.marketer_id ASC

    ''');
  }

  // ==================================================

  /// جلب كود مسوق معين

  Future<Map<String, dynamic>?> getCode(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''

      SELECT

        c.marketer_id,

        c.code,

        c.created_at,

        c.is_active,



        m.name,

        m.phone,

        m.parent_id,

        m.commission_rate,

        m.is_active AS marketer_is_active



      FROM codes c



      LEFT JOIN marketers m

        ON m.id = c.marketer_id



      WHERE c.marketer_id = ?

      ''',

      [marketerId],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ==================================================

  /// حذف رقم مسوق وكوده

  Future<int> deleteCode(int marketerId) async {
    final db = await database;

    // نتأكد أولاً أن الرقم غير مستخدم في بيانات مسوق

    final marketer = await db.query(
      'marketers',

      where: 'id = ?',

      whereArgs: [marketerId],

      limit: 1,
    );

    if (marketer.isNotEmpty) {
      throw Exception('لا يمكن حذف الكود قبل فصل المسوق المرتبط به');
    }

    return await db.delete(
      'codes',

      where: 'marketer_id = ?',

      whereArgs: [marketerId],
    );
  }

  // ==================================================

  // المسوقون

  // ==================================================

  /// إضافة بيانات مسوق إلى رقم موجود مسبقًا

  Future<int> addMarketer({
    required int marketerId,

    required String name,

    String? phone,

    int? parentId,

    double commissionRate = 0,
  }) async {
    final db = await database;

    // ----------------------------------------------

    // التأكد من وجود الرقم والكود

    // ----------------------------------------------

    final codeResult = await db.query(
      'codes',

      where: 'marketer_id = ?',

      whereArgs: [marketerId],

      limit: 1,
    );

    if (codeResult.isEmpty) {
      throw Exception('رقم المسوق غير موجود في قائمة الأكواد');
    }

    // ----------------------------------------------

    // التأكد من عدم وجود مسوق نشط بالفعل

    // ----------------------------------------------

    final existingMarketer = await db.query(
      'marketers',

      where: 'id = ?',

      whereArgs: [marketerId],

      limit: 1,
    );

    if (existingMarketer.isNotEmpty) {
      final isActive = existingMarketer.first['is_active'] == 1;

      if (isActive) {
        throw Exception('يوجد مسوق مرتبط بهذا الرقم بالفعل');
      }

      // --------------------------------------------

      // الرقم موجود لكن المسوق السابق مفصول

      // نعيد استخدام نفس الرقم

      // --------------------------------------------

      return await db.update(
        'marketers',

        {
          'name': name.trim(),

          'phone': phone?.trim(),

          'parent_id': parentId,

          'commission_rate': commissionRate,

          'is_active': 1,

          'updated_at': DateTime.now().toIso8601String(),
        },

        where: 'id = ?',

        whereArgs: [marketerId],
      );
    }

    // ----------------------------------------------

    // إضافة مسوق جديد

    // ----------------------------------------------

    return await db.insert('marketers', {
      'id': marketerId,

      'name': name.trim(),

      'phone': phone?.trim(),

      'parent_id': parentId,

      'commission_rate': commissionRate,

      'is_active': 1,

      'created_at': DateTime.now().toIso8601String(),

      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================================================

  /// جلب مسوق واحد

  Future<Map<String, dynamic>?> getMarketer(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''

      SELECT

        m.id,

        c.code,

        m.name,

        m.phone,

        m.parent_id,

        m.commission_rate,

        m.is_active,

        m.created_at,

        m.updated_at



      FROM marketers m



      INNER JOIN codes c

        ON c.marketer_id = m.id



      WHERE m.id = ?

      ''',

      [marketerId],
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ==================================================

  /// جلب جميع المسوقين النشطين

  Future<List<Map<String, dynamic>>> getAllMarketers() async {
    final db = await database;

    return await db.rawQuery('''

      SELECT

        m.id,

        c.code,

        m.name,

        m.phone,

        m.parent_id,

        m.commission_rate,

        m.is_active,

        m.created_at,

        m.updated_at



      FROM marketers m



      INNER JOIN codes c

        ON c.marketer_id = m.id



      WHERE m.is_active = 1



      ORDER BY m.id ASC

    ''');
  }

  // ==================================================

  /// تعديل بيانات المسوق

  Future<int> updateMarketer({
    required int marketerId,

    required String name,

    String? phone,

    int? parentId,

    required double commissionRate,
  }) async {
    final db = await database;

    // ----------------------------------------------

    // منع المسوق من دعوة نفسه

    // ----------------------------------------------

    if (parentId == marketerId) {
      throw Exception('لا يمكن للمسوق أن يكون هو الشخص الذي دعاه');
    }

    // ----------------------------------------------

    // التأكد من وجود المسوق

    // ----------------------------------------------

    final existing = await db.query(
      'marketers',

      where: 'id = ?',

      whereArgs: [marketerId],

      limit: 1,
    );

    if (existing.isEmpty) {
      throw Exception('المسوق غير موجود');
    }

    return await db.update(
      'marketers',

      {
        'name': name.trim(),

        'phone': phone?.trim(),

        'parent_id': parentId,

        'commission_rate': commissionRate,

        'updated_at': DateTime.now().toIso8601String(),
      },

      where: 'id = ?',

      whereArgs: [marketerId],
    );
  }

  // ==================================================

  /// فصل المسوق عن رقمه وكوده

  ///

  /// الرقم والكود يبقيان موجودين.

  /// بيانات الشخص تصبح فارغة.

  // ==================================================

  Future<int> detachMarketer(int marketerId) async {
    final db = await database;

    return await db.update(
      'marketers',

      {
        'name': null,

        'phone': null,

        'parent_id': null,

        'commission_rate': 0,

        'is_active': 0,

        'updated_at': DateTime.now().toIso8601String(),
      },

      where: 'id = ?',

      whereArgs: [marketerId],
    );
  }

  // ==================================================

  // المسوقون الذين دعاهم مسوق معين

  // ==================================================

  /// يرجع أرقام المسوقين الذين دعاهم هذا المسوق

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

  // ==================================================

  /// جلب بيانات المسوقين الذين دعاهم

  Future<List<Map<String, dynamic>>> getInvitedMarketers(int marketerId) async {
    final db = await database;

    return await db.rawQuery(
      '''

      SELECT

        m.id,

        c.code,

        m.name,

        m.phone,

        m.parent_id,

        m.commission_rate,

        m.is_active



      FROM marketers m



      INNER JOIN codes c

        ON c.marketer_id = m.id



      WHERE m.parent_id = ?

        AND m.is_active = 1



      ORDER BY m.id ASC

      ''',

      [marketerId],
    );
  }

  // ==================================================

  // عدد مبيعات المسوق

  // ==================================================

  Future<int> getMarketerSalesCount(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''

      SELECT COUNT(*) AS total

      FROM sales

      WHERE marketer_id = ?

      ''',

      [marketerId],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  // ==================================================

  // إجمالي أرباح المسوق

  // ==================================================

  Future<double> getMarketerTotalProfit(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''

      SELECT

        COALESCE(SUM(total_profit), 0) AS total_profit



      FROM sales



      WHERE marketer_id = ?

      ''',

      [marketerId],
    );

    final value = result.first['total_profit'];

    if (value == null) {
      return 0;
    }

    return (value as num).toDouble();
  }

  // ==================================================

  // إجمالي عمولة المسوق

  // ==================================================

  Future<double> getMarketerTotalCommission(int marketerId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''

      SELECT

        COALESCE(SUM(commission_amount), 0)

        AS total_commission



      FROM sales



      WHERE marketer_id = ?

      ''',

      [marketerId],
    );

    final value = result.first['total_commission'];

    if (value == null) {
      return 0;
    }

    return (value as num).toDouble();
  }

  // ==================================================

  // مبيعات المسوق مع المنتجات

  // ==================================================

  Future<List<Map<String, dynamic>>> getMarketerSales(int marketerId) async {
    final db = await database;

    return await db.rawQuery(
      '''

      SELECT

        s.id AS sale_id,

        s.total_amount,

        s.total_profit,

        s.commission_amount,

        s.created_at,



        si.product_id,

        p.name AS product_name,

        si.quantity,

        si.unit_price,

        si.purchase_price,

        si.total_amount AS item_total,

        si.profit



      FROM sales s



      INNER JOIN sale_items si

        ON si.sale_id = s.id



      INNER JOIN products p

        ON p.id = si.product_id



      WHERE s.marketer_id = ?



      ORDER BY s.created_at DESC

      ''',

      [marketerId],
    );
  }
}
