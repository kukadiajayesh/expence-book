@file:OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)

package app.ledger.platform

import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.alloc
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.value
import platform.CoreFoundation.CFDictionaryAddValue
import platform.CoreFoundation.CFDictionaryCreateMutable
import platform.CoreFoundation.CFRelease
import platform.CoreFoundation.CFTypeRefVar
import platform.CoreFoundation.kCFBooleanTrue
import platform.CoreFoundation.kCFTypeDictionaryKeyCallBacks
import platform.CoreFoundation.kCFTypeDictionaryValueCallBacks
import platform.Foundation.CFBridgingRelease
import platform.Foundation.CFBridgingRetain
import platform.Foundation.NSData
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.create
import platform.Foundation.dataUsingEncoding
import platform.Security.SecItemAdd
import platform.Security.SecItemCopyMatching
import platform.Security.SecItemDelete
import platform.Security.errSecSuccess
import platform.Security.kSecAttrAccessible
import platform.Security.kSecAttrAccessibleAfterFirstUnlock
import platform.Security.kSecAttrAccount
import platform.Security.kSecAttrService
import platform.Security.kSecClass
import platform.Security.kSecClassGenericPassword
import platform.Security.kSecMatchLimit
import platform.Security.kSecMatchLimitOne
import platform.Security.kSecReturnData
import platform.Security.kSecValueData

actual fun createSecretStore(): SecretStore = KeychainSecrets()

/** Keeps secrets in the iOS Keychain, readable after the first unlock and never synced to iCloud. */
class KeychainSecrets : SecretStore {
    private fun <R> query(key: String, extra: (CFMutableDictionary) -> Unit = {}, block: (CFMutableDictionary) -> R): R {
        val dict = CFDictionaryCreateMutable(null, 0, kCFTypeDictionaryKeyCallBacks.ptr, kCFTypeDictionaryValueCallBacks.ptr)
        val service = CFBridgingRetain(NSString.create(string = SERVICE))
        val account = CFBridgingRetain(NSString.create(string = key))
        try {
            CFDictionaryAddValue(dict, kSecClass, kSecClassGenericPassword)
            CFDictionaryAddValue(dict, kSecAttrService, service)
            CFDictionaryAddValue(dict, kSecAttrAccount, account)
            extra(dict)
            return block(dict)
        } finally {
            CFRelease(service)
            CFRelease(account)
            CFRelease(dict)
        }
    }

    override fun read(key: String): String? = memScoped {
        query(key, extra = {
            CFDictionaryAddValue(it, kSecReturnData, kCFBooleanTrue)
            CFDictionaryAddValue(it, kSecMatchLimit, kSecMatchLimitOne)
        }) { dict ->
            val result = alloc<CFTypeRefVar>()
            if (SecItemCopyMatching(dict, result.ptr) != errSecSuccess) return@query null
            val data = CFBridgingRelease(result.value) as? NSData ?: return@query null
            NSString.create(data = data, encoding = NSUTF8StringEncoding)?.toString()
        }
    }

    override fun write(key: String, value: String) {
        delete(key)
        val data = CFBridgingRetain((NSString.create(string = value)).dataUsingEncoding(NSUTF8StringEncoding))
        try {
            query(key, extra = {
                CFDictionaryAddValue(it, kSecValueData, data)
                CFDictionaryAddValue(it, kSecAttrAccessible, kSecAttrAccessibleAfterFirstUnlock)
            }) { dict ->
                val status = SecItemAdd(dict, null)
                check(status == errSecSuccess) { "Keychain write failed ($status)" }
            }
        } finally {
            CFRelease(data)
        }
    }

    override fun delete(key: String) {
        query(key) { SecItemDelete(it) }
    }

    private companion object {
        const val SERVICE = "app.ledger.kmp"
    }
}

private typealias CFMutableDictionary = platform.CoreFoundation.CFMutableDictionaryRef?
