package dev.chandra.chat_media_cleaner.storage

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class FileOpsTest {
    @get:Rule
    val temp = TemporaryFolder()

    private val tree = FsTree(mimeForExtension = { if (it == "jpg") "image/jpeg" else null })
    private lateinit var root: File

    @Before
    fun setUp() {
        root = temp.newFolder("storage")
    }

    private fun dir(path: String): File = File(root, path).apply { mkdirs() }

    private fun file(path: String, text: String = path): File =
        File(root, path).apply {
            parentFile!!.mkdirs()
            writeText(text)
        }

    private fun expectFailure(code: String, block: () -> Unit) {
        try {
            block()
            fail("Expected $code")
        } catch (e: StorageFailure) {
            assertEquals(code, e.code)
        }
    }

    @Test
    fun nodeReportsFilesAndFolders() {
        val photo = file("DCIM/a.jpg", "12345")
        val node = tree.node(photo.path)
        assertEquals("a.jpg", node.name)
        assertEquals(5L, node.size)
        assertEquals("image/jpeg", node.mime)
        assertFalse(node.isDir)
        val folder = tree.node(dir("DCIM").path)
        assertTrue(folder.isDir)
        assertEquals(DocTree.MIME_DIR, folder.mime)
        assertEquals(DocTree.MIME_DEFAULT, tree.node(file("notes").path).mime)
    }

    @Test
    fun copyFileIntoTheSameFolderGetsANumberedName() {
        val photo = file("DCIM/a.jpg", "pixels")
        val first = FileOps.copyItem(tree, photo.path, tree, photo.parent!!)
        val second = FileOps.copyItem(tree, photo.path, tree, photo.parent!!)
        assertEquals("a (1).jpg", first.name)
        assertEquals("a (2).jpg", second.name)
        assertEquals("pixels", File(first.id).readText())
        assertEquals("pixels", photo.readText())
    }

    @Test
    fun copyFolderIsRecursiveAndNumbered() {
        file("src/Media/x.txt", "x")
        file("src/Media/sub/y.txt", "y")
        dir("src/Media/empty")
        dir("dst/Media")
        val copied = FileOps.copyItem(tree, File(root, "src/Media").path, tree, File(root, "dst").path)
        assertEquals("Media (1)", copied.name)
        val target = File(copied.id)
        assertEquals("x", File(target, "x.txt").readText())
        assertEquals("y", File(target, "sub/y.txt").readText())
        assertTrue(File(target, "empty").isDirectory)
        assertTrue(File(root, "src/Media/x.txt").exists())
    }

    @Test
    fun copyFolderIntoItselfIsInvalid() {
        file("a/b/c.txt")
        expectFailure("invalid") { FileOps.copyItem(tree, File(root, "a").path, tree, File(root, "a").path) }
        expectFailure("invalid") { FileOps.copyItem(tree, File(root, "a").path, tree, File(root, "a/b").path) }
    }

    @Test
    fun copyIntoASiblingWithAPrefixNameIsAllowed() {
        file("a/c.txt")
        dir("ab")
        val copied = FileOps.copyItem(tree, File(root, "a").path, tree, File(root, "ab").path)
        assertEquals("a", copied.name)
        assertTrue(File(root, "ab/a/c.txt").exists())
    }

    @Test
    fun moveIntoTheSameParentChangesNothing() {
        val photo = file("DCIM/a.jpg")
        val moved = FileOps.moveItem(tree, photo.path, photo.parent!!, tree, photo.parent!! + "/")
        assertEquals(photo.path, moved.id)
        assertEquals("a.jpg", moved.name)
        assertTrue(photo.exists())
    }

    @Test
    fun moveIntoItselfIsInvalid() {
        file("a/b/c.txt")
        expectFailure("invalid") { FileOps.moveItem(tree, File(root, "a").path, root.path, tree, File(root, "a/b").path) }
        expectFailure("invalid") { FileOps.moveItem(tree, File(root, "a").path, root.path, tree, File(root, "a").path) }
        assertTrue(File(root, "a/b/c.txt").exists())
    }

    @Test
    fun moveNumbersTheNameWhenItIsTaken() {
        val photo = file("from/a.jpg", "new")
        file("to/a.jpg", "old")
        val moved = FileOps.moveItem(tree, photo.path, photo.parent!!, tree, File(root, "to").path)
        assertEquals("a (1).jpg", moved.name)
        assertEquals("new", File(moved.id).readText())
        assertEquals("old", File(root, "to/a.jpg").readText())
        assertFalse(photo.exists())
    }

    @Test
    fun moveFolderTakesItsContents() {
        file("from/Media/x.txt", "x")
        dir("to")
        val moved = FileOps.moveItem(tree, File(root, "from/Media").path, File(root, "from").path, tree, File(root, "to").path)
        assertEquals("Media", moved.name)
        assertEquals("x", File(root, "to/Media/x.txt").readText())
        assertFalse(File(root, "from/Media").exists())
    }

    @Test
    fun moveOrCopyFallsBackToCopyAndDelete() {
        val noRename = object : DocTree by tree {
            override fun moveWithin(id: String, fromParentId: String, toParentId: String, name: String): String? = null
        }
        file("from/sub/x.txt", "x")
        dir("to")
        val id = FileOps.moveOrCopy(noRename, File(root, "from/sub").path, File(root, "from").path, File(root, "to").path, "sub2")
        assertEquals(File(root, "to/sub2").path, id)
        assertEquals("x", File(root, "to/sub2/x.txt").readText())
        assertFalse(File(root, "from/sub").exists())
    }

    @Test
    fun folderSizeCountsEverythingBelow() {
        file("m/a.bin", "12345")
        file("m/s/b.bin", "123")
        dir("m/s/t")
        assertEquals(FolderSize(8L, 2, 2), FileOps.folderSize(tree, File(root, "m").path))
        assertEquals(FolderSize(5L, 1, 0), FileOps.folderSize(tree, File(root, "m/a.bin").path))
    }

    @Test
    fun createFolderReportsAClash() {
        dir("parent/taken")
        val made = FileOps.createFolder(tree, File(root, "parent").path, "new")
        assertEquals("new", made.name)
        assertTrue(File(made.id).isDirectory)
        expectFailure("exists") { FileOps.createFolder(tree, File(root, "parent").path, "taken") }
        expectFailure("invalid") { FileOps.createFolder(tree, File(root, "parent").path, "a/b") }
        expectFailure("invalid") { FileOps.createFolder(tree, File(root, "parent").path, "..") }
    }

    @Test
    fun deleteIsRecursive() {
        file("gone/a/b/c.txt")
        FileOps.deleteItem(tree, File(root, "gone").path)
        assertFalse(File(root, "gone").exists())
        try {
            FileOps.deleteItem(tree, File(root, "gone").path)
            fail("Expected not found")
        } catch (_: FileNotFoundException) {
            // Expected.
        }
    }

    @Test
    fun renameReportsAClashAndAllowsCaseChanges() {
        val a = file("r/a.txt")
        file("r/b.txt")
        expectFailure("exists") { tree.rename(a.path, "b.txt") }
        val renamed = tree.rename(a.path, "c.txt")
        assertEquals(File(root, "r/c.txt").path, renamed)
    }

    @Test
    fun zipAndUnzipRoundTrip() {
        file("z/Media/a.txt", "alpha")
        file("z/Media/sub/b.txt", "beta")
        dir("z/Media/empty")
        file("z/c.txt", "gamma")
        file("z/pack.zip", "taken")
        val zip = FileOps.zipItems(
            tree,
            listOf(File(root, "z/Media").path, File(root, "z/c.txt").path),
            File(root, "z").path,
            "pack.zip",
        )
        assertEquals("pack (1).zip", zip.name)
        ZipFile(zip.id).use { archive ->
            val names = archive.entries().toList().map { it.name }.toSet()
            assertEquals(setOf("Media/", "Media/a.txt", "Media/sub/", "Media/sub/b.txt", "Media/empty/", "c.txt"), names)
        }

        dir("out")
        val unpacked = FileOps.unzip(tree, zip.id, File(root, "out").path)
        assertEquals("pack (1)", unpacked.name)
        val out = File(unpacked.id)
        assertEquals("alpha", File(out, "Media/a.txt").readText())
        assertEquals("beta", File(out, "Media/sub/b.txt").readText())
        assertTrue(File(out, "Media/empty").isDirectory)
        assertEquals("gamma", File(out, "c.txt").readText())

        val again = FileOps.unzip(tree, zip.id, File(root, "out").path)
        assertEquals("pack (1) (1)", again.name)
    }

    @Test
    fun zipInsideAZippedFolderLeavesTheArchiveOut() {
        file("self/a.txt", "a")
        val zip = FileOps.zipItems(tree, listOf(File(root, "self").path), File(root, "self").path, "self.zip")
        ZipFile(zip.id).use { archive ->
            assertEquals(setOf("self/", "self/a.txt"), archive.entries().toList().map { it.name }.toSet())
        }
    }

    @Test
    fun unzipSkipsEntriesThatEscapeTheFolder() {
        val evil = File(root, "in/evil.zip").apply { parentFile!!.mkdirs() }
        ZipOutputStream(FileOutputStream(evil)).use { zip ->
            for (name in listOf("../escape.txt", "/abs.txt", "a\\..\\b.txt", "ok/../../x.txt", "C:/win.txt", "good/file.txt", "./dot.txt")) {
                zip.putNextEntry(ZipEntry(name))
                zip.write(name.toByteArray())
                zip.closeEntry()
            }
        }
        val unpacked = FileOps.unzip(tree, evil.path, File(root, "in").path)
        assertEquals("evil", unpacked.name)
        val out = File(unpacked.id)
        assertEquals("good/file.txt", File(out, "good/file.txt").readText())
        assertEquals("./dot.txt", File(out, "dot.txt").readText())
        assertEquals(setOf("good", "dot.txt"), out.list()!!.toSet())
        assertFalse(File(root, "escape.txt").exists())
        assertFalse(File(root, "x.txt").exists())
        assertEquals(setOf("evil.zip", "evil"), File(root, "in").list()!!.toSet())
    }

    @Test
    fun unzipOfACorruptArchiveFailsAndCleansUp() {
        file("bad/notzip.zip", "hello, this is not an archive")
        expectFailure("unreadable") { FileOps.unzip(tree, File(root, "bad/notzip.zip").path, File(root, "bad").path) }

        val whole = File(root, "bad/whole.zip")
        ZipOutputStream(FileOutputStream(whole)).use { zip ->
            zip.putNextEntry(ZipEntry("big.bin"))
            zip.write(ByteArray(200_000) { (it * 31 % 251).toByte() })
            zip.closeEntry()
        }
        val bytes = whole.readBytes()
        val cut = File(root, "bad/cut.zip").apply { writeBytes(bytes.copyOf(bytes.size / 3)) }
        whole.delete()
        expectFailure("unreadable") { FileOps.unzip(tree, cut.path, File(root, "bad").path) }
        assertEquals(setOf("notzip.zip", "cut.zip"), File(root, "bad").list()!!.toSet())
    }

    @Test
    fun copyBetweenTreesKeepsBytes() {
        val other = FsTree(mimeForExtension = { null })
        val data = ByteArray(150_000) { (it % 256).toByte() }
        val src = File(root, "bin/data.bin").apply {
            parentFile!!.mkdirs()
            writeBytes(data)
        }
        dir("dest")
        val copied = FileOps.copyItem(tree, src.path, other, File(root, "dest").path)
        assertArrayEquals(data, File(copied.id).readBytes())
    }
}
