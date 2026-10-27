package dev.chandra.chat_media_cleaner.storage

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Point
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Storage Access Framework operations for the Dart `PlatformMediaStorage`.
 *
 * Everything works on folders the user picked with ACTION_OPEN_DOCUMENT_TREE, so the
 * app needs no storage permission. Slow work runs on background threads and replies
 * on the main thread.
 */
class StorageChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "dev.chandra.chat_media_cleaner/storage"
        private const val REQUEST_PICK_FOLDER = 0x5AF
        private const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
        private const val GRANT_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        private val CHILD_COLUMNS = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_SIZE,
            Document.COLUMN_LAST_MODIFIED,
        )
    }

    private val io: ExecutorService = Executors.newFixedThreadPool(2)
    private val thumbs: ExecutorService = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private val resolver: ContentResolver get() = activity.contentResolver
    private val trashDirs = ConcurrentHashMap<String, String>()
    private var pendingPick: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "pickFolder" -> pickFolder(call.argument<String>("initialDocId"), result)
            "grantedFolders" -> result.success(
                resolver.persistedUriPermissions
                    .filter { it.isReadPermission && it.isWritePermission }
                    .map { it.uri.toString() },
            )
            "releaseFolder" -> {
                releaseFolder(call.str("treeUri"))
                result.success(null)
            }
            "listChildren" -> run(io, result) { listChildren(call.tree(), call.str("docId")) }
            "moveToTrash" -> run(io, result) {
                moveToTrash(
                    call.tree(),
                    rootId = call.str("rootId"),
                    docId = call.str("docId"),
                    parentId = call.str("parentId"),
                    itemKey = call.str("itemKey"),
                )
            }
            "restoreFromTrash" -> run(io, result) {
                restoreFromTrash(
                    call.tree(),
                    itemDirId = call.str("itemDirId"),
                    docId = call.str("docId"),
                    targetParentId = call.str("targetParentId"),
                )
            }
            "deleteTrashItem" -> run(io, result) { deleteTrashItem(call.tree(), call.str("docId")) }
            "thumbnail" -> run(thumbs, result) {
                thumbnail(call.tree(), call.str("docId"), call.argument<Int>("size") ?: 256)
            }
            "readBytes" -> run(io, result) {
                readBytes(call.tree(), call.str("docId"), call.argument<Int>("maxBytes") ?: Int.MAX_VALUE)
            }
            "openExternally" -> openExternally(call.tree(), call.str("docId"), call.argument<String>("mime"), result)
            else -> result.notImplemented()
        }
    }

    /** Handles the folder picker result. Returns true when it was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_FOLDER) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            resolver.takePersistableUriPermission(uri, GRANT_FLAGS)
            result.success(
                mapOf(
                    "treeUri" to uri.toString(),
                    "treeDocId" to DocumentsContract.getTreeDocumentId(uri),
                ),
            )
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
        }
        return true
    }

    fun dispose() {
        io.shutdownNow()
        thumbs.shutdownNow()
        pendingPick?.success(null)
        pendingPick = null
    }

    private fun pickFolder(initialDocId: String?, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "The folder picker is already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            GRANT_FLAGS or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        if (initialDocId != null) {
            intent.putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                DocumentsContract.buildDocumentUri(EXTERNAL_STORAGE_AUTHORITY, initialDocId),
            )
        }
        pendingPick = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK_FOLDER)
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            result.error("no_app", e.message, null)
        }
    }

    private fun releaseFolder(treeUri: String) {
        try {
            resolver.releasePersistableUriPermission(Uri.parse(treeUri), GRANT_FLAGS)
        } catch (_: SecurityException) {
            // Already released, for example from system settings.
        }
    }

    private fun listChildren(tree: Uri, docId: String): List<Map<String, Any?>> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
        val cursor = resolver.query(uri, CHILD_COLUMNS, null, null, null)
            ?: throw FileNotFoundException(docId)
        val rows = ArrayList<Map<String, Any?>>(cursor.count)
        cursor.use { c ->
            while (c.moveToNext()) {
                val mime = c.getString(2)
                rows += mapOf(
                    "id" to c.getString(0),
                    "name" to c.getString(1),
                    "isDir" to (mime == Document.MIME_TYPE_DIR),
                    "size" to if (c.isNull(3)) 0L else c.getLong(3),
                    "modified" to if (c.isNull(4)) 0L else c.getLong(4),
                    "mime" to mime,
                )
            }
        }
        return rows
    }

    private fun moveToTrash(
        tree: Uri,
        rootId: String,
        docId: String,
        parentId: String,
        itemKey: String,
    ): Map<String, String> {
        if (!exists(tree, docId)) throw FileNotFoundException(docId)
        val itemDir = try {
            createDir(trashDir(tree, rootId), itemKey)
        } catch (_: Exception) {
            // The trash folder may have been deleted since it was cached.
            trashDirs.remove("$tree|$rootId")
            createDir(trashDir(tree, rootId), itemKey)
        }
        val moved = try {
            DocumentsContract.moveDocument(resolver, docUri(tree, docId), docUri(tree, parentId), itemDir)
        } catch (e: Exception) {
            deleteQuietly(itemDir)
            throw e
        }
        if (moved == null) {
            deleteQuietly(itemDir)
            throw IOException("Could not move $docId to the trash")
        }
        return mapOf(
            "itemDirId" to DocumentsContract.getDocumentId(itemDir),
            "fileId" to DocumentsContract.getDocumentId(moved),
        )
    }

    private fun restoreFromTrash(
        tree: Uri,
        itemDirId: String,
        docId: String,
        targetParentId: String,
    ): Map<String, String> {
        if (!exists(tree, docId)) throw FileNotFoundException(docId)
        if (!exists(tree, targetParentId)) {
            throw StorageFailure("target_missing", "The original folder no longer exists")
        }
        val name = displayName(tree, docId)
        val freeName = Names.firstFree(name, childNames(tree, targetParentId))
        var fileUri = docUri(tree, docId)
        if (freeName != name) {
            fileUri = DocumentsContract.renameDocument(resolver, fileUri, freeName)
                ?: throw IOException("Could not rename $docId")
        }
        val moved = DocumentsContract.moveDocument(
            resolver,
            fileUri,
            docUri(tree, itemDirId),
            docUri(tree, targetParentId),
        ) ?: throw IOException("Could not move $docId back")
        deleteQuietly(docUri(tree, itemDirId))
        return mapOf("fileId" to DocumentsContract.getDocumentId(moved), "name" to freeName)
    }

    private fun deleteTrashItem(tree: Uri, itemDirId: String): Boolean {
        if (!exists(tree, itemDirId)) throw FileNotFoundException(itemDirId)
        if (!DocumentsContract.deleteDocument(resolver, docUri(tree, itemDirId))) {
            throw IOException("Could not delete $itemDirId")
        }
        return true
    }

    private fun thumbnail(tree: Uri, docId: String, size: Int): ByteArray? {
        val uri = docUri(tree, docId)
        val mime = resolver.getType(uri) ?: ""
        val bitmap = providerThumbnail(uri, size)
            ?: when {
                mime.startsWith("video/") -> videoFrame(uri, size)
                mime.startsWith("image/") -> decodeImage(uri, size)
                else -> null
            }
            ?: return null
        val (w, h) = ThumbnailMath.fit(bitmap.width, bitmap.height, size)
        val scaled = if (w != bitmap.width || h != bitmap.height) {
            Bitmap.createScaledBitmap(bitmap, w, h, true)
        } else {
            bitmap
        }
        val out = ByteArrayOutputStream()
        if (scaled.hasAlpha()) {
            scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
        } else {
            scaled.compress(Bitmap.CompressFormat.JPEG, 82, out)
        }
        return out.toByteArray()
    }

    private fun providerThumbnail(uri: Uri, size: Int): Bitmap? = try {
        DocumentsContract.getDocumentThumbnail(resolver, uri, Point(size, size), null)
    } catch (_: Exception) {
        null
    }

    private fun videoFrame(uri: Uri, size: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(activity, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(-1, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, size, size)
            } else {
                retriever.frameAtTime
            }
        } catch (_: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun decodeImage(uri: Uri, size: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = ThumbnailMath.sampleSize(bounds.outWidth, bounds.outHeight, size)
        }
        return resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
    }

    private fun readBytes(tree: Uri, docId: String, maxBytes: Int): ByteArray {
        val uri = docUri(tree, docId)
        val size = querySingle(uri, Document.COLUMN_SIZE)?.toLongOrNull() ?: 0L
        if (size > maxBytes) throw StorageFailure("too_large", "$size bytes")
        return resolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw FileNotFoundException(docId)
    }

    private fun openExternally(tree: Uri, docId: String, mime: String?, result: MethodChannel.Result) {
        val uri = docUri(tree, docId)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, mime ?: resolver.getType(uri) ?: "*/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            activity.startActivity(intent)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("no_app", e.message, null)
        }
    }

    /** Finds or creates the trash folder below [rootId], with a `.nomedia` file in it. */
    private fun trashDir(tree: Uri, rootId: String): Uri {
        val key = "$tree|$rootId"
        trashDirs[key]?.let { return docUri(tree, it) }
        val existing = findChild(tree, rootId, TrashFolder.NAME)
        val dir = existing ?: createDir(docUri(tree, rootId), TrashFolder.NAME)
        if (findChild(tree, DocumentsContract.getDocumentId(dir), TrashFolder.NO_MEDIA) == null) {
            DocumentsContract.createDocument(resolver, dir, "application/octet-stream", TrashFolder.NO_MEDIA)
        }
        trashDirs[key] = DocumentsContract.getDocumentId(dir)
        return dir
    }

    private fun createDir(parent: Uri, name: String): Uri =
        DocumentsContract.createDocument(resolver, parent, Document.MIME_TYPE_DIR, name)
            ?: throw IOException("Could not create folder $name")

    private fun findChild(tree: Uri, parentId: String, name: String): Uri? {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        resolver.query(uri, arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?.use { c ->
                while (c.moveToNext()) {
                    if (c.getString(1) == name) return docUri(tree, c.getString(0))
                }
            }
        return null
    }

    private fun childNames(tree: Uri, parentId: String): Set<String> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val names = HashSet<String>()
        resolver.query(uri, arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c ->
            while (c.moveToNext()) names += c.getString(0)
        }
        return names
    }

    private fun exists(tree: Uri, docId: String): Boolean = try {
        querySingle(docUri(tree, docId), Document.COLUMN_DOCUMENT_ID) != null
    } catch (_: IllegalArgumentException) {
        false
    } catch (_: FileNotFoundException) {
        false
    }

    private fun displayName(tree: Uri, docId: String): String =
        querySingle(docUri(tree, docId), Document.COLUMN_DISPLAY_NAME)
            ?: throw FileNotFoundException(docId)

    private fun querySingle(uri: Uri, column: String): String? =
        resolver.query(uri, arrayOf(column), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
        }

    private fun deleteQuietly(uri: Uri) {
        try {
            DocumentsContract.deleteDocument(resolver, uri)
        } catch (_: Exception) {
            // Best effort: an empty item folder in the trash is harmless.
        }
    }

    private fun docUri(tree: Uri, docId: String): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, docId)

    private fun <T> run(executor: ExecutorService, result: MethodChannel.Result, work: () -> T) {
        executor.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                val code = errorCode(e)
                main.post { result.error(code, e.message, null) }
            }
        }
    }

    private fun errorCode(e: Exception): String = when (e) {
        is StorageFailure -> e.code
        is FileNotFoundException -> "not_found"
        is SecurityException -> "permission"
        else -> "failed"
    }

    private fun MethodCall.str(name: String): String =
        argument<String>(name) ?: throw IllegalArgumentException("Missing $name")

    private fun MethodCall.tree(): Uri = Uri.parse(str("treeUri"))
}
