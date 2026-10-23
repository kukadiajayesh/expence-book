import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'models.dart';
import 'screens/login.dart';
import 'screens/overview.dart';
import 'screens/records.dart';
import 'screens/settings.dart';
import 'screens/sheets.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/spring_sheet.dart';

/// The whole app: screens, nav bar, tab bar, toast and the three spring
/// sheets. The add/edit sheet pushes the app back as it rises.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.store});

  final LedgerStore store;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with TickerProviderStateMixin {
  LedgerStore get store => widget.store;

  String tab = 'home'; // 'home' | 'list' | 'settings'
  String filter = 'all';
  String? person;
  bool collapsed = false;
  ({String msg, VoidCallback? undo})? toast;
  Timer? _toastTimer;
  String dialog = 'logout'; // 'delete' | 'logout'

  final draft = TxnDraft();
  late final form = SheetController(vsync: this, maxOpacity: 0.4, onClosed: () => FocusManager.instance.primaryFocus?.unfocus());
  late final follow = SheetController(vsync: this, maxOpacity: 0.4);
  late final confirm = SheetController(vsync: this, maxOpacity: 0.45);
  final formScroll = ScrollController(), followScroll = ScrollController();
  final formScrollKey = GlobalKey(), followScrollKey = GlobalKey();

  @override
  void dispose() {
    _toastTimer?.cancel();
    for (final c in [form, follow, confirm]) {
      c.dispose();
    }
    formScroll.dispose();
    followScroll.dispose();
    draft.dispose();
    super.dispose();
  }

  void go(String t) => setState(() {
        tab = t;
        collapsed = false;
      });

  void showToast(String msg, [VoidCallback? undo]) {
    _toastTimer?.cancel();
    setState(() => toast = (msg: msg, undo: undo));
    _toastTimer = Timer(const Duration(seconds: 4), () => setState(() => toast = null));
  }

  void hideToast() {
    _toastTimer?.cancel();
    setState(() => toast = null);
  }

  void openForm(Txn? r) {
    draft.load(r);
    if (formScroll.hasClients) formScroll.jumpTo(0);
    hideToast();
    form.open();
  }

  void openDialog(String kind) {
    setState(() => dialog = kind);
    confirm.open();
  }

  void save() {
    final amt = draft.parsedAmount;
    draft.amountErr = amt > 0 ? '' : 'Enter an amount above zero.';
    draft.personErr = draft.person.text.trim().isNotEmpty ? '' : 'Add who this was with.';
    if (draft.amountErr.isNotEmpty || draft.personErr.isNotEmpty) return setState(() {});
    final editing = draft.id != null;
    store.upsert(id: draft.id, type: draft.type, amount: (amt * 100).round() / 100, person: draft.person.text.trim(), date: draft.date, note: draft.note.text.trim());
    FocusManager.instance.primaryFocus?.unfocus();
    form.close();
    showToast(editing ? 'Transaction updated' : 'Transaction added');
  }

  void confirmAction() {
    confirm.close();
    if (dialog == 'logout') {
      store.logout();
      setState(() {
        tab = 'home';
        filter = 'all';
        person = null;
        collapsed = false;
        toast = null;
      });
      return;
    }
    form.close();
    if (draft.id == null) return;
    final undo = store.delete(draft.id!);
    showToast('Transaction deleted', () {
      undo();
      hideToast();
    });
  }

  /// Closes the topmost open sheet; false when none is open.
  bool closeTop() {
    for (final c in [confirm, follow, form]) {
      if (c.isOpen) {
        c.close();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mq = MediaQuery.of(context);
    final h = mq.size.height, top = mq.padding.top;
    final sheetH = h - top - 10;
    form.reduceMotion = follow.reduceMotion = confirm.reduceMotion = mq.disableAnimations;
    form.setGeometry([0], sheetH + 36);
    follow.setGeometry([0, math.max(0, sheetH - h * 0.5)], sheetH + 36);
    confirm.setGeometry([0], 440 + mq.padding.bottom);

    final names = <String>[];
    for (final r in store.sorted) {
      if (!names.contains(r.person)) names.add(r.person);
      if (names.length == 5) break;
    }

    return Material(
      type: MaterialType.canvas,
      color: const Color(0xFF000000),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !closeTop()) SystemNavigator.pop();
        },
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): closeTop},
          child: Focus(
            autofocus: true,
            child: Stack(children: [
              AnimatedBuilder(
                animation: form,
                builder: (context, child) {
                  final p = form.progress;
                  final lightIcons = c.dark || p > 0.3;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: (lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: const Color(0x00000000)),
                    child: Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.translationValues(0, 12 * p, 0)..scaleByDouble(1 - 0.07 * p, 1 - 0.07 * p, 1, 1),
                      child: ClipRRect(borderRadius: BorderRadius.circular(46 * math.min(1, p * 4)), child: child),
                    ),
                  );
                },
                child: _app(context),
              ),
              SheetLayer(
                controller: form,
                height: sheetH,
                onDismiss: form.close,
                sheet: TxnSheet(
                  draft: draft,
                  names: names,
                  controller: form,
                  scroll: formScroll,
                  scrollKey: formScrollKey,
                  onChanged: () => setState(() {}),
                  onCancel: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    form.close();
                  },
                  onSave: save,
                  onDelete: () => openDialog('delete'),
                ),
              ),
              SheetLayer(
                controller: follow,
                height: sheetH,
                onDismiss: follow.close,
                sheet: FollowSheet(store: store, controller: follow, scroll: followScroll, scrollKey: followScrollKey, onDone: follow.close),
              ),
              SheetLayer(
                controller: confirm,
                left: 8,
                right: 8,
                onDismiss: confirm.close,
                sheet: ConfirmSheet(
                  controller: confirm,
                  title: dialog == 'delete' ? 'Delete this transaction?' : 'Log out of Ledger?',
                  body: dialog == 'delete'
                      ? '${draft.type == 'got' ? 'Received from' : 'Paid to'} ${draft.person.text.trim()} · ${fmt(draft.parsedAmount)} will be removed.'
                      : 'You’ll need to sign in again to see your transactions.',
                  cta: dialog == 'delete' ? 'Delete transaction' : 'Log out',
                  onConfirm: confirmAction,
                  onCancel: confirm.close,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _app(BuildContext context) {
    final c = context.c;
    final mq = MediaQuery.of(context);
    if (!store.loggedIn) {
      return ColoredBox(
        color: c.bg,
        child: Padding(padding: EdgeInsets.only(top: mq.padding.top), child: LoginScreen(store: store)),
      );
    }
    final tabBottom = math.max(mq.padding.bottom - 4, 8.0);
    final title = {'home': 'Overview', 'list': 'Records', 'settings': 'Settings'}[tab]!;

    final body = switch (tab) {
      'list' => RecordsScreen(
          key: const ValueKey('list'),
          store: store,
          filter: filter,
          person: person,
          onFilter: (f) => setState(() => filter = f),
          onClearPerson: () => setState(() => person = null),
          onOpen: openForm,
          onAdd: () => openForm(null),
        ),
      'settings' => SettingsScreen(key: const ValueKey('settings'), store: store, onFollow: () => follow.open(1), onLogout: () => openDialog('logout')),
      _ => OverviewScreen(
          key: const ValueKey('home'),
          store: store,
          onOpen: openForm,
          onAdd: () => openForm(null),
          onSeeAll: () => go('list'),
          onPerson: (name) => setState(() {
            tab = 'list';
            person = name;
            filter = 'all';
            collapsed = false;
          }),
        ),
    };

    Widget tabItem(String key, String label, String icon) {
      final col = tab == key ? c.accent : c.muted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: tab == key,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => go(key),
            child: Container(
              constraints: const BoxConstraints(minHeight: 49),
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Ico(icon, size: 24, color: col),
                const SizedBox(height: 3),
                Text(label, style: ts(11, w: 600, color: col)),
              ]),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: c.bg,
      child: Stack(children: [
        Column(children: [
          SizedBox(height: mq.padding.top),
          // Nav bar: theme toggle · collapsing title · add
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: collapsed ? c.line : const Color(0x00000000)))),
            child: Row(children: [
              SizedBox(width: 88, child: Align(alignment: Alignment.centerLeft, child: ThemeToggle(store: store))),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: collapsed ? 1 : 0,
                  child: Text(title, textAlign: TextAlign.center, style: ts(17, w: 700, ls: -0.01, color: c.text)),
                ),
              ),
              SizedBox(
                width: 88,
                child: tab == 'settings'
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          label: 'New transaction',
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => openForm(null),
                            child: SizedBox(width: 44, height: 44, child: Center(child: Ico(Ico.plus, size: 24, color: c.accent, stroke: 2.25))),
                          ),
                        ),
                      ),
              ),
            ]),
          ),
          Expanded(
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                if (n.depth == 0) {
                  final v = n.metrics.pixels > 34;
                  if (v != collapsed) setState(() => collapsed = v);
                }
                return false;
              },
              child: MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, child: body),
            ),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(8, 4, 8, tabBottom),
                decoration: BoxDecoration(color: c.card.withValues(alpha: c.card.a * .88), border: Border(top: BorderSide(color: c.line))),
                child: Row(children: [
                  tabItem('home', 'Overview', Ico.tabOverview),
                  tabItem('list', 'Records', Ico.tabRecords),
                  tabItem('settings', 'Settings', Ico.tabSettings),
                ]),
              ),
            ),
          ),
        ]),
        if (toast != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 4 + 49 + tabBottom + 21,
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(14), boxShadow: c.shadowLgList),
              child: Row(children: [
                Expanded(child: Text(toast!.msg, style: ts(15, w: 600, color: const Color(0xFFFFFFFF)))),
                if (toast!.undo != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: toast!.undo,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      child: Text('Undo', style: ts(15, w: 700, color: c.emSub)),
                    ),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}
