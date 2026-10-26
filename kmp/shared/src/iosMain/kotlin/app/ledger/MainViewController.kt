package app.ledger

import androidx.compose.ui.window.ComposeUIViewController
import app.ledger.ui.DevConnection
import app.ledger.ui.LedgerRoot
import platform.Foundation.NSProcessInfo

/**
 * The root view controller hosted by the iOS app. For development, launch with `LEDGER_DEMO=true` for
 * sample data, or with `LEDGER_ODOO_URL`, `LEDGER_ODOO_DB` and `LEDGER_ODOO_KEY` to connect on start-up.
 */
fun MainViewController() = ComposeUIViewController {
    val env = NSProcessInfo.processInfo.environment
    val dev = (env["LEDGER_ODOO_URL"] as? String)?.let { url ->
        DevConnection(url, env["LEDGER_ODOO_DB"] as? String ?: "", env["LEDGER_ODOO_KEY"] as? String ?: "")
    }
    LedgerRoot(demo = env["LEDGER_DEMO"] == "true", dev = dev)
}
