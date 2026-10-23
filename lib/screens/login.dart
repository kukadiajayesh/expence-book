import 'package:flutter/material.dart' show TextField, InputDecoration, InputBorder;
import 'package:flutter/services.dart' show TextInputAction, TextInputFormatter;
import 'package:flutter/widgets.dart';

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
  late final _email = TextEditingController(text: widget.store.email);
  final _password = TextEditingController(text: 'demo1234');
  String _err = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return setState(() => _err = 'Enter a valid email address.');
    if (_password.text.length < 4) return setState(() => _err = 'Password must be at least 4 characters.');
    FocusScope.of(context).unfocus();
    widget.store.login(email);
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
        Text('Welcome back', style: ts(34, w: 800, ls: -0.03, height: 1.1, color: c.text)),
        const SizedBox(height: 8),
        Text('Sign in to see what you’ve paid and received.', style: ts(17, height: 1.45, color: c.muted)),
        const SizedBox(height: 28),
        InsetGroup(children: [
          GroupRow(
            leading: SizedBox(width: 84, child: Text('Email', style: ts(17, color: c.text))),
            child: bareField(context, controller: _email, keyboard: TextInputType.emailAddress, action: TextInputAction.next, onChanged: clear),
          ),
          GroupRow(
            leading: SizedBox(width: 84, child: Text('Password', style: ts(17, color: c.text))),
            divider: false,
            child: bareField(context, controller: _password, obscure: true, action: TextInputAction.go, onChanged: clear, onSubmitted: (_) => _submit()),
          ),
        ]),
        if (_err.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_err, style: ts(13, w: 600, color: c.expense))),
        ],
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Demo account is prefilled.', style: ts(13, color: c.muted))),
        const SizedBox(height: 28),
        AccentButton('Sign in', onTap: _submit),
      ],
    );
  }
}
