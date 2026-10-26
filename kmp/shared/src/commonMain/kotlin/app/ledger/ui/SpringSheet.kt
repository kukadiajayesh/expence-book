package app.ledger.ui

import androidx.compose.animation.core.animate
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** Spring feel from the design's Tweaks panel: 0.42 s response, 0.86 damping. */
const val SPRING_RESPONSE = 0.42f
const val SPRING_DAMPING = 0.86f

/**
 * Drives one sheet's vertical offset (0 = fully open, [closed] = off screen), in dp, with a damped
 * spring. Any animation can be grabbed and redirected.
 */
@Stable
class SheetController(private val scope: CoroutineScope, val maxOpacity: Float, private val onClosed: () -> Unit = {}) {
    var y by mutableFloatStateOf(10000f); private set
    var closed by mutableFloatStateOf(10000f); private set
    var detents by mutableStateOf(listOf(0f)); private set
    var reduceMotion = false

    private var job: Job? = null

    val isOpen get() = y < closed - 0.5f
    val isAnimating get() = job?.isActive == true
    val progress get() = ((closed - y) / closed).coerceIn(0f, 1f)

    /** Called with the current screen geometry. */
    fun setGeometry(detents: List<Float>, closed: Float) {
        this.detents = detents
        val wasClosed = !isOpen && !isAnimating
        this.closed = closed
        if (wasClosed) y = closed
    }

    fun animateTo(target: Float, velocity: Float = 0f) {
        job?.cancel()
        val resp = if (reduceMotion) 0.25f else SPRING_RESPONSE
        val zeta = if (reduceMotion) 1f else SPRING_DAMPING
        val stiffness = (2 * PI.toFloat() / resp).pow(2)
        job = scope.launch {
            animate(y, target, velocity, spring(zeta, stiffness, visibilityThreshold = 0.5f)) { v, _ -> y = v }
            y = target
            if (target == closed) onClosed()
        }
    }

    fun open(detent: Int = 0) = animateTo(detents[detent])
    fun close() = animateTo(closed)

    /** Take hold of the sheet, e.g. at the start of a drag. */
    fun grab() {
        job?.cancel()
    }

    /** Move by [delta] dp, with rubber-band resistance above the top detent. */
    fun dragBy(delta: Float) {
        job?.cancel()
        val top = detents.first()
        val raw = y + delta
        y = if (raw < top || y < top) (if (delta > 0) y + delta else y + delta * 0.35f).coerceAtMost(closed) else raw
    }

    val stops get() = detents + closed
    fun nearest(v: Float) = stops.reduce { a, b -> if (abs(b - v) < abs(a - v)) b else a }

    /** Let go with [velocity] (dp/s): carry on to the nearest stop. */
    fun settle(velocity: Float) {
        val projected = y + velocity * 0.998f / (1 - 0.998f) / 1000f
        animateTo(nearest(projected), velocity)
    }
}

/** Lets a scrollable inside a sheet scroll first and hand off to dragging the sheet at the top edge. */
@Composable
fun Modifier.sheetNestedScroll(controller: SheetController): Modifier {
    val density = LocalDensity.current.density
    val connection = remember(controller, density) {
        object : NestedScrollConnection {
            val top get() = controller.detents.first()

            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                // Dragging up while the sheet is below its top: raise the sheet before scrolling.
                if (available.y < 0 && controller.y > top + 0.5f) {
                    val move = max(available.y / density, top - controller.y)
                    controller.dragBy(move)
                    return Offset(0f, move * density)
                }
                return Offset.Zero
            }

            override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
                // Content is at its top and the finger keeps moving down: pull the sheet down.
                if (available.y > 0 && source == NestedScrollSource.UserInput) {
                    controller.dragBy(available.y / density)
                    return Offset(0f, available.y)
                }
                return Offset.Zero
            }

            override suspend fun onPreFling(available: Velocity): Velocity {
                if (controller.y > top + 0.5f) {
                    controller.settle(available.y / density)
                    return available
                }
                return Velocity.Zero
            }
        }
    }
    return nestedScroll(connection)
}

/** Makes the whole sheet a vertical drag handle for [controller]. */
@Composable
fun Modifier.sheetDrag(controller: SheetController): Modifier {
    val density = LocalDensity.current.density
    val state = rememberDraggableState { controller.dragBy(it / density) }
    return draggable(
        state,
        Orientation.Vertical,
        onDragStarted = { controller.grab() },
        onDragStopped = { controller.settle(it / density) },
    )
}

/** Backdrop + sheet pair. The sheet slides by the controller's offset and is removed when fully closed. */
@Composable
fun SheetLayer(
    controller: SheetController,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
    left: Dp = 0.dp,
    right: Dp = 0.dp,
    bottom: Dp = 0.dp,
    height: Dp? = null,
    sheet: @Composable () -> Unit,
) {
    val density = LocalDensity.current.density
    if (!controller.isOpen) return
    Box(modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize()
                .background(LedgerColors.backdrop.copy(alpha = controller.maxOpacity * controller.progress))
                .pointerInput(Unit) { detectTapGestures { onDismiss() } },
        )
        Box(
            Modifier.align(Alignment.BottomCenter)
                .padding(start = left, end = right, bottom = bottom)
                .fillMaxWidth()
                .then(if (height != null) Modifier.height(height) else Modifier.wrapContentHeight())
                .offset { IntOffset(0, (controller.y * density).roundToInt()) },
        ) { sheet() }
    }
}

/** The 36×5 grabber pill at the top of a sheet. */
@Composable
fun Grabber(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().padding(top = 6.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(36.dp, 5.dp).background(colors.lineStrong, RoundedCornerShape(50)))
    }
}
