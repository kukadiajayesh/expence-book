package app.ledger.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusManager
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.ledger.data.OdooClient
import app.ledger.data.PaymentApi
import app.ledger.model.Txn
import app.ledger.platform.BackHandler
import app.ledger.platform.StatusBarStyle
import app.ledger.platform.copyToClipboard
import app.ledger.platform.createSecretStore
import app.ledger.platform.rememberSystemPalette
import app.ledger.store.LedgerStore
import com.russhwolf.settings.Settings
import kotlin.math.max
import kotlin.math.min
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Odoo details handed to the app at launch by a developer or a test, so it connects without typing. */
class DevConnection(val url: String, val db: String, val apiKey: String)

/**
 * The whole app: creates the store, applies the theme, and shows the shell. [dev] is for testing only:
 * when given, and not yet connected, the app connects with it at start-up.
 */
@Composable
fun LedgerRoot(demo: Boolean = false, dev: DevConnection? = null) {
    val scope = rememberCoroutineScope()
    val store = remember { LedgerStore(Settings(), createSecretStore(), { PaymentApi(OdooClient(it)) }, scope, demo) }
    LaunchedEffect(dev) {
        if (dev != null && !store.connected) runCatching { store.connect(dev.url, dev.db, dev.apiKey) }.onFailure { store.devError = it.message }
    }
    val system = rememberSystemPalette()
    val palette = (if (store.palette == SYSTEM_PALETTE_KEY) system else null) ?: paletteFor(store.palette)
    LedgerTheme(palette, store.dark, system) { Shell(store) }
}

private class Toast(val msg: String, val undo: (() -> Unit)?)

