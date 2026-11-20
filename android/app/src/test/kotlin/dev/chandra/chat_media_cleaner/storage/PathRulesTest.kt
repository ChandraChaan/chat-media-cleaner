package dev.chandra.chat_media_cleaner.storage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PathRulesTest {
    private val roots = listOf("/storage/emulated/0")

    @Test
    fun servesSharedStorage() {
        assertTrue(FsPaths.isServable("/storage/emulated/0/DCIM/a.jpg", roots))
        assertTrue(FsPaths.isServable("/storage/1234-ABCD/Movies/b.mp4", roots))
        assertTrue(FsPaths.isServable("/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/x.jpg", roots))
        assertTrue(FsPaths.isServable("/mnt/sdcard/a.jpg", listOf("/mnt/sdcard")))
    }

    @Test
    fun refusesPrivateAndSystemFiles() {
        assertFalse(FsPaths.isServable("/data/data/dev.chandra.chat_media_cleaner/shared_prefs/a.xml", roots))
        assertFalse(FsPaths.isServable("/data/user/0/x/files/y", roots))
        assertFalse(FsPaths.isServable("/proc/self/maps", roots))
        assertFalse(FsPaths.isServable("/storage", roots))
        assertFalse(FsPaths.isServable("/storage/emulated/0/Android/data/com.whatsapp/files/key", roots))
        assertFalse(FsPaths.isServable("/storage/emulated/0/android/OBB/com.game/main.obb", roots))
        assertFalse(FsPaths.isServable("/storage/emulated/0/../../data/x", roots))
        assertFalse(FsPaths.isServable("relative/path", roots))
        assertFalse(FsPaths.isServable("/storage/emulated/0/a\u0000b", roots))
        assertFalse(FsPaths.isServable("/etc/hosts", listOf("", "/")))
    }

    @Test
    fun otherAppsDirsAreHiddenButOursIsNot() {
        val own = "dev.chandra.chat_media_cleaner"
        assertTrue(FsPaths.isOtherAppsDir("/storage/emulated/0/Android/data", own))
        assertTrue(FsPaths.isOtherAppsDir("/storage/emulated/0/Android/obb", own))
        assertTrue(FsPaths.isOtherAppsDir("/storage/emulated/0/Android/data/com.whatsapp", own))
        assertTrue(FsPaths.isOtherAppsDir("/storage/1234-ABCD/Android/data/com.x/files", own))
        assertFalse(FsPaths.isOtherAppsDir("/storage/emulated/0/Android/data/$own/files", own))
        assertFalse(FsPaths.isOtherAppsDir("/storage/emulated/0/Android/media/com.whatsapp", own))
        assertFalse(FsPaths.isOtherAppsDir("/storage/emulated/0/Android", own))
        assertFalse(FsPaths.isOtherAppsDir("/storage/emulated/0/DCIM/Android/data", own))
    }

    @Test
    fun uriSegmentsBecomeAnAbsolutePath() {
        assertEquals(
            "/storage/emulated/0/My Files/a b.jpg",
            FsPaths.fromUriSegments(listOf("f", "storage", "emulated", "0", "My Files", "a b.jpg")),
        )
        assertNull(FsPaths.fromUriSegments(listOf("x", "storage")))
        assertNull(FsPaths.fromUriSegments(listOf("f")))
        assertNull(FsPaths.fromUriSegments(listOf("f", "storage", "..", "data")))
        assertNull(FsPaths.fromUriSegments(listOf("f", "storage/emulated")))
    }

    @Test
    fun sameOrBelowComparesWholeSegments() {
        assertTrue(FsPaths.isSameOrBelow("/a/b", "/a"))
        assertTrue(FsPaths.isSameOrBelow("/a", "/a/"))
        assertFalse(FsPaths.isSameOrBelow("/ab", "/a"))
        assertFalse(FsPaths.isSameOrBelow("/a", "/a/b"))
    }

    @Test
    fun validNames() {
        assertTrue(FsPaths.isValidName("photo.jpg"))
        assertTrue(FsPaths.isValidName(".nomedia"))
        assertFalse(FsPaths.isValidName(""))
        assertFalse(FsPaths.isValidName("."))
        assertFalse(FsPaths.isValidName(".."))
        assertFalse(FsPaths.isValidName("a/b"))
    }

    @Test
    fun zipEntryPaths() {
        assertEquals(listOf("a", "b.txt"), ZipPaths.safeSegments("a/b.txt"))
        assertEquals(listOf("dir"), ZipPaths.safeSegments("dir/"))
        assertEquals(listOf("a", "b"), ZipPaths.safeSegments("./a//b"))
        assertNull(ZipPaths.safeSegments("../x"))
        assertNull(ZipPaths.safeSegments("a/../../x"))
        assertNull(ZipPaths.safeSegments("a/.."))
        assertNull(ZipPaths.safeSegments("/etc/passwd"))
        assertNull(ZipPaths.safeSegments("a\\b"))
        assertNull(ZipPaths.safeSegments("C:/x"))
        assertNull(ZipPaths.safeSegments(""))
        assertNull(ZipPaths.safeSegments("./"))
    }
}
