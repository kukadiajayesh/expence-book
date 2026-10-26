package app.ledger.platform

import androidx.compose.runtime.Composable
import app.ledger.ui.Palette
import platform.UIKit.UIPasteboard

actual fun copyToClipboard(text: String) {
    UIPasteboard.generalPasteboard.string = text
}

/** iOS has no wallpaper-derived palette. */
@Composable
actual fun rememberSystemPalette(): Palette? = null

/** iOS has no system back button; edge-swipe navigation isn't used in this app. */
@Composable
actual fun BackHandler(enabled: Boolean, onBack: () -> Unit) {}

@Composable
actual fun StatusBarStyle(lightIcons: Boolean) {}
