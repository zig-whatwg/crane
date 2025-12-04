package com.whatwg.compose

import org.junit.Test
import org.junit.Assert.*
import java.net.URL

/**
 * Unit tests for WhatWGBrowser Compose component.
 * 
 * Note: Tests that require Android context or native library are in
 * instrumented tests (androidTest).
 */
class BrowserTests {

    // MARK: - Navigation State Tests

    @Test
    fun testEmptyNavigationState() {
        val state = NavigationState()

        assertNull(state.url)
        assertTrue(state.title.isEmpty())
        assertFalse(state.isLoading)
        assertEquals(0f, state.loadingProgress)
        assertFalse(state.canGoBack)
        assertFalse(state.canGoForward)
        assertFalse(state.isSecure)
    }

    @Test
    fun testNavigationStateLoading() {
        val url = URL("https://example.com")
        val state = NavigationState.loading(url)

        assertEquals(url, state.url)
        assertTrue(state.isLoading)
        assertEquals(0f, state.loadingProgress)
    }

    @Test
    fun testNavigationStateLoaded() {
        val url = URL("https://example.com")
        val state = NavigationState.loaded(url, "Example")

        assertEquals(url, state.url)
        assertEquals("Example", state.title)
        assertFalse(state.isLoading)
        assertEquals(1f, state.loadingProgress)
        assertTrue(state.isSecure)
    }

    @Test
    fun testNavigationStateHttpInsecure() {
        val url = URL("http://example.com")
        val state = NavigationState.loaded(url, "Example")

        assertFalse(state.isSecure)
        assertEquals(SecurityState.SecurityLevel.NONE, state.securityState.level)
    }

    @Test
    fun testNavigationStateHttpsSecure() {
        val url = URL("https://example.com")
        val state = NavigationState.loaded(url, "Example")

        assertTrue(state.isSecure)
        assertEquals(SecurityState.SecurityLevel.SECURE, state.securityState.level)
    }

    @Test
    fun testNavigationStateDerivedProperties() {
        val url = URL("https://example.com/path")
        val state = NavigationState(
            url = url,
            title = "Test"
        )

        assertTrue(state.hasContent)
        assertEquals("https://example.com/path", state.urlString)
        assertEquals("example.com", state.host)
        assertEquals("https", state.scheme)
    }

    @Test
    fun testEmptyNavigationStateDerivedProperties() {
        val state = NavigationState.Empty

        assertFalse(state.hasContent)
        assertEquals("", state.urlString)
        assertNull(state.host)
        assertNull(state.scheme)
    }

    // MARK: - Browser Tab Tests

    @Test
    fun testBrowserTabCreation() {
        val tab = BrowserTab()

        assertNotNull(tab.id)
        assertFalse(tab.isActive)
        assertFalse(tab.isPinned)
        assertFalse(tab.isMuted)
        assertFalse(tab.isPlayingAudio)
        assertNull(tab.parentTabId)
    }

    @Test
    fun testBrowserTabActive() {
        val tab = BrowserTab(isActive = true)
        assertTrue(tab.isActive)
    }

    @Test
    fun testBrowserTabUniqueness() {
        val tab1 = BrowserTab()
        val tab2 = BrowserTab()

        assertNotEquals(tab1.id, tab2.id)
    }

    @Test
    fun testBrowserTabTimestamps() {
        val before = System.currentTimeMillis()
        val tab = BrowserTab()
        val after = System.currentTimeMillis()

        assertTrue(tab.createdAt in before..after)
        assertTrue(tab.lastAccessedAt in before..after)
    }

    // MARK: - History Entry Tests

    @Test
    fun testHistoryEntryCreation() {
        val url = URL("https://example.com")
        val entry = HistoryEntry(url = url, title = "Example")

        assertEquals(url, entry.url)
        assertEquals("Example", entry.title)
        assertNotNull(entry.visitedAt)
        assertNull(entry.faviconUrl)
    }

    @Test
    fun testHistoryEntryWithFavicon() {
        val url = URL("https://example.com")
        val faviconUrl = "https://example.com/favicon.ico"
        val entry = HistoryEntry(url = url, title = "Example", faviconUrl = faviconUrl)

        assertEquals(faviconUrl, entry.faviconUrl)
    }

    @Test
    fun testHistoryEntryWithScrollPosition() {
        val url = URL("https://example.com")
        val scrollPos = ScrollPosition(100f, 200f)
        val entry = HistoryEntry(url = url, title = "Example", scrollPosition = scrollPos)

        assertEquals(100f, entry.scrollPosition?.x)
        assertEquals(200f, entry.scrollPosition?.y)
    }

    // MARK: - Browser Error Tests

    @Test
    fun testInvalidUrlError() {
        val error = BrowserError.InvalidUrl("not a url")
        assertEquals("not a url", error.url)
        assertTrue(error.message!!.contains("not a url"))
    }

    @Test
    fun testNetworkError() {
        val error = BrowserError.NetworkError("Connection failed", 500)
        assertEquals("Connection failed", error.message)
        assertEquals(500, error.statusCode)
    }

    @Test
    fun testNetworkErrorWithoutStatusCode() {
        val error = BrowserError.NetworkError("Connection failed")
        assertEquals("Connection failed", error.message)
        assertNull(error.statusCode)
    }

    @Test
    fun testScriptError() {
        val error = BrowserError.ScriptError(
            message = "Syntax error",
            line = 10,
            column = 5,
            sourceUrl = "test.js"
        )

        assertEquals("Syntax error", error.message)
        assertEquals(10, error.line)
        assertEquals(5, error.column)
        assertEquals("test.js", error.sourceUrl)
    }

