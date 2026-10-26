package app.ledger.data

import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/** Where and how to reach an Odoo 19 server. */
data class OdooConfig(val baseUrl: String, val db: String, val apiKey: String) {
    val host: String get() = baseUrl.substringAfter("://").substringBefore('/').substringBefore(':')

    companion object {
        /** Adds `https://` when no scheme is given and drops trailing slashes. */
        fun normaliseUrl(raw: String): String {
            var u = raw.trim()
            if (u.isEmpty()) return u
            if (!Regex("^[a-zA-Z][a-zA-Z0-9+.-]*://").containsMatchIn(u)) u = "https://$u"
            return u.trimEnd('/')
        }
    }
}

/** A failed call: the server said no, or it could not be reached. */
class OdooException(message: String, val status: Int? = null, val network: Boolean = false) : Exception(message) {
    val isAuth get() = status == 401 || status == 403
}

/**
 * Calls Odoo's JSON-2 external API: `POST /json/2/<model>/<method>` with a bearer API key.
 * Arguments go in the JSON body by name; `ids` selects the records a method runs on.
 */
class OdooClient(
    val config: OdooConfig,
    private val http: HttpClient = HttpClient(),
    timeoutMillis: Long = 20_000,
) {
    private val client = http.config { install(HttpTimeout) { requestTimeoutMillis = timeoutMillis } }
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun call(model: String, method: String, ids: List<Int>? = null, args: JsonObject = JsonObject(emptyMap())): JsonElement {
        val body = JsonObject(buildMap {
            if (ids != null) put("ids", JsonArray(ids.map { JsonPrimitive(it) }))
            putAll(args)
        })
        val status: Int
        val text: String
        try {
            val res = client.post("${config.baseUrl}/json/2/$model/$method") {
                contentType(ContentType.Application.Json)
                header("Authorization", "bearer ${config.apiKey}")
                if (config.db.isNotEmpty()) header("X-Odoo-Database", config.db)
                setBody(body.toString())
            }
            status = res.status.value
            text = res.bodyAsText()
        } catch (e: CancellationException) {
            throw e
        } catch (e: IllegalArgumentException) {
            throw OdooException("The server address is not valid.")
        } catch (e: Throwable) {
            // Offline, DNS, TLS, timeout: all mean "no answer", so retrying later may work.
            throw OdooException("Could not reach the server: ${e.message ?: e::class.simpleName}", network = true)
        }

        if (status in 200..299) {
            val notJson = OdooException("The server sent something that is not Odoo JSON. Check the address.", status = status)
            if (text.isBlank()) return JsonNull
            val value = try {
                json.parseToJsonElement(text)
            } catch (e: Exception) {
                throw notJson
            }
            // The parser lets bare words like <html> through as text; Odoo never sends those.
            if (value is JsonPrimitive && !value.isString && value !is JsonNull && value.content.let { it != "true" && it != "false" && it.toDoubleOrNull() == null }) throw notJson
            return value
        }
        throw OdooException(errorMessage(status, text), status = status)
    }

    private fun errorMessage(status: Int, body: String): String {
        try {
            val m = json.parseToJsonElement(body).jsonObject["message"]?.jsonPrimitive?.contentOrNull
            if (!m.isNullOrEmpty()) return m
        } catch (_: Exception) {
            // Not JSON; fall through to the generic text.
        }
        return when (status) {
            401 -> "The API key was rejected."
            403 -> "This API key is not allowed to do that."
            404 -> "Odoo was not found at that address, or it is not version 19 (no /json/2 API)."
            else -> "Odoo returned an error ($status)."
        }
    }

    fun close() = client.close()
}
