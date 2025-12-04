package com.whatwg.compose

import android.graphics.Color
import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for WebViewConfiguration.
 */
class WebViewConfigTests {

    // MARK: - Default Configuration

    @Test
    fun testDefaultConfiguration() {
        val config = WebViewConfiguration.Default

        assertTrue(config.javaScriptEnabled)
        assertTrue(config.allowsZooming)
        assertEquals(1f, config.minimumZoomScale)
        assertEquals(4f, config.maximumZoomScale)
        assertTrue(config.allowsBackForwardNavigationGestures)
        assertEquals(Color.WHITE, config.backgroundColor)
        assertNull(config.customUserAgent)
        assertTrue(config.domStorageEnabled)
        assertTrue(config.databaseEnabled)
        assertFalse(config.allowFileAccess)
        assertEquals(
            WebViewConfiguration.MediaPlaybackPolicy.USER_GESTURE_REQUIRED,
            config.mediaPlaybackPolicy
        )
    }

    // MARK: - Minimal Configuration

    @Test
    fun testMinimalConfiguration() {
        val config = WebViewConfiguration.Minimal

        assertFalse(config.javaScriptEnabled)
        assertFalse(config.allowsZooming)
        assertFalse(config.allowsBackForwardNavigationGestures)
        assertFalse(config.domStorageEnabled)
        assertFalse(config.databaseEnabled)
        assertEquals(
            WebViewConfiguration.MediaPlaybackPolicy.NEVER_ALLOW,
            config.mediaPlaybackPolicy
        )
    }

    // MARK: - Reader Configuration

    @Test
    fun testReaderConfiguration() {
        val config = WebViewConfiguration.Reader

        assertTrue(config.allowsZooming)
        assertEquals(6f, config.maximumZoomScale)
        assertEquals(
            WebViewConfiguration.MediaPlaybackPolicy.NEVER_ALLOW,
            config.mediaPlaybackPolicy
        )
    }

    // MARK: - Kiosk Configuration

    @Test
    fun testKioskConfiguration() {
        val config = WebViewConfiguration.Kiosk

        assertFalse(config.allowsZooming)
        assertFalse(config.allowsBackForwardNavigationGestures)
    }

    // MARK: - Custom Configuration

    @Test
    fun testCustomConfiguration() {
        val config = WebViewConfiguration(
            javaScriptEnabled = false,
            allowsZooming = true,
            minimumZoomScale = 0.5f,
            maximumZoomScale = 10f,
            allowsBackForwardNavigationGestures = false,
            backgroundColor = Color.BLACK,
            customUserAgent = "MyApp/1.0",
            domStorageEnabled = true,
            databaseEnabled = false,
            allowFileAccess = true,
            mediaPlaybackPolicy = WebViewConfiguration.MediaPlaybackPolicy.ALWAYS_ALLOW
        )

        assertFalse(config.javaScriptEnabled)
        assertTrue(config.allowsZooming)
        assertEquals(0.5f, config.minimumZoomScale)
        assertEquals(10f, config.maximumZoomScale)
        assertFalse(config.allowsBackForwardNavigationGestures)
        assertEquals(Color.BLACK, config.backgroundColor)
        assertEquals("MyApp/1.0", config.customUserAgent)
        assertTrue(config.domStorageEnabled)
        assertFalse(config.databaseEnabled)
        assertTrue(config.allowFileAccess)
        assertEquals(
            WebViewConfiguration.MediaPlaybackPolicy.ALWAYS_ALLOW,
            config.mediaPlaybackPolicy
        )
    }

    // MARK: - Media Playback Policy

    @Test
    fun testMediaPlaybackPolicies() {
        assertEquals(3, WebViewConfiguration.MediaPlaybackPolicy.entries.size)
        assertTrue(WebViewConfiguration.MediaPlaybackPolicy.entries.containsAll(listOf(
            WebViewConfiguration.MediaPlaybackPolicy.ALWAYS_ALLOW,
            WebViewConfiguration.MediaPlaybackPolicy.USER_GESTURE_REQUIRED,
            WebViewConfiguration.MediaPlaybackPolicy.NEVER_ALLOW
        )))
    }

    // MARK: - Copy Behavior

    @Test
    fun testConfigurationCopy() {
        val original = WebViewConfiguration(
            javaScriptEnabled = true,
            allowsZooming = true
        )
        
        val copy = original.copy(javaScriptEnabled = false)

        assertTrue(original.javaScriptEnabled)
        assertFalse(copy.javaScriptEnabled)
        assertEquals(original.allowsZooming, copy.allowsZooming)
    }
}
