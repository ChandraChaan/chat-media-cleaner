package dev.chandra.chat_media_cleaner.storage

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException

/**
 * Serves files on shared storage, read only, as
 * `content://<applicationId>.files/f/<path segments>`, so the video player and
 * other apps (through share and "open with" grants) can read files the app
 * reached with all-files access.
 *
 * It is not exported: other apps only get the URIs this app grants them. Only
 * files below shared storage are served (see [FsPaths.isServable]).
 */
class FilesProvider : ContentProvider() {
    companion object {
        private const val AUTHORITY_SUFFIX = ".files"
        private val DEFAULT_COLUMNS = arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)

        fun authority(context: Context): String = context.packageName + AUTHORITY_SUFFIX

        fun uriFor(authority: String, path: String): Uri {
            val builder = Uri.Builder().scheme("content").authority(authority).appendPath(FsPaths.FILE_PREFIX)
            for (segment in path.split('/')) {
                if (segment.isNotEmpty()) builder.appendPath(segment)
            }
            return builder.build()
        }

        fun mimeOf(name: String): String {
            val dot = name.lastIndexOf('.')
            if (dot < 0 || dot == name.length - 1) return DocTree.MIME_DEFAULT
            return MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substring(dot + 1).lowercase())
                ?: DocTree.MIME_DEFAULT
        }
    }

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val file = fileFor(uri)
        val columns = projection?.filter { it in DEFAULT_COLUMNS }?.toTypedArray() ?: DEFAULT_COLUMNS
        val row = columns.map { column ->
            when (column) {
                OpenableColumns.DISPLAY_NAME -> file.name
                else -> file.length()
            }
        }
        return MatrixCursor(columns, 1).apply { addRow(row) }
    }

    override fun getType(uri: Uri): String {
        val path = FsPaths.fromUriSegments(uri.pathSegments) ?: return DocTree.MIME_DEFAULT
        return mimeOf(File(path).name)
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if ('w' in mode || 'a' in mode || 't' in mode) throw SecurityException("Files are shared read only")
        return ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("Read only")

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Read only")

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Read only")

    /** The canonical file behind [uri], if it is one this provider may serve. */
    private fun fileFor(uri: Uri): File {
        val path = FsPaths.fromUriSegments(uri.pathSegments) ?: throw FileNotFoundException("Unknown URI")
        val file = File(path).canonicalFile
        @Suppress("DEPRECATION")
        val roots = listOfNotNull(Environment.getExternalStorageDirectory()?.absolutePath)
        if (!FsPaths.isServable(file.path, roots)) throw SecurityException("Not a shared file")
        if (!file.isFile) throw FileNotFoundException("Not a file")
        return file
    }
}
