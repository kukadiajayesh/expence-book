package app.ledger.platform

/** Where the Odoo API key lives: the Android Keystore or the iOS Keychain. */
interface SecretStore {
    fun read(key: String): String?
    fun write(key: String, value: String)
    fun delete(key: String)
}

/** The platform's secure store. */
expect fun createSecretStore(): SecretStore
