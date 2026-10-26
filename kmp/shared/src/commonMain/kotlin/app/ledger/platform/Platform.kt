package app.ledger.platform

import androidx.compose.runtime.Composable
import app.ledger.ui.Palette

/** Puts [text] on the system clipboard. */
expect fun copyToClipboard(text: String)

/** The wallpaper palette (Material You) on Android 12+, refreshed when the app returns to the foreground; null elsewhere. */
@Composable
expect fun rememberSystemPalette(): Palette?

/** Runs [onBack] for the system back gesture or button while [enabled]. */
@Composable
expect fun BackHandler(enabled: Boolean, onBack: () -> Unit)

/** Light or dark status bar icons. */
@Composable
expect fun StatusBarStyle(lightIcons: Boolean)
