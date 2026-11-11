package dev.chandra.chat_media_cleaner.storage

import java.io.InputStream
import java.security.MessageDigest

/** The app's trash folder inside each chat `Media` folder. */
object TrashFolder {
    /** Must match `MediaScanner.trashFolderName` in the Dart code. */
    const val NAME = ".media-cleaner-trash"

    /** Keeps gallery apps from showing trashed photos and videos. */
    const val NO_MEDIA = ".nomedia"
}

/** Content hashes for finding exact duplicates. */
object Hashing {
    private const val BUFFER_SIZE = 64 * 1024
    private val HEX = "0123456789abcdef".toCharArray()

    /** SHA-256 of everything [input] yields, as lowercase hex. Does not close [input]. */
    fun sha256Hex(input: InputStream): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(BUFFER_SIZE)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            digest.update(buffer, 0, read)
        }
        return toHex(digest.digest())
    }

    fun toHex(bytes: ByteArray): String {
        val chars = CharArray(bytes.size * 2)
        for ((i, b) in bytes.withIndex()) {
            val v = b.toInt() and 0xFF
            chars[i * 2] = HEX[v ushr 4]
            chars[i * 2 + 1] = HEX[v and 0x0F]
        }
        return String(chars)
    }
}

/** File names for files put back from the trash. */
object Names {
    /** `IMG.jpg` -> `IMG (2).jpg`; names without an extension get the number at the end. */
    fun numbered(name: String, n: Int): String {
        val dot = name.lastIndexOf('.')
        return if (dot > 0) {
            "${name.substring(0, dot)} ($n)${name.substring(dot)}"
        } else {
            "$name ($n)"
        }
    }

    /** [name] itself when it is free, otherwise the first numbered name that is. */
    fun firstFree(name: String, taken: Set<String>): String {
        if (name !in taken) return name
        var n = 1
        while (numbered(name, n) in taken) n++
        return numbered(name, n)
    }
}

/** Sizes for decoding thumbnails without loading full images into memory. */
object ThumbnailMath {
    /** The largest power-of-two sample size that keeps both sides at least [target]. */
    fun sampleSize(width: Int, height: Int, target: Int): Int {
        if (width <= 0 || height <= 0 || target <= 0) return 1
        var sample = 1
        while (width / (sample * 2) >= target && height / (sample * 2) >= target) {
            sample *= 2
        }
        return sample
    }

    /** Scales ([width], [height]) down so the longer side is at most [target]. */
    fun fit(width: Int, height: Int, target: Int): Pair<Int, Int> {
        val longer = maxOf(width, height)
        if (longer <= target || longer <= 0) return width to height
        val scale = target.toDouble() / longer
        return maxOf(1, (width * scale).toInt()) to maxOf(1, (height * scale).toInt())
    }
}

/** Bitmap sizes for drawing PDF pages. */
object PdfMath {
    /** Wider than this adds memory without adding anything a phone screen can show. */
    const val MAX_WIDTH = 2048

    /** About 32 MB as ARGB_8888; very tall pages are drawn narrower to stay below it. */
    const val MAX_PIXELS = 8_000_000L

    /**
     * The bitmap size for a page of [pageWidth] x [pageHeight] points drawn
     * [targetWidth] pixels wide, keeping the page's shape.
     */
    fun renderSize(pageWidth: Int, pageHeight: Int, targetWidth: Int): Pair<Int, Int> {
        if (pageWidth <= 0 || pageHeight <= 0) return 1 to 1
        var width = targetWidth.coerceIn(1, MAX_WIDTH)
        var height = maxOf(1, Math.round(width.toDouble() * pageHeight / pageWidth).toInt())
        if (width.toLong() * height > MAX_PIXELS) {
            val scale = Math.sqrt(MAX_PIXELS.toDouble() / (width.toLong() * height))
            width = maxOf(1, (width * scale).toInt())
            height = maxOf(1, (height * scale).toInt())
        }
        return width to height
    }
}

/** A storage failure with an error code the Dart side understands. */
class StorageFailure(val code: String, message: String) : Exception(message)
