package app.ledger.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.graphics.vector.toPath
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.ledger.model.initials

val WhiteText = Color(0xFFFFFFFF)

/** A line of text in Archivo. */
@Composable
fun Txt(text: String, style: androidx.compose.ui.text.TextStyle, modifier: Modifier = Modifier, maxLines: Int = Int.MAX_VALUE, overflow: TextOverflow = TextOverflow.Clip) =
    BasicText(text, modifier, style, maxLines = maxLines, overflow = overflow)

/** A stroke icon from [Icons], drawn from its 24×24 path data. */
@Composable
fun Ico(paths: String, size: Dp, color: Color, stroke: Float = 2f) {
    val path = remember(paths) { PathParser().parsePathString(paths).toPath() }
    Canvas(Modifier.size(size)) {
        val s = this.size.width / 24f
        withTransform({ scale(s, s, Offset.Zero) }) {
            drawPath(path, color, style = Stroke(width = stroke, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}

/** Tap target that tints to the surface colour while pressed (the design's hover/active state). */
@Composable
fun Pressable(
    modifier: Modifier = Modifier,
    onTap: (() -> Unit)? = null,
    color: Color? = null,
    highlight: Color? = null,
    shape: Shape = RectangleShape,
    border: BorderStroke? = null,
    scaleDown: Boolean = false,
    label: String? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    var down by remember { mutableStateOf(false) }
    val hl = highlight ?: colors.surface
    val scale by animateFloatAsState(if (scaleDown && down) .97f else 1f, tween(120))
    val fill = if (down && onTap != null) hl else color
    var m = modifier.graphicsLayer { scaleX = scale; scaleY = scale }.clip(shape)
    if (fill != null) m = m.background(fill, shape)
    if (border != null) m = m.border(border, shape)
    Box(
        m
            .pointerInput(onTap) {
                detectTapGestures(onPress = {
                    down = true
                    tryAwaitRelease()
                    down = false
                }, onTap = { onTap?.invoke() })
            }
            .semantics(mergeDescendants = true) {
                role = Role.Button
                if (label != null) contentDescription = label
            },
        content = content,
    )
}

/** iOS inset-grouped container: card colour, hairline border, 20 radius. */
@Composable
fun InsetGroup(modifier: Modifier = Modifier, color: Color? = null, bordered: Boolean = true, content: @Composable ColumnScope.() -> Unit) {
    val c = colors
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier.fillMaxWidth().clip(shape).background(color ?: c.card, shape).let { if (bordered) it.border(1.dp, c.line, shape) else it },
        content = content,
    )
}

/** A row inside an [InsetGroup]: leading at 16dp inset, then content whose bottom hairline starts after the leading element. */
@Composable
fun GroupRow(
    modifier: Modifier = Modifier,
    leading: (@Composable () -> Unit)? = null,
    divider: Boolean = true,
    onTap: (() -> Unit)? = null,
    minHeight: Dp = 52.dp,
    padding: PaddingValues = PaddingValues(end = 16.dp),
    gap: Dp = 12.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    val line = colors.line
    val row: @Composable () -> Unit = {
        Row(modifier.fillMaxWidth().heightIn(min = minHeight).height(IntrinsicSize.Min)) {
            Spacer(Modifier.width(16.dp))
            if (leading != null) {
                Box(Modifier.fillMaxHeight(), contentAlignment = Alignment.Center) { leading() }
                Spacer(Modifier.width(gap))
            }
            Box(
                Modifier.weight(1f).fillMaxHeight()
                    .drawBehind { if (divider) drawRect(line, Offset(0f, size.height - 1.dp.toPx()), androidx.compose.ui.geometry.Size(size.width, 1.dp.toPx())) }
                    .padding(padding),
                contentAlignment = Alignment.CenterStart,
                content = content,
            )
        }
    }
    if (onTap == null) row() else Pressable(onTap = onTap) { row() }
}

@Composable
fun Avatar(name: String, size: Dp = 40.dp) {
    val (tint, fg) = colors.avatar(name)
    Box(Modifier.size(size).background(tint, CircleShape), contentAlignment = Alignment.Center) {
        Txt(initials(name), ts(15, 700, fg))
    }
}

/** Small grey section caption above a group, e.g. "People". */
@Composable
fun SectionLabel(text: String, trailing: String? = null) {
    val st = ts(13, 600, colors.muted)
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Txt(text, st, Modifier.weight(1f))
        if (trailing != null) Txt(trailing, st)
    }
}

@Composable
fun Chevron(size: Dp = 14.dp) = Ico(Icons.chevron, size, colors.muted, 2.5f)

/** Full-width filled button in the accent colour. */
@Composable
fun AccentButton(label: String, onTap: () -> Unit, modifier: Modifier = Modifier, height: Dp = 52.dp, padding: PaddingValues = PaddingValues(0.dp)) {
    val c = colors
    Pressable(modifier.fillMaxWidth(), onTap, color = c.accent, highlight = c.accent600, shape = RoundedCornerShape(14.dp)) {
        Box(Modifier.fillMaxWidth().heightIn(min = height).padding(padding), contentAlignment = Alignment.Center) {
            Txt(label, ts(17, 700, WhiteText))
        }
    }
}

/** Card-coloured button used for "Log out" and "Delete transaction". */
@Composable
fun CardButton(label: String, onTap: () -> Unit, color: Color, modifier: Modifier = Modifier) {
    val c = colors
    Pressable(modifier.fillMaxWidth(), onTap, color = c.card, shape = RoundedCornerShape(20.dp), border = BorderStroke(1.dp, c.line)) {
        Box(Modifier.fillMaxWidth().heightIn(min = 52.dp), contentAlignment = Alignment.Center) {
            Txt(label, ts(17, 600, color))
        }
    }
}

/** iOS-style 51×31 switch with a springy thumb. */
@Composable
fun LedgerSwitch(value: Boolean, onChanged: (Boolean) -> Unit, label: String) {
    val c = colors
    val track by animateColorAsState(if (value) c.accent else c.swOff, tween(250))
    val left by animateDpAsState(if (value) 22.dp else 2.dp, tween(350, easing = CubicBezierEasing(.3f, 1.35f, .5f, 1f)))
    Box(
        Modifier.size(51.dp, 31.dp).clip(RoundedCornerShape(50)).background(track)
            .pointerInput(value) { detectTapGestures { onChanged(!value) } }
            .semantics { role = Role.Switch; contentDescription = label; stateDescription = if (value) "On" else "Off" },
    ) {
        Box(
            Modifier.offset(left, 2.dp).size(27.dp)
                .shadow(4.dp, CircleShape, ambientColor = Color(0x29000000), spotColor = Color(0x26000000))
                .background(WhiteText, CircleShape),
        )
    }
}

/** iOS segmented control. */
@Composable
fun <T> Segmented(options: List<Pair<T, String>>, value: T, onChanged: (T) -> Unit, modifier: Modifier = Modifier) {
    val c = colors
    Row(modifier.fillMaxWidth().background(c.segBg, RoundedCornerShape(10.dp)).padding(2.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        for ((v, label) in options) {
            val on = v == value
            val bg by animateColorAsState(if (on) c.card else Transparent, tween(200))
            Box(
                Modifier.weight(1f).heightIn(min = 36.dp)
                    .then(if (on) Modifier.shadow(1.dp, RoundedCornerShape(8.dp), ambientColor = Color(0x24131A26), spotColor = Color(0x24131A26)) else Modifier)
                    .background(bg, RoundedCornerShape(8.dp))
                    .pointerInput(v) { detectTapGestures { onChanged(v) } }
                    .semantics { role = Role.Tab; selected = on },
                contentAlignment = Alignment.Center,
            ) {
                Txt(label, ts(14, 600, if (on) c.text else c.muted))
            }
        }
    }
}

/** Centered icon disc used by the empty states. */
@Composable
fun IconDisc(icon: String, size: Dp, iconSize: Dp) {
    val c = colors
    Box(Modifier.size(size).background(c.accent100, CircleShape), contentAlignment = Alignment.Center) {
        Ico(icon, iconSize, c.accent)
    }
}

/** Plain borderless text style helper for text input hints. */
fun hintColor(muted: Color) = muted.copy(alpha = muted.alpha * .7f)
