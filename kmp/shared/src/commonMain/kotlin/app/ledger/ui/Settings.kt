package app.ledger.ui

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.BorderStroke
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ledger.store.LedgerStore
import app.ledger.store.SyncStatus
import app.ledger.store.followOptions

const val SYSTEM_PALETTE_KEY = "system"

/** One line for the Odoo sync row. */
fun syncLabel(s: LedgerStore): String = when {
    s.status == SyncStatus.Syncing -> "Syncing…"
    s.status == SyncStatus.AuthFailed -> "Key rejected"
    s.failedCount > 0 -> "${s.failedCount} failed"
    s.pendingCount > 0 -> "${s.pendingCount} waiting"
    s.status == SyncStatus.Offline -> "Offline"
    else -> "Up to date"
}

@Composable
fun SettingsScreen(store: LedgerStore, scroll: ScrollState, onFollow: () -> Unit, onLogout: () -> Unit, onExport: () -> Unit, onSync: () -> Unit) {
    val c = colors
    val system = LocalSystemPalette.current
    val name = store.config?.db ?: "On this device"
    val where = store.config?.host ?: "Not connected to Odoo"

    @Composable
    fun tile(i: Int, icon: String) = Box(Modifier.size(30.dp).background(c.ic[i], RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
        Ico(icon, 17.dp, WhiteText, 2.25f)
    }

    @Composable
    fun switchRow(ic: Int, icon: String, label: String, value: Boolean, on: (Boolean) -> Unit, divider: Boolean = true) =
        GroupRow(leading = { tile(ic, icon) }, divider = divider) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Txt(label, ts(17, color = c.text), Modifier.weight(1f))
                Spacer(Modifier.width(12.dp))
                LedgerSwitch(value, on, label)
            }
        }

    val activePalette = (if (store.palette == SYSTEM_PALETTE_KEY) system else null) ?: paletteFor(store.palette)
    val choices = listOfNotNull(system) + palettes

    Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(start = 20.dp, end = 20.dp, bottom = 32.dp)) {
        Txt("Settings", ts(34, 800, c.text, ls = -0.03f, height = 1.1f), Modifier.offset(y = (-4).dp))
        Spacer(Modifier.height(24.dp))
        Pressable(Modifier.fillMaxWidth(), color = c.card, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, c.line)) {
            Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(56.dp).background(c.accent100, CircleShape), contentAlignment = Alignment.Center) {
                    Txt(name.take(1).uppercase(), ts(22, 800, c.accent))
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Txt(name, ts(19, 700, c.text, ls = -0.01f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.height(2.dp))
                    Txt(where, ts(14, color = c.muted), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
        Spacer(Modifier.height(28.dp))
        SectionLabel("Preferences")
        Spacer(Modifier.height(8.dp))
        InsetGroup {
            GroupRow(leading = { tile(0, Icons.clock) }, onTap = onFollow) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Txt("Follow up after", ts(17, color = c.text), Modifier.weight(1f))
                    Txt(store.follow, ts(17, color = c.muted))
                    Spacer(Modifier.width(8.dp))
                    Chevron()
                }
            }
            switchRow(1, Icons.moon, "Dark appearance", store.dark, store::updateDark, divider = false)
        }
        Spacer(Modifier.height(28.dp))
        SectionLabel("Color theme", trailing = activePalette.name)
        Spacer(Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            for (pair in choices.chunked(2)) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    for (p in pair) PaletteCard(p, p.key == store.palette, { store.updatePalette(p.key) }, Modifier.weight(1f))
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
        Spacer(Modifier.height(28.dp))
        SectionLabel("Notifications")
        Spacer(Modifier.height(8.dp))
        InsetGroup {
            switchRow(2, Icons.bell, "Daily reminder", store.daily, { store.setSwitch("daily", it) })
            switchRow(3, Icons.userAlert, "Unsettled balances", store.unsettled, { store.setSwitch("unsettled", it) }, divider = false)
        }
        Spacer(Modifier.height(8.dp))
        Txt("Get a notification when someone hasn’t settled up within your follow-up period.", ts(13, color = c.muted, height = 1.45f), Modifier.padding(horizontal = 16.dp))
        Spacer(Modifier.height(28.dp))
        SectionLabel("Privacy & data")
        Spacer(Modifier.height(8.dp))
        InsetGroup {
            switchRow(4, Icons.lock, "Require Face ID", store.faceId, { store.setSwitch("faceId", it) })
            if (store.connected) {
                GroupRow(leading = { tile(3, Icons.sync) }, onTap = onSync) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Txt("Odoo sync", ts(17, color = c.text), Modifier.weight(1f))
                        Txt(syncLabel(store), ts(17, color = if (store.status == SyncStatus.AuthFailed || store.failedCount > 0) c.expense else c.muted))
                        Spacer(Modifier.width(8.dp))
                        Chevron()
                    }
                }
            }
            GroupRow(leading = { tile(5, Icons.download) }, divider = false, onTap = onExport) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Txt("Export transactions", ts(17, color = c.text), Modifier.weight(1f))
                    Txt("CSV", ts(17, color = c.muted))
                    Spacer(Modifier.width(8.dp))
                    Chevron()
                }
            }
        }
        Spacer(Modifier.height(28.dp))
        CardButton("Log out", onLogout, c.expense)
    }
}

@Composable
private fun PaletteCard(palette: Palette, selected: Boolean, onTap: () -> Unit, modifier: Modifier) {
    val c = colors
    Pressable(
        modifier.height(116.dp).semantics { this.selected = selected; contentDescription = palette.name },
        onTap = onTap, scaleDown = true, color = c.card, highlight = c.card, shape = RoundedCornerShape(18.dp),
        border = BorderStroke(2.dp, if (selected) c.accent else c.line),
    ) {
        Column(Modifier.padding(8.dp)) {
            Box(Modifier.fillMaxWidth().height(64.dp).background(palette.ink, RoundedCornerShape(12.dp)), contentAlignment = Alignment.BottomStart) {
                DotGrid(mix(palette.neutral, 28f, Transparent), 9f, 1.1f, Modifier.matchParentSizeCompat())
                Row(Modifier.padding(start = 8.dp, bottom = 8.dp)) {
                    for (col in listOf(palette.accent, palette.posD, palette.neutral)) {
                        Box(Modifier.padding(end = 5.dp).size(16.dp).background(col, CircleShape))
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.height(24.dp).padding(start = 4.dp, end = 4.dp, bottom = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                Txt(palette.name, ts(15, 700, c.text), Modifier.weight(1f))
                if (selected) {
                    Box(Modifier.size(22.dp).background(c.accent, CircleShape), contentAlignment = Alignment.Center) { Ico(Icons.check, 12.dp, WhiteText, 3.5f) }
                }
            }
        }
    }
}

private fun Modifier.matchParentSizeCompat(): Modifier = this.fillMaxSize()
