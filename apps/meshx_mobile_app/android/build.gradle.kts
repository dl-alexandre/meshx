plugins {
    id("com.android.application") version "8.5.0"
    id("org.jetbrains.kotlin.android") version "1.9.24"
}

android {
    namespace = "dev.meshx.mob"
    compileSdk = 34

    // sourceSets is overridden because the project deliberately keeps the
    // manifest at android/AndroidManifest.xml (mirroring the flat layout
    // of android/build_device.sh and the iOS shell's ios/Info.plist),
    // instead of the default src/main/AndroidManifest.xml location.
    sourceSets {
        getByName("main") {
            manifest.srcFile("AndroidManifest.xml")
            java.srcDirs("src/main/java")
            kotlin.srcDirs("src/main/java")
        }
    }

    defaultConfig {
        applicationId = "dev.meshx.mob"
        // BLE peripheral (advertising) and the split BLUETOOTH_* runtime
        // permissions need API 26+ and API 31+ respectively; staying on
        // minSdk 26 keeps the floor BLE-capable while letting the manifest
        // gate newer permissions.
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
