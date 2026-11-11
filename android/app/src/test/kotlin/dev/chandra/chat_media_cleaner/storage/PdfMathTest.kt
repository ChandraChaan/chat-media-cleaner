package dev.chandra.chat_media_cleaner.storage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PdfMathTest {
    @Test
    fun keepsThePageShape() {
        // A4 is 595 x 842 points.
        assertEquals(1080 to 1528, PdfMath.renderSize(595, 842, 1080))
    }

    @Test
    fun limitsTheWidth() {
        val (w, h) = PdfMath.renderSize(595, 842, 10_000)
        assertEquals(PdfMath.MAX_WIDTH, w)
        assertEquals(2898, h)
    }

    @Test
    fun drawsVeryTallPagesSmaller() {
        val (w, h) = PdfMath.renderSize(100, 2000, 2000)
        assertTrue(w.toLong() * h <= PdfMath.MAX_PIXELS)
        // Still 1:20.
        assertEquals(20.0, h.toDouble() / w, 0.1)
    }

    @Test
    fun survivesBrokenPageSizes() {
        assertEquals(1 to 1, PdfMath.renderSize(0, 842, 1080))
        assertEquals(1 to 1, PdfMath.renderSize(595, -1, 1080))
    }

    @Test
    fun neverReturnsZero() {
        assertEquals(1 to 1, PdfMath.renderSize(5000, 1, 0))
    }
}
