package app.ledger

import app.ledger.data.OdooClient
import app.ledger.data.OdooConfig
import app.ledger.data.OdooException
import app.ledger.data.OpKind
import app.ledger.data.PaymentApi
import app.ledger.data.PaymentGateway
import app.ledger.data.SyncQueue
import app.ledger.model.Txn
import app.ledger.model.fmt
import app.ledger.model.signedFmt
import app.ledger.platform.SecretStore
import app.ledger.store.LedgerStore
import app.ledger.store.SyncStatus
import com.russhwolf.settings.MapSettings
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

val cfg = OdooConfig("https://odoo.test", "prod", "k123")
val day = LocalDate(2026, 10, 23)

fun txn(id: Int, type: String = "gave", amount: Double = 100.0, person: String = "Ravi", note: String = "") = Txn(id, type, amount, person, day, note)

/** An in-memory server for store tests. */
class FakeGateway : PaymentGateway {
    val server = mutableMapOf<Int, Txn>()
    var next = 1000
    var offline = false
    var rejectCreate = false
    var authFail = false

    private fun gate() {
        if (authFail) throw OdooException("The API key was rejected.", status = 401)
        if (offline) throw OdooException("no network", network = true)
    }

    override suspend fun check() = gate()
    override suspend fun fetchAll(): List<Txn> { gate(); return server.values.toList() }
    override suspend fun create(t: Txn): Int {
        gate()
        if (rejectCreate) throw OdooException("Invalid field", status = 400)
        val id = next++
        server[id] = t.withId(id)
        return id
    }
    override suspend fun update(t: Txn) { gate(); server[t.id] = t }
    override suspend fun delete(id: Int) { gate(); server.remove(id) }
}

class MemorySecrets : SecretStore {
    val m = mutableMapOf<String, String>()
    override fun read(key: String) = m[key]
    override fun write(key: String, value: String) { m[key] = value }
    override fun delete(key: String) { m.remove(key) }
}

class OdooClientTest {
    private fun client(status: HttpStatusCode = HttpStatusCode.OK, body: String = "[7]", onRequest: (io.ktor.client.request.HttpRequestData) -> Unit = {}) =
        OdooClient(cfg, HttpClient(MockEngine { onRequest(it); respond(body, status, headersOf("Content-Type", "application/json")) }))

    @Test
    fun postsJson2RequestsWithBearerKeyAndDatabase() = runTest {
        var seen: io.ktor.client.request.HttpRequestData? = null
        var text = ""
        val c = OdooClient(cfg, HttpClient(MockEngine { seen = it; text = it.body.toByteArray().decodeToString(); respond("[7]", HttpStatusCode.OK) }))
        val out = c.call("account.payment", "write", ids = listOf(5), args = Json.parseToJsonElement("""{"vals":{"amount":3}}""").jsonObject)
        assertEquals(7, out.jsonArray.first().jsonPrimitive.int)
        assertEquals("https://odoo.test/json/2/account.payment/write", seen!!.url.toString())
        assertEquals("bearer k123", seen!!.headers["Authorization"])
        assertEquals("prod", seen!!.headers["X-Odoo-Database"])
        assertEquals(Json.parseToJsonElement("""{"ids":[5],"vals":{"amount":3}}"""), Json.parseToJsonElement(text))
    }

    @Test
    fun mapsHttpErrors() = runTest {
        val auth = assertFailsWith401 { client(HttpStatusCode.Unauthorized, "").call("res.partner", "search_count") }
        assertTrue(auth.isAuth)
        val msg = runCatching { client(HttpStatusCode.UnprocessableEntity, """{"message":"Invalid field amount"}""").call("x", "y") }.exceptionOrNull() as OdooException
        assertEquals("Invalid field amount", msg.message)
        val notJson = runCatching { client(HttpStatusCode.OK, "<html>").call("x", "y") }.exceptionOrNull() as OdooException
        assertFalse(notJson.network)
    }

