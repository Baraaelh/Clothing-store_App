/// أسماء الجداول المحلية.
abstract final class Tables {
  // نسخة القراءة من السيرفر (Cache). تُملأ فقط من /sync/bootstrap و/sync/pull.
  static const categories = 'cache_categories';
  static const colors = 'cache_colors';
  static const sizes = 'cache_sizes';
  static const products = 'cache_products';
  static const variants = 'cache_variants';
  static const stocks = 'cache_stocks';
  static const accounts = 'cache_accounts';
  static const customers = 'cache_customers';
  static const suppliers = 'cache_suppliers';
  static const branches = 'cache_branches';

  /// كيانات لا يعرضها التطبيق حاليًا (مبيعات/مشتريات/سندات السيرفر...). تُحفظ كما هي.
  static const other = 'cache_other';

  /// حالة المزامنة (cursor، sync_uuid...).
  static const syncState = 'sync_state';

  /// العمليات المحلية المنتظرة للإرسال ونتائجها (Outbox).
  static const outbox = 'outbox';

  /// فواتير البيع التي أُنشئت على هذا الجهاز (للسجل وخصم الكميات قبل التأكيد).
  static const localSales = 'local_sales';
  static const localSaleItems = 'local_sale_items';

  /// كل جداول الـ Cache (تُمسح عند تغيير المستخدم/الفرع أو عند إعادة Bootstrap).
  static const cacheTables = [
    categories,
    colors,
    sizes,
    products,
    variants,
    stocks,
    accounts,
    customers,
    suppliers,
    branches,
    other,
  ];
}

/// حالة عملية في الـ Outbox.
abstract final class OutboxStatus {
  /// تنتظر الإرسال (أو إعادة المحاولة).
  static const pending = 'pending';

  /// قبلها السيرفر.
  static const accepted = 'accepted';

  /// رفضها السيرفر (تحقق أو تعارض): تحتاج مراجعة المستخدم. لا تُعاد تلقائيًا.
  static const review = 'review';

  /// ألغاها المستخدم بعد المراجعة.
  static const dismissed = 'dismissed';
}

abstract final class Schema {
  static const List<String> v2 = [
    'CREATE TABLE ${Tables.categories} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1)',
    'CREATE TABLE ${Tables.colors} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, code TEXT, hex TEXT, is_active INTEGER NOT NULL DEFAULT 1)',
    'CREATE TABLE ${Tables.sizes} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, code TEXT, sort_order INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1)',
    '''
    CREATE TABLE ${Tables.products} (
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL,
      name TEXT NOT NULL,
      category_id INTEGER,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      revision TEXT
    )
    ''',
    '''
    CREATE TABLE ${Tables.variants} (
      id INTEGER PRIMARY KEY,
      product_id INTEGER NOT NULL,
      color_id INTEGER,
      size_id INTEGER,
      sku TEXT NOT NULL,
      selling_price INTEGER NOT NULL,
      minimum_selling_price INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      revision TEXT
    )
    ''',
    'CREATE INDEX idx_variants_product ON ${Tables.variants} (product_id)',
    '''
    CREATE TABLE ${Tables.stocks} (
      variant_id INTEGER PRIMARY KEY,
      id INTEGER NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 0,
      reserved_quantity INTEGER NOT NULL DEFAULT 0,
      available_quantity INTEGER NOT NULL DEFAULT 0,
      average_cost INTEGER,
      revision TEXT NOT NULL
    )
    ''',
    'CREATE TABLE ${Tables.accounts} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1)',
    'CREATE TABLE ${Tables.customers} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, phone TEXT)',
    'CREATE TABLE ${Tables.suppliers} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, phone TEXT)',
    'CREATE TABLE ${Tables.branches} (id INTEGER PRIMARY KEY, name TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, opening_stock_closed_at TEXT)',
    'CREATE TABLE ${Tables.other} (entity TEXT NOT NULL, id INTEGER NOT NULL, data TEXT NOT NULL, PRIMARY KEY (entity, id))',
    'CREATE TABLE ${Tables.syncState} (key TEXT PRIMARY KEY, value TEXT)',
    '''
    CREATE TABLE ${Tables.outbox} (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      operation_uuid TEXT NOT NULL UNIQUE,
      operation_type TEXT NOT NULL,
      client_created_at TEXT NOT NULL,
      branch_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      payload TEXT NOT NULL,
      dependencies TEXT NOT NULL DEFAULT '[]',
      summary TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      result TEXT,
      error_code TEXT,
      error_message TEXT,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at TEXT,
      updated_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_outbox_status ON ${Tables.outbox} (status, seq)',
    '''
    CREATE TABLE ${Tables.localSales} (
      id TEXT PRIMARY KEY,
      operation_uuid TEXT NOT NULL UNIQUE,
      user_id INTEGER NOT NULL,
      branch_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      cashier_name TEXT NOT NULL,
      customer_name TEXT,
      payment_label TEXT NOT NULL,
      subtotal INTEGER NOT NULL,
      discount INTEGER NOT NULL DEFAULT 0,
      total INTEGER NOT NULL,
      paid INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      number TEXT
    )
    ''',
    '''
    CREATE TABLE ${Tables.localSaleItems} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id TEXT NOT NULL REFERENCES ${Tables.localSales}(id) ON DELETE CASCADE,
      variant_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      variant_label TEXT,
      sku TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_local_sale_items_variant ON ${Tables.localSaleItems} (variant_id)',
  ];
}
