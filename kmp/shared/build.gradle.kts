plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidKmpLibrary)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.kotlinSerialization)
}

kotlin {
    androidLibrary {
        namespace = "app.ledger.shared"
        compileSdk = 37
        minSdk = 24
        withHostTestBuilder {}
        androidResources { enable = true }
    }

    listOf(iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.ui)
            implementation(compose.material3) // only for the date picker
            implementation(compose.components.resources)
            implementation(libs.coroutines.core)
            implementation(libs.serialization.json)
            implementation(libs.datetime)
            implementation(libs.ktor.client.core)
            implementation(libs.settings)
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
            implementation(libs.activity.compose)
            implementation(libs.androidx.core)
            implementation(libs.lifecycle.runtime.compose)
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation(libs.coroutines.test)
            implementation(libs.ktor.client.mock)
            implementation(libs.settings.test)
        }
    }
}

compose.resources {
    publicResClass = true
    packageOfResClass = "app.ledger.shared.resources"
}