    @Test
    fun unreachableServerIsANetworkError() = runTest {
        val down = OdooClient(cfg, HttpClient(MockEngine { throw RuntimeException("nope") }))
        val e = runCatching { down.call("x", "y") }.exceptionOrNull() as OdooException
        assertTrue(e.network)
    }

    @Test
    fun normalisesTheServerAddress() {
        assertEquals("https://odoo.example.com", OdooConfig.normaliseUrl("odoo.example.com/"))
        assertEquals("http://10.0.0.2:8069", OdooConfig.normaliseUrl(" http://10.0.0.2:8069// "))
        assertEquals("odoo.example.com", OdooConfig("https://odoo.example.com:8443/x", "d", "k").host)
    }

    private suspend fun assertFailsWith401(block: suspend () -> Unit): OdooException = runCatching { block() }.exceptionOrNull() as OdooException
}

class PaymentApiTest {
    @Test
    fun readsPaymentsIntoTransactions() {
        val t = PaymentApi.fromRecord(Json.parseToJsonElement("""{"id":9,"payment_type":"inbound","partner_id":[3,"Meera Iyer"],"amount":1500.0,"date":"2026-10-14","memo":false}""").jsonObject)
        assertEquals(9, t.id)
        assertTrue(t.isGot)
        assertEquals("Meera Iyer", t.person)
        assertEquals("", t.note)
        val cab = PaymentApi.fromRecord(Json.parseToJsonElement("""{"id":1,"payment_type":"outbound","partner_id":[3,"A"],"amount":5,"date":"2026-10-14","memo":"Cab"}""").jsonObject)
        assertEquals("Cab", cab.note)
        assertFalse(cab.isGot)
    }

    @Test
    fun creatingFindsOrCreatesThePartnerOnceAndSendsTheRightValues() = runTest {
        val paths = mutableListOf<String>()
        val bodies = mutableListOf<JsonObject>()
        val engine = MockEngine { req ->
            paths += req.url.encodedPath
            bodies += Json.parseToJsonElement(req.body.toByteArray().decodeToString()).jsonObject
            when (req.url.encodedPath) {
                "/json/2/res.partner/search" -> respond("[]", HttpStatusCode.OK)
                "/json/2/res.partner/create" -> respond("[42]", HttpStatusCode.OK)
                "/json/2/account.payment/create" -> respond("[900]", HttpStatusCode.OK)
                else -> respond("{}", HttpStatusCode.NotFound)
            }
        }
        val api = PaymentApi(OdooClient(cfg, HttpClient(engine)))
        assertEquals(900, api.create(txn(-1, "got", 1250.5, "Zoya", "Lunch")))
        api.create(txn(-2, person = "zoya"))
        assertEquals(1, paths.count { it == "/json/2/res.partner/create" }) // cached, case-insensitive
        val vals = bodies.first { it["vals_list"]?.jsonArray?.firstOrNull()?.jsonObject?.containsKey("amount") == true }["vals_list"]!!.jsonArray.first().jsonObject
        assertEquals(
            Json.parseToJsonElement("""{"payment_type":"inbound","partner_type":"customer","partner_id":42,"amount":1250.5,"date":"2026-10-23","memo":"Lunch"}"""),
            vals,
        )
    }
}

class SyncQueueTest {
    @Test
    fun editsToAnUnsentAddStayOneCreate() {
        val q = SyncQueue().apply { upsert(txn(-1)); upsert(txn(-1, amount = 250.0)) }
        assertEquals(1, q.size)
        assertEquals(OpKind.Create, q.ops.single().kind)
        assertEquals(250.0, q.ops.single().txn!!.amount)
    }

    @Test
    fun deletingAnUnsentAddForgetsItAndUndoBringsItBack() {
        val q = SyncQueue().apply { upsert(txn(-1)) }
        val token = q.delete(-1)
        assertTrue(q.isEmpty)
        assertTrue(q.undoDelete(token))
        assertEquals(OpKind.Create, q.ops.single().kind)
    }

