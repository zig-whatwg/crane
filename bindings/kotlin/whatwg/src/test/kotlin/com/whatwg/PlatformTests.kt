package com.whatwg

import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for WhatWGPlatform initialization and configuration.
 * 
 * Note: Tests that require native library loading are tested in 
 * instrumented tests (androidTest).
 */
class PlatformTests {

    // MARK: - Platform Creation

    @Test
    fun testPlatformCreation() {
        val platform = WhatWGPlatform()
        assertNotNull(platform)
    }

    @Test
    fun testPlatformWithCustomEngine() {
        val platform = WhatWGPlatform()
        platform.engine = JSEngine.QUICKJS
        assertEquals(JSEngine.QUICKJS, platform.engine)
    }

    @Test
    fun testDefaultEngine() {
        val platform = WhatWGPlatform()
        assertEquals(JSEngine.QUICKJS, platform.engine)
    }

    // MARK: - Capability Configuration

    @Test
    fun testCapabilityEnumValues() {
        assertEquals(0, Capability.CLIPBOARD.value)
        assertEquals(1, Capability.TIMER.value)
        assertEquals(2, Capability.NETWORK.value)
        assertEquals(3, Capability.STORAGE.value)
        assertEquals(4, Capability.LAYOUT.value)
        assertEquals(5, Capability.UI.value)
    }

    @Test
    fun testAllCapabilitiesCount() {
        assertEquals(31, Capability.entries.size)
    }

    @Test
    fun testCapabilityNames() {
        assertEquals("CLIPBOARD", Capability.CLIPBOARD.name)
        assertEquals("NETWORK", Capability.NETWORK.name)
        assertEquals("STORAGE", Capability.STORAGE.name)
        assertEquals("GEOLOCATION", Capability.GEOLOCATION.name)
    }

    // MARK: - Provider Configuration (without native calls)

    @Test
    fun testSetClipboardProviderNull() {
        val platform = WhatWGPlatform()
        platform.clipboardProvider = null
        assertNull(platform.clipboardProvider)
    }

    @Test
    fun testSetTimerProviderNull() {
        val platform = WhatWGPlatform()
        platform.timerProvider = null
        assertNull(platform.timerProvider)
    }

    @Test
    fun testSetNetworkProviderNull() {
        val platform = WhatWGPlatform()
        platform.networkProvider = null
        assertNull(platform.networkProvider)
    }

    @Test
    fun testSetStorageProviderNull() {
        val platform = WhatWGPlatform()
        platform.storageProvider = null
        assertNull(platform.storageProvider)
    }

    // MARK: - JS Engine Tests

    @Test
    fun testJSEngineRecommended() {
        assertEquals(JSEngine.QUICKJS, JSEngine.recommended)
    }

    @Test
    fun testJSEngineDisplayNames() {
        assertEquals("V8", JSEngine.V8.displayName)
        assertEquals("JavaScriptCore", JSEngine.JAVASCRIPT_CORE.displayName)
        assertEquals("QuickJS", JSEngine.QUICKJS.displayName)
    }

    @Test
    fun testJSEngineValues() {
        assertEquals("v8", JSEngine.V8.value)
        assertEquals("jsc", JSEngine.JAVASCRIPT_CORE.value)
        assertEquals("quickjs", JSEngine.QUICKJS.value)
    }

    @Test
    fun testJSEngineIsAvailable() {
        // QuickJS should always be available
        assertTrue(JSEngine.QUICKJS.isAvailable)
    }

    // MARK: - Exception Tests

    @Test
    fun testWhatWGException() {
        val exception = WhatWGException("Test error")
        assertEquals("Test error", exception.message)
    }

    @Test
    fun testWhatWGExceptionWithCause() {
        val cause = RuntimeException("Cause")
        val exception = WhatWGException("Test error", cause)
        assertEquals("Test error", exception.message)
        assertEquals(cause, exception.cause)
    }

    // MARK: - AutoCloseable Tests

    @Test
    fun testPlatformClose() {
        val platform = WhatWGPlatform()
        // Should not throw
        platform.close()
    }

    @Test
    fun testPlatformUseBlock() {
        WhatWGPlatform().use { platform ->
            assertNotNull(platform)
        }
        // Platform should be closed after use block
    }
}
