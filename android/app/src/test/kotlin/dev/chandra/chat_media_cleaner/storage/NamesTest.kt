package dev.chandra.chat_media_cleaner.storage

import org.junit.Assert.assertEquals
import org.junit.Test

class NamesTest {
    @Test
    fun numberedKeepsTheExtension() {
        assertEquals("IMG-20240101-WA0001 (1).jpg", Names.numbered("IMG-20240101-WA0001.jpg", 1))
        assertEquals("archive.tar (2).gz", Names.numbered("archive.tar.gz", 2))
    }

    @Test
    fun numberedWithoutExtensionAppendsTheNumber() {
        assertEquals("notes (3)", Names.numbered("notes", 3))
        assertEquals(".nomedia (1)", Names.numbered(".nomedia", 1))
    }

    @Test
    fun firstFreeReturnsTheNameWhenItIsFree() {
        assertEquals("a.jpg", Names.firstFree("a.jpg", setOf("b.jpg")))
    }

    @Test
    fun firstFreeSkipsTakenNumbers() {
        val taken = setOf("a.jpg", "a (1).jpg", "a (2).jpg")
        assertEquals("a (3).jpg", Names.firstFree("a.jpg", taken))
    }
}