    @Test
    fun anEditedSyncedRecordSendsOneUpdateThenADeleteReplacesIt() {
        val q = SyncQueue().apply { upsert(txn(7)); upsert(txn(7, amount = 1.0)) }
        assertEquals(listOf(OpKind.Update), q.ops.map { it.kind })
        val token = q.delete(7)
        assertEquals(listOf(OpKind.Delete), q.ops.map { it.kind })
        assertTrue(q.undoDelete(token))
        assertEquals(listOf(OpKind.Update), q.ops.map { it.kind })
    }

    @Test
    fun undoReportsFailureOnceTheDeleteWasSent() {
        val q = SyncQueue()
        val token = q.delete(7)
        q.remove(q.ops.single()) // sent
        assertFalse(q.undoDelete(token))
    }

    @Test
    fun aRequestInFlightIsNeverEdited() {
        val q = SyncQueue().apply { upsert(txn(-1)) }
        q.ops.single().inFlight = true
        q.upsert(txn(-1, amount = 9.0))
        assertEquals(2, q.size)
        q.remapId(-1, 55)
        assertEquals(listOf(55, 55), q.ops.map { it.id })
        assertEquals(55, q.ops.last().txn!!.id)
    }
}

class StoreTest {
    private fun TestScope.store(g: FakeGateway, settings: MapSettings = MapSettings(), secrets: MemorySecrets = MemorySecrets(), demo: Boolean = false) =
        LedgerStore(settings, secrets, { g }, backgroundScope as CoroutineScope, demo)

    private suspend fun TestScope.connected(g: FakeGateway = FakeGateway()): Pair<LedgerStore, FakeGateway> {
        val s = store(g)
        s.connect("odoo.test", "prod", "k")
        s.sync()
        return s to g
    }

    @Test
    fun connectingUploadsWhatWasAlreadyOnTheDevice() = runTest {
        val g = FakeGateway()
        val s = store(g, demo = true)
        assertEquals(12, s.records.size)
        s.connect("odoo.test", "prod", "k")
        s.sync()
        assertEquals(12, g.server.size)
        assertEquals(12, s.records.size)
        assertTrue(s.records.all { it.id >= 1000 })
        assertEquals(0, s.pendingCount)
        assertEquals(SyncStatus.Idle, s.status)
    }

    @Test
    fun addEditAndDeleteReachTheServer() = runTest {
        val (s, g) = connected()
        s.upsert(null, "gave", 320.0, "Ankit", day, "Lunch")
        assertEquals(1, s.pendingCount)
        s.sync()
        val id = s.records.single().id
        assertEquals(320.0, g.server[id]!!.amount)
        s.upsert(id, "gave", 350.0, "Ankit", day, "Lunch")
        s.sync()
        assertEquals(350.0, g.server[id]!!.amount)
        s.delete(id)
        s.sync()
        assertTrue(g.server.isEmpty())
        assertTrue(s.records.isEmpty())
    }

    @Test
    fun offlineChangesWaitAndGoOutOnceTheNetworkIsBack() = runTest {
        val (s, g) = connected()
        g.offline = true
        s.upsert(null, "got", 500.0, "Priya", day, "")
        s.sync()
        assertEquals(SyncStatus.Offline, s.status)
        assertEquals(1, s.pendingCount)
        assertEquals(1, s.records.size) // still visible
        g.offline = false
        s.sync()
        assertEquals(SyncStatus.Idle, s.status)
        assertEquals(0, s.pendingCount)
        assertEquals("Priya", g.server.values.single().person)
    }

    @Test
    fun thePendingQueueSurvivesARestart() = runTest {
        val g = FakeGateway()
        val settings = MapSettings()
        val secrets = MemorySecrets()
        val s = store(g, settings, secrets)
        s.connect("odoo.test", "prod", "k")
        s.sync()
        g.offline = true
        s.upsert(null, "got", 500.0, "Priya", day, "")
        val again = store(g, settings, secrets)
        assertTrue(again.connected)
        assertEquals(1, again.pendingCount)
        g.offline = false
        again.sync()
        assertEquals(1, g.server.size)
    }

