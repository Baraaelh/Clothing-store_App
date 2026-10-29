import 'package:intl/intl.dart';

/// المبالغ تُخزن كأعداد صحيحة بالأغورة (1 ₪ = 100) لتجنب أخطاء الكسور العشرية.
/// السيرفر يستخدم decimal(12,2)، والتحويل يتم في الـ models فقط.
abstract final class Money {
  static final NumberFormat _format = NumberFormat('#,##0.00', 'en');

  static int fromDecimal(num value) => (value * 100).round();

  static int fromJson(Object? value) => switch (value) {
    null => 0,
    final num n => fromDecimal(n),
    final String s => fromDecimal(num.tryParse(s) ?? 0),
    _ => 0,
  };

  static String toDecimalString(int minor) => (minor / 100).toStringAsFixed(2);

  static String format(int minor) => '₪${_format.format(minor / 100)}';
}
