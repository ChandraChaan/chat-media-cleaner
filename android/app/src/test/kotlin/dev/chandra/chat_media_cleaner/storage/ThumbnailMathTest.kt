package dev.chandra.chat_media_cleaner.storage

import org.junit.Assert.assertEquals
import org.junit.Test

class ThumbnailMathTest {
    @Test
    fun sampleSizeIsOneForSmallImages() {
        assertEquals(1, ThumbnailMath.sampleSize(200, 300, 256))
        assertEquals(1, ThumbnailMath.sampleSize(511, 4000, 256))
    }

    @Test
    fun sampleSizeIsTheLargestPowerOfTwoThatKeepsBothSidesBigEnough() {
        assertEquals(2, ThumbnailMath.sampleSize(512, 512, 256))
        assertEquals(8, ThumbnailMath.sampleSize(4000, 3000, 256))
        assertEquals(4, ThumbnailMath.sampleSize(1080, 2400, 256))
    }

    @Test
    fun sampleSizeHandlesUnknownSizes() {
        assertEquals(1, ThumbnailMath.sampleSize(0, 100, 256))
        assertEquals(1, ThumbnailMath.sampleSize(100, -1, 256))
    }

    @Test
    fun fitScalesTheLongerSideToTheTarget() {
        assertEquals(256 to 192, ThumbnailMath.fit(1024, 768, 256))
        assertEquals(115 to 256, ThumbnailMath.fit(1080, 2400, 256))
    }

    @Test
    fun fitLeavesSmallImagesAlone() {
        assertEquals(100 to 50, ThumbnailMath.fit(100, 50, 256))
    }

    @Test
    fun fitNeverReturnsZero() {
        assertEquals(1 to 256, ThumbnailMath.fit(10, 10000, 256))
    }
}
