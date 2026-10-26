import 'package:flutter/material.dart' show TextField, InputDecoration, InputBorder;
import 'package:flutter/services.dart' show TextInputAction, TextInputFormatter;
import 'package:flutter/widgets.dart';

import '../data/odoo_client.dart' show OdooException;
import '../icons.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Plain borderless text field styled like the design's `all:unset` inputs.
TextField bareField(
  BuildContext context, {
  required TextEditingController controller,
  TextStyle? style,
  String? hint,
  bool obscure = false,
  TextAlign align = TextAlign.start,
  TextInputType? keyboard,
  TextInputAction? action,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  List<TextInputFormatter>? formatters,
}) {
  final c = context.c;
  final st = style ?? ts(17, color: c.text);
  return TextField(
    controller: controller,
    obscureText: obscure,
    textAlign: align,
    keyboardType: keyboard,
    textInputAction: action,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    cursorColor: c.accent,
    style: st,
    inputFormatters: formatters,
    decoration: InputDecoration(
      isCollapsed: true,
      border: InputBorder.none,
      hintText: hint,
      hintStyle: st.copyWith(color: c.muted.withValues(alpha: .7)),
    ),
  );
}

/// The theme toggle (moon in light, sun in dark).
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, required this.store, this.boxed = false});

  final LedgerStore store;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final icon = Ico(store.dark ? Ico.sun : Ico.moon, size: boxed ? 20 : 22, color: boxed ? c.text : c.accent);
    return Semantics(
      label: store.dark ? 'Switch to light appearance' : 'Switch to dark appearance',
      button: true,
      child: boxed
          ? Pressable(
              onTap: () => store.setDark(!store.dark),
              color: c.card,
              radius: BorderRadius.circular(12),
              border: Border.all(color: c.line),
              child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => store.setDark(!store.dark),
              child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
            ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final LedgerStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _url = TextEditingController();
  final _db = TextEditingController();
  final _key = TextEditingController();
  String _err = '';
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _db.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_url.text.trim().isEmpty) return setState(() => _err = 'Enter your Odoo server address.');
    if (_db.text.trim().isEmpty) return setState(() => _err = 'Enter the database name.');
    if (_key.text.trim().isEmpty) return setState(() => _err = 'Enter your API key.');
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await widget.store.connect(url: _url.text, db: _db.text, apiKey: _key.text);
    } on OdooException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } catch (e) {
      if (mounted) setState(() => _err = 'Could not connect: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    void clear(String _) {
      if (_err.isNotEmpty) setState(() => _err = '');
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + MediaQuery.viewInsetsOf(context).bottom),
      children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(11)),
            child: Text('L', style: ts(19, w: 800, color: const Color(0xFFFFFFFF))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Ledger', style: ts(20, w: 800, ls: -0.02, color: c.text))),
          ThemeToggle(store: widget.store, boxed: true),
        ]),
        const SizedBox(height: 28 + 36),
        Text('Connect to Odoo', style: ts(34, w: 800, ls: -0.03, height: 1.1, color: c.text)),
        const SizedBox(height: 8),
        Text('Your payments are saved in Odoo and kept on this phone for when you are offline.', style: ts(17, height: 1.45, color: c.muted)),
        const SizedBox(height: 28),
        InsetGroup(children: [
          GroupRow(
            leading: SizedBox(width: 84, child: Text('Server', style: ts(17, color: c.text))),
            child: bareField(context, controller: _url, hint: 'odoo.example.com', keyboard: TextInputType.url, action: TextInputAction.next, onChanged: clear),
          ),
          GroupRow(
            leading: SizedBox(width: 84, child: Text('Database', style: ts(17, color: c.text))),
            child: bareField(context, controller: _db, hint: 'database name', action: TextInputAction.next, onChanged: clear),
          ),
          GroupRow(
            leading: SizedBox(width: 84, child: Text('API key', style: ts(17, color: c.text))),
            divider: false,
            child: bareField(context, controller: _key, obscure: true, hint: 'paste your key', action: TextInputAction.go, onChanged: clear, onSubmitted: (_) => _submit()),
          ),
        ]),
        if (_err.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_err, style: ts(13, w: 600, color: c.expense))),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Needs Odoo 19. Create a key in Odoo under Preferences → Account Security → New API Key.', style: ts(13, height: 1.4, color: c.muted)),
        ),
        const SizedBox(height: 28),
        AccentButton(_busy ? 'Connecting…' : 'Connect', onTap: _submit),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : widget.store.useLocally,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Text('Use without Odoo', style: ts(15, w: 600, color: c.accent)),
          ),
        ),
      ],
    );
  }
}
