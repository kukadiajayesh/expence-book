import 'package:flutter/material.dart' show showDatePicker, Theme, ThemeData, ColorScheme, Brightness;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/spring_sheet.dart';
import 'login.dart' show bareField;

/// The add/edit form's working copy.
class TxnDraft {
  int? id;
  String type = 'gave';
  final amount = TextEditingController();
  final person = TextEditingController();
  final note = TextEditingController();
  DateTime date = dateOnly(DateTime.now());
  String amountErr = '', personErr = '';

  void load(Txn? r) {
    id = r?.id;
    type = r?.type ?? 'gave';
    amount.text = r == null ? '' : (r.amount % 1 == 0 ? r.amount.toInt().toString() : r.amount.toString());
    person.text = r?.person ?? '';
    note.text = r?.note ?? '';
    date = r?.date ?? dateOnly(DateTime.now());
    amountErr = personErr = '';
  }

  double get parsedAmount => double.tryParse(amount.text.replaceAll(',', '')) ?? 0;

  void dispose() {
    amount.dispose();
    person.dispose();
    note.dispose();
  }
}

/// Full-height "New / Edit transaction" sheet.
class TxnSheet extends StatelessWidget {
  const TxnSheet({
    super.key,
    required this.draft,
    required this.names,
    required this.controller,
    required this.scroll,
    required this.scrollKey,
    required this.onChanged,
    required this.onCancel,
    required this.onSave,
    required this.onDelete,
  });

  final TxnDraft draft;
  final List<String> names;
  final SheetController controller;
  final ScrollController scroll;
  final GlobalKey scrollKey;
  final VoidCallback onChanged, onCancel, onSave, onDelete;

