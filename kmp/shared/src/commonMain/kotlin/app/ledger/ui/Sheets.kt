package app.ledger.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.ledger.model.Txn
import app.ledger.model.dateLabel
import app.ledger.model.today
import app.ledger.store.LedgerStore
import app.ledger.store.followOptions
import kotlin.time.Instant
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.toLocalDateTime

/** The add/edit form's working copy. */
class TxnDraft {
    var id by mutableStateOf<Int?>(null)
    var type by mutableStateOf("gave")
    var amount by mutableStateOf("")
    var person by mutableStateOf("")
    var note by mutableStateOf("")
    var date by mutableStateOf(today())
    var amountErr by mutableStateOf("")
    var personErr by mutableStateOf("")

    fun load(r: Txn?) {
        id = r?.id
        type = r?.type ?: "gave"
        amount = if (r == null) "" else if (r.amount % 1.0 == 0.0) r.amount.toLong().toString() else r.amount.toString()
        person = r?.person ?: ""
        note = r?.note ?: ""
        date = r?.date ?: today()
        amountErr = ""
        personErr = ""
    }

    val parsedAmount get() = amount.replace(",", "").toDoubleOrNull() ?: 0.0
}

@Composable
private fun SheetHeaderButton(label: String, onTap: () -> Unit, bold: Boolean = false) {
    Box(Modifier.heightIn(min = 44.dp).padding(horizontal = 12.dp).pointerInput(onTap) { detectTapGestures { onTap() } }, contentAlignment = Alignment.Center) {
        Txt(label, ts(17, if (bold) 700 else 400, colors.accent))
    }
}

private val sheetShape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)

/** Full-height "New / Edit transaction" sheet. */
@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun TxnSheet(draft: TxnDraft, names: List<String>, controller: SheetController, scroll: ScrollState, onCancel: () -> Unit, onSave: () -> Unit, onDelete: () -> Unit) {
    val c = colors
    val got = draft.type == "got"
    var showDate by remember { mutableStateOf(false) }
    val imeBottom = WindowInsets.ime.asPaddingValues().calculateBottomPadding()

    @Composable
    fun Err(e: String) {
        if (e.isNotEmpty()) Txt(e, ts(13, 600, c.expense), Modifier.padding(start = 16.dp, top = 8.dp, end = 16.dp))
    }

    Column(
        Modifier.fillMaxSize()
            .shadow(14.dp, sheetShape, ambientColor = Color(0x2E05070B), spotColor = Color(0x2E05070B))
            .clip(sheetShape).background(c.bg).sheetDrag(controller),
    ) {
        Grabber()
        Row(Modifier.fillMaxWidth().padding(start = 8.dp, top = 4.dp, end = 8.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) { SheetHeaderButton("Cancel", onCancel) }
            Txt(if (draft.id != null) "Edit transaction" else "New transaction", ts(17, 700, c.text))
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) { SheetHeaderButton("Save", onSave, bold = true) }
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().sheetNestedScroll(controller).verticalScroll(scroll)
                .padding(start = 20.dp, top = 10.dp, end = 20.dp, bottom = 48.dp + imeBottom),
        ) {
            Segmented(listOf("gave" to "Paid", "got" to "Received"), draft.type, { draft.type = it })
            Spacer(Modifier.height(24.dp))
            Row(
                Modifier.fillMaxWidth().background(c.card, RoundedCornerShape(20.dp))
                    .border(1.dp, if (draft.amountErr.isNotEmpty()) c.expense else c.line, RoundedCornerShape(20.dp))
                    .padding(horizontal = 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Txt("₹", ts(30, 800, c.muted))
                Spacer(Modifier.width(6.dp))
                BareField(
                    draft.amount, { draft.amount = it; if (draft.amountErr.isNotEmpty()) draft.amountErr = "" },
                    hint = "0", style = ts(40, 800, c.text, ls = -0.03f, tabular = true), keyboard = KeyboardType.Decimal,
                    label = "Amount", filter = { s -> s.filter { it.isDigit() || it == '.' || it == ',' } },
                )
            }
            Err(draft.amountErr)
            Spacer(Modifier.height(24.dp))
            SectionLabel(if (got) "Received from" else "Paid to")
            Spacer(Modifier.height(8.dp))
            Box(
                Modifier.fillMaxWidth().heightIn(min = 52.dp).background(c.card, RoundedCornerShape(20.dp))
                    .border(1.dp, if (draft.personErr.isNotEmpty()) c.expense else c.line, RoundedCornerShape(20.dp)).padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                BareField(draft.person, { draft.person = it; draft.personErr = "" }, hint = "Name", ime = ImeAction.Next, label = "Person")
            }
            Err(draft.personErr)
            if (names.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (n in names) {
                        val on = draft.person == n
                        Box(
                            Modifier.heightIn(min = 36.dp).background(if (on) c.accent else c.card, RoundedCornerShape(50))
                                .border(1.dp, if (on) c.accent else c.line, RoundedCornerShape(50))
                                .pointerInput(n) { detectTapGestures { draft.person = n; draft.personErr = "" } }.padding(horizontal = 14.dp),
                            contentAlignment = Alignment.Center,
                        ) { Txt(n, ts(14, 600, if (on) WhiteText else c.text)) }
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
            InsetGroup {
                GroupRow(onTap = { showDate = true }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Txt("Date", ts(17, color = c.text), Modifier.weight(1f))
                        Txt(dateLabel(draft.date), ts(17, color = c.accent))
                    }
                }
                GroupRow(divider = false) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Txt("Note", ts(17, color = c.text))
                        Spacer(Modifier.width(12.dp))
                        Box(Modifier.weight(1f)) {
                            BareField(draft.note, { draft.note = it }, hint = "Optional", align = TextAlign.End, ime = ImeAction.Done, onAction = onSave, label = "Note")
                        }
                    }
                }
            }
            if (draft.id != null) {
                Spacer(Modifier.height(24.dp))
                CardButton("Delete transaction", onDelete, c.expense)
            }
        }
    }

    if (showDate) {
        val state = rememberDatePickerState(initialSelectedDateMillis = draft.date.atStartOfDayIn(TimeZone.UTC).toEpochMilliseconds())
        val scheme = if (c.dark) darkColorScheme(primary = c.accent, surface = c.card, onSurface = c.text, surfaceContainerHigh = c.card)
        else lightColorScheme(primary = c.accent, surface = c.card, onSurface = c.text, surfaceContainerHigh = c.card)
        MaterialTheme(colorScheme = scheme) {
            DatePickerDialog(
                onDismissRequest = { showDate = false },
                confirmButton = {
                    TextButton(onClick = {
                        state.selectedDateMillis?.let { draft.date = Instant.fromEpochMilliseconds(it).toLocalDateTime(TimeZone.UTC).date }
                        showDate = false
                    }) { Text("OK") }
                },
                dismissButton = { TextButton(onClick = { showDate = false }) { Text("Cancel") } },
            ) { DatePicker(state) }
        }
    }
}

