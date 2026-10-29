/// طرق الدفع، مطابقة لـ `payment_methods.type` في السيرفر.
enum PaymentMethod {
  cash('cash', 'نقدي'),
  wallet('wallet', 'محفظة إلكترونية'),
  bank('bank', 'تحويل بنكي');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethod fromApi(String value) =>
      values.firstWhere((m) => m.apiValue == value, orElse: () => PaymentMethod.cash);
}
