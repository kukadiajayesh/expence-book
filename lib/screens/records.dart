import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login.dart' show bareField;
import 'overview.dart' show TxnRow;

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({
    super.key,
    required this.store,
    required this.filter,
    required this.person,
    required this.query,
    required this.search,
    required this.onFilter,
    required this.onQuery,
    required this.onClearPerson,
    required this.onOpen,
    required this.onAdd,
  });

  final LedgerStore store;
  final String filter; // 'all' | 'got' | 'gave'
  final String? person;
  final String query;
  final TextEditingController search;
  final ValueChanged<String> onFilter, onQuery;
  final VoidCallback onClearPerson, onAdd;
  final ValueChanged<Txn> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final recs = store.sorted;
    final q = query.trim().toLowerCase();
    final qNum = q.replaceAll(RegExp(r'[₹,\s]'), '');
    bool matches(Txn r) =>
        q.isEmpty ||
        r.person.toLowerCase().contains(q) ||
        r.note.toLowerCase().contains(q) ||
        (qNum.isNotEmpty && r.amount.toStringAsFixed(2).contains(qNum));
    final listed = recs.where((r) => (filter == 'all' || r.type == filter) && (person == null || r.person == person) && matches(r)).toList();

    final groups = <(DateTime, List<Txn>)>[];
    for (final r in listed) {
      if (groups.isEmpty || groups.last.$1 != r.date) groups.add((r.date, []));
      groups.last.$2.add(r);
    }

    final header = Transform.translate(
      offset: const Offset(0, -4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text('Records', style: ts(34, w: 800, ls: -0.03, height: 1.1, color: c.text))),
        Text('${listed.length} ${listed.length == 1 ? 'transaction' : 'transactions'}', style: ts(15, color: c.muted)),
      ]),
    );

    final controls = recs.isEmpty
        ? null
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Ico(Ico.search, size: 18, color: c.muted, stroke: 2.25),
                const SizedBox(width: 10),
                Expanded(child: bareField(context, controller: search, hint: 'Search name, note or amount', action: TextInputAction.search, onChanged: onQuery)),
                if (query.isNotEmpty)
                  Semantics(
                    label: 'Clear search',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        search.clear();
                        onQuery('');
                      },
                      child: SizedBox(width: 44, height: 44, child: Center(child: Ico(Ico.close, size: 18, color: c.muted, stroke: 2.5))),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Segmented<String>(options: const [('all', 'All'), ('got', 'Received'), ('gave', 'Paid')], value: filter, onChanged: onFilter),
            if (person != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onClearPerson,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  decoration: BoxDecoration(color: c.accent100, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(person!, style: ts(14, w: 600, color: c.accent)),
                    const SizedBox(width: 6),
                    Ico(Ico.close, size: 16, color: c.accent, stroke: 2.5),
                  ]),
                ),
              ),
            ],
          ]);

    if (listed.isEmpty) {
      final none = recs.isEmpty;
      final kind = filter == 'got' ? 'received ' : filter == 'gave' ? 'paid ' : '';
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 32),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                header,
                if (controls != null) ...[const SizedBox(height: 16), controls],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 64),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const IconDisc(icon: Ico.notebook, size: 128, iconSize: 56),
                      const SizedBox(height: 20),
                      Text(none ? 'No transactions yet' : 'Nothing here', style: ts(20, w: 800, ls: -0.015, color: c.text)),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 270),
                        child: Text(
                          none
                              ? 'Every payment you make or receive from someone will be listed here, grouped by day.'
                              : q.isNotEmpty
                                  ? 'No ${kind}transactions match “${query.trim()}”${person != null ? ' with $person' : ''}.'
                                  : 'No ${kind}transactions${person != null ? ' with $person' : ''}.',
                          textAlign: TextAlign.center,
                          style: ts(15, height: 1.5, color: c.muted),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AccentButton(
                        none ? 'Add transaction' : 'Show all',
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        onTap: none
                            ? onAdd
                            : () {
                                onFilter('all');
                                onClearPerson();
                                search.clear();
                                onQuery('');
                              },
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        header,
        const SizedBox(height: 16),
        controls!,
        for (final g in groups) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(dayLabel(g.$1, now), style: ts(13, w: 600, color: c.muted))),
              Text(signedFmt(g.$2.fold<double>(0, (a, r) => a + r.signed)), style: ts(13, w: 600, color: c.muted, tabular: true)),
            ]),
          ),
          const SizedBox(height: 8),
          InsetGroup(children: [
            for (var i = 0; i < g.$2.length; i++)
              TxnRow(
                txn: g.$2[i],
                sub: g.$2[i].note.isNotEmpty ? g.$2[i].note : (g.$2[i].isGot ? 'Received' : 'Paid'),
                divider: i < g.$2.length - 1,
                onTap: () => onOpen(g.$2[i]),
              ),
          ]),
        ],
      ],
    );
  }
}
