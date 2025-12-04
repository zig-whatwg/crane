package com.whatwg.compose

import java.net.URL

/**
 * Represents the current navigation state of the browser.
 *
 * This immutable data class captures all relevant state about the current
 * page and navigation capabilities.
 */
data class NavigationState(
    /**
     * The current URL, or null if no page is loaded.
     */
    val url: URL? = null,

    /**
     * The current page title.
     */
    val title: String = "",

    /**
     * Whether the page is currently loading.
     */
    val isLoading: Boolean = false,

    /**
     * The estimated loading progress (0.0 to 1.0).
     */
    val loadingProgress: Float = 0f,

    /**
     * Whether navigation can go back.
     */
    val canGoBack: Boolean = false,

    /**
     * Whether navigation can go forward.
     */
    val canGoForward: Boolean = false,

    /**
     * Security state of the current page.
     */
    val securityState: SecurityState = SecurityState(),

    /**
     * The favicon URL, if available.
     */
    val faviconUrl: String? = null,

    /**
     * The number of history entries.
     */
    val historyLength: Int = 0,

    /**
     * The current position in history.
     */
    val historyIndex: Int = 0
) {
    /**
     * Whether the connection is secure (HTTPS).
     */
    val isSecure: Boolean
        get() = securityState.isSecure

    /**
     * Whether a page is currently loaded.
     */
    val hasContent: Boolean
        get() = url != null

    /**
     * The URL as a string, or empty string if none.
     */
    val urlString: String
        get() = url?.toString() ?: ""

    /**
     * The host of the current URL, or null if none.
     */
    val host: String?
        get() = url?.host

    /**
     * The scheme of the current URL (http, https, etc.), or null if none.
     */
    val scheme: String?
        get() = url?.protocol

    companion object {
        /**
         * Returns an empty navigation state.
         */
        val Empty = NavigationState()

        /**
         * Creates a navigation state for a loading URL.
         */
        fun loading(url: URL) = NavigationState(
            url = url,
            isLoading = true,
            loadingProgress = 0f
        )

        /**
         * Creates a navigation state for a loaded URL.
         */
        fun loaded(url: URL, title: String) = NavigationState(
            url = url,
            title = title,
            isLoading = false,
            loadingProgress = 1f,
            securityState = SecurityState(
                isSecure = url.protocol == "https",
                level = if (url.protocol == "https") {
                    SecurityState.SecurityLevel.SECURE
                } else {
                    SecurityState.SecurityLevel.NONE
                }
            )
        )
    }
}

/**
 * Navigation options for controlling how URLs are loaded.
 */
data class NavigationOptions(
    /**
     * Whether to force a reload even if cached.
     */
    val bypassCache: Boolean = false,

    /**
     * Custom HTTP headers to include.
     */
    val headers: Map<String, String> = emptyMap(),

    /**
     * POST data to send, if any.
     */
    val postData: ByteArray? = null,

    /**
     * The referrer URL.
     */
    val referrer: String? = null,

    /**
     * The referrer policy.
     */
    val referrerPolicy: ReferrerPolicy = ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN,

    /**
     * Whether this navigation should create a new history entry.
     */
    val replaceHistory: Boolean = false,

    /**
     * Whether to open in a new tab.
     */
    val openInNewTab: Boolean = false
) {
    /**
     * Referrer policy options.
     */
    enum class ReferrerPolicy {
        NO_REFERRER,
        NO_REFERRER_WHEN_DOWNGRADE,
        ORIGIN,
        ORIGIN_WHEN_CROSS_ORIGIN,
        SAME_ORIGIN,
        STRICT_ORIGIN,
        STRICT_ORIGIN_WHEN_CROSS_ORIGIN,
        UNSAFE_URL
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as NavigationOptions

        if (bypassCache != other.bypassCache) return false
        if (headers != other.headers) return false
        if (postData != null) {
            if (other.postData == null) return false
            if (!postData.contentEquals(other.postData)) return false
        } else if (other.postData != null) return false
        if (referrer != other.referrer) return false
        if (referrerPolicy != other.referrerPolicy) return false
        if (replaceHistory != other.replaceHistory) return false
        if (openInNewTab != other.openInNewTab) return false

        return true
    }

    override fun hashCode(): Int {
        var result = bypassCache.hashCode()
        result = 31 * result + headers.hashCode()
        result = 31 * result + (postData?.contentHashCode() ?: 0)
        result = 31 * result + (referrer?.hashCode() ?: 0)
        result = 31 * result + referrerPolicy.hashCode()
        result = 31 * result + replaceHistory.hashCode()
        result = 31 * result + openInNewTab.hashCode()
        return result
    }

    companion object {
        /**
         * Default navigation options.
         */
        val Default = NavigationOptions()

        /**
         * Options for reloading with cache bypass.
         */
        val ForceReload = NavigationOptions(bypassCache = true)
    }
}
