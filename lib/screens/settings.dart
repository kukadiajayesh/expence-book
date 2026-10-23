import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/net_card.dart' show DotGridPainter;

/// "alex.morgan@x.com" → "Alex Morgan".
String displayName(String email) {
  final local = email.split('@').first;
  final words = local.split(RegExp(r'[._\-+]+')).where((w) => w.isNotEmpty);
  final name = words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  return name.isEmpty ? 'You' : name;
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store, required this.onFollow, required this.onLogout});

  final LedgerStore store;
  final VoidCallback onFollow, onLogout;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = displayName(store.email);

    Widget tile(int i, String icon) => Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.ic[i], borderRadius: BorderRadius.circular(8)),
          child: Ico(icon, size: 17, color: const Color(0xFFFFFFFF), stroke: 2.25),
        );

    Widget switchRow(int ic, String icon, String label, bool value, ValueChanged<bool> on, {bool divider = true}) => GroupRow(
          leading: tile(ic, icon),
          divider: divider,
          child: Row(children: [
            Expanded(child: Text(label, style: ts(17, color: c.text))),
            const SizedBox(width: 12),
            LedgerSwitch(value: value, onChanged: on, label: label),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Transform.translate(offset: const Offset(0, -4), child: Text('Settings', style: ts(34, w: 800, ls: -0.03, height: 1.1, color: c.text))),
        const SizedBox(height: 24),
        Pressable(
          onTap: () {},
          color: c.card,
          radius: BorderRadius.circular(20),
          border: Border.all(color: c.line),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accent100, shape: BoxShape.circle),
                child: Text(name[0], style: ts(22, w: 800, color: c.accent)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: ts(19, w: 700, ls: -0.01, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(store.email, style: ts(14, color: c.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 14),
              const Chevron(size: 16),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        const SectionLabel('Preferences'),
        const SizedBox(height: 8),
        InsetGroup(children: [
          GroupRow(
            leading: tile(0, Ico.clock),
            onTap: onFollow,
            child: Row(children: [
              Expanded(child: Text('Follow up after', style: ts(17, color: c.text))),
              Text(store.follow, style: ts(17, color: c.muted)),
              const SizedBox(width: 8),
              const Chevron(),
            ]),
          ),
          switchRow(1, Ico.moon, 'Dark appearance', store.dark, store.setDark, divider: false),
        ]),
        const SizedBox(height: 28),
        SectionLabel('Color theme', trailing: paletteFor(store.palette).name),
        const SizedBox(height: 8),
        GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 116),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [for (final p in palettes) _PaletteCard(palette: p, selected: p.key == store.palette, onTap: () => store.setPalette(p.key))],
        ),
        const SizedBox(height: 28),
        const SectionLabel('Notifications'),
        const SizedBox(height: 8),
        InsetGroup(children: [
          switchRow(2, Ico.bell, 'Daily reminder', store.daily, (v) => store.setSwitch('daily', v)),
          switchRow(3, Ico.userAlert, 'Unsettled balances', store.unsettled, (v) => store.setSwitch('unsettled', v), divider: false),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Get a notification when someone hasn’t settled up within your follow-up period.', style: ts(13, height: 1.45, color: c.muted)),
        ),
        const SizedBox(height: 28),
        const SectionLabel('Privacy & data'),
        const SizedBox(height: 8),
        InsetGroup(children: [
          switchRow(4, Ico.lock, 'Require Face ID', store.faceId, (v) => store.setSwitch('faceId', v)),
          GroupRow(
            leading: tile(5, Ico.download),
            divider: false,
            onTap: () {},
            child: Row(children: [
              Expanded(child: Text('Export transactions', style: ts(17, color: c.text))),
              Text('CSV', style: ts(17, color: c.muted)),
              const SizedBox(width: 8),
              const Chevron(),
            ]),
          ),
        ]),
        const SizedBox(height: 28),
        CardButton('Log out', onTap: onLogout, color: c.expense),
      ],
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({required this.palette, required this.selected, required this.onTap});

  final Palette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget dot(Color col) => Container(width: 16, height: 16, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: col, shape: BoxShape.circle));
    return Semantics(
      selected: selected,
      label: palette.name,
      child: Pressable(
        onTap: onTap,
        scaleDown: true,
        color: c.card,
        highlight: c.card,
        radius: BorderRadius.circular(18),
        border: Border.all(color: selected ? c.accent : c.line, width: 2),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 64,
              child: Container(
                decoration: BoxDecoration(color: palette.ink, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: DotGridPainter(color: mix(palette.neutral, 28, const Color(0x00000000)), spacing: 9, radius: 1.1))),
                  Positioned(left: 8, bottom: 8, child: Row(children: [dot(palette.accent), dot(palette.posD), dot(palette.neutral)])),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                child: Row(children: [
                  Expanded(child: Text(palette.name, style: ts(15, w: 700, color: c.text))),
                  if (selected)
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: const Ico(Ico.check, size: 12, color: Color(0xFFFFFFFF), stroke: 3.5),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