    @Test
    fun undoBeforeTheDeleteIsSentLeavesTheServerUntouched() = runTest {
        val (s, g) = connected()
        s.upsert(null, "gave", 1.0, "A", day, "")
        s.sync()
        val id = s.records.single().id
        val undo = s.delete(id)
        undo()
        s.sync()
        assertEquals(1, g.server.size)
        assertEquals(id, s.records.single().id)
    }

    @Test
    fun undoAfterTheDeleteWasSentRecreatesTheRecord() = runTest {
        val (s, g) = connected()
        s.upsert(null, "gave", 1.0, "A", day, "")
        s.sync()
        val undo = s.delete(s.records.single().id)
        s.sync()
        assertTrue(g.server.isEmpty())
        undo()
        s.sync()
        assertEquals(1, g.server.size)
        assertEquals(1, s.records.size)
    }

    @Test
    fun aChangeOdooRejectsStaysQueuedAndIsCountedWithoutBlockingTheRest() = runTest {
        val (s, g) = connected()
        g.rejectCreate = true
        s.upsert(null, "gave", 1.0, "A", day, "")
        s.sync()
        assertEquals(1, s.failedCount)
        assertEquals(SyncStatus.Idle, s.status)
        assertEquals(1, s.records.size)
        g.rejectCreate = false
        s.sync()
        assertEquals(0, s.failedCount)
        assertEquals(1, g.server.size)
    }

    @Test
    fun serverChangesAppearButLocalUnsentEditsWin() = runTest {
        val (s, g) = connected()
        g.server[1] = txn(1, person = "Remote", amount = 10.0)
        g.server[2] = txn(2, person = "Edited", amount = 20.0)
        s.sync()
        assertEquals(setOf(1, 2), s.records.map { it.id }.toSet())
        g.offline = true
        s.upsert(2, "gave", 99.0, "Edited", day, "")
        s.sync() // offline: stays queued
        g.offline = false
        g.server.remove(1) // deleted in Odoo
        s.sync()
        assertEquals(listOf(2), s.records.map { it.id })
        assertEquals(99.0, g.server[2]!!.amount)
    }

    @Test
    fun aBadKeyIsReportedAndKeepsTheData() = runTest {
        val g = FakeGateway()
        val settings = MapSettings()
        val secrets = MemorySecrets()
        val s = store(g, settings, secrets)
        s.connect("odoo.test", "prod", "k")
        s.sync()
        s.upsert(null, "gave", 1.0, "A", day, "")
        g.authFail = true
        s.sync()
        assertEquals(SyncStatus.AuthFailed, s.status)
        assertEquals(1, s.pendingCount)
        assertEquals(1, s.records.size)
    }

    @Test
    fun loggingOutClearsTheCacheAndTheKey() = runTest {
        val secrets = MemorySecrets()
        val s = store(FakeGateway(), secrets = secrets)
        s.connect("odoo.test", "prod", "k")
        s.upsert(null, "gave", 1.0, "A", day, "")
        s.logout()
        assertFalse(s.loggedIn)
        assertFalse(s.connected)
        assertTrue(s.records.isEmpty())
        assertTrue(secrets.m.isEmpty())
    }

    @Test
    fun csvQuotesCommasAndQuotes() = runTest {
        val s = store(FakeGateway())
        s.upsert(null, "gave", 12.5, "A, B", day, "say \"hi\"")
        assertEquals("Date,Type,Person,Amount,Note\n2026-10-23,Paid,\"A, B\",12.50,\"say \"\"hi\"\"\"", s.toCsv())
    }
}

class FormatTest {
    @Test
    fun indianDigitGrouping() {
        assertEquals("₹0", fmt(0.0))
        assertEquals("₹450", fmt(450.0))
        assertEquals("₹4,200", fmt(4200.0))
        assertEquals("₹1,00,000", fmt(100000.0))
        assertEquals("₹1,23,45,678", fmt(12345678.0))
        assertEquals("₹1,250.50", fmt(1250.5))
        assertEquals("₹320", fmt(-320.0))
    }

    @Test
    fun signedAmountsUseATrueMinusSign() {
        assertEquals("+₹1,880", signedFmt(1880.0))
        assertEquals("−₹450", signedFmt(-450.0))
    }
}
