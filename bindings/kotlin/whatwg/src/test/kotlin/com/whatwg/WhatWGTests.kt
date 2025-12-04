package com.whatwg

import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for WHATWG Platform.
 *
 * Note: Tests that require native library are skipped in unit tests.
 * Integration tests should be run on Android device/emulator.
 */
class WhatWGTests {

    // MARK: - Capability Tests

    @Test
    fun testCapabilityEnumValues() {
        assertEquals(0, Capability.CLIPBOARD.value)
        assertEquals(1, Capability.TIMER.value)
        assertEquals(2, Capability.NETWORK.value)
        assertEquals(3, Capability.STORAGE.value)
    }

    @Test
    fun testAllCapabilities() {
        assertEquals(31, Capability.entries.size)
    }

    // MARK: - JSEngine Tests

    @Test
    fun testJSEngineRecommended() {
        assertEquals(JSEngine.QUICKJS, JSEngine.recommended)
    }

    @Test
    fun testJSEngineDisplayNames() {
        assertEquals("V8", JSEngine.V8.displayName)
        assertEquals("QuickJS", JSEngine.QUICKJS.displayName)
    }

    @Test
    fun testJSEngineValues() {
        assertEquals("v8", JSEngine.V8.value)
        assertEquals("quickjs", JSEngine.QUICKJS.value)
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
}
