package app.ledger.kmp

import android.app.Application
import app.ledger.platform.AppContext

class LedgerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AppContext.app = this
    }
}
