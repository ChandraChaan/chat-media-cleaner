package dev.chandra.chat_media_cleaner.storage

import android.util.Log
import java.io.EOFException
import java.io.FileNotFoundException
import java.io.InputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipException
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/** A file or folder that an operation created or moved, as the Dart side expects it. */
data class Item(val id: String, val name: String) {
    fun toMap(): Map<String, String> = mapOf("id" to id, "name" to name)
}

data class FolderSize(val bytes: Long, val files: Int, val folders: Int) {
    fun toMap(): Map<String, Any> = mapOf("bytes" to bytes, "files" to files, "folders" to folders)
}

/**
 * File manager operations that work on any [DocTree], and between two trees
 * of different kinds. Free of Android calls apart from logging, so they run in
 * JVM unit tests on [FsTree].
 */
object FileOps {
    private const val TAG = "FileOps"
    private const val BUFFER_SIZE = 64 * 1024
    private const val ZIP_MIME = "application/zip"

    fun createFolder(tree: DocTree, parentId: String, name: String): Item {
        if (!FsPaths.isValidName(name)) throw StorageFailure("invalid", "Bad name: $name")
        if (name in tree.childNames(parentId)) throw StorageFailure("exists", name)
        val id = tree.createDir(parentId, name)
        return Item(id, nameOf(tree, id, name))
    }

    /** Copies [id] (a file, or a folder with everything in it) into [targetParentId] of [dst]. */
    fun copyItem(src: DocTree, id: String, dst: DocTree, targetParentId: String): Item {
        val node = src.node(id)
        if (node.isDir && contains(src, id, dst, targetParentId)) {
            throw StorageFailure("invalid", "Can't copy a folder into itself")
        }
        val name = Names.firstFree(node.name, dst.childNames(targetParentId))
        val newId = copyFresh(src, node, dst, targetParentId, name)
        return Item(newId, nameOf(dst, newId, name))
    }

    /**
     * Moves [id] from [parentId] of [src] into [targetParentId] of [dst]. Inside
     * one tree this is a rename when possible; otherwise the item is copied and
     * the original deleted once the copy is complete.
     */
    fun moveItem(src: DocTree, id: String, parentId: String, dst: DocTree, targetParentId: String): Item {
        val node = src.node(id)
        if (contains(src, id, dst, targetParentId)) {
            throw StorageFailure("invalid", "Can't move a folder into itself")
        }
        if (sameLocation(src, parentId, dst, targetParentId)) return Item(node.id, node.name)
        val name = Names.firstFree(node.name, dst.childNames(targetParentId))
        if (src.sameTree(dst)) {
            val moved = src.moveWithin(id, parentId, targetParentId, name)
            if (moved != null) return Item(moved, nameOf(dst, moved, name))
        }
        val copied = copyFresh(src, node, dst, targetParentId, name)
        try {
            src.delete(id)
        } catch (e: Exception) {
            Log.w(TAG, "Copied an item but could not delete the original", e)
            throw e
        }
        return Item(copied, nameOf(dst, copied, name))
    }

    /** Moves inside one tree, copying and deleting when the tree can't move directly. */
    fun moveOrCopy(tree: DocTree, id: String, fromParentId: String, toParentId: String, name: String): String {
        tree.moveWithin(id, fromParentId, toParentId, name)?.let { return it }
        val copied = copyFresh(tree, tree.node(id), tree, toParentId, name)
        tree.delete(id)
        return copied
    }

    /** Permanently deletes a file, or a folder with everything in it. */
    fun deleteItem(tree: DocTree, id: String) {
        if (!tree.exists(id)) throw FileNotFoundException(id)
        tree.delete(id)
    }

    /** Total size and counts below [id]; for a file, its own size and one file. */
    fun folderSize(tree: DocTree, id: String): FolderSize {
        val root = tree.node(id)
        if (!root.isDir) return FolderSize(root.size, 1, 0)
        var bytes = 0L
        var files = 0
        var folders = 0
        val pending = ArrayDeque<String>()
        pending.add(root.id)
        while (pending.isNotEmpty()) {
            for (child in tree.children(pending.removeFirst())) {
                if (child.isDir) {
                    folders++
                    pending.add(child.id)
                } else {
                    files++
                    bytes += child.size
                }
            }
        }
        return FolderSize(bytes, files, folders)
    }

