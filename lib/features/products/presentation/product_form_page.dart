import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/reference_data.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/color_dot.dart';
import '../domain/product.dart';
import 'products_cubit.dart';

/// إضافة منتج جديد أو تعديل منتج موجود.
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.current});

  final ProductDetail? current;

  static Future<void> open(BuildContext context, {ProductDetail? current}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => ProductFormCubit(sl(), sl(), sl())..load(),
        child: ProductFormPage(current: current),
      ),
    ),
  );

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _Row {
  _Row({this.id, this.colorId, this.sizeId, int? price, int? minPrice, this.isActive = true})
    : price = TextEditingController(text: price == null ? '' : Money.toDecimalString(price)),
      minPrice = TextEditingController(text: minPrice == null ? '' : Money.toDecimalString(minPrice));

  final int? id;
  int? colorId;
  int? sizeId;
  bool isActive;
  final TextEditingController price;
  final TextEditingController minPrice;

  void dispose() {
    price.dispose();
    minPrice.dispose();
  }
}

class _ProductFormPageState extends State<ProductFormPage> {
  late final _name = TextEditingController(text: widget.current?.name ?? '');
  late final _description = TextEditingController(text: widget.current?.description ?? '');
  late int? _categoryId = widget.current?.categoryId;
  late bool _active = widget.current?.isActive ?? true;
  late final List<_Row> _rows = [
    for (final v in widget.current?.variants ?? const <VariantInfo>[])
      _Row(id: v.id, colorId: v.colorId, sizeId: v.sizeId, price: v.price, minPrice: v.minPrice, isActive: v.isActive),
  ];

  bool get _editing => widget.current != null;

  @override
  void initState() {
    super.initState();
    if (_rows.isEmpty) _rows.add(_Row());
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  static int? _money(String text) {
    final value = num.tryParse(text.trim());
    return value == null ? null : Money.fromDecimal(value);
  }

  ProductDraft _draft() => ProductDraft(
    name: _name.text.trim(),
    categoryId: _categoryId,
    description: _description.text.trim(),
    isActive: _active,
    variants: [
      for (final r in _rows)
        if (r.colorId != null && r.sizeId != null)
          VariantDraft(
            id: r.id,
            colorId: r.colorId!,
            sizeId: r.sizeId!,
            price: _money(r.price.text) ?? 0,
            minPrice: _money(r.minPrice.text),
            isActive: r.isActive,
          ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductFormCubit, ProductFormState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!), backgroundColor: Colors.red));
        }
        if (state.saved) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_editing ? 'حُفظ التعديل وسيُرسل للسيرفر' : 'حُفظ المنتج وسيظهر بعد اعتماد السيرفر'),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ProductFormCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(_editing ? 'تعديل منتج' : 'منتج جديد')),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: state.saving ? null : () => cubit.save(_draft(), current: widget.current),
                child: Text(_editing ? 'حفظ التعديل' : 'حفظ المنتج'),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المنتج'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: state.categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: [for (final c in state.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
              ),
              if (_editing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('المنتج فعّال'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('الأصناف (لون + مقاس + سعر)', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _rows.add(_Row())),
                    icon: const Icon(Icons.add),
                    label: const Text('صنف'),
                  ),
                ],
              ),
              if (!_editing)
                Text(
                  'الكود والـ SKU يولدهما السيرفر. لإدخال كميات استخدم "استلام بضاعة" من شاشة المخزون بعد اعتماد المنتج.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              for (final (i, row) in _rows.indexed)
                _VariantCard(
                  key: ObjectKey(row),
                  row: row,
                  colors: state.colors,
                  sizes: state.sizes,
                  showMinimum: cubit.canSetMinimum,
                  locked: row.id != null,
                  onChanged: () => setState(() {}),
                  onRemove: row.id == null && _rows.length > 1
                      ? () => setState(() => _rows.removeAt(i).dispose())
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    super.key,
    required this.row,
    required this.colors,
    required this.sizes,
    required this.showMinimum,
    required this.locked,
    required this.onChanged,
    this.onRemove,
  });

  final _Row row;
  final List<NamedRef> colors;
  final List<NamedRef> sizes;
  final bool showMinimum;

  /// صنف موجود: لونه ومقاسه هوية ثابتة (قد يكون مرتبطًا بمستندات).
  final bool locked;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: colors.any((c) => c.id == row.colorId) ? row.colorId : null,
                    decoration: const InputDecoration(labelText: 'اللون'),
                    items: [
                      for (final c in colors)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              ColorDot(hex: c.hex),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        ),
                    ],
                    onChanged: locked ? null : (v) => {row.colorId = v, onChanged()},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: sizes.any((s) => s.id == row.sizeId) ? row.sizeId : null,
                    decoration: const InputDecoration(labelText: 'المقاس'),
                    items: [for (final s in sizes) DropdownMenuItem(value: s.id, child: Text(s.name))],
                    onChanged: locked ? null : (v) => {row.sizeId = v, onChanged()},
                  ),
                ),
                if (onRemove != null)
                  IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: onRemove),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'سعر البيع (₪)'),
                  ),
                ),
                if (showMinimum) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.minPrice,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'الحد الأدنى (اختياري)'),
                    ),
                  ),
                ],
              ],
            ),
            if (locked)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('الصنف فعّال'),
                value: row.isActive,
                onChanged: (v) {
                  row.isActive = v;
                  onChanged();
                },
              ),
          ],
        ),
      ),
    );
  }
}
