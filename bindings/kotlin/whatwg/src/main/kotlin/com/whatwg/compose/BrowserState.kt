package com.whatwg.compose

import java.net.URL
import java.util.UUID

/**
 * Error types that can occur during browser operations.
 */
sealed class BrowserError : Exception() {
    /**
     * The URL is invalid or malformed.
     */
    data class InvalidUrl(val url: String) : BrowserError() {
        override val message: String = "Invalid URL: $url"
    }

    /**
     * A network error occurred during loading.
     */
    data class NetworkError(
        override val message: String,
        val statusCode: Int? = null
    ) : BrowserError()

    /**
     * A JavaScript execution error occurred.
     */
    data class ScriptError(
        override val message: String,
        val line: Int? = null,
        val column: Int? = null,
        val sourceUrl: String? = null
    ) : BrowserError()

    /**
     * The operation timed out.
     */
    data class Timeout(override val message: String = "Operation timed out") : BrowserError()

    /**
     * The navigation was cancelled.
     */
    data class Cancelled(override val message: String = "Navigation cancelled") : BrowserError()

    /**
     * The browser engine is not available.
     */
    data class EngineUnavailable(
        override val message: String = "Browser engine not available"
    ) : BrowserError()

    /**
     * An unknown error occurred.
     */
    data class Unknown(
        override val message: String,
        override val cause: Throwable? = null
    ) : BrowserError()
}

/**
 * Represents a single tab in the browser.
 */
data class BrowserTab(
    /**
     * Unique identifier for this tab.
     */
    val id: UUID = UUID.randomUUID(),

    /**
     * The current navigation state of the tab.
     */
    val state: NavigationState = NavigationState(),

    /**
     * Whether this tab is currently active.
     */
    val isActive: Boolean = false,

    /**
     * Whether this tab is pinned.
     */
    val isPinned: Boolean = false,

    /**
     * Whether this tab is muted.
     */
    val isMuted: Boolean = false,

    /**
     * Whether this tab is playing audio.
     */
    val isPlayingAudio: Boolean = false,

    /**
     * The parent tab ID, if this was opened from another tab.
     */
    val parentTabId: UUID? = null,

    /**
     * Creation timestamp in milliseconds.
     */
    val createdAt: Long = System.currentTimeMillis(),

    /**
     * Last access timestamp in milliseconds.
     */
    val lastAccessedAt: Long = System.currentTimeMillis()
)

/**
 * Represents an entry in the browser history.
 */
data class HistoryEntry(
    /**
     * The URL of the page.
     */
    val url: URL,

    /**
     * The page title.
     */
    val title: String,

    /**
     * When the page was visited.
     */
    val visitedAt: Long = System.currentTimeMillis(),

    /**
     * The favicon URL, if available.
     */
    val faviconUrl: String? = null,

    /**
     * The scroll position when leaving this page.
     */
    val scrollPosition: ScrollPosition? = null
)

/**
 * Represents a scroll position.
 */
data class ScrollPosition(
    val x: Float = 0f,
    val y: Float = 0f
)

/**
 * Events emitted during navigation.
 */
sealed class NavigationEvent {
    /**
     * Navigation started.
     */
    data class Started(val url: URL) : NavigationEvent()

    /**
     * Navigation finished successfully.
     */
    data class Finished(val url: URL) : NavigationEvent()

    /**
     * Navigation failed.
     */
    data class Failed(val error: BrowserError) : NavigationEvent()

    /**
     * Going back in history.
     */
    data object GoingBack : NavigationEvent()

    /**
     * Going forward in history.
     */
    data object GoingForward : NavigationEvent()

    /**
     * Reloading the page.
     */
    data object Reloading : NavigationEvent()

    /**
     * Loading was stopped.
     */
    data object Stopped : NavigationEvent()

    /**
     * Redirected to a new URL.
     */
    data class Redirected(val from: URL, val to: URL) : NavigationEvent()
}

/**
 * A message from the JavaScript console.
 */
data class ConsoleMessage(
    /**
     * The message level.
     */
    val level: Level,

    /**
     * The message text.
     */
    val text: String,

    /**
     * The source URL.
     */
    val source: String? = null,

    /**
     * The line number.
     */
    val line: Int? = null,

    /**
     * The column number.
     */
    val column: Int? = null,

    /**
     * Timestamp when the message was logged.
     */
    val timestamp: Long = System.currentTimeMillis()
) {
    /**
     * Console message level.
     */
    enum class Level {
        LOG,
        INFO,
        WARN,
        ERROR,
        DEBUG
    }
}

/**
 * JavaScript execution result.
 */
sealed class JavaScriptResult {
    /**
     * Script executed successfully.
     */
    data class Success(val value: Any?) : JavaScriptResult()

    /**
     * Script execution failed.
     */
    data class Error(val error: BrowserError.ScriptError) : JavaScriptResult()
}

/**
 * Browser security state information.
 */
data class SecurityState(
    /**
     * Whether the connection is secure (HTTPS).
     */
    val isSecure: Boolean = false,

    /**
     * The security level.
     */
    val level: SecurityLevel = SecurityLevel.NONE,

    /**
     * Certificate information, if available.
     */
    val certificate: CertificateInfo? = null,

    /**
     * Whether mixed content is present.
     */
    val hasMixedContent: Boolean = false
) {
    enum class SecurityLevel {
        NONE,
        SECURE,
        SECURE_EV,
        INSECURE,
        DANGEROUS
    }
}

/**
 * SSL/TLS certificate information.
 */
data class CertificateInfo(
    /**
     * The certificate issuer.
     */
    val issuer: String,

    /**
     * The certificate subject.
     */
    val subject: String,

    /**
     * When the certificate was issued.
     */
    val issuedAt: Long,

    /**
     * When the certificate expires.
     */
    val expiresAt: Long,

    /**
     * Whether the certificate is valid.
     */
    val isValid: Boolean
)