    /**
     * Packs [ids] (folders with everything in them) into a new archive called
     * [name] in [parentId]. A partial archive is deleted when anything fails.
     */
    fun zipItems(tree: DocTree, ids: List<String>, parentId: String, name: String): Item {
        if (ids.isEmpty()) throw StorageFailure("invalid", "Nothing to pack")
        if (!FsPaths.isValidName(name)) throw StorageFailure("invalid", "Bad name: $name")
        val nodes = ids.map { tree.node(it) }
        val archiveName = Names.firstFree(name, tree.childNames(parentId))
        val zipId = tree.createFile(parentId, archiveName, ZIP_MIME)
        try {
            tree.openOutput(zipId).use { raw ->
                ZipOutputStream(raw.buffered(BUFFER_SIZE)).use { zip ->
                    val used = HashSet<String>()
                    for (node in nodes) {
                        val entryName = Names.firstFree(node.name, used)
                        used += entryName
                        addToZip(tree, node, entryName, zip, skipId = zipId)
                    }
                }
            }
        } catch (e: Exception) {
            deleteLogged(tree, zipId)
            throw e
        }
        return Item(zipId, nameOf(tree, zipId, archiveName))
    }

    /**
     * Unpacks the archive [id] into a new folder in [parentId] named after it.
     * Entries that would land outside that folder are skipped. A file that is
     * not a readable archive fails with `unreadable`.
     */
    fun unzip(tree: DocTree, id: String, parentId: String): Item {
        val node = tree.node(id)
        if (node.isDir || !looksLikeZip(tree, id)) throw StorageFailure("unreadable", "Not a zip archive")
        val base = node.name.substringBeforeLast('.').ifEmpty { node.name }
        val folderName = Names.firstFree(base, tree.childNames(parentId))
        val rootId = tree.createDir(parentId, folderName)
        try {
            extract(tree, id, rootId)
        } catch (e: Exception) {
            deleteLogged(tree, rootId)
            throw e
        }
        return Item(rootId, nameOf(tree, rootId, folderName))
    }

    /** Whether the folder [outerId] of [outer] is, or contains, [innerId] of [inner]. */
    fun contains(outer: DocTree, outerId: String, inner: DocTree, innerId: String): Boolean {
        val a = outer.pathOf(outerId)
        val b = inner.pathOf(innerId)
        if (a != null && b != null) return FsPaths.isSameOrBelow(b, a)
        if (outer.sameTree(inner)) return inner.isSameOrBelow(innerId, outerId)
        return false
    }

    private fun sameLocation(src: DocTree, parentId: String, dst: DocTree, targetParentId: String): Boolean {
        if (src.sameTree(dst) && parentId == targetParentId) return true
        val a = src.pathOf(parentId) ?: return false
        val b = dst.pathOf(targetParentId) ?: return false
        return a.trimEnd('/') == b.trimEnd('/')
    }

    /** Creates [name] in [parentId] of [dst] and fills it; removes it again when that fails. */
    private fun copyFresh(src: DocTree, node: DocNode, dst: DocTree, parentId: String, name: String): String {
        val newId = create(node, dst, parentId, name)
        try {
            fill(src, node, dst, newId)
        } catch (e: Exception) {
            deleteLogged(dst, newId)
            throw e
        }
        return newId
    }

    private fun fill(src: DocTree, node: DocNode, dst: DocTree, newId: String) {
        if (!node.isDir) {
            src.openInput(node.id).use { input ->
                dst.openOutput(newId).use { output -> input.copyTo(output, BUFFER_SIZE) }
            }
            return
        }
        for (child in src.children(node.id)) {
            fill(src, child, dst, create(child, dst, newId, child.name))
        }
    }

    /**
     * Files are created as `application/octet-stream`, which makes SAF providers
     * keep the name exactly instead of adding an extension; they derive the
     * type from the name anyway.
     */
    private fun create(node: DocNode, dst: DocTree, parentId: String, name: String): String =
        if (node.isDir) dst.createDir(parentId, name) else dst.createFile(parentId, name, DocTree.MIME_DEFAULT)