  Future<void> _pickDate(BuildContext context) async {
    final c = context.c;
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: c.dark ? Brightness.dark : Brightness.light, primary: c.accent, surface: c.card),
          fontFamily: 'Archivo',
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      draft.date = dateOnly(picked);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final got = draft.type == 'got';
    Widget err(String e) => e.isEmpty
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(e, style: ts(13, w: 600, color: c.expense)));
    Widget headerBtn(String label, VoidCallback onTap, {bool bold = false}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Text(label, style: ts(17, w: bold ? 700 : 400, color: c.accent)),
          ),
        );

    return SheetDragArea(
      controller: controller,
      scroll: scroll,
      scrollKey: scrollKey,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Color(0x2E05070B), offset: Offset(0, -8), blurRadius: 30)],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ColoredBox(
            color: c.bg,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Grabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Row(children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: headerBtn('Cancel', onCancel))),
                  Text(draft.id != null ? 'Edit transaction' : 'New transaction', style: ts(17, w: 700, color: c.text)),
                  Expanded(child: Align(alignment: Alignment.centerRight, child: headerBtn('Save', onSave, bold: true))),
                ]),
              ),
              Expanded(
                child: ListView(
                  key: scrollKey,
                  controller: scroll,
                  physics: const SheetScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 48 + MediaQuery.viewInsetsOf(context).bottom),
                  children: [
                    Segmented<String>(
                      options: const [('gave', 'Paid'), ('got', 'Received')],
                      value: draft.type,
                      onChanged: (v) {
                        draft.type = v;
                        onChanged();
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: draft.amountErr.isNotEmpty ? c.expense : c.line)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text('₹', style: ts(30, w: 800, color: c.muted)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: NoSheetDrag(
                            child: Semantics(
                              label: 'Amount',
                              child: bareField(
                                context,
                                controller: draft.amount,
                                hint: '0',
                                style: ts(40, w: 800, ls: -0.03, color: c.text, tabular: true),
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                onChanged: (_) {
                                  if (draft.amountErr.isNotEmpty) {
                                    draft.amountErr = '';
                                    onChanged();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    err(draft.amountErr),
                    const SizedBox(height: 24),
                    SectionLabel(got ? 'Received from' : 'Paid to'),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: draft.personErr.isNotEmpty ? c.expense : c.line)),
                      child: NoSheetDrag(
                        child: Semantics(
                          label: 'Person',
                          child: bareField(
                            context,
                            controller: draft.person,
                            hint: 'Name',
                            action: TextInputAction.next,
                            onChanged: (_) {
                              draft.personErr = '';
                              onChanged();
                            },
                          ),
                        ),
                      ),
                    ),
                    err(draft.personErr),
                    if (names.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final n in names)
                          GestureDetector(
                            onTap: () {
                              draft.person.text = n;
                              draft.personErr = '';
                              onChanged();
                            },
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: draft.person.text == n ? c.accent : c.card,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: draft.person.text == n ? c.accent : c.line),
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(n, style: ts(14, w: 600, color: draft.person.text == n ? const Color(0xFFFFFFFF) : c.text)),
                              ]),
                            ),
                          ),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    InsetGroup(children: [
                      GroupRow(
                        onTap: () => _pickDate(context),
                        child: Row(children: [
                          Expanded(child: Text('Date', style: ts(17, color: c.text))),
                          Text(dateLabel(draft.date), style: ts(17, color: c.accent)),
                        ]),
                      ),
                      GroupRow(
                        divider: false,
                        child: Row(children: [
                          Text('Note', style: ts(17, color: c.text)),
                          const SizedBox(width: 12),
                          Expanded(child: NoSheetDrag(child: bareField(context, controller: draft.note, hint: 'Optional', align: TextAlign.right, action: TextInputAction.done, onSubmitted: (_) => onSave()))),
                        ]),
                      ),
                    ]),
                    if (draft.id != null) ...[
                      const SizedBox(height: 24),
                      CardButton('Delete transaction', onTap: onDelete, color: c.expense),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Two-detent "Follow up after" picker.
class FollowSheet extends StatelessWidget {
  const FollowSheet({super.key, required this.store, required this.controller, required this.scroll, required this.scrollKey, required this.onDone});

  final LedgerStore store;
  final SheetController controller;
  final ScrollController scroll;
  final GlobalKey scrollKey;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SheetDragArea(
      controller: controller,
      scroll: scroll,
      scrollKey: scrollKey,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [BoxShadow(color: Color(0x2905070B), offset: Offset(0, -8), blurRadius: 30)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Grabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              Text('Follow up after', style: ts(17, w: 700, color: c.text)),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDone,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: Text('Done', style: ts(17, w: 700, color: c.accent)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              key: scrollKey,
              controller: scroll,
              physics: const SheetScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Ledger reminds you to follow up when a balance with someone stays open this long.', style: ts(13, height: 1.45, color: c.muted)),
                ),
                const SizedBox(height: 8),
                InsetGroup(color: c.bg, bordered: false, children: [
                  for (var i = 0; i < followOptions.length; i++)
                    GroupRow(
                      divider: i < followOptions.length - 1,
                      onTap: () {
                        store.setFollow(followOptions[i]);
                        Future.delayed(const Duration(milliseconds: 140), onDone);
                      },
                      child: Row(children: [
                        Expanded(child: Text(followOptions[i], style: ts(17, color: c.text))),
                        Opacity(opacity: followOptions[i] == store.follow ? 1 : 0, child: Ico(Ico.tick, size: 20, color: c.accent, stroke: 2.75)),
                      ]),
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// iOS action-sheet style confirmation (delete / log out).
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({super.key, required this.controller, required this.title, required this.body, required this.cta, required this.onConfirm, required this.onCancel});

  final SheetController controller;
  final String title, body, cta;
  final VoidCallback onConfirm, onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SheetDragArea(
      controller: controller,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: title,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(children: [
                    Text(title, textAlign: TextAlign.center, style: ts(15, w: 700, color: c.text)),
                    const SizedBox(height: 4),
                    Text(body, textAlign: TextAlign.center, style: ts(13, height: 1.45, color: c.muted)),
                  ]),
                ),
                Pressable(
                  onTap: onConfirm,
                  border: Border(top: BorderSide(color: c.line)),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    alignment: Alignment.center,
                    child: Text(cta, style: ts(18, w: 600, color: c.expense)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Pressable(
              onTap: onCancel,
              color: c.card,
              radius: BorderRadius.circular(18),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                alignment: Alignment.center,
                child: Text('Cancel', style: ts(18, w: 700, color: c.accent)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
