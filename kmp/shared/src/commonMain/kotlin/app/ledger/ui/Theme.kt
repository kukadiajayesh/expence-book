package app.ledger.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import org.jetbrains.compose.resources.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import app.ledger.shared.resources.Res
import app.ledger.shared.resources.archivo
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin

/** One of the colour palettes from Settings → Color theme. */
@Immutable
class Palette(
    val key: String,
    val name: String,
    val ink: Color,
    val accent: Color,
    val accentD: Color,
    val pos: Color,
    val posD: Color,
    val neg: Color,
    val negD: Color,
    val neutral: Color,
    val bg: Color,
    val bgD: Color,
    val text: Color,
    val textD: Color,
    val muted: Color,
    val mutedD: Color,
)

private fun c(argb: Long) = Color(argb)

val palettes = listOf(
    Palette("terracotta", "Terracotta", c(0xFF4A3333), c(0xFFE1473F), c(0xFFEF6A61), c(0xFF3E7B75), c(0xFF8FC2BC), c(0xFFC63A33), c(0xFFF07A6F), c(0xFFDBD1B3), c(0xFFF6F2EA), c(0xFF161010), c(0xFF2E2020), c(0xFFEFE8DC), c(0xFF6E5F5C), c(0xFFB3A49C)),
    Palette("midnight", "Midnight", c(0xFF16233D), c(0xFF2F5BD3), c(0xFF7096F5), c(0xFF157A62), c(0xFF5FCCA8), c(0xFFC2362D), c(0xFFF2867B), c(0xFFC9D3E3), c(0xFFF3F5F9), c(0xFF0C111B), c(0xFF121A2B), c(0xFFE6EAF1), c(0xFF56627A), c(0xFF9AA6BB)),
    Palette("forest", "Forest", c(0xFF1F3A30), c(0xFF2E7D5B), c(0xFF5FBF8F), c(0xFF2A7A50), c(0xFF6FD1A0), c(0xFFB8432F), c(0xFFF08A72), c(0xFFE3DCC4), c(0xFFF5F3EC), c(0xFF0F1512), c(0xFF18241F), c(0xFFE6ECE7), c(0xFF5D675F), c(0xFFA3AEA6)),
    Palette("graphite", "Graphite", c(0xFF26282D), c(0xFFC94A17), c(0xFFF07A45), c(0xFF2F7D62), c(0xFF6CC9A4), c(0xFFC0392B), c(0xFFF08577), c(0xFFD8D4CC), c(0xFFF4F4F2), c(0xFF111214), c(0xFF18191C), c(0xFFECECEC), c(0xFF5F6168), c(0xFFA2A4AB)),
)

fun paletteFor(key: String): Palette = palettes.firstOrNull { it.key == key } ?: palettes.first()

val Transparent = Color(0x00000000)
private val White = Color(0xFFFFFFFF)
private val Black = Color(0xFF000000)

/** CSS `color-mix(in srgb, a p%, b)`. Mixing with transparent keeps `a`'s colour and scales its alpha. */
fun mix(a: Color, p: Float, b: Color): Color {
    val f = p / 100f
    if (b.alpha == 0f) return a.copy(alpha = a.alpha * f)
    return Color(
        red = a.red * f + b.red * (1 - f),
        green = a.green * f + b.green * (1 - f),
        blue = a.blue * f + b.blue * (1 - f),
        alpha = a.alpha * f + b.alpha * (1 - f),
    )
}

/** CSS `oklch(L C h)` converted to sRGB. */
fun oklch(l: Double, c: Double, h: Double): Color {
    val hr = h * PI / 180
    val a = c * cos(hr)
    val b = c * sin(hr)
    val l1 = (l + 0.3963377774 * a + 0.2158037573 * b).pow(3)
    val m1 = (l - 0.1055613458 * a - 0.0638541728 * b).pow(3)
    val s1 = (l - 0.0894841775 * a - 1.2914855480 * b).pow(3)
    fun g(x: Double): Float {
        val v = if (x <= 0.0031308) 12.92 * x else 1.055 * x.pow(1 / 2.4) - 0.055
        return v.coerceIn(0.0, 1.0).toFloat()
    }
    return Color(
        red = g(4.0767416621 * l1 - 3.3077115913 * m1 + 0.2309699292 * s1),
        green = g(-1.2684380046 * l1 + 2.6097574011 * m1 - 0.3413193965 * s1),
        blue = g(-0.0041960863 * l1 - 0.7034186147 * m1 + 1.7076147010 * s1),
        alpha = 1f,
    )
}

/** Resolved colour tokens for one palette in light or dark appearance. Mirrors `buildTheme()` in the design prototype. */
@Immutable
class LedgerColors(val palette: Palette, val dark: Boolean) {
    val emBg: Color
    val emBorder: Color
    val emShadow: Color
    val emText: Color
    val emSub: Color
    val emChip: Color
    val emDot: Color
    val emMark: Color
    val emLine: Color
    val emLineStrong: Color
    val emUp: Color
    val emDown: Color
    val emFlat: Color
    val emOnChip: Color
    val bg: Color
    val surface: Color
    val text: Color
    val accent: Color
    val accent100: Color
    val accent600: Color
    val income: Color
    val expense: Color
    val card: Color
    val line: Color
    val lineStrong: Color
    val muted: Color
    val hero: Color
    val segBg: Color
    val swOff: Color
    val shadowLg: Color

    /** Settings row icon tiles, `--ic1` … `--ic6`. */
    val ic: List<Color>

