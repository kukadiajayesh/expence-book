package app.ledger.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.ledger.data.OdooException
import app.ledger.store.LedgerStore
import kotlinx.coroutines.launch

/** Plain borderless text field, like the design's `all:unset` inputs. */
@Composable
fun BareField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    hint: String? = null,
    style: TextStyle? = null,
    obscure: Boolean = false,
    align: TextAlign = TextAlign.Start,
    keyboard: KeyboardType = KeyboardType.Text,
    ime: ImeAction = ImeAction.Default,
    onAction: (() -> Unit)? = null,
    label: String? = null,
    filter: ((String) -> String)? = null,
) {
    val c = colors
    val st = (style ?: ts(17, color = c.text)).copy(textAlign = align)
    BasicTextField(
        value = value,
        onValueChange = { onValueChange(filter?.invoke(it) ?: it) },
        modifier = modifier.fillMaxWidth().let { if (label != null) it.semantics { contentDescription = label } else it },
        textStyle = st,
        singleLine = true,
        cursorBrush = SolidColor(c.accent),
        visualTransformation = if (obscure) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard, imeAction = ime),
        keyboardActions = KeyboardActions(onAny = { onAction?.invoke() }),
        decorationBox = { inner ->
            Box(contentAlignment = when (align) { TextAlign.End, TextAlign.Right -> Alignment.CenterEnd; else -> Alignment.CenterStart }) {
                if (value.isEmpty() && hint != null) Txt(hint, st.copy(color = hintColor(c.muted)))
                inner()
            }
        },
    )
}

/** The theme toggle (moon in light, sun in dark). */
@Composable
fun ThemeToggle(store: LedgerStore, boxed: Boolean = false) {
    val c = colors
    val icon = if (store.dark) Icons.sun else Icons.moon
    val label = if (store.dark) "Switch to light appearance" else "Switch to dark appearance"
    if (boxed) {
        Pressable(onTap = { store.updateDark(!store.dark) }, color = c.card, shape = RoundedCornerShape(12.dp), border = BorderStroke(1.dp, c.line), label = label) {
            Box(Modifier.size(44.dp), contentAlignment = Alignment.Center) { Ico(icon, 20.dp, c.text) }
        }
    } else {
        Box(
            Modifier.size(44.dp).pointerInput(store.dark) { detectTapGestures { store.updateDark(!store.dark) } }.semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) { Ico(icon, 22.dp, c.accent) }
    }
}

@Composable
fun LoginScreen(store: LedgerStore, showLocalOption: Boolean = true) {
    val c = colors
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    var url by remember { mutableStateOf("") }
    var db by remember { mutableStateOf("") }
    var key by remember { mutableStateOf("") }
    var err by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    LaunchedEffect(store.devError) { store.devError?.let { err = it } }

    fun submit() {
        if (busy) return
        if (url.isBlank()) { err = "Enter your Odoo server address."; return }
        if (db.isBlank()) { err = "Enter the database name."; return }
        if (key.isBlank()) { err = "Enter your API key."; return }
        focus.clearFocus()
        busy = true
        err = ""
        scope.launch {
            try {
                store.connect(url, db, key)
            } catch (e: OdooException) {
                err = e.message ?: "Could not connect."
            } catch (e: Exception) {
                err = "Could not connect: ${e.message}"
            } finally {
                busy = false
            }
        }
    }

    val imeBottom = WindowInsets.ime.asPaddingValues().calculateBottomPadding()
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 20.dp, top = 20.dp, end = 20.dp, bottom = 40.dp + imeBottom),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(38.dp).background(c.accent, RoundedCornerShape(11.dp)), contentAlignment = Alignment.Center) {
                Txt("L", ts(19, 800, WhiteText))
            }
            Spacer(Modifier.width(10.dp))
            Txt("Ledger", ts(20, 800, c.text, ls = -0.02f), Modifier.weight(1f))
            ThemeToggle(store, boxed = true)
        }
        Spacer(Modifier.height(64.dp))
        Txt("Connect to Odoo", ts(34, 800, c.text, ls = -0.03f, height = 1.1f))
        Spacer(Modifier.height(8.dp))
        Txt("Your payments are saved in Odoo and kept on this phone for when you are offline.", ts(17, color = c.muted, height = 1.45f))
        Spacer(Modifier.height(28.dp))
        InsetGroup {
            GroupRow(leading = { Txt("Server", ts(17, color = c.text), Modifier.width(84.dp)) }) {
                BareField(url, { url = it; err = "" }, hint = "odoo.example.com", keyboard = KeyboardType.Uri, ime = ImeAction.Next, label = "Server")
            }
            GroupRow(leading = { Txt("Database", ts(17, color = c.text), Modifier.width(84.dp)) }) {
                BareField(db, { db = it; err = "" }, hint = "database name", ime = ImeAction.Next, label = "Database")
            }
            GroupRow(leading = { Txt("API key", ts(17, color = c.text), Modifier.width(84.dp)) }, divider = false) {
                BareField(key, { key = it; err = "" }, hint = "paste your key", obscure = true, ime = ImeAction.Go, onAction = ::submit, label = "API key")
            }
        }
        if (err.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Txt(err, ts(13, 600, c.expense), Modifier.padding(horizontal = 16.dp))
        }
        Spacer(Modifier.height(8.dp))
        Txt(
            "Needs Odoo 19. Create a key in Odoo under Preferences → Account Security → New API Key.",
            ts(13, color = c.muted, height = 1.4f),
            Modifier.padding(horizontal = 16.dp),
        )
        Spacer(Modifier.height(28.dp))
        AccentButton(if (busy) "Connecting…" else "Connect", onTap = ::submit)
        if (showLocalOption) {
            Spacer(Modifier.height(12.dp))
            Box(
                Modifier.fillMaxWidth().heightIn(min = 44.dp).pointerInput(busy) { detectTapGestures { if (!busy) store.useLocally() } },
                contentAlignment = Alignment.Center,
            ) { Txt("Use without Odoo", ts(15, 600, c.accent)) }
        }
    }
}
