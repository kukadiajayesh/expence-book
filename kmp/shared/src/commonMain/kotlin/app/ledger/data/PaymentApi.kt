package app.ledger.data

import app.ledger.model.Txn
import app.ledger.model.isoDate
import kotlinx.datetime.LocalDate
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray

/** What the app needs from the server. [PaymentApi] is the Odoo version; tests use an in-memory one. */
interface PaymentGateway {
    /** Throws [OdooException] unless the address, database and key all work. */
    suspend fun check()

    /** Every payment, as transactions that carry their Odoo id. */
    suspend fun fetchAll(): List<Txn>

    /** Creates [t] on the server (ignoring `t.id`) and returns the new Odoo id. */
    suspend fun create(t: Txn): Int

    suspend fun update(t: Txn)

    suspend fun delete(id: Int)
}

/**
 * Maps a [Txn] to an `account.payment` record:
 *
 * | Txn      | account.payment                                          |
 * | received | `payment_type = inbound`, `partner_type = customer`      |
 * | paid     | `payment_type = outbound`, `partner_type = customer`     |
 * | person   | `partner_id` (a `res.partner`, found or created by name) |
 * | amount   | `amount`                                                 |
 * | date     | `date`                                                   |
 * | note     | `memo`                                                   |
 *
 * Payments are left in draft, so they stay editable and deletable from the app.
 */
class PaymentApi(private val odoo: OdooClient) : PaymentGateway {
    private val partnerIds = mutableMapOf<String, Int>()

    override suspend fun check() {
        odoo.call("res.partner", "search_count", args = buildJsonObject { putJsonArray("domain") {} })
        odoo.call(MODEL, "search_count", args = buildJsonObject { putJsonArray("domain") {} })
    }

    override suspend fun fetchAll(): List<Txn> {
        val rows = odoo.call(MODEL, "search_read", args = buildJsonObject {
            putJsonArray("domain") {
                add(buildDomainTerm("partner_id", "!=", JsonPrimitive(false)))
                add(buildDomainTerm("state", "!=", JsonPrimitive("canceled")))
            }
            putJsonArray("fields") { FIELDS.forEach { add(JsonPrimitive(it)) } }
            put("order", "date desc, id desc")
        })
        if (rows !is JsonArray) throw OdooException("Unexpected answer from Odoo when listing payments.")
        return rows.map { fromRecord(it.jsonObject) }
    }

    override suspend fun create(t: Txn): Int {
        val vals = values(t)
        val ids = odoo.call(MODEL, "create", args = buildJsonObject { putJsonArray("vals_list") { add(vals) } })
        if (ids !is JsonArray || ids.isEmpty()) throw OdooException("Odoo did not return the new payment.")
        return ids.first().jsonPrimitive.int
    }

    override suspend fun update(t: Txn) {
        odoo.call(MODEL, "write", ids = listOf(t.id), args = buildJsonObject { put("vals", values(t)) })
    }

    override suspend fun delete(id: Int) {
        odoo.call(MODEL, "unlink", ids = listOf(id))
    }

    private suspend fun values(t: Txn): JsonObject {
        val partner = partnerId(t.person)
        return buildJsonObject {
            put("payment_type", if (t.isGot) "inbound" else "outbound")
            put("partner_type", "customer")
            put("partner_id", partner)
            put("amount", t.amount)
            put("date", isoDate(t.date))
            put("memo", t.note)
        }
    }

    /** Finds the partner with this name (case-insensitive), or creates one. */
    private suspend fun partnerId(name: String): Int {
        val key = name.trim().lowercase()
        partnerIds[key]?.let { return it }
        val found = odoo.call("res.partner", "search", args = buildJsonObject {
            putJsonArray("domain") { add(buildDomainTerm("name", "=ilike", JsonPrimitive(name.trim()))) }
            put("limit", 1)
        })
        val id = if (found is JsonArray && found.isNotEmpty()) {
            found.first().jsonPrimitive.int
        } else {
            val created = odoo.call("res.partner", "create", args = buildJsonObject {
                putJsonArray("vals_list") { add(buildJsonObject { put("name", name.trim()) }) }
            })
            if (created !is JsonArray || created.isEmpty()) throw OdooException("Odoo did not return the new contact.")
            created.first().jsonPrimitive.int
        }
        partnerIds[key] = id
        return id
    }

    companion object {
        private const val MODEL = "account.payment"
        private val FIELDS = listOf("payment_type", "partner_id", "amount", "date", "memo")

        private fun buildDomainTerm(field: String, op: String, value: JsonElement) =
            JsonArray(listOf(JsonPrimitive(field), JsonPrimitive(op), value))

        /** One `search_read` row → a transaction. Odoo sends `false` for empty fields. */
        fun fromRecord(r: JsonObject): Txn {
            val partner = r["partner_id"]
            val memo = r["memo"]
            val name = (partner as? JsonArray)?.takeIf { it.size > 1 }?.get(1)?.jsonPrimitive?.contentOrNull ?: "Unknown"
            return Txn(
                id = r.getValue("id").jsonPrimitive.int,
                type = if (r["payment_type"]?.jsonPrimitive?.contentOrNull == "inbound") "got" else "gave",
                amount = r.getValue("amount").jsonPrimitive.double,
                person = name,
                date = LocalDate.parse(r.getValue("date").jsonPrimitive.content),
                note = (memo as? JsonPrimitive)?.takeIf { it.isString }?.content ?: "",
            )
        }
    }
}
