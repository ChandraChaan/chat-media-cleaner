package dev.chandra.chat_media_cleaner.storage

import java.io.ByteArrayInputStream
import java.io.InputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class HashingTest {
    private fun hash(bytes: ByteArray) = Hashing.sha256Hex(ByteArrayInputStream(bytes))

    @Test
    fun matchesKnownSha256Values() {
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            hash(ByteArray(0)),
        )
        assertEquals(
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            hash("abc".toByteArray()),
        )
    }

    @Test
    fun hashesLargeInputAcrossBufferBoundaries() {
        // 200 KB of 'a' spans several 64 KB reads.
        val big = ByteArray(200 * 1024) { 'a'.code.toByte() }
        val chunked = object : InputStream() {
            private var pos = 0
            override fun read(): Int = if (pos < big.size) big[pos++].toInt() and 0xFF else -1
            override fun read(b: ByteArray, off: Int, len: Int): Int {
                if (pos >= big.size) return -1
                val n = minOf(len, 1000, big.size - pos)
                System.arraycopy(big, pos, b, off, n)
                pos += n
                return n
            }
        }
        assertEquals(hash(big), Hashing.sha256Hex(chunked))
    }

    @Test
    fun differentContentGivesDifferentHashes() {
        assertNotEquals(hash("IMG-1".toByteArray()), hash("IMG-2".toByteArray()))
        assertEquals(hash("same".toByteArray()), hash("same".toByteArray()))
    }

    @Test
    fun toHexPadsAndUsesLowercase() {
        assertEquals("000fff10", Hashing.toHex(byteArrayOf(0x00, 0x0F, 0xFF.toByte(), 0x10)))
    }
}
