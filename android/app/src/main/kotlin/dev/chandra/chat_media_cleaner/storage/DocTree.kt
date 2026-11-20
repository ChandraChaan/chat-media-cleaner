package dev.chandra.chat_media_cleaner.storage

import android.net.Uri
import java.io.InputStream
import java.io.OutputStream

/** One file or folder in a [DocTree]. */
data class DocNode(
    val id: String,
    val name: String,
    val isDir: Boolean,
    val size: Long,
    val modified: Long,
    val mime: String,
)

/**
 * A folder tree the app can work in: either a Storage Access Framework grant
 * ([SafTree]) or the file system itself with all-files access ([FsTree]).
 *
 * Ids are opaque: SAF document ids, or absolute paths for the file system.
 * Missing items throw [java.io.FileNotFoundException], refused access throws
 * [SecurityException], and clashes or bad names throw [StorageFailure].
 */
interface DocTree {
    /** Whether [other] is the same tree, so items can move inside it with [moveWithin]. */
    fun sameTree(other: DocTree): Boolean

    fun node(id: String): DocNode

    fun exists(id: String): Boolean

    fun children(dirId: String): List<DocNode>

    fun openInput(id: String): InputStream

    fun openOutput(id: String): OutputStream

    /** Creates an empty file and returns its id. Providers may adjust the name. */
    fun createFile(parentId: String, name: String, mime: String): String

    /** Creates a folder and returns its id. */
    fun createDir(parentId: String, name: String): String

    /** Deletes a file, or a folder with everything in it. */
    fun delete(id: String)

    /** Renames in place and returns the new id. */
    fun rename(id: String, newName: String): String

    /**
     * Moves [id] from [fromParentId] into [toParentId] under [name] without
     * copying, and returns the new id. Null when this tree can't do that (for
     * example across volumes); the caller then copies and deletes.
     */
    fun moveWithin(id: String, fromParentId: String, toParentId: String, name: String): String?

    /** Whether [id] is [ancestorId] or somewhere below it. */
    fun isSameOrBelow(id: String, ancestorId: String): Boolean

    /** The absolute file-system path of [id], when this tree knows it. */
    fun pathOf(id: String): String?

    /** A URI this app can open through ContentResolver or MediaMetadataRetriever. */
    fun readUri(id: String): Uri

    /** A content:// URI other apps can read when granted FLAG_GRANT_READ_URI_PERMISSION. */
    fun shareUri(id: String): Uri

    fun mimeOf(id: String): String

    fun childNames(dirId: String): Set<String> = children(dirId).mapTo(HashSet()) { it.name }

    fun findChild(dirId: String, name: String): DocNode? = children(dirId).firstOrNull { it.name == name }

    companion object {
        const val MIME_DIR = "vnd.android.document/directory"
        const val MIME_DEFAULT = "application/octet-stream"
    }
}
