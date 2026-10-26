package app.ledger.kmp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import app.ledger.ui.DevConnection
import app.ledger.ui.LedgerRoot

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        // For development: `adb shell am start -n app.ledger.kmp/.MainActivity --ez demo true` starts with sample data;
        // `--es url http://10.0.2.2:8069 --es db mydb --es key MYKEY` connects to Odoo on start-up.
        val demo = intent.getBooleanExtra("demo", false)
        val dev = intent.getStringExtra("url")?.let { DevConnection(it, intent.getStringExtra("db") ?: "", intent.getStringExtra("key") ?: "") }
        setContent { LedgerRoot(demo = demo, dev = dev) }
    }
}
