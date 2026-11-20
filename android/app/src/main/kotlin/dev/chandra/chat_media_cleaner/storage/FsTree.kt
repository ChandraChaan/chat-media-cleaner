package dev.chandra.chat_media_cleaner.storage

import android.net.Uri
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/**
 * The file system, reached with all-files access. Ids are absolute paths.
 *
 * Android calls are injected so the tree works in JVM unit tests:
 * [mimeForExtension] wraps `MimeTypeMap`, [shareUriFor] builds a [FilesProvider]
 * URI, and [hidesOtherAppsDirs] is true on Android 11 and later.
 */
class FsTree(
    private val mimeForExtension: (String) -> String?,
    private val shareUriFor: (String) -> Uri = { Uri.fromFile(File(it)) },
    private val hidesOtherAppsDirs: Boolean = false,
    private val ownPackage: String? = null,
) : DocTree {
    override fun sameTree(other: DocTree): Boolean = other is FsTree

    override fun node(id: String): DocNode = nodeOf(existing(id))

    override fun exists(id: String): Boolean = file(id).exists()

    override fun children(dirId: String): List<DocNode> {
        val dir = existing(dirId)
        if (!dir.isDirectory) throw FileNotFoundException("$dirId is not a folder")
        if (hidesOtherAppsDirs && FsPaths.isOtherAppsDir(dir.path, ownPackage)) {
            throw SecurityException("Android does not let apps read ${dir.path}")
        }
        val files = dir.listFiles() ?: throw SecurityException("Can't read ${dir.path}")
        return files.map(::nodeOf)
    }

    override fun openInput(id: String): InputStream {
        val f = existing(id)
        if (f.isDirectory) throw FileNotFoundException("$id is a folder")
        if (!f.canRead()) throw SecurityException("Can't read $id")
        return FileInputStream(f)
    }

    override fun openOutput(id: String): OutputStream {
        val f = file(id)
        if (f.isDirectory) throw FileNotFoundException("$id is a folder")
        if (f.exists() && !f.canWrite()) throw SecurityException("Can't write $id")
        return FileOutputStream(f)
    }

    override fun createFile(parentId: String, name: String, mime: String): String {
        val target = newChild(parentId, name)
        if (!target.createNewFile()) throw StorageFailure("exists", name)
        return target.path
    }

    override fun createDir(parentId: String, name: String): String {
        val target = newChild(parentId, name)
        if (!target.mkdir()) {
            if (target.exists()) throw StorageFailure("exists", name)
            throw IOException("Could not create folder $name")
        }
        return target.path
    }

    override fun delete(id: String) {
        val f = existing(id)
        if (!f.deleteRecursively()) throw IOException("Could not delete $id")
    }

    override fun rename(id: String, newName: String): String {
        val f = existing(id)
        if (!FsPaths.isValidName(newName)) throw StorageFailure("invalid", "Bad name: $newName")
        val parent = f.parentFile ?: throw IOException("Can't rename $id")
        val target = File(parent, newName)
        // A change of case only is allowed on case-insensitive volumes.
        if (target.exists() && !newName.equals(f.name, ignoreCase = true)) {
            throw StorageFailure("exists", newName)
        }
        if (!f.renameTo(target)) throw IOException("Could not rename $id")
        return target.path
    }

    override fun moveWithin(id: String, fromParentId: String, toParentId: String, name: String): String? {
        val f = existing(id)
        val target = newChild(toParentId, name)
        return if (f.renameTo(target)) target.path else null
    }

    override fun isSameOrBelow(id: String, ancestorId: String): Boolean =
        FsPaths.isSameOrBelow(file(id).path, file(ancestorId).path)

    override fun pathOf(id: String): String = file(id).path

    override fun readUri(id: String): Uri = Uri.fromFile(file(id))

    override fun shareUri(id: String): Uri = shareUriFor(existing(id).path)

    override fun mimeOf(id: String): String = mimeFor(file(id))

    private fun nodeOf(f: File): DocNode {
        val dir = f.isDirectory
        return DocNode(
            id = f.path,
            name = f.name,
            isDir = dir,
            size = if (dir) 0L else f.length(),
            modified = f.lastModified(),
            mime = mimeFor(f),
        )
    }

    private fun mimeFor(f: File): String {
        if (f.isDirectory) return DocTree.MIME_DIR
        val dot = f.name.lastIndexOf('.')
        if (dot < 0 || dot == f.name.length - 1) return DocTree.MIME_DEFAULT
        return mimeForExtension(f.name.substring(dot + 1).lowercase()) ?: DocTree.MIME_DEFAULT
    }

    /** A child that doesn't exist yet, in a folder that does. */
    private fun newChild(parentId: String, name: String): File {
        if (!FsPaths.isValidName(name)) throw StorageFailure("invalid", "Bad name: $name")
        val parent = existing(parentId)
        if (!parent.isDirectory) throw FileNotFoundException("$parentId is not a folder")
        val target = File(parent, name)
        if (target.exists()) throw StorageFailure("exists", name)
        return target
    }

    private fun existing(id: String): File {
        val f = file(id)
        if (!f.exists()) throw FileNotFoundException(id)
        return f
    }

    private fun file(id: String): File {
        if (!id.startsWith("/")) throw FileNotFoundException("Not an absolute path: $id")
        return File(id)
    }
}
