package app.ledger.platform

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import androidx.activity.compose.BackHandler as ActivityBackHandler
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.ledger.ui.Palette
import app.ledger.ui.SYSTEM_PALETTE_KEY

actual fun copyToClipboard(text: String) {
    val cm = AppContext.app.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    cm.setPrimaryClip(ClipData.newPlainText("Ledger", text))
}

@Composable
actual fun rememberSystemPalette(): Palette? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var resumes by remember { mutableIntStateOf(0) }
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) resumes++ }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    // A new wallpaper is picked up the next time the app comes back to the foreground.
    return remember(resumes) {
        val l = dynamicLightColorScheme(context)
        val d = dynamicDarkColorScheme(context)
        Palette(
            key = SYSTEM_PALETTE_KEY,
            name = "Wallpaper",
            ink = l.onPrimaryContainer,
            accent = l.primary,
            accentD = d.primary,
            pos = Color(0xFF157A62),
            posD = Color(0xFF5FCCA8),
            neg = Color(0xFFC2362D),
            negD = Color(0xFFF2867B),
            neutral = l.primaryContainer,
            bg = l.surface,
            bgD = d.surface,
            text = l.onSurface,
            textD = d.onSurface,
            muted = l.onSurfaceVariant,
            mutedD = d.onSurfaceVariant,
        )
    }
}

@Composable
actual fun BackHandler(enabled: Boolean, onBack: () -> Unit) = ActivityBackHandler(enabled, onBack)

@Composable
actual fun StatusBarStyle(lightIcons: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    SideEffect {
        val window = (view.context as? Activity)?.window ?: return@SideEffect
        WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !lightIcons
    }
}