/** Two-detent "Follow up after" picker. */
@Composable
fun FollowSheet(store: LedgerStore, controller: SheetController, scroll: ScrollState, onDone: () -> Unit) {
    val c = colors
    val scope = rememberCoroutineScope()
    Column(
        Modifier.fillMaxSize()
            .shadow(14.dp, sheetShape, ambientColor = Color(0x2905070B), spotColor = Color(0x2905070B))
            .clip(sheetShape).background(c.card).sheetDrag(controller),
    ) {
        Grabber()
        Row(Modifier.fillMaxWidth().padding(start = 8.dp, top = 4.dp, end = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.weight(1f))
            Txt("Follow up after", ts(17, 700, c.text))
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterEnd) { SheetHeaderButton("Done", onDone, bold = true) }
        }
        Column(Modifier.weight(1f).fillMaxWidth().sheetNestedScroll(controller).verticalScroll(scroll).padding(start = 20.dp, end = 20.dp, bottom = 40.dp)) {
            Txt("Ledger reminds you to follow up when a balance with someone stays open this long.", ts(13, color = c.muted, height = 1.45f), Modifier.padding(horizontal = 16.dp))
            Spacer(Modifier.height(8.dp))
            InsetGroup(color = c.bg, bordered = false) {
                followOptions.forEachIndexed { i, opt ->
                    GroupRow(divider = i < followOptions.size - 1, onTap = {
                        store.updateFollow(opt)
                        scope.launch { delay(140); onDone() }
                    }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Txt(opt, ts(17, color = c.text), Modifier.weight(1f))
                            if (opt == store.follow) Ico(Icons.tick, 20.dp, c.accent, 2.75f)
                        }
                    }
                }
            }
        }
    }
}

/** iOS action-sheet style confirmation (delete / log out). */
@Composable
fun ConfirmSheet(controller: SheetController, title: String, body: String, cta: String, onConfirm: () -> Unit, onCancel: () -> Unit) {
    val c = colors
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Column(Modifier.fillMaxWidth().sheetDrag(controller).padding(bottom = if (bottom > 0.dp) bottom else 16.dp).semantics { contentDescription = title }) {
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(c.card)) {
            Column(Modifier.fillMaxWidth().padding(start = 20.dp, top = 18.dp, end = 20.dp, bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Txt(title, ts(15, 700, c.text, align = TextAlign.Center))
                Spacer(Modifier.height(4.dp))
                Txt(body, ts(13, color = c.muted, height = 1.45f, align = TextAlign.Center))
            }
            Box(Modifier.fillMaxWidth().height(1.dp).background(c.line))
            Pressable(Modifier.fillMaxWidth(), onTap = onConfirm) {
                Box(Modifier.fillMaxWidth().heightIn(min = 56.dp), contentAlignment = Alignment.Center) { Txt(cta, ts(18, 600, c.expense)) }
            }
        }
        Spacer(Modifier.height(8.dp))
        Pressable(Modifier.fillMaxWidth(), onTap = onCancel, color = c.card, shape = RoundedCornerShape(18.dp)) {
            Box(Modifier.fillMaxWidth().heightIn(min = 56.dp), contentAlignment = Alignment.Center) { Txt("Cancel", ts(18, 700, c.accent)) }
        }
    }
}