    private fun addToZip(tree: DocTree, node: DocNode, path: String, zip: ZipOutputStream, skipId: String) {
        if (node.id == skipId) return
        if (node.isDir) {
            zip.putNextEntry(ZipEntry("$path/").apply { if (node.modified > 0) time = node.modified })
            zip.closeEntry()
            for (child in tree.children(node.id)) {
                addToZip(tree, child, "$path/${child.name}", zip, skipId)
            }
            return
        }
        zip.putNextEntry(ZipEntry(path).apply { if (node.modified > 0) time = node.modified })
        tree.openInput(node.id).use { it.copyTo(zip, BUFFER_SIZE) }
        zip.closeEntry()
    }

    /** Zip files start with a local file header, or an end record when they are empty. */
    private fun looksLikeZip(tree: DocTree, id: String): Boolean {
        val header = ByteArray(4)
        val read = tree.openInput(id).use { input -> readFully(input, header) }
        if (read < 4 || header[0] != 'P'.code.toByte() || header[1] != 'K'.code.toByte()) return false
        return (header[2].toInt() == 3 && header[3].toInt() == 4) ||
            (header[2].toInt() == 5 && header[3].toInt() == 6) ||
            (header[2].toInt() == 7 && header[3].toInt() == 8)
    }

    private fun readFully(input: InputStream, buffer: ByteArray): Int {
        var filled = 0
        while (filled < buffer.size) {
            val read = input.read(buffer, filled, buffer.size - filled)
            if (read < 0) break
            filled += read
        }
        return filled
    }

    private fun extract(tree: DocTree, archiveId: String, rootId: String) {
        val dirs = HashMap<String, String>()
        val taken = HashMap<String, MutableSet<String>>()
        taken[rootId] = HashSet()

        fun dirFor(segments: List<String>): String {
            var current = rootId
            var relative = ""
            for (segment in segments) {
                relative = if (relative.isEmpty()) segment else "$relative/$segment"
                val parent = current
                current = dirs.getOrPut(relative) {
                    val names = taken.getValue(parent)
                    val free = Names.firstFree(segment, names)
                    names += free
                    tree.createDir(parent, free).also { taken[it] = HashSet() }
                }
            }
            return current
        }

        var skipped = 0
        val buffer = ByteArray(BUFFER_SIZE)
        tree.openInput(archiveId).use { raw ->
            ZipInputStream(raw.buffered(BUFFER_SIZE)).use { zip ->
                while (true) {
                    val entry = readingArchive { zip.nextEntry } ?: break
                    val segments = ZipPaths.safeSegments(entry.name)
                    if (segments == null) {
                        skipped++
                        continue
                    }
                    if (entry.isDirectory) {
                        dirFor(segments)
                        continue
                    }
                    val dirId = dirFor(segments.dropLast(1))
                    val names = taken.getValue(dirId)
                    val fileName = Names.firstFree(segments.last(), names)
                    names += fileName
                    val fileId = tree.createFile(dirId, fileName, DocTree.MIME_DEFAULT)
                    tree.openOutput(fileId).use { out ->
                        while (true) {
                            val read = readingArchive { zip.read(buffer) }
                            if (read < 0) break
                            out.write(buffer, 0, read)
                        }
                    }
                }
            }
        }
        if (skipped > 0) Log.w(TAG, "Skipped $skipped archive entries with unsafe paths")
    }

    /** Turns the ways a damaged archive fails into `unreadable`. */
    private inline fun <T> readingArchive(read: () -> T): T = try {
        read()
    } catch (e: ZipException) {
        throw StorageFailure("unreadable", e.message ?: "Damaged archive")
    } catch (e: EOFException) {
        throw StorageFailure("unreadable", e.message ?: "Archive ends early")
    } catch (e: IllegalArgumentException) {
        // Entry names that are not valid UTF-8.
        throw StorageFailure("unreadable", e.message ?: "Bad entry name")
    }

    fun nameOf(tree: DocTree, id: String, fallback: String): String = try {
        tree.node(id).name
    } catch (e: FileNotFoundException) {
        Log.w(TAG, "A new item could not be read back", e)
        fallback
    }

    private fun deleteLogged(tree: DocTree, id: String) {
        try {
            tree.delete(id)
        } catch (e: Exception) {
            Log.w(TAG, "Could not remove a partial result", e)
        }
    }
}
