package app.ledger.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.ledger.data.OdooConfig
import app.ledger.data.OdooException
import app.ledger.data.OpKind
import app.ledger.data.PaymentGateway
import app.ledger.data.PendingOp
import app.ledger.data.SyncQueue
import app.ledger.model.Txn
import app.ledger.model.isoDate
import app.ledger.model.sampleTxns
import app.ledger.model.today
import app.ledger.platform.SecretStore
import com.russhwolf.settings.Settings
import kotlin.time.Clock
import kotlin.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.datetime.LocalDate
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

val followOptions = listOf("3 days", "1 week", "2 weeks", "1 month", "Never")

typealias GatewayFactory = (OdooConfig) -> PaymentGateway

enum class SyncStatus {
    /** Not connected to Odoo; everything stays on this device. */
    Local,
    Idle,
    Syncing,
    Offline,

    /** Odoo refused the API key. */
    AuthFailed,
}

/**
 * App data and preferences. Records are cached on the device. When connected to Odoo,
 * changes are queued and sent in the background, and the list is refreshed from Odoo after
 * each sync.
 */
class LedgerStore(
    private val settings: Settings,
    private val secrets: SecretStore,
    private val gatewayFor: GatewayFactory,
    private val scope: CoroutineScope,
    demo: Boolean = false,
    private val syncDelayMillis: Long = 5_000,
) {
    var records by mutableStateOf(emptyList<Txn>()); private set
    var loggedIn by mutableStateOf(false); private set
    var config by mutableStateOf<OdooConfig?>(null); private set
    var dark by mutableStateOf(false); private set
    var palette by mutableStateOf("terracotta"); private set
    var follow by mutableStateOf("1 week"); private set
    var daily by mutableStateOf(true); private set
    var unsettled by mutableStateOf(true); private set
    var faceId by mutableStateOf(false); private set
    var status by mutableStateOf(SyncStatus.Local); private set
    var lastSync by mutableStateOf<Instant?>(null); private set
    var syncError by mutableStateOf<String?>(null); private set
    var pendingCount by mutableStateOf(0); private set
    var failedCount by mutableStateOf(0); private set

    val connected get() = config != null

    /** Why a launch-time connection (see `DevConnection`) failed, shown on the Connect screen. */
    var devError by mutableStateOf<String?>(null)

    private val json = Json { ignoreUnknownKeys = true }
    private var queue = SyncQueue()
    private var gateway: PaymentGateway? = null
    private var nextLocalId = -1
    private var syncJob: Job? = null
    private var running: Deferred<Unit>? = null
    private var syncAgain = false

    init {
        val raw = settings.getStringOrNull("records")
        if (raw != null) {
            records = json.decodeFromString(ListSerializer(Txn.serializer()), raw)
        } else if (demo) {
            records = sampleTxns(today())
        }
        settings.getStringOrNull("pending")?.let {
            queue = SyncQueue(json.decodeFromString(ListSerializer(PendingOp.serializer()), it))
        }
        loggedIn = settings.getBoolean("loggedIn", false)
        dark = settings.getBoolean("dark", false)
        palette = settings.getString("palette", "terracotta")
        follow = settings.getString("follow", "1 week")
        daily = settings.getBoolean("daily", true)
        unsettled = settings.getBoolean("unsettled", true)
        faceId = settings.getBoolean("faceId", false)
        nextLocalId = minOf(0, records.minOfOrNull { it.id } ?: 0) - 1

        val url = settings.getStringOrNull("serverUrl")
        val db = settings.getStringOrNull("db")
        if (url != null && db != null) {
            val key = try {
                secrets.read("apiKey")
            } catch (_: Exception) {
                null // keystore unavailable: ask to connect again
            }
            if (key != null && loggedIn) {
                config = OdooConfig(url, db, key)
                gateway = gatewayFor(config!!)
                status = SyncStatus.Idle
            } else {
                loggedIn = false
            }
        }
        refreshCounts()
    }

    /** Newest first; ties broken by newest id. */
    val sorted: List<Txn> get() = records.sortedWith(compareByDescending<Txn> { it.date }.thenByDescending { it.id })

    /** All records as CSV text, newest first. */
    fun toCsv(): String {
        fun q(v: String) = if (v.any { it == '"' || it == ',' || it == '\n' }) "\"${v.replace("\"", "\"\"")}\"" else v
        return (listOf("Date,Type,Person,Amount,Note") + sorted.map {
            listOf(isoDate(it.date), if (it.isGot) "Received" else "Paid", q(it.person), amountText(it.amount), q(it.note)).joinToString(",")
        }).joinToString("\n")
    }

    private fun amountText(a: Double): String {
        val cents = kotlin.math.round(a * 100).toLong()
        return "${cents / 100}.${(cents % 100).toString().padStart(2, '0')}"
    }

    fun upsert(id: Int? = null, type: String, amount: Double, person: String, date: LocalDate, note: String) {
        val rec = Txn(id ?: nextLocalId--, type, amount, person, date, note)
        records = if (id == null) listOf(rec) + records else records.map { if (it.id == id) rec else it }
        if (connected) queue.upsert(rec)
        changed()
    }

    /** Deletes a record and returns a callback that restores it. */
    fun delete(id: Int): () -> Unit {
        val removed = records.filter { it.id == id }
        records = records.filter { it.id != id }
        val token = if (connected) queue.delete(id) else null
        changed()
        return {
            if (token == null || queue.undoDelete(token)) {
                records = records + removed
            } else {
                // Odoo already deleted it, so it comes back as a new record.
                for (r in removed) {
                    val again = r.withId(nextLocalId--)
                    records = records + again
                    queue.upsert(again)
                }
            }
            changed()
        }
    }

    private fun changed() {
        save()
        if (connected) {
            syncJob?.cancel()
            syncJob = scope.launch {
                delay(syncDelayMillis)
                sync()
            }
        }
    }

    private fun refreshCounts() {
        pendingCount = queue.size
        failedCount = queue.ops.count { it.error != null }
    }

    private fun save() {
        settings.putString("records", json.encodeToString(ListSerializer(Txn.serializer()), records))
        settings.putString("pending", json.encodeToString(ListSerializer(PendingOp.serializer()), queue.ops))
        refreshCounts()
    }

    // ---- Odoo connection ----

    /**
     * Checks the URL, database and key against Odoo, then starts syncing. Anything already on
     * this device is uploaded. Throws [OdooException].
     */
    suspend fun connect(url: String, db: String, apiKey: String) {
        val c = OdooConfig(OdooConfig.normaliseUrl(url), db.trim(), apiKey.trim())
        val g = gatewayFor(c)
        g.check()

        secrets.write("apiKey", c.apiKey)
        settings.putString("serverUrl", c.baseUrl)
        settings.putString("db", c.db)
        config = c
        gateway = g
        // Records made before connecting are new to Odoo.
        val local = records
        records = emptyList()
        queue = SyncQueue()
        for (r in local.asReversed()) {
            val rec = r.withId(nextLocalId--)
            records = listOf(rec) + records
            queue.upsert(rec)
        }
        loggedIn = true
        status = SyncStatus.Idle
        syncError = null
        settings.putBoolean("loggedIn", true)
        save()
        scope.launch { sync() }
    }

    /** Use the app without Odoo; data stays on this device. */
    fun useLocally() {
        loggedIn = true
        settings.putBoolean("loggedIn", true)
    }

    fun logout() {
        syncJob?.cancel()
        loggedIn = false
        settings.putBoolean("loggedIn", false)
        if (connected) {
            // The cache belongs to that Odoo account.
            config = null
            gateway = null
            records = emptyList()
            queue = SyncQueue()
            status = SyncStatus.Local
            lastSync = null
            syncError = null
            settings.remove("serverUrl")
            settings.remove("db")
            save()
            try {
                secrets.delete("apiKey")
            } catch (_: Exception) {
            }
        }
    }

    // ---- Sync ----

    /**
     * Sends queued changes, then refreshes the list from Odoo. Safe to call at any time: a call
     * during a sync waits for it (and asks for one more pass), and nothing happens when not connected.
     */
    suspend fun sync() {
        if (gateway == null) return
        running?.let {
            syncAgain = true // changes arrived mid-sync; go round once more
            it.await()
            return
        }
        syncJob?.cancel()
        val job = scope.async(start = CoroutineStart.LAZY) {
            try {
                syncLoop()
            } finally {
                running = null
            }
        }
        running = job
        job.await()
    }

    private suspend fun syncLoop() {
        do {
            syncAgain = false
            val g = gateway ?: return
            syncOnce(g)
        } while (syncAgain && gateway != null && status != SyncStatus.Offline && status != SyncStatus.AuthFailed)
    }

    private suspend fun syncOnce(g: PaymentGateway) {
        status = SyncStatus.Syncing
        try {
            flush(g)
            pull(g)
            status = SyncStatus.Idle
            lastSync = Clock.System.now()
            syncError = if (failedCount == 0) null else "Some changes could not be saved in Odoo."
        } catch (e: OdooException) {
            status = if (e.isAuth) SyncStatus.AuthFailed else if (e.network) SyncStatus.Offline else SyncStatus.Idle
            syncError = e.message
        } finally {
            save()
        }
    }

    private suspend fun flush(g: PaymentGateway) {
        for (op in queue.ops.toList()) {
            if (gateway !== g) return // logged out meanwhile
            if (op !in queue.ops) continue // removed while we were away
            try {
                when (op.kind) {
                    OpKind.Create -> {
                        op.inFlight = true
                        val newId = g.create(op.txn!!)
                        if (gateway !== g) return
                        records = records.map { if (it.id == op.id) it.withId(newId) else it }
                        queue.remapId(op.id, newId)
                        queue.remove(op)
                    }
                    OpKind.Update -> {
                        op.inFlight = true
                        g.update(op.txn!!)
                        queue.remove(op)
                    }
                    OpKind.Delete ->
                        if (op.id < 0) {
                            // Its create never succeeded, so Odoo has nothing to delete.
                            queue.ops.removeAll { it.id == op.id }
                        } else {
                            op.inFlight = true
                            g.delete(op.id)
                            queue.remove(op)
                        }
                }
                save()
            } catch (e: OdooException) {
                if (e.network || e.isAuth) throw e
                op.error = e.message // keep it; the user sees a count and can retry
            } finally {
                op.inFlight = false
            }
        }
    }

    private suspend fun pull(g: PaymentGateway) {
        val remote = g.fetchAll()
        if (gateway !== g) return
        // Computed after the request, so edits made meanwhile are kept.
        val deleting = queue.idsWith(OpKind.Delete)
        val editing = queue.idsWith(OpKind.Update)
        val mine = records.associateBy { it.id }
        records = remote.filter { it.id !in deleting }.map { if (it.id in editing) mine[it.id] ?: it else it } +
            records.filter { it.id < 0 } // added here, not in Odoo yet
    }

    // ---- Preferences ----

    fun updateDark(v: Boolean) {
        dark = v
        settings.putBoolean("dark", v)
    }

    fun updatePalette(v: String) {
        palette = v
        settings.putString("palette", v)
    }

    fun updateFollow(v: String) {
        follow = v
        settings.putString("follow", v)
    }

    fun setSwitch(key: String, v: Boolean) {
        when (key) {
            "daily" -> daily = v
            "unsettled" -> unsettled = v
            "faceId" -> faceId = v
        }
        settings.putBoolean(key, v)
    }
}
