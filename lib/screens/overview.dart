import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/net_card.dart';

/// Running total per person across all their transactions.
class PersonSummary {
  PersonSummary(this.name);

  final String name;
  int count = 0;
  double net = 0;
}

List<PersonSummary> summarizePeople(List<Txn> sorted) {
  final m = <String, PersonSummary>{};
  for (final r in sorted) {
    final p = m.putIfAbsent(r.person, () => PersonSummary(r.person));
    p.count++;
    p.net += r.signed;
  }
  return m.values.toList();
}

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.store, required this.onOpen, required this.onAdd, required this.onPerson, required this.onSeeAll});

  final LedgerStore store;
  final ValueChanged<Txn> onOpen;
  final VoidCallback onAdd, onSeeAll;
  final ValueChanged<String> onPerson;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final recs = store.sorted;
    final month = recs.where((r) => r.date.year == now.year && r.date.month == now.month);
    final got = month.where((r) => r.isGot).fold<double>(0, (a, r) => a + r.amount);
    final gave = month.where((r) => !r.isGot).fold<double>(0, (a, r) => a + r.amount);
    final people = summarizePeople(recs).take(4).toList();
    final recent = recs.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Transform.translate(offset: const Offset(0, -4), child: Text('Overview', style: ts(34, w: 800, ls: -0.03, height: 1.1, color: c.text))),
        const SizedBox(height: 24),
        NetCard(got: got, gave: gave, month: now),
        const SizedBox(height: 28),
        if (recs.isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const IconDisc(icon: Ico.userPlus, size: 56, iconSize: 26),
              const SizedBox(height: 14),
              Text('Start your ledger', style: ts(20, w: 800, ls: -0.015, color: c.text)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text('Record money you pay to or receive from someone. Balances for each person will show up here.',
                    textAlign: TextAlign.center, style: ts(15, height: 1.5, color: c.muted)),
              ),
              const SizedBox(height: 20),
              AccentButton('Add first transaction', onTap: onAdd, height: 50),
            ]),
          )
        else ...[
          const SectionLabel('People'),
          const SizedBox(height: 8),
          InsetGroup(children: [
            for (var i = 0; i < people.length; i++)
              GroupRow(
                minHeight: 60,
                padding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
                leading: Avatar(people[i].name),
                divider: i < people.length - 1,
                onTap: () => onPerson(people[i].name),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(people[i].name, style: ts(16, w: 600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${people[i].count} ${people[i].count == 1 ? 'transaction' : 'transactions'}', style: ts(13, color: c.muted)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(signedFmt(people[i].net), style: ts(16, w: 700, tabular: true, color: people[i].net >= 0 ? c.income : c.text)),
                  const SizedBox(width: 8),
                  const Chevron(),
                ]),
              ),
          ]),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(children: [
              Expanded(child: Text('Recent', style: ts(13, w: 600, color: c.muted))),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeAll,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: Text('See all', style: ts(15, w: 600, color: c.accent)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          InsetGroup(children: [
            for (var i = 0; i < recent.length; i++)
              TxnRow(
                txn: recent[i],
                sub: dayLabel(recent[i].date, now) + (recent[i].note.isNotEmpty ? ' · ${recent[i].note}' : ''),
                divider: i < recent.length - 1,
                onTap: () => onOpen(recent[i]),
              ),
          ]),
        ],
      ],
    );
  }
}

/// One transaction: avatar, person, a subtitle and the signed amount.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, required this.sub, required this.divider, required this.onTap});

  final Txn txn;
  final String sub;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GroupRow(
      minHeight: 60,
      padding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
      leading: Avatar(txn.person),
      divider: divider,
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(txn.person, style: ts(16, w: 600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(sub, style: ts(13, color: c.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 10),
        Text('${txn.isGot ? '+' : '−'}${fmt(txn.amount)}', style: ts(16, w: 700, tabular: true, color: txn.isGot ? c.income : c.text)),
      ]),
    );
  }
}
