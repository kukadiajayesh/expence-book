package app.ledger.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.ledger.model.Txn
import app.ledger.model.dayLabel
import app.ledger.model.fmt
import app.ledger.model.signedFmt
import app.ledger.model.today
import app.ledger.store.LedgerStore

/** Running total per person across all their transactions. */
class PersonSummary(val name: String) {
    var count = 0
    var net = 0.0
}

fun summarizePeople(sorted: List<Txn>): List<PersonSummary> {
    val m = LinkedHashMap<String, PersonSummary>()
    for (r in sorted) {
        val p = m.getOrPut(r.person) { PersonSummary(r.person) }
        p.count++
        p.net += r.signed
    }
    return m.values.toList()
}

@Composable
fun OverviewScreen(store: LedgerStore, scroll: ScrollState, onOpen: (Txn) -> Unit, onAdd: () -> Unit, onPerson: (String) -> Unit, onSeeAll: () -> Unit) {
    val c = colors
    val now = today()
    val recs = store.sorted
    val month = recs.filter { it.date.year == now.year && it.date.month == now.month }
    val got = month.filter { it.isGot }.sumOf { it.amount }
    val gave = month.filter { !it.isGot }.sumOf { it.amount }
    val people = summarizePeople(recs).take(4)
    val recent = recs.take(4)

    Column(Modifier.fillMaxSize().verticalScroll(scroll).padding(start = 20.dp, end = 20.dp, bottom = 32.dp)) {
        Txt("Overview", ts(34, 800, c.text, ls = -0.03f, height = 1.1f), Modifier.offset(y = (-4).dp))
        Spacer(Modifier.height(24.dp))
        NetCard(got, gave, now)
        Spacer(Modifier.height(28.dp))
        if (recs.isEmpty()) {
            Column(
                Modifier.fillMaxWidth().background(c.card, RoundedCornerShape(20.dp)).border(1.dp, c.line, RoundedCornerShape(20.dp)).padding(start = 22.dp, top = 28.dp, end = 22.dp, bottom = 22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                IconDisc(Icons.userPlus, 56.dp, 26.dp)
                Spacer(Modifier.height(14.dp))
                Txt("Start your ledger", ts(20, 800, c.text, ls = -0.015f))
                Spacer(Modifier.height(10.dp))
                Txt(
                    "Record money you pay to or receive from someone. Balances for each person will show up here.",
                    ts(15, color = c.muted, height = 1.5f, align = TextAlign.Center),
                    Modifier.widthIn(max = 280.dp),
                )
                Spacer(Modifier.height(20.dp))
                AccentButton("Add first transaction", onAdd, Modifier.fillMaxWidth(), height = 50.dp)
            }
        } else {
            SectionLabel("People")
            Spacer(Modifier.height(8.dp))
            InsetGroup {
                people.forEachIndexed { i, p ->
                    GroupRow(
                        minHeight = 60.dp,
                        padding = PaddingValues(top = 10.dp, end = 16.dp, bottom = 10.dp),
                        leading = { Avatar(p.name) },
                        divider = i < people.size - 1,
                        onTap = { onPerson(p.name) },
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Txt(p.name, ts(16, 600, c.text), maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Spacer(Modifier.height(2.dp))
                                Txt("${p.count} ${if (p.count == 1) "transaction" else "transactions"}", ts(13, color = c.muted))
                            }
                            Spacer(Modifier.width(8.dp))
                            Txt(signedFmt(p.net), ts(16, 700, if (p.net >= 0) c.income else c.text, tabular = true))
                            Spacer(Modifier.width(8.dp))
                            Chevron()
                        }
                    }
                }
            }
            Spacer(Modifier.height(28.dp))
            Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Txt("Recent", ts(13, 600, c.muted), Modifier.weight(1f))
                Box(
                    Modifier.heightIn(min = 32.dp).padding(horizontal = 12.dp).pointerInput(Unit) { detectTapGestures { onSeeAll() } },
                    contentAlignment = Alignment.Center,
                ) { Txt("See all", ts(15, 600, c.accent)) }
            }
            Spacer(Modifier.height(8.dp))
            InsetGroup {
                recent.forEachIndexed { i, r ->
                    TxnRow(r, dayLabel(r.date, now) + if (r.note.isNotEmpty()) " · ${r.note}" else "", divider = i < recent.size - 1, onTap = { onOpen(r) })
                }
            }
        }
    }
}

/** One transaction: avatar, person, a subtitle and the signed amount. */
@Composable
fun TxnRow(txn: Txn, sub: String, divider: Boolean, onTap: () -> Unit) {
    val c = colors
    GroupRow(
        minHeight = 60.dp,
        padding = PaddingValues(top = 10.dp, end = 16.dp, bottom = 10.dp),
        leading = { Avatar(txn.person) },
        divider = divider,
        onTap = onTap,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Txt(txn.person, ts(16, 600, c.text), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(2.dp))
                Txt(sub, ts(13, color = c.muted), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Spacer(Modifier.width(10.dp))
            Txt("${if (txn.isGot) "+" else "−"}${fmt(txn.amount)}", ts(16, 700, if (txn.isGot) c.income else c.text, tabular = true))
        }
    }
}