    @Test
    fun testTimeoutError() {
        val error = BrowserError.Timeout()
        assertTrue(error.message!!.contains("timed out"))
    }

    @Test
    fun testCancelledError() {
        val error = BrowserError.Cancelled()
        assertTrue(error.message!!.contains("cancelled"))
    }

    @Test
    fun testEngineUnavailableError() {
        val error = BrowserError.EngineUnavailable()
        assertTrue(error.message!!.contains("not available"))
    }

    @Test
    fun testUnknownError() {
        val cause = RuntimeException("Root cause")
        val error = BrowserError.Unknown("Something went wrong", cause)

        assertEquals("Something went wrong", error.message)
        assertEquals(cause, error.cause)
    }

    // MARK: - Navigation Event Tests

    @Test
    fun testNavigationEventStarted() {
        val url = URL("https://example.com")
        val event = NavigationEvent.Started(url)

        assertEquals(url, event.url)
    }

    @Test
    fun testNavigationEventFinished() {
        val url = URL("https://example.com")
        val event = NavigationEvent.Finished(url)

        assertEquals(url, event.url)
    }

    @Test
    fun testNavigationEventFailed() {
        val error = BrowserError.Timeout()
        val event = NavigationEvent.Failed(error)

        assertTrue(event.error is BrowserError.Timeout)
    }

    @Test
    fun testNavigationEventRedirected() {
        val from = URL("http://example.com")
        val to = URL("https://example.com")
        val event = NavigationEvent.Redirected(from, to)

        assertEquals(from, event.from)
        assertEquals(to, event.to)
    }

    // MARK: - Console Message Tests

    @Test
    fun testConsoleMessageCreation() {
        val message = ConsoleMessage(
            level = ConsoleMessage.Level.LOG,
            text = "Test message",
            source = "test.js",
            line = 42
        )

        assertEquals(ConsoleMessage.Level.LOG, message.level)
        assertEquals("Test message", message.text)
        assertEquals("test.js", message.source)
        assertEquals(42, message.line)
    }

    @Test
    fun testConsoleMessageLevels() {
        assertEquals(5, ConsoleMessage.Level.entries.size)
        assertTrue(ConsoleMessage.Level.entries.containsAll(listOf(
            ConsoleMessage.Level.LOG,
            ConsoleMessage.Level.INFO,
            ConsoleMessage.Level.WARN,
            ConsoleMessage.Level.ERROR,
            ConsoleMessage.Level.DEBUG
        )))
    }

    @Test
    fun testConsoleMessageTimestamp() {
        val before = System.currentTimeMillis()
        val message = ConsoleMessage(level = ConsoleMessage.Level.LOG, text = "Test")
        val after = System.currentTimeMillis()

        assertTrue(message.timestamp in before..after)
    }

    // MARK: - JavaScript Result Tests

    @Test
    fun testJavaScriptResultSuccess() {
        val result = JavaScriptResult.Success("hello")

        assertTrue(result is JavaScriptResult.Success)
        assertEquals("hello", (result as JavaScriptResult.Success).value)
    }

    @Test
    fun testJavaScriptResultSuccessNull() {
        val result = JavaScriptResult.Success(null)

        assertNull((result as JavaScriptResult.Success).value)
    }

    @Test
    fun testJavaScriptResultError() {
        val error = BrowserError.ScriptError("Error", 1, 1)
        val result = JavaScriptResult.Error(error)

        assertTrue(result is JavaScriptResult.Error)
        assertEquals("Error", (result as JavaScriptResult.Error).error.message)
    }

    // MARK: - Security State Tests

    @Test
    fun testSecurityStateDefault() {
        val state = SecurityState()

        assertFalse(state.isSecure)
        assertEquals(SecurityState.SecurityLevel.NONE, state.level)
        assertNull(state.certificate)
        assertFalse(state.hasMixedContent)
    }

    @Test
    fun testSecurityStateLevels() {
        assertEquals(5, SecurityState.SecurityLevel.entries.size)
        assertTrue(SecurityState.SecurityLevel.entries.containsAll(listOf(
            SecurityState.SecurityLevel.NONE,
            SecurityState.SecurityLevel.SECURE,
            SecurityState.SecurityLevel.SECURE_EV,
            SecurityState.SecurityLevel.INSECURE,
            SecurityState.SecurityLevel.DANGEROUS
        )))
    }

    // MARK: - Navigation Options Tests

    @Test
    fun testNavigationOptionsDefault() {
        val options = NavigationOptions.Default

        assertFalse(options.bypassCache)
        assertTrue(options.headers.isEmpty())
        assertNull(options.postData)
        assertNull(options.referrer)
        assertEquals(NavigationOptions.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN, options.referrerPolicy)
        assertFalse(options.replaceHistory)
        assertFalse(options.openInNewTab)
    }

    @Test
    fun testNavigationOptionsForceReload() {
        val options = NavigationOptions.ForceReload

        assertTrue(options.bypassCache)
    }

    @Test
    fun testNavigationOptionsWithHeaders() {
        val options = NavigationOptions(
            headers = mapOf("Authorization" to "Bearer token")
        )

        assertEquals("Bearer token", options.headers["Authorization"])
    }

    @Test
    fun testNavigationOptionsReferrerPolicies() {
        assertEquals(8, NavigationOptions.ReferrerPolicy.entries.size)
    }
}