/** Nav bar, tab bar, toast and the three spring sheets. The add/edit sheet pushes the app back as it rises. */
@Composable
fun Shell(store: LedgerStore) {
    val c = colors
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    val density = LocalDensity.current

    var tab by remember { mutableStateOf("home") } // "home" | "list" | "settings"
    var filter by remember { mutableStateOf("all") }
    var person by remember { mutableStateOf<String?>(null) }
    var query by remember { mutableStateOf("") }
    var toast by remember { mutableStateOf<Toast?>(null) }
    var dialog by remember { mutableStateOf("logout") } // "delete" | "logout"
    val draft = remember { TxnDraft() }

    val form = remember { SheetController(scope, 0.4f) { focus.clearFocus() } }
    val follow = remember { SheetController(scope, 0.4f) }
    val confirm = remember { SheetController(scope, 0.45f) }
    val homeScroll = rememberScrollState()
    val settingsScroll = rememberScrollState()
    val formScroll = rememberScrollState()
    val followScroll = rememberScrollState()
    val listState = rememberLazyListState()

    var toastJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    fun showToast(msg: String, undo: (() -> Unit)? = null) {
        toastJob?.cancel()
        toast = Toast(msg, undo)
        toastJob = scope.launch { delay(4000); toast = null }
    }

    fun hideToast() {
        toastJob?.cancel()
        toast = null
    }

    fun openForm(r: Txn?) {
        draft.load(r)
        scope.launch { formScroll.scrollTo(0) }
        hideToast()
        form.open()
    }

    fun openDialog(kind: String) {
        dialog = kind
        confirm.open()
    }

    fun save() {
        val amt = draft.parsedAmount
        draft.amountErr = if (amt > 0) "" else "Enter an amount above zero."
        draft.personErr = if (draft.person.trim().isNotEmpty()) "" else "Add who this was with."
        if (draft.amountErr.isNotEmpty() || draft.personErr.isNotEmpty()) return
        val editing = draft.id != null
        store.upsert(draft.id, draft.type, kotlin.math.round(amt * 100) / 100, draft.person.trim(), draft.date, draft.note.trim())
        focus.clearFocus()
        form.close()
        showToast(if (editing) "Transaction updated" else "Transaction added")
    }

    fun confirmAction() {
        confirm.close()
        if (dialog == "logout") {
            store.logout()
            tab = "home"; filter = "all"; person = null; query = ""; toast = null
            return
        }
        form.close()
        val id = draft.id ?: return
        val undo = store.delete(id)
        showToast("Transaction deleted") { undo(); hideToast() }
    }

    fun closeTop(): Boolean {
        for (s in listOf(confirm, follow, form)) {
            if (s.isOpen) { s.close(); return true }
        }
        return false
    }

    fun syncNow() {
        scope.launch {
            store.sync()
            showToast(store.syncError ?: "Synced with Odoo")
        }
    }

    fun exportCsv() {
        copyToClipboard(store.toCsv())
        showToast(if (store.records.isEmpty()) "No transactions to export" else "CSV copied to clipboard")
    }

    LaunchedEffect(Unit) { store.sync() }

    BackHandler(enabled = form.isOpen || follow.isOpen || confirm.isOpen) { closeTop() }

    val statusTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val navBottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val tabBottom = max(navBottom.value - 4, 8f).dp

    StatusBarStyle(lightIcons = c.dark || form.progress > 0.3f)

    BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black)) {
        val h = maxHeight.value
        val sheetH = h - statusTop.value - 10
        LaunchedEffect(h, statusTop, navBottom) {
            form.setGeometry(listOf(0f), sheetH + 36)
            follow.setGeometry(listOf(0f, max(0f, sheetH - h * 0.5f)), sheetH + 36)
            confirm.setGeometry(listOf(0f), 440 + navBottom.value)
        }

        val collapsed by remember {
            derivedStateOf {
                val px = with(density) { 34.dp.toPx() }
                when (tab) {
                    "home" -> homeScroll.value > px
                    "settings" -> settingsScroll.value > px
                    else -> listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > px
                }
            }
        }

        // The app steps back as the form rises over it.
        Box(
            Modifier.fillMaxSize().graphicsLayer {
                val p = form.progress
                scaleX = 1 - 0.07f * p
                scaleY = 1 - 0.07f * p
                translationY = 12f * p * this.density
                transformOrigin = TransformOrigin(0.5f, 0f)
                clip = p > 0f
                shape = RoundedCornerShape((46f * min(1f, p * 4)).dp)
            },
        ) {
            AppBody(
                store, tab, { tab = it }, collapsed, statusTop, tabBottom,
                filter, { filter = it }, person, { person = it }, query, { query = it },
                homeScroll, settingsScroll, listState, toast,
                onOpenForm = ::openForm, onFollow = { follow.open(1) }, onLogout = { openDialog("logout") }, onExport = ::exportCsv, onSync = ::syncNow,
            )
        }

        val names = remember(store.records) {
            val out = mutableListOf<String>()
            for (r in store.sorted) {
                if (r.person !in out) out.add(r.person)
                if (out.size == 5) break
            }
            out
        }
        SheetLayer(form, onDismiss = form::close, height = sheetH.dp) {
            TxnSheet(draft, names, form, formScroll, onCancel = { focus.clearFocus(); form.close() }, onSave = ::save, onDelete = { openDialog("delete") })
        }
        SheetLayer(follow, onDismiss = follow::close, height = sheetH.dp) {
            FollowSheet(store, follow, followScroll, onDone = follow::close)
        }
        SheetLayer(confirm, onDismiss = confirm::close, left = 8.dp, right = 8.dp) {
            ConfirmSheet(
                confirm,
                title = if (dialog == "delete") "Delete this transaction?" else "Log out of Ledger?",
                body = if (dialog == "delete") "${if (draft.type == "got") "Received from" else "Paid to"} ${draft.person.trim()} · ${app.ledger.model.fmt(draft.parsedAmount)} will be removed."
                else if (store.connected) "You’ll need to connect to Odoo again.${if (store.pendingCount > 0) " ${store.pendingCount} change${if (store.pendingCount == 1) "" else "s"} not yet sent to Odoo will be lost." else ""}"
                else "You’ll need to sign in again to see your transactions.",
                cta = if (dialog == "delete") "Delete transaction" else "Log out",
                onConfirm = ::confirmAction,
                onCancel = confirm::close,
            )
        }
    }
}

