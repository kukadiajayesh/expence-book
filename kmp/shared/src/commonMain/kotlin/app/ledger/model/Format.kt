package app.ledger.model

import kotlin.math.abs
import kotlin.math.roundToLong
import kotlin.time.Clock
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.todayIn

private val months = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
private val days = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

fun today(): LocalDate = Clock.System.todayIn(TimeZone.currentSystemDefault())

fun isoDate(d: LocalDate) = d.toString()

/** "Oct 2026" */
fun monthLabel(d: LocalDate) = "${months[d.month.ordinal]} ${d.year}"

/** "Oct 23, 2026" */
fun dateLabel(d: LocalDate) = "${months[d.month.ordinal]} ${d.day}, ${d.year}"

/** "Today", "Yesterday" or "Thu, Oct 22". */
fun dayLabel(d: LocalDate, today: LocalDate): String {
    val diff = today.toEpochDays() - d.toEpochDays()
    if (diff == 0L) return "Today"
    if (diff == 1L) return "Yesterday"
    return "${days[d.dayOfWeek.ordinal]}, ${months[d.month.ordinal]} ${d.day}"
}

/** Rupees with Indian digit grouping: ₹1,00,000 or ₹1,250.50. */
fun fmt(n: Double): String {
    val cents = (abs(n) * 100).roundToLong()
    val whole = cents / 100
    val frac = (cents % 100).toInt()
    val s = whole.toString()
    val grouped = if (s.length <= 3) {
        s
    } else {
        val head = s.substring(0, s.length - 3)
        val tail = s.substring(s.length - 3)
        val parts = ArrayDeque<String>()
        var i = head.length
        while (i > 0) {
            parts.addFirst(head.substring(maxOf(i - 2, 0), i))
            i -= 2
        }
        "${parts.joinToString(",")},$tail"
    }
    return "₹$grouped${if (frac == 0) "" else "." + frac.toString().padStart(2, '0')}"
}

/** "+₹1,200" / "−₹450" */
fun signedFmt(n: Double) = "${if (n < 0) "−" else "+"}${fmt(n)}"

fun initials(name: String) = name.split(Regex("\\s+")).filter { it.isNotEmpty() }.take(2).joinToString("") { it.take(1).uppercase() }

/** Sample data from the design, shifted so the latest entry is today. */
fun sampleTxns(today: LocalDate): List<Txn> {
    val anchor = LocalDate(2026, 10, 23)
    val rows = listOf(
        Row(1, "got", 5000.0, "Ravi Kumar", "2026-10-01", "Rent share"),
        Row(2, "gave", 4000.0, "Suresh Patil", "2026-10-02", "October salary"),
        Row(3, "gave", 1200.0, "Ankit Verma", "2026-10-05", "Movie tickets"),
        Row(4, "got", 800.0, "Priya Sharma", "2026-10-08", "Dinner split"),
        Row(5, "gave", 3000.0, "Ravi Kumar", "2026-10-12", "Short-term loan"),
        Row(6, "got", 1500.0, "Meera Iyer", "2026-10-14", "Concert tickets"),
        Row(7, "gave", 450.0, "Meera Iyer", "2026-10-17", "Cab fare"),
        Row(8, "got", 1200.0, "Ankit Verma", "2026-10-19", "Paid back"),
        Row(9, "gave", 650.0, "Priya Sharma", "2026-10-22", "Groceries"),
        Row(10, "got", 3000.0, "Ravi Kumar", "2026-10-22", "Loan returned"),
        Row(11, "gave", 320.0, "Ankit Verma", "2026-10-23", "Lunch"),
        Row(12, "got", 5000.0, "Ravi Kumar", "2026-09-01", "Rent share"),
    )
    return rows.map {
        val back = anchor.toEpochDays() - LocalDate.parse(it.date).toEpochDays()
        Txn(it.id, it.type, it.amount, it.person, LocalDate.fromEpochDays(today.toEpochDays() - back), it.note)
    }
}

private class Row(val id: Int, val type: String, val amount: Double, val person: String, val date: String, val note: String)
