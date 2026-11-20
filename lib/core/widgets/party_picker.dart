import 'package:flutter/material.dart';

import '../data/reference_data.dart';

/// حقل اختيار زبون أو مورد من البيانات المحلية مع بحث.
class PartyField extends StatelessWidget {
  const PartyField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.search,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final Party? value;
  final Future<List<Party>> Function(String query) search;
  final ValueChanged<Party?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<Party>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _PartySearch(title: label, search: search),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(icon: const Icon(Icons.close), tooltip: 'إزالة', onPressed: () => onChanged(null)),
        ),
        child: Text(value == null ? 'اختر' : '${value!.name}${value!.phone == null ? '' : ' • ${value!.phone}'}'),
      ),
    );
  }
}

class _PartySearch extends StatefulWidget {
  const _PartySearch({required this.title, required this.search});

  final String title;
  final Future<List<Party>> Function(String query) search;

  @override
  State<_PartySearch> createState() => _PartySearchState();
}

class _PartySearchState extends State<_PartySearch> {
  List<Party> _results = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _run('');
  }

  Future<void> _run(String q) async {
    _query = q;
    final results = await widget.search(q);
    if (mounted && q == _query) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم أو الهاتف'),
              onChanged: _run,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('لا توجد نتائج'))
                  : ListView(
                      children: [
                        for (final p in _results)
                          ListTile(
                            title: Text(p.name),
                            subtitle: p.phone == null ? null : Text(p.phone!),
                            onTap: () => Navigator.pop(context, p),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
