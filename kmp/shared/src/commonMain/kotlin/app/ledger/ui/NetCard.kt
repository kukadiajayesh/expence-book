package app.ledger.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ledger.model.fmt
import app.ledger.model.monthLabel
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.datetime.LocalDate

/**
 * Dot grid background: one dot centred in each [spacing]² tile. With [fade], dots fade out along a
 * 200° CSS linear gradient (opaque at the top-right, gone by 65%).
 */
@Composable
fun DotGrid(color: Color, spacing: Float, radius: Float, modifier: Modifier = Modifier, fade: Boolean = false) {
    Canvas(modifier) {
        val a = 200 * PI / 180
        val dx = sin(a).toFloat()
        val dy = -cos(a).toFloat()
        val len = abs(size.width * sin(a)).toFloat() + abs(size.height * cos(a)).toFloat()
        val cx = size.width / 2
        val cy = size.height / 2
        val sp = spacing.dp.toPx()
        var y = sp / 2
        while (y < size.height) {
            var x = sp / 2
            while (x < size.width) {
                var alpha = 1f
                if (fade) {
                    val t = ((x - cx) * dx + (y - cy) * dy) / len + 0.5f
                    alpha = (1 - t / 0.65f).coerceIn(0f, 1f)
                }
                if (alpha > 0f) drawCircle(color.copy(alpha = color.alpha * alpha), radius.dp.toPx(), Offset(x, y))
                x += sp
            }
            y += sp
        }
    }
}

/** The "Net this month" money card on Overview (the 2b dot-grid concept). */
@Composable
fun NetCard(got: Double, gave: Double, month: LocalDate) {
    val c = colors
    val net = got - gave
    val shape = RoundedCornerShape(24.dp)

    @Composable
    fun figure(label: String, icon: String, iconColor: Color, v: Double, mod: Modifier) = Column(mod) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Ico(icon, 14.dp, iconColor, 2.75f)
            Spacer(Modifier.width(6.dp))
            Txt(label, ts(12, 600, c.emSub))
        }
        Spacer(Modifier.height(6.dp))
        Txt(fmt(v), ts(18, 700, WhiteText, tabular = true))
    }

    Box(
        Modifier.fillMaxWidth()
            .shadow(14.dp, shape, ambientColor = c.emShadow, spotColor = c.emShadow)
            .clip(shape).background(c.emBg, shape).border(1.dp, c.emBorder, shape),
    ) {
        DotGrid(c.emDot, 14f, 1.3f, Modifier.matchParentSize(), fade = true)
        Box(Modifier.matchParentSize()) {
            BasicText("₹", Modifier.align(Alignment.BottomEnd).offset(14.dp, 62.dp), style = ts(220, 800, c.emMark, height = 1f), softWrap = false)
        }
        Column(Modifier.padding(start = 22.dp, top = 20.dp, end = 22.dp, bottom = 22.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Txt("Net this month", ts(13, 600, c.emSub), Modifier.weight(1f))
                Row(
                    Modifier.border(BorderStroke(1.dp, c.emLineStrong), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Ico(Icons.calendar, 13.dp, c.emChip, 2.5f)
                    Spacer(Modifier.width(6.dp))
                    Txt(monthLabel(month), ts(12, 700, c.emChip))
                }
            }
            Spacer(Modifier.height(22.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                BasicText(
                    "${if (net < 0) "−" else ""}${fmt(net)}",
                    Modifier.weight(1f, fill = false),
                    style = ts(42, 800, WhiteText, ls = -0.035f, height = 1f, tabular = true),
                    maxLines = 1,
                    autoSize = TextAutoSize.StepBased(minFontSize = 18.sp, maxFontSize = 42.sp),
                )
                Spacer(Modifier.width(12.dp))
                val (bg, fg, icon) = when {
                    net > 0 -> Triple(c.emUp, c.emOnChip, Icons.trendUp)
                    net < 0 -> Triple(c.emDown, c.emOnChip, Icons.trendDown)
                    else -> Triple(c.emFlat, c.emText, Icons.flat)
                }
                Box(Modifier.size(34.dp).background(bg, CircleShape), contentAlignment = Alignment.Center) { Ico(icon, 18.dp, fg, 2.5f) }
            }
            Spacer(Modifier.height(22.dp))
            Row(
                Modifier.fillMaxWidth().height(IntrinsicSize.Min)
                    .drawBehind { drawRect(c.emLine, size = androidx.compose.ui.geometry.Size(size.width, 1.dp.toPx())) }
                    .padding(top = 16.dp),
            ) {
                figure("Received", Icons.arrowIn, c.emUp, got, Modifier.weight(1f))
                Spacer(Modifier.width(16.dp))
                Box(Modifier.width(1.dp).fillMaxHeight().background(c.emLine))
                Spacer(Modifier.width(16.dp))
                figure("Paid", Icons.arrowOut, c.emDown, gave, Modifier.weight(1f))
            }
        }
    }
}