@Composable
private fun AppBody(
    store: LedgerStore,
    tab: String, setTab: (String) -> Unit,
    collapsed: Boolean,
    statusTop: androidx.compose.ui.unit.Dp,
    tabBottom: androidx.compose.ui.unit.Dp,
    filter: String, setFilter: (String) -> Unit,
    person: String?, setPerson: (String?) -> Unit,
    query: String, setQuery: (String) -> Unit,
    homeScroll: ScrollState, settingsScroll: ScrollState, listState: LazyListState,
    toast: Toast?,
    onOpenForm: (Txn?) -> Unit, onFollow: () -> Unit, onLogout: () -> Unit, onExport: () -> Unit, onSync: () -> Unit,
) {
    val c = colors
    if (!store.loggedIn) {
        Box(Modifier.fillMaxSize().background(c.bg).padding(top = statusTop)) { LoginScreen(store) }
        return
    }
    val title = mapOf("home" to "Overview", "list" to "Records", "settings" to "Settings")[tab]!!

    Box(Modifier.fillMaxSize().background(c.bg)) {
        Column(Modifier.fillMaxSize()) {
            Box(Modifier.height(statusTop))
            // Nav bar: theme toggle · collapsing title · add
            val border by animateColorAsState(if (collapsed) c.line else Transparent, tween(200))
            val titleAlpha by animateFloatAsState(if (collapsed) 1f else 0f, tween(200))
            Row(
                Modifier.fillMaxWidth().height(44.dp).padding(horizontal = 8.dp)
                    .drawBottomBorder(border),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.width(88.dp), contentAlignment = Alignment.CenterStart) { ThemeToggle(store) }
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) { Txt(title, ts(17, 700, c.text, ls = -0.01f), Modifier.alpha(titleAlpha)) }
                Box(Modifier.width(88.dp), contentAlignment = Alignment.CenterEnd) {
                    if (tab != "settings") {
                        Box(
                            Modifier.size(44.dp).pointerInput(Unit) { detectTapGestures { onOpenForm(null) } }.semantics { contentDescription = "New transaction"; role = Role.Button },
                            contentAlignment = Alignment.Center,
                        ) { Ico(Icons.plus, 24.dp, c.accent, 2.25f) }
                    }
                }
            }
            Box(Modifier.weight(1f).fillMaxWidth()) {
                when (tab) {
                    "list" -> RecordsScreen(
                        store, listState, filter, person, query,
                        onFilter = setFilter, onQuery = setQuery, onClearPerson = { setPerson(null) },
                        onOpen = { onOpenForm(it) }, onAdd = { onOpenForm(null) },
                    )
                    "settings" -> SettingsScreen(store, settingsScroll, onFollow, onLogout, onExport, onSync)
                    else -> OverviewScreen(
                        store, homeScroll, onOpen = { onOpenForm(it) }, onAdd = { onOpenForm(null) },
                        onPerson = { name -> setPerson(name); setTab("list"); setFilter("all"); setQuery("") },
                        onSeeAll = { setTab("list") },
                    )
                }
            }
            // Tab bar
            Row(
                Modifier.fillMaxWidth().background(c.card.copy(alpha = c.card.alpha * .88f)).drawTopBorder(c.line)
                    .padding(start = 8.dp, top = 4.dp, end = 8.dp, bottom = tabBottom),
            ) {
                TabItem("home", "Overview", Icons.tabOverview, tab, setTab, Modifier.weight(1f))
                TabItem("list", "Records", Icons.tabRecords, tab, setTab, Modifier.weight(1f))
                TabItem("settings", "Settings", Icons.tabSettings, tab, setTab, Modifier.weight(1f))
            }
        }
        if (toast != null) {
            Box(Modifier.align(Alignment.BottomCenter).padding(start = 20.dp, end = 20.dp, bottom = 4.dp + 49.dp + tabBottom + 21.dp)) {
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 50.dp)
                        .shadow(12.dp, RoundedCornerShape(14.dp), ambientColor = c.shadowLg, spotColor = c.shadowLg)
                        .background(c.hero, RoundedCornerShape(14.dp)).padding(start = 16.dp, top = 6.dp, end = 6.dp, bottom = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Txt(toast.msg, ts(15, 600, WhiteText), Modifier.weight(1f))
                    if (toast.undo != null) {
                        Box(Modifier.heightIn(min = 38.dp).padding(horizontal = 14.dp).pointerInput(toast) { detectTapGestures { toast.undo.invoke() } }, contentAlignment = Alignment.Center) {
                            Txt("Undo", ts(15, 700, c.emSub))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TabItem(key: String, label: String, icon: String, current: String, onSelect: (String) -> Unit, modifier: Modifier) {
    val c = colors
    val col = if (current == key) c.accent else c.muted
    Column(
        modifier.heightIn(min = 49.dp).pointerInput(key) { detectTapGestures { onSelect(key) } }.semantics { role = Role.Tab; selected = current == key; contentDescription = label },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
    ) {
        Ico(icon, 24.dp, col)
        androidx.compose.foundation.layout.Spacer(Modifier.height(3.dp))
        Txt(label, ts(11, 600, col))
    }
}

private fun Modifier.drawBottomBorder(color: Color) = drawBehind {
    drawRect(color, Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx()))
}

private fun Modifier.drawTopBorder(color: Color) = drawBehind {
    drawRect(color, Offset.Zero, Size(size.width, 1.dp.toPx()))
}
