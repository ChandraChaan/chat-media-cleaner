package dev.chandra.chat_media_cleaner.storage

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * All-files access: MANAGE_EXTERNAL_STORAGE on Android 11 and later, and the
 * READ/WRITE_EXTERNAL_STORAGE runtime permissions (with legacy storage) on
 * Android 8 to 10. Also lists the storage volumes to browse.
 */
class AllFilesAccess(private val activity: Activity) {
    companion object {
        private const val TAG = "AllFilesAccess"
        const val REQUEST_SETTINGS = 0x5B0
        const val REQUEST_PERMISSIONS = 0x5B1
        private val LEGACY_PERMISSIONS = arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
    }

    private var pending: MethodChannel.Result? = null

    fun granted(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        Environment.isExternalStorageManager()
    } else {
        LEGACY_PERMISSIONS.all { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    }

    fun status(): Map<String, Any> = mapOf("granted" to granted(), "sdk" to Build.VERSION.SDK_INT)

    /** Asks for access and replies whether the app has it afterwards. */
    fun request(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A permission request is already open", null)
            return
        }
        if (granted()) {
            result.success(true)
            return
        }
        pending = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val forApp = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            )
            if (start(forApp) || start(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))) return
            pending = null
            result.error("no_app", "No settings screen for all-files access", null)
        } else {
            activity.requestPermissions(LEGACY_PERMISSIONS, REQUEST_PERMISSIONS)
        }
    }

    private fun start(intent: Intent): Boolean = try {
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQUEST_SETTINGS)
        true
    } catch (e: ActivityNotFoundException) {
        Log.w(TAG, "No activity for ${intent.action}", e)
        false
    }

    /** The user came back from the settings screen. Returns true when it was ours. */
    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_SETTINGS) return false
        reply()
        return true
    }

    /** The permission dialog closed. Returns true when it was ours. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_PERMISSIONS) return false
        reply()
        return true
    }

    fun dispose() {
        pending?.success(false)
        pending = null
    }

    private fun reply() {
        val result = pending ?: return
        pending = null
        result.success(granted())
    }

    /** Mounted volumes with their root folder, name and space. */
    fun volumes(): List<Map<String, Any>> {
        val manager = activity.getSystemService(StorageManager::class.java)
        val legacyRoots = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) emptyMap() else legacyRoots(manager)
        val rows = ArrayList<Map<String, Any>>()
        for (volume in manager.storageVolumes) {
            val state = volume.state
            if (state != Environment.MEDIA_MOUNTED && state != Environment.MEDIA_MOUNTED_READ_ONLY) continue
            val path = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                volume.directory?.path
            } else {
                legacyRoots[volumeKey(volume)]
            } ?: continue
            var total = 0L
            var free = 0L
            try {
                val stat = StatFs(path)
                total = stat.totalBytes
                free = stat.availableBytes
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "Could not read the size of a volume", e)
            }
            rows += mapOf(
                "path" to path,
                "label" to volume.getDescription(activity),
                "primary" to volume.isPrimary,
                "removable" to volume.isRemovable,
                "totalBytes" to total,
                "freeBytes" to free,
            )
        }
        return rows
    }

    /**
     * Before Android 11 volumes don't expose their folder, but the app's own
     * folder on each one does: `<root>/Android/data/<package>/files`.
     */
    private fun legacyRoots(manager: StorageManager): Map<String, String> {
        val roots = HashMap<String, String>()
        for (dir in activity.getExternalFilesDirs(null)) {
            if (dir == null) continue
            val marker = dir.path.indexOf("/Android/data/")
            if (marker <= 0) continue
            val volume = manager.getStorageVolume(dir) ?: continue
            roots[volumeKey(volume)] = dir.path.substring(0, marker)
        }
        return roots
    }

    private fun volumeKey(volume: StorageVolume): String =
        if (volume.isPrimary) "primary" else volume.uuid ?: volume.toString()
}
