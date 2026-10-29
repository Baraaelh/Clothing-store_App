/// أسماء الجداول والأعمدة المشتركة.
abstract final class Tables {
  static const catalogItems = 'catalog_items';
  static const sales = 'sales';
  static const saleItems = 'sale_items';
  static const onlineOrders = 'online_orders';
  static const syncQueue = 'sync_queue';
}

/// حالة مزامنة السجل المحلي.
abstract final class SyncStatus {
  static const pending = 'pending';
  static const synced = 'synced';
  static const failed = 'failed';
}

abstract final class Schema {
  static const List<String> v1 = [
    // نسخة محلية من منتجات الفرع (variant = منتج + لون + مقاس). مصدرها السيرفر فقط.
    // server_quantity = الكمية حسب آخر سحب من السيرفر. الكمية المتاحة للبيع
    // = server_quantity - كميات المبيعات المحلية التي لم تُرسل بعد.
    '''
    CREATE TABLE ${Tables.catalogItems} (
      variant_id INTEGER PRIMARY KEY,
      product_id INTEGER NOT NULL,
      product_code TEXT NOT NULL,
      product_name TEXT NOT NULL,
      category_name TEXT,
      color_name TEXT,
      size_name TEXT,
      sku TEXT NOT NULL,
      selling_price INTEGER NOT NULL,
      minimum_selling_price INTEGER,
      server_quantity INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      synced_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_catalog_search ON ${Tables.catalogItems} (product_name, sku)',

    // فواتير البيع. id = UUID يُولد على الجهاز ويُرسل للسيرفر كـ client_uuid.
    '''
    CREATE TABLE ${Tables.sales} (
      id TEXT PRIMARY KEY,
      server_id INTEGER,
      branch_id INTEGER NOT NULL,
      cashier_name TEXT NOT NULL,
      customer_name TEXT,
      payment_method TEXT NOT NULL,
      subtotal INTEGER NOT NULL,
      discount INTEGER NOT NULL DEFAULT 0,
      total INTEGER NOT NULL,
      amount_paid INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending'
    )
    ''',
    'CREATE INDEX idx_sales_sync ON ${Tables.sales} (sync_status)',
    '''
    CREATE TABLE ${Tables.saleItems} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id TEXT NOT NULL REFERENCES ${Tables.sales}(id) ON DELETE CASCADE,
      variant_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      color_name TEXT,
      size_name TEXT,
      sku TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price INTEGER NOT NULL,
      line_total INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_sale_items_variant ON ${Tables.saleItems} (variant_id)',

    // طلبات المتجر الإلكتروني. status = آخر حالة معروفة (محلية إن وُجد تغيير لم يُرسل).
    '''
    CREATE TABLE ${Tables.onlineOrders} (
      id TEXT PRIMARY KEY,
      customer_name TEXT NOT NULL,
      phone TEXT,
      city TEXT,
      address TEXT,
      notes TEXT,
      items_json TEXT NOT NULL,
      total INTEGER NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced'
    )
    ''',

    // طابور العمليات المنتظرة للإرسال (Outbox). تُنفذ بالترتيب.
    '''
    CREATE TABLE ${Tables.syncQueue} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      operation TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_sync_queue_status ON ${Tables.syncQueue} (status, id)',
  ];
}
