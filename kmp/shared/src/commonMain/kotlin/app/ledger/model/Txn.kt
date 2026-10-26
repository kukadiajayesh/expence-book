package app.ledger.model

import kotlinx.datetime.LocalDate
import kotlinx.serialization.Serializable

/** A person-to-person transaction: money you paid someone ('gave') or received from them ('got'). */
@Serializable
data class Txn(
    val id: Int,
    val type: String, // "got" | "gave"
    val amount: Double,
    val person: String,
    val date: LocalDate,
    val note: String = "",
) {
    val isGot get() = type == "got"
    val signed get() = if (isGot) amount else -amount

    fun withId(id: Int) = copy(id = id)
}
