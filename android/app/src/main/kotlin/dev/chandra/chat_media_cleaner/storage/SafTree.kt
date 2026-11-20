package dev.chandra.chat_media_cleaner.storage

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.util.Log
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/** A folder the user picked with ACTION_OPEN_DOCUMENT_TREE. Ids are SAF document ids. */
class SafTree(
    val treeUri: Uri,
    private val resolver: ContentResolver,
    /** The primary shared storage folder, for turning `primary:` ids into paths. */
    private val primaryRoot: () -> String?,
) : DocTree {
    companion object {
        private const val TAG = "SafTree"
        private const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
        private val NODE_COLUMNS = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_SIZE,
            Document.COLUMN_LAST_MODIFIED,
        )
    }

    override fun sameTree(other: DocTree): Boolean = other is SafTree && other.treeUri == treeUri

    override fun node(id: String): DocNode {
        resolver.query(docUri(id), NODE_COLUMNS, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val mime = c.getString(2) ?: DocTree.MIME_DEFAULT
                return DocNode(
                    id = c.getString(0) ?: id,
                    name = c.getString(1) ?: id,
                    isDir = mime == Document.MIME_TYPE_DIR,
                    size = if (c.isNull(3)) 0L else c.getLong(3),
                    modified = if (c.isNull(4)) 0L else c.getLong(4),
                    mime = mime,
                )
            }
        }
        throw FileNotFoundException(id)
    }

    override fun exists(id: String): Boolean = try {
        querySingle(docUri(id), Document.COLUMN_DOCUMENT_ID) != null
    } catch (_: IllegalArgumentException) {
        false
    } catch (_: FileNotFoundException) {
        false
    }

    override fun children(dirId: String): List<DocNode> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, dirId)
        val cursor = resolver.query(uri, NODE_COLUMNS, null, null, null)
            ?: throw FileNotFoundException(dirId)
        val rows = ArrayList<DocNode>(cursor.count)
        cursor.use { c ->
            while (c.moveToNext()) {
                val mime = c.getString(2)
                rows += DocNode(
                    id = c.getString(0),
                    name = c.getString(1),
                    isDir = mime == Document.MIME_TYPE_DIR,
                    size = if (c.isNull(3)) 0L else c.getLong(3),
                    modified = if (c.isNull(4)) 0L else c.getLong(4),
                    mime = mime ?: DocTree.MIME_DEFAULT,
                )
            }
        }
        return rows
    }

    override fun childNames(dirId: String): Set<String> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, dirId)
        val names = HashSet<String>()
        resolver.query(uri, arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c ->
            while (c.moveToNext()) names += c.getString(0)
        }
        return names
    }

    override fun openInput(id: String): InputStream =
        resolver.openInputStream(docUri(id)) ?: throw FileNotFoundException(id)

    override fun openOutput(id: String): OutputStream =
        resolver.openOutputStream(docUri(id)) ?: throw FileNotFoundException(id)

    override fun createFile(parentId: String, name: String, mime: String): String {
        val created = DocumentsContract.createDocument(resolver, docUri(parentId), mime, name)
            ?: throw IOException("Could not create $name")
        return DocumentsContract.getDocumentId(created)
    }

    override fun createDir(parentId: String, name: String): String {
        val created = DocumentsContract.createDocument(resolver, docUri(parentId), Document.MIME_TYPE_DIR, name)
            ?: throw IOException("Could not create folder $name")
        return DocumentsContract.getDocumentId(created)
    }

    override fun delete(id: String) {
        if (!DocumentsContract.deleteDocument(resolver, docUri(id))) {
            throw IOException("Could not delete $id")
        }
    }

    override fun rename(id: String, newName: String): String {
        val renamed = DocumentsContract.renameDocument(resolver, docUri(id), newName)
            ?: throw IOException("Could not rename $id")
        return DocumentsContract.getDocumentId(renamed)
    }

    /** Renames first when [name] differs, because moveDocument keeps the name. */
    override fun moveWithin(id: String, fromParentId: String, toParentId: String, name: String): String? {
        val original = node(id).name
        var currentId = id
        if (name != original) currentId = rename(id, name)
        fun restoreName() {
            if (currentId == id) return
            try {
                rename(currentId, original)
            } catch (e: Exception) {
                Log.w(TAG, "Could not restore the name of a document after a failed move", e)
            }
        }
        val moved = try {
            DocumentsContract.moveDocument(resolver, docUri(currentId), docUri(fromParentId), docUri(toParentId))
        } catch (e: Exception) {
            restoreName()
            throw e
        }
        if (moved != null) return DocumentsContract.getDocumentId(moved)
        restoreName()
        return null
    }

    override fun isSameOrBelow(id: String, ancestorId: String): Boolean {
        if (id == ancestorId) return true
        val a = pathOf(id)
        val b = pathOf(ancestorId)
        if (a != null && b != null) return FsPaths.isSameOrBelow(a, b)
        return try {
            DocumentsContract.isChildDocument(resolver, docUri(ancestorId), docUri(id))
        } catch (e: Exception) {
            Log.w(TAG, "The provider can't tell whether one document is inside another", e)
            false
        }
    }

    /** Paths are only known for the phone's own storage provider (`primary:DCIM/x.jpg`). */
    override fun pathOf(id: String): String? {
        if (treeUri.authority != EXTERNAL_STORAGE_AUTHORITY) return null
        val colon = id.indexOf(':')
        if (colon <= 0) return null
        val volume = id.substring(0, colon)
        val relative = id.substring(colon + 1).trim('/')
        val root = if (volume == "primary") primaryRoot() ?: return null else "/storage/$volume"
        return if (relative.isEmpty()) root else File(root, relative).path
    }

    override fun readUri(id: String): Uri = docUri(id)

    override fun shareUri(id: String): Uri = docUri(id)

    override fun mimeOf(id: String): String = resolver.getType(docUri(id)) ?: ""

    fun docUri(docId: String): Uri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)

    private fun querySingle(uri: Uri, column: String): String? =
        resolver.query(uri, arrayOf(column), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
        }
}