    init {
        val c = palette
        if (!dark) {
            emBg = c.ink
            emBorder = Transparent
            emShadow = mix(c.ink, 30f, Transparent)
            emText = mix(c.neutral, 30f, White)
            emSub = c.neutral
            emChip = mix(c.neutral, 60f, White)
            emDot = mix(c.neutral, 22f, Transparent)
            emMark = mix(c.neutral, 8f, Transparent)
            emLine = mix(c.neutral, 20f, Transparent)
            emLineStrong = mix(c.neutral, 36f, Transparent)
            emFlat = mix(c.neutral, 20f, Transparent)
            emOnChip = c.ink
            bg = c.bg
            surface = mix(c.neutral, 35f, c.bg)
            text = c.text
            accent = c.accent
            accent100 = mix(c.accent, 12f, White)
            accent600 = mix(c.accent, 82f, Black)
            income = c.pos
            expense = c.neg
            card = mix(c.bg, 25f, White)
            line = mix(c.neutral, 40f, White)
            lineStrong = mix(c.neutral, 75f, White)
            muted = c.muted
            segBg = mix(c.neutral, 40f, c.bg)
            swOff = Color(120, 120, 128, 51)
            shadowLg = mix(c.ink, 18f, Transparent)
            ic = listOf(c.pos, c.ink, c.accent, mix(c.neutral, 60f, Black), mix(c.pos, 80f, Black), c.muted)
        } else {
            emBg = mix(c.ink, 75f, Black)
            emBorder = mix(c.neutral, 18f, Transparent)
            emShadow = Color(0, 0, 0, 115)
            emText = mix(c.neutral, 25f, White)
            emSub = mix(c.neutral, 85f, Black)
            emChip = mix(c.neutral, 80f, White)
            emDot = mix(c.neutral, 15f, Transparent)
            emMark = mix(c.neutral, 5f, Transparent)
            emLine = mix(c.neutral, 14f, Transparent)
            emLineStrong = mix(c.neutral, 28f, Transparent)
            emFlat = mix(c.neutral, 14f, Transparent)
            emOnChip = emBg
            bg = c.bgD
            surface = mix(c.bgD, 86f, c.neutral)
            text = c.textD
            accent = c.accentD
            accent100 = mix(c.accentD, 18f, c.bgD)
            accent600 = mix(c.accentD, 80f, White)
            income = c.posD
            expense = c.negD
            card = mix(c.bgD, 93f, c.neutral)
            line = Color(255, 255, 255, 20)
            lineStrong = Color(255, 255, 255, 56)
            muted = c.mutedD
            segBg = mix(c.bgD, 86f, c.neutral)
            swOff = Color(150, 150, 160, 92)
            shadowLg = Color(0, 0, 0, 115)
            ic = listOf(mix(c.posD, 80f, Black), mix(c.ink, 70f, c.neutral), c.accentD, mix(c.neutral, 55f, Black), mix(c.posD, 60f, Black), mix(c.mutedD, 70f, Black))
        }
        emUp = c.posD
        emDown = c.negD
        hero = c.ink
    }

    val shadowLgColor get() = shadowLg

    /** Avatar tint and initials colour for a person, hashed from their name. */
    fun avatar(name: String): Pair<Color, Color> {
        val hues = listOf(25.0, 185.0, 75.0, 350.0, 160.0, 45.0)
        val h = hues[name.sumOf { it.code } % hues.size]
        return if (dark) oklch(0.32, 0.05, h) to oklch(0.86, 0.09, h) else oklch(0.94, 0.035, h) to oklch(0.47, 0.12, h)
    }

    companion object {
        val backdrop = Color(0xFF05070B)
    }
}

val LocalColors = compositionLocalOf { LedgerColors(palettes.first(), false) }

/** The wallpaper palette, when this device has one to offer (Android 12+). */
val LocalSystemPalette = compositionLocalOf<Palette?> { null }

val LocalLedgerFont = compositionLocalOf<FontFamily> { FontFamily.Default }

/** Shorthand for the current colours. */
val colors: LedgerColors
    @Composable @ReadOnlyComposable get() = LocalColors.current

/** Archivo is a variable font, so each weight sets its own `wght` axis. */
@Composable
fun rememberArchivo(): FontFamily {
    val weights = listOf(400, 500, 600, 700, 800)
    val fonts = weights.map { w ->
        Font(Res.font.archivo, FontWeight(w), FontStyle.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(w)))
    }
    return remember(fonts) { FontFamily(fonts) }
}

/** Archivo text style. [ls] is letter-spacing in em and [height] a line-height multiplier, as in the design. */
@Composable
fun ts(size: Int, w: Int = 400, color: Color = Color.Unspecified, ls: Float = 0f, height: Float? = null, tabular: Boolean = false, align: androidx.compose.ui.text.style.TextAlign? = null): TextStyle =
    TextStyle(
        fontFamily = LocalLedgerFont.current,
        fontSize = size.sp,
        fontWeight = FontWeight(w.coerceIn(100, 900)),
        color = color,
        letterSpacing = ls.em,
        lineHeight = if (height != null) (height * size).sp else androidx.compose.ui.unit.TextUnit.Unspecified,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
        fontFeatureSettings = if (tabular) "tnum" else null,
        textAlign = align ?: androidx.compose.ui.text.style.TextAlign.Unspecified,
    )

@Composable
fun LedgerTheme(palette: Palette, dark: Boolean, system: Palette?, content: @Composable () -> Unit) {
    val colors = remember(palette, dark) { LedgerColors(palette, dark) }
    CompositionLocalProvider(
        LocalColors provides colors,
        LocalSystemPalette provides system,
        LocalLedgerFont provides rememberArchivo(),
        content = content,
    )
}
