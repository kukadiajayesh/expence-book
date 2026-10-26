package app.ledger.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.ledger.model.Txn
import app.ledger.model.dayLabel
import app.ledger.model.signedFmt
import app.ledger.model.today
import app.ledger.store.LedgerStore
import kotlinx.datetime.LocalDate

@Composable
fun RecordsScreen(
    store: LedgerStore,
    listState: LazyListState,
    filter: String,
    person: String?,
    query: String,
    onFilter: (String) -> Unit,
    onQuery: (String) -> Unit,
    onClearPerson: () -> Unit,
    onOpen: (Txn) -> Unit,
    onAdd: () -> Unit,
) {
    val c = colors
    val now = today()
    val recs = store.sorted
    val q = query.trim().lowercase()
    val qNum = q.replace(Regex("[₹,\\s]"), "")
    fun matches(r: Txn) = q.isEmpty() || r.person.lowercase().contains(q) || r.note.lowercase().contains(q) || (qNum.isNotEmpty() && amountDigits(r.amount).contains(qNum))
    val listed = recs.filter { (filter == "all" || it.type == filter) && (person == null || it.person == person) && matches(it) }

    val groups = mutableListOf<Pair<LocalDate, MutableList<Txn>>>()
    for (r in listed) {
        if (groups.isEmpty() || groups.last().first != r.date) groups.add(r.date to mutableListOf())
        groups.last().second.add(r)
    }

    @Composable
    fun Header() = Row(Modifier.fillMaxWidth().offset(y = (-4).dp), verticalAlignment = Alignment.Bottom) {
        Txt("Records", ts(34, 800, c.text, ls = -0.03f, height = 1.1f), Modifier.weight(1f))
        Txt("${listed.size} ${if (listed.size == 1) "transaction" else "transactions"}", ts(15, color = c.muted))
    }

    @Composable
    fun Controls() = Column {
        Row(
            Modifier.fillMaxWidth().height(44.dp).background(c.card, RoundedCornerShape(12.dp)).border(1.dp, c.line, RoundedCornerShape(12.dp)).padding(start = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Ico(Icons.search, 18.dp, c.muted, 2.25f)
            Spacer(Modifier.width(10.dp))
            Box(Modifier.weight(1f)) { BareField(query, onQuery, hint = "Search name, note or amount", ime = ImeAction.Search, label = "Search") }
            if (query.isNotEmpty()) {
                Box(Modifier.size(44.dp).pointerInput(Unit) { detectTapGestures { onQuery("") } }, contentAlignment = Alignment.Center) { Ico(Icons.close, 18.dp, c.muted, 2.5f) }
            }
        }
        Spacer(Modifier.height(12.dp))
        Segmented(listOf("all" to "All", "got" to "Received", "gave" to "Paid"), filter, onFilter)
        if (person != null) {
            Spacer(Modifier.height(10.dp))
            Row(
                Modifier.heightIn(min = 36.dp).background(c.accent100, RoundedCornerShape(50)).pointerInput(Unit) { detectTapGestures { onClearPerson() } }.padding(start = 14.dp, end = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Txt(person, ts(14, 600, c.accent))
                Spacer(Modifier.width(6.dp))
                Ico(Icons.close, 16.dp, c.accent, 2.5f)
            }
        }
    }

    if (listed.isEmpty()) {
        val none = recs.isEmpty()
        val kind = when (filter) { "got" -> "received "; "gave" -> "paid "; else -> "" }
        Column(Modifier.fillMaxSize().padding(start = 20.dp, end = 20.dp, bottom = 32.dp)) {
            Header()
            if (!none) {
                Spacer(Modifier.height(16.dp))
                Controls()
            }
            Column(Modifier.weight(1f).fillMaxWidth().padding(start = 16.dp, top = 24.dp, end = 16.dp, bottom = 64.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                IconDisc(Icons.notebook, 128.dp, 56.dp)
                Spacer(Modifier.height(20.dp))
                Txt(if (none) "No transactions yet" else "Nothing here", ts(20, 800, c.text, ls = -0.015f))
                Spacer(Modifier.height(10.dp))
                val body = when {
                    none -> "Every payment you make or receive from someone will be listed here, grouped by day."
                    q.isNotEmpty() -> "No ${kind}transactions match “${query.trim()}”${if (person != null) " with $person" else ""}."
                    else -> "No ${kind}transactions${if (person != null) " with $person" else ""}."
                }
                Txt(body, ts(15, color = c.muted, height = 1.5f, align = TextAlign.Center), Modifier.widthIn(max = 270.dp))
                Spacer(Modifier.height(20.dp))
                AccentButton(
                    if (none) "Add transaction" else "Show all",
                    if (none) onAdd else { { onFilter("all"); onClearPerson(); onQuery("") } },
                    Modifier.fillMaxWidth(),
                    height = 50.dp,
                    padding = PaddingValues(horizontal = 24.dp),
                )
            }
        }
        return
    }

    LazyColumn(Modifier.fillMaxSize(), listState, contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 32.dp)) {
        item("header") { Header() }
        item("controls") { Spacer(Modifier.height(16.dp)); Controls() }
        items(groups, key = { it.first.toString() }) { (date, rows) ->
            Spacer(Modifier.height(20.dp))
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Txt(dayLabel(date, now), ts(13, 600, c.muted), Modifier.weight(1f))
                Txt(signedFmt(rows.sumOf { it.signed }), ts(13, 600, c.muted, tabular = true))
            }
            Spacer(Modifier.height(8.dp))
            InsetGroup {
                rows.forEachIndexed { i, r ->
                    TxnRow(r, r.note.ifEmpty { if (r.isGot) "Received" else "Paid" }, divider = i < rows.size - 1, onTap = { onOpen(r) })
                }
            }
        }
    }
}

private fun amountDigits(a: Double): String {
    val cents = kotlin.math.round(a * 100).toLong()
    return "${cents / 100}.${(cents % 100).toString().padStart(2, '0')}"
}
