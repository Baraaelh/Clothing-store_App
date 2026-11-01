# متجر الأناقة — تطبيق الموبايل

تطبيق Flutter للكاشير وطلبات الموقع. **يعمل بدون إنترنت**: كل شيء يُحفظ في SQLite على الجهاز، ويُرسل للسيرفر تلقائيًا عند توفر الاتصال.

## الميزات
- **تسجيل الدخول:** التوكن يُحفظ في التخزين الآمن للجهاز، والجلسة تُستعاد عند فتح التطبيق بدون إنترنت. الفرع واسم الكاشير يأتيان من حساب المستخدم. عند انتهاء الجلسة (401) يرجع التطبيق لشاشة الدخول **دون أن يفقد العمليات المنتظرة**.
- **الصلاحيات:** الكاشير يرى الكاشير فقط. المالك والمدير يرون طلبات الموقع أيضًا.
- **الكاشير:** بحث في المنتجات (منتج + لون + مقاس)، سلة، خصم، دفع نقدي / محفظة / بنكي، حساب الباقي. لا يسمح بالبيع بأكثر من الكمية المتوفرة ولا بأقل من الحد الأدنى للسعر.
- **طلبات الموقع:** عرض الطلبات حسب الحالة، قبول ورفض، تفاصيل الزبون والأصناف.
- **المزامنة:** أيقونة في الأعلى تعرض حالة الاتصال وعدد العمليات المنتظرة، مع "مزامنة الآن" و"إعادة محاولة الفاشلة".

## التشغيل
```bash
flutter pub get
flutter run                                                   # بدون API: دخول وبيانات تجريبية (وضع التطوير فقط)
flutter run --dart-define=API_BASE_URL=https://example.com/api
flutter test
```

## البنية (Clean Architecture + Cubit)
```
lib/
├── app/                      # MaterialApp، الثيم، الشاشة الرئيسية
├── core/
│   ├── config/               # ApiConfig (المسارات)، AppSettings (اسم الجهاز، فترة المزامنة)
│   ├── session/              # الجلسة الحالية (التوكن، المستخدم، الفرع) وحفظها الآمن
│   ├── database/             # SQLite: الجداول، الترحيلات، بيانات تجريبية
│   ├── di/                   # get_it
│   ├── error/                # Exceptions (data) → Failures (domain)
│   ├── network/              # ApiClient (Dio)، NetworkInfo
│   ├── sync/                 # طابور المزامنة، المحرك، SyncCubit
│   └── utils/                # Result<T>، Money
└── features/
    ├── auth/                 # تسجيل الدخول والخروج
    ├── pos/                  # الكاشير
    └── online_orders/        # طلبات الموقع
        ├── domain/           # entities، repository (interface)، usecases — بدون Flutter
        ├── data/             # models، local/remote data sources، repository impl، sync handlers
        └── presentation/     # cubits، pages، widgets
```
اتجاه الاعتماد: `presentation → domain ← data`. الواجهة لا تعرف شيئًا عن SQLite أو الـ API.

## كيف تعمل المزامنة (Offline-first)
1. **الكتابة محليًا دائمًا.** عند البيع أو قبول طلب، يُحفظ التغيير في SQLite **ويُضاف لجدول `sync_queue` في نفس الـ transaction**، فلا يضيع أحدهما بدون الآخر.
2. **الإرسال (push):** عند عودة الاتصال، وكل دقيقتين، وفور إضافة عملية جديدة، يرسل `SyncService` العمليات بالترتيب.
   - انقطاع الاتصال ← تتوقف الدورة وتبقى العمليات.
   - خطأ مؤقت (5xx) ← إعادة محاولة في الدورة القادمة.
   - رفض نهائي (4xx مثل 422)، أو تجاوز عدد المحاولات ← العملية "فاشلة" وتظهر في أيقونة المزامنة.
3. **السحب (pull):** بعد الإرسال، تُسحب المنتجات والكميات وطلبات الموقع.
4. **عدم التكرار:** كل فاتورة لها UUID يُولد على الجهاز ويُرسل كـ `client_uuid`. **يجب على السيرفر رفض/تجاهل أي فاتورة بنفس `client_uuid`**، لأن الجهاز قد يعيد الإرسال إذا انقطع الاتصال قبل وصول الرد.
5. **الكمية المتاحة** = كمية السيرفر − مبيعات الجهاز التي لم يؤكدها السيرفر بعد.
6. **التعارض في الطلبات:** إذا غيّر الجهاز حالة طلب ولم يُرسلها بعد، لا يكتب السحب فوقها.

## ربط الـ API
ابحث عن `TODO(api)` في الكود. الأماكن:

| الملف | ما يجب تعديله |
|---|---|
| `lib/core/config/api_config.dart` | مسارات الـ endpoints |
| `features/pos/data/models/catalog_item_model.dart` | تحويل رد المنتجات |
| `features/pos/data/models/sale_model.dart` | جسم طلب إنشاء الفاتورة |
| `features/pos/data/datasources/pos_remote_data_source.dart` | شكل الردود |
| `features/online_orders/data/models/online_order_model.dart` | تحويل رد الطلبات |
| `features/online_orders/data/datasources/online_orders_remote_data_source.dart` | طريقة تغيير الحالة |
| `features/auth/data/datasources/auth_remote_data_source.dart` | شكل رد تسجيل الدخول |

المبالغ داخل التطبيق أعداد صحيحة بالأغورة (`2500` = ₪25.00)، والتحويل من/إلى `"25.00"` يتم في الـ models فقط.

## إضافة ميزة جديدة للمزامنة
1. أنشئ `features/<name>/` بنفس الطبقات الثلاث.
2. عند الحفظ المحلي: `queue.enqueue(txn, operation: '<name>.<action>', ...)` داخل الـ transaction.
3. اكتب `SyncHandler` للإرسال و/أو `PullHandler` للسحب، وسجّلهما في `injection.dart`.
