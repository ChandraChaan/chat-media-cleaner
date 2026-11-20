package dev.chandra.chat_media_cleaner.storage

/** Pure rules about file-system paths, kept free of Android calls so they can be unit tested. */
object FsPaths {
    /** `<volume>/Android/data` or `<volume>/Android/obb`, and the package folder below it. */
    private val APP_DIR = Regex(
        "^/storage/(?:emulated/\\d+|[^/]+)/Android/(?:data|obb)(?:/([^/]+))?(?:/.*)?$",
        RegexOption.IGNORE_CASE,
    )

    /** Whether [path] is [ancestor] itself or inside it. Both must be normalized. */
    fun isSameOrBelow(path: String, ancestor: String): Boolean {
        val root = ancestor.trimEnd('/')
        return path == root || path.startsWith("$root/") || root.isEmpty()
    }

    /**
     * Whether [path] is another app's private folder on shared storage, which
     * Android 11 and later hide even with all-files access. [ownPackage]'s own
     * folders stay readable.
     */
    fun isOtherAppsDir(path: String, ownPackage: String?): Boolean {
        val match = APP_DIR.matchEntire(path) ?: return false
        val pkg = match.groupValues[1]
        return pkg.isEmpty() || ownPackage == null || pkg != ownPackage
    }

    /**
     * Whether [FilesProvider] may hand out [canonicalPath]: only files on shared
     * storage (below one of [externalRoots] or `/storage/`), never app-private
     * folders.
     */
    fun isServable(canonicalPath: String, externalRoots: List<String>): Boolean {
        if (!canonicalPath.startsWith("/") || canonicalPath.contains('\u0000')) return false
        val segments = canonicalPath.split('/')
        if (segments.any { it == ".." || it == "." }) return false
        val roots = externalRoots.filter { it.startsWith("/") && it.trimEnd('/').isNotEmpty() } + "/storage"
        val inside = roots.any { root ->
            val r = root.trimEnd('/')
            canonicalPath.startsWith("$r/")
        }
        return inside && !isOtherAppsDir(canonicalPath, ownPackage = null)
    }

    /** The absolute path from a [FilesProvider] URI's path segments (`f`, then the path's segments). */
    fun fromUriSegments(segments: List<String>): String? {
        if (segments.size < 2 || segments[0] != FILE_PREFIX) return null
        val parts = segments.drop(1)
        if (parts.any { it.isEmpty() || it == "." || it == ".." || it.contains('/') }) return null
        return "/" + parts.joinToString("/")
    }

    /** A file or folder name that is safe to create: no separators, not `.` or `..`. */
    fun isValidName(name: String): Boolean =
        name.isNotEmpty() && name != "." && name != ".." &&
            !name.contains('/') && !name.contains('\u0000')

    const val FILE_PREFIX = "f"
}

/** Guards against archive entries that would escape the folder they are unpacked into. */
object ZipPaths {
    /**
     * The path segments to unpack the entry [name] to, or null when the entry
     * must be skipped: absolute paths, `..`, backslashes, drive letters and
     * names that end up empty.
     */
    fun safeSegments(name: String): List<String>? {
        if (name.isEmpty() || name.startsWith("/") || name.contains('\\') || name.contains('\u0000')) {
            return null
        }
        val segments = name.split('/').filter { it.isNotEmpty() && it != "." }
        if (segments.isEmpty()) return null
        if (segments.any { it == ".." }) return null
        if (segments[0].length == 2 && segments[0][1] == ':') return null
        return segments
    }
}
