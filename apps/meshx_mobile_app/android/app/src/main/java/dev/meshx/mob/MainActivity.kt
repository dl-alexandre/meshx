package dev.meshx.mob

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.core.content.FileProvider
import mob.ble.MobBleNative
import java.io.File

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "MeshX"
        init { System.loadLibrary("meshx_mobile_app") }
    }

    external fun nativeSetActivity(activity: Activity)
    external fun nativeStartBeam()

    // ── Camera launchers ──────────────────────────────────────────────────
    private var cameraPhotoUri: Uri? = null

    private val cameraPhotoLauncher =
        registerForActivityResult(ActivityResultContracts.TakePicture()) { success ->
            MobBridge.handleCameraPhotoResult(if (success) cameraPhotoUri else null)
        }

    private val cameraVideoLauncher =
        registerForActivityResult(ActivityResultContracts.CaptureVideo()) { success ->
            MobBridge.handleCameraVideoResult(if (success) cameraPhotoUri else null)
        }

    fun launchCameraPhoto() {
        val file = File(cacheDir, "mob_cam_${System.currentTimeMillis()}.jpg")
        cameraPhotoUri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        cameraPhotoLauncher.launch(cameraPhotoUri!!)
    }

    fun launchCameraVideo() {
        val file = File(cacheDir, "mob_cam_${System.currentTimeMillis()}.mp4")
        cameraPhotoUri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        cameraVideoLauncher.launch(cameraPhotoUri!!)
    }

    // ── Photo picker launcher ─────────────────────────────────────────────
    private val photosPickerLauncher =
        registerForActivityResult(ActivityResultContracts.PickMultipleVisualMedia()) { uris ->
            MobBridge.handlePhotosResult(uris)
        }

    fun launchPhotosPicker(max: Int) {
        photosPickerLauncher.launch(
            androidx.activity.result.PickVisualMediaRequest(
                androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageAndVideo
            )
        )
    }

    // ── File picker launcher ──────────────────────────────────────────────
    private val filePickerLauncher =
        registerForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
            MobBridge.handleFilesResult(uris)
        }

    fun launchFilePicker() {
        filePickerLauncher.launch(arrayOf("*/*"))
    }

    // ── QR scanner launcher ───────────────────────────────────────────────
    // For QR scanning we use an intent to a helper activity (MobScannerActivity)
    // that uses CameraX + ML Kit. It returns the scanned value as a result string.
    private val scannerLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val value = result.data?.getStringExtra("scan_value")
            val type  = result.data?.getStringExtra("scan_type") ?: "qr"
            MobBridge.handleScanResult(value, type)
        }

    fun launchQrScanner() {
        val intent = android.content.Intent(this, MobScannerActivity::class.java)
        scannerLauncher.launch(intent)
    }

    // ── Permission result ─────────────────────────────────────────────────
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 9001) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            MobBridge.onPermissionResult(granted)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Edge-to-edge: lets the content draw behind the (transparent) status
        // and navigation bars instead of being letterboxed by opaque system
        // bars. Must be called BEFORE super.onCreate() per AndroidX docs.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        MobBridge.init(this)

        // Supply the BLE NIF bridge with an application Context before the
        // BEAM starts — mob_ble_nif's start_scan/start_advertising calls
        // route through MobBleNative, which builds RealBleBridge lazily.
        MobBleNative.init(this)
        registerBluetoothStateReceiver()

        // Android does not always provide a process TMPDIR to embedded BEAM
        // code. MeshxStore.DB falls back through System.tmp_dir!/0 during
        // runtime startup, so seed it with an app-writable directory before
        // nativeStartBeam().
        val beamTmpDir = File(cacheDir, "beam_tmp")
        beamTmpDir.mkdirs()
        android.system.Os.setenv("TMPDIR", beamTmpDir.absolutePath, true)
        Log.i(TAG, "onCreate: TMPDIR=${beamTmpDir.absolutePath}")

        // Forward launcher-supplied env vars into the BEAM process. Set BEFORE
        // nativeStartBeam below so the BEAM (and Mob.Dist in particular) sees
        // them when it reads getenv()/System.get_env/1.
        //
        //   mob_node_suffix — appended to the configured node name
        //                     (`<app>_android` → `<app>_android_<suffix>`).
        //                     Lets multiple Android phones running the same
        //                     app coexist in Mac's shared EPMD.
        //   mob_dist_port   — Erlang dist listen port (default 9100).
        intent?.extras?.getString("mob_node_suffix")?.takeIf { it.isNotEmpty() }?.let { suffix ->
            android.system.Os.setenv("MOB_NODE_SUFFIX", suffix, true)
            Log.i(TAG, "onCreate: MOB_NODE_SUFFIX=$suffix")
        }

        intent?.extras?.getInt("mob_dist_port", -1)?.takeIf { it > 0 }?.let { port ->
            android.system.Os.setenv("MOB_DIST_PORT", port.toString(), true)
            Log.i(TAG, "onCreate: MOB_DIST_PORT=$port")
        }

        // meshx_ble_selftest — when set, MeshxMobileApp.App.on_start runs
        // the headless BLE bring-up probe (MeshxMobileApp.BleSelfTest)
        // that drives the real mob_ble_nif scan+advertise path.
        if (intent?.extras?.getBoolean("meshx_ble_selftest", false) == true) {
            android.system.Os.setenv("MESHX_BLE_SELFTEST", "1", true)
            Log.i(TAG, "onCreate: MESHX_BLE_SELFTEST=1")
        }

        // RT-01 reliability event logging — enables MeshxMobileApp.BLE.Observability
        // to emit "MeshxAppEvent:" timeline lines consumed by
        // mix meshx.mobile.rt01.analyze. Off unless explicitly launched with the
        // extra, so normal runs stay quiet.
        if (intent?.extras?.getBoolean("meshx_rt_event_log", false) == true) {
            android.system.Os.setenv("MESHX_RT_EVENT_LOG", "1", true)
            Log.i(TAG, "onCreate: MESHX_RT_EVENT_LOG=1")
        }

        intent?.extras?.getString("meshx_rt_run_id")?.takeIf { it.isNotEmpty() }?.let { runId ->
            android.system.Os.setenv("MESHX_RT_RUN_ID", runId, true)
            Log.i(TAG, "onCreate: MESHX_RT_RUN_ID=$runId")
        }

        // Doze exemption (opt-in): deep-idle suspends background BLE scans even
        // with a foreground service, which is what kills locked-window receive
        // (RT-01). When launched with this extra we ask the OS to whitelist the
        // app (system dialog). For scripted captures the same effect is
        // `adb shell dumpsys deviceidle whitelist +dev.meshx.mob`.
        if (intent?.extras?.getBoolean("meshx_ignore_battery_opt", false) == true) {
            val pm = getSystemService(android.os.PowerManager::class.java)
            if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    startActivity(
                        Intent(
                            android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                    )
                    Log.i(TAG, "onCreate: requested battery-optimization exemption")
                } catch (t: Throwable) {
                    Log.w(TAG, "onCreate: battery-opt exemption request failed: ${t.message}")
                }
            } else {
                Log.i(TAG, "onCreate: already ignoring battery optimizations")
            }
        }

        // mob_ble_* extras — support the recommended default path (Phase 2+)
        // for on-device validation and harness launches. These set the
        // MOB_BLE_* env vars consumed by MeshxMobileApp.App and
        // Mob.Ble.* (new canonical path unless MOB_BLE_TRANSPORT=0).
        if (intent?.extras?.getBoolean("mob_ble_selftest", false) == true) {
            android.system.Os.setenv("MOB_BLE_SELFTEST", "1", true)
            Log.i(TAG, "onCreate: MOB_BLE_SELFTEST=1 (recommended mob_ble path)")
        }

        intent?.extras?.getString("mob_ble_local_name")?.takeIf { it.isNotEmpty() }?.let { name ->
            android.system.Os.setenv("MOB_BLE_LOCAL_NAME", name, true)
            Log.i(TAG, "onCreate: MOB_BLE_LOCAL_NAME=$name")
        }

        intent?.extras?.getString("mob_ble_transport")?.takeIf { it.isNotEmpty() }?.let { v ->
            android.system.Os.setenv("MOB_BLE_TRANSPORT", v, true)
            Log.i(TAG, "onCreate: MOB_BLE_TRANSPORT=$v")
        }

        // Also accept --ez mob_ble_transport_0 true as a convenience for opt-out
        if (intent?.extras?.getBoolean("mob_ble_transport_0", false) == true) {
            android.system.Os.setenv("MOB_BLE_TRANSPORT", "0", true)
            Log.i(TAG, "onCreate: MOB_BLE_TRANSPORT=0 (legacy path forced)")
        }

        // MOB_BLE_FETCH_ON_BEACON parity (in addition to legacy meshx_ name)
        // Allows launch scripts / harnesses to use the MOB_BLE_* namespace uniformly
        // for the new default path while keeping full backward compat.
        val mobBleFetch = intent?.extras?.getBoolean("mob_ble_fetch_on_beacon", false) == true
        val fetchOnBeacon = mobBleFetch || (intent?.extras?.getBoolean("meshx_ble_fetch_on_beacon", false) == true)
        MobBleNative.setFetchOnBeaconEnabled(fetchOnBeacon)
        if (fetchOnBeacon) {
            Log.i(TAG, "onCreate: fetch_on_beacon=true (mob_ble or legacy)")
            if (mobBleFetch) {
                android.system.Os.setenv("MOB_BLE_FETCH_ON_BEACON", "1", true)
            }
        }

        if (intent?.extras?.containsKey("meshx_ble_selftest_send") == true) {
            val enabled = intent?.extras?.getBoolean("meshx_ble_selftest_send", true) != false
            android.system.Os.setenv("MESHX_BLE_SELFTEST_SEND", if (enabled) "1" else "0", true)
            MobBleNative.setSelftestSendEnabled(enabled)
            Log.i(TAG, "onCreate: MESHX_BLE_SELFTEST_SEND=${if (enabled) "1" else "0"}")
        } else {
            MobBleNative.setSelftestSendEnabled(true)
        }

        // Check if launched from a notification tap
        intent?.extras?.getString("mob_notification_json")?.let { json ->
            MobBridge.setLaunchNotification(json)
        }

        setContent {
            val state by MobBridge.rootState

            BackHandler(enabled = state.node != null) { MobBridge.nativeHandleBack() }

            AnimatedContent(
                targetState   = state,
                contentKey    = { it.navKey },
                transitionSpec = {
                    when (targetState.transition) {
                        "push" ->
                            slideInHorizontally(animationSpec = tween(300)) { it } togetherWith
                            slideOutHorizontally(animationSpec = tween(300)) { -it / 3 }
                        "pop" ->
                            slideInHorizontally(animationSpec = tween(300)) { -it / 3 } togetherWith
                            slideOutHorizontally(animationSpec = tween(300)) { it }
                        "reset" ->
                            fadeIn(animationSpec = tween(250)) togetherWith
                            fadeOut(animationSpec = tween(250))
                        else ->
                            EnterTransition.None togetherWith ExitTransition.None
                    }
                },
                label = "nav"
            ) { s ->
                s.node?.let { RenderNode(it, modifier = Modifier.fillMaxSize().safeDrawingPadding()) }
            }
        }

        // If the project ships embedded Python (mix mob.enable python), the
        // APK contains assets/python/{stdlib,lib-dynload}/. Extract those to
        // filesDir on first launch and tell the BEAM where they landed via
        // env vars consumed by <App>.PythonPaths. Idempotent — re-launches
        // skip extraction once the marker file is present.
        extractPythonAssetsIfNeeded()

        Log.i(TAG, "onCreate — handing off to BEAM")
        nativeSetActivity(this)
        Thread({ nativeStartBeam() }, "beam-main").start()
    }

    private fun extractPythonAssetsIfNeeded() {
        val pythonRoot = File(filesDir, "python")
        val marker = File(pythonRoot, ".extracted")

        // libpython3.13.so is auto-extracted by the APK installer to the
        // app's nativeLibraryDir — point Pythonx.init/4 at it.
        val libPython = File(applicationInfo.nativeLibraryDir, "libpython3.13.so")

        if (libPython.exists()) {
            android.system.Os.setenv("MOB_PYTHON_DL", libPython.absolutePath, true)
        }

        // Skip extraction if no assets ship Python (project doesn't use Pythonx)
        // or if extraction has already happened.
        val assetList = try { assets.list("python") ?: emptyArray() } catch (_: Throwable) { emptyArray() }
        if (assetList.isEmpty() || marker.exists()) {
            if (pythonRoot.exists()) {
                android.system.Os.setenv("MOB_PYTHON_HOME", pythonRoot.absolutePath, true)
            }
            return
        }

        Log.i(TAG, "extractPythonAssets: extracting assets/python → ${pythonRoot.absolutePath}")
        copyAssetTree("python", pythonRoot)
        flattenLibDynload(pythonRoot)
        marker.createNewFile()
        android.system.Os.setenv("MOB_PYTHON_HOME", pythonRoot.absolutePath, true)
        Log.i(TAG, "extractPythonAssets: done")
    }

    // Chaquopy ships lib-dynload/<abi>/*.so per architecture; CPython expects
    // them flat in lib-dynload/. Move the device's primary-abi `.so` files
    // up one level and discard the rest.
    private fun flattenLibDynload(pythonRoot: File) {
        val libDynload = File(pythonRoot, "lib/python3.13/lib-dynload")
        if (!libDynload.isDirectory) return

        val deviceAbi = android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: return
        val abiDir = File(libDynload, deviceAbi)
        if (!abiDir.isDirectory) return

        abiDir.listFiles()?.forEach { src ->
            val dst = File(libDynload, src.name)
            if (!dst.exists()) src.renameTo(dst)
        }
        // Drop the other-abi dirs to free space.
        libDynload.listFiles { f -> f.isDirectory }?.forEach { it.deleteRecursively() }
    }

    private fun copyAssetTree(srcPath: String, destDir: File) {
        val children = assets.list(srcPath) ?: emptyArray()

        if (children.isEmpty()) {
            // Leaf: copy the file
            destDir.parentFile?.mkdirs()
            assets.open(srcPath).use { input ->
                destDir.outputStream().use { output -> input.copyTo(output) }
            }
            return
        }

        destDir.mkdirs()
        for (child in children) {
            copyAssetTree("$srcPath/$child", File(destDir, child))
        }
    }

    // Called when a notification is tapped and the activity already exists at
    // the top of the stack (singleTop launch mode). If BEAM is running, deliver
    // the notification directly; otherwise store it for delivery on boot.
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.extras?.getString("mob_notification_json")?.let { json ->
            val pid = MobBridge.notifyPid
            if (pid != 0L) {
                MobBridge.nativeDeliverNotification(pid, json)
            } else {
                MobBridge.setLaunchNotification(json)
            }
        }
    }

    // Manifest declares `android:configChanges` including `uiMode`, so a
    // dark/light toggle delivers here instead of recreating the activity.
    // Forward to MobBridge so Mob.Device :appearance subscribers can react
    // (e.g. re-resolve Mob.Theme.Adaptive without an app restart).
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val nightMode = newConfig.uiMode and Configuration.UI_MODE_NIGHT_MASK
        val scheme = if (nightMode == Configuration.UI_MODE_NIGHT_YES) "dark" else "light"
        MobBridge.notifyColorSchemeChanged(scheme)
    }

    // ── Doze / adapter-cycle resilience ─────────────────────────────────
    // Forward BluetoothAdapter.ACTION_STATE_CHANGED to the BLE bridge so
    // it can surface a BLUETOOTH_OFF event when the radio drops (Doze
    // suspend, airplane mode, user toggle) and auto-replay the caller's
    // scan/advertise intent when it comes back. Registered for the
    // Activity's lifetime — Doze is a background concern so we can't
    // gate this on foreground state.
    private val bluetoothStateReceiver: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(
                    BluetoothAdapter.EXTRA_STATE,
                    BluetoothAdapter.ERROR
                )
                Log.i(TAG, "BluetoothAdapter state -> $state")
                MobBleNative.onBluetoothStateChanged(state)
            }
        }
    }

    private var bluetoothStateReceiverRegistered = false

    private fun registerBluetoothStateReceiver() {
        if (bluetoothStateReceiverRegistered) return
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        // Android 13+ requires the export flag for runtime receivers.
        // The state-changed broadcast is a system protected broadcast,
        // so RECEIVER_NOT_EXPORTED is correct (no third-party should be
        // sending us bluetooth state changes).
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bluetoothStateReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(bluetoothStateReceiver, filter)
        }
        bluetoothStateReceiverRegistered = true
        Log.i(TAG, "registered BluetoothAdapter state receiver")
    }

    override fun onDestroy() {
        if (bluetoothStateReceiverRegistered) {
            try {
                unregisterReceiver(bluetoothStateReceiver)
            } catch (_: IllegalArgumentException) {
                // Already unregistered — defensive against duplicate-destroy paths.
            }
            bluetoothStateReceiverRegistered = false
        }
        super.onDestroy()
    }
}
