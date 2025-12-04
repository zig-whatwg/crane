package com.whatwg.compose

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import java.net.URL

/**
 * A Composable that displays web content using the WHATWG browser engine.
 *
 * `WhatWGWebView` wraps the underlying platform-specific web view and integrates
 * with `WhatWGBrowser` for navigation and JavaScript execution.
 *
 * ## Example Usage
 *
 * ```kotlin
 * @Composable
 * fun BrowserScreen() {
 *     val browser = rememberWhatWGBrowser()
 *
 *     Column {
 *         WhatWGWebView(
 *             browser = browser,
 *             modifier = Modifier.weight(1f)
 *         )
 *
 *         BottomBar(browser = browser)
 *     }
 * }
 * ```
 */
@Composable
fun WhatWGWebView(
    browser: WhatWGBrowser,
    modifier: Modifier = Modifier,
    configuration: WebViewConfiguration = WebViewConfiguration.Default
) {
    val context = LocalContext.current
    var currentUrl by remember { mutableStateOf<URL?>(null) }

    // Track navigation state changes
    LaunchedEffect(browser.navigationState.url) {
        val newUrl = browser.navigationState.url
        if (newUrl != null && newUrl != currentUrl) {
            currentUrl = newUrl
        }
    }

    AndroidView(
        factory = { ctx ->
            WhatWGWebViewContainer(ctx, configuration).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            }
        },
        update = { container ->
            container.update(browser)
        },
        modifier = modifier.fillMaxSize()
    )
}

/**
 * Configuration options for the web view.
 */
data class WebViewConfiguration(
    /**
     * Whether JavaScript is enabled.
     */
    val javaScriptEnabled: Boolean = true,

    /**
     * Whether to allow zooming.
     */
    val allowsZooming: Boolean = true,

    /**
     * The minimum zoom scale.
     */
    val minimumZoomScale: Float = 1f,

    /**
     * The maximum zoom scale.
     */
    val maximumZoomScale: Float = 4f,

    /**
     * Whether to allow backward/forward navigation gestures.
     */
    val allowsBackForwardNavigationGestures: Boolean = true,

    /**
     * Background color (ARGB).
     */
    val backgroundColor: Int = Color.WHITE,

    /**
     * Custom user agent string (null for default).
     */
    val customUserAgent: String? = null,

    /**
     * Whether to enable DOM storage.
     */
    val domStorageEnabled: Boolean = true,

    /**
     * Whether to enable database storage.
     */
    val databaseEnabled: Boolean = true,

    /**
     * Whether to allow file access.
     */
    val allowFileAccess: Boolean = false,

    /**
     * Media playback policy.
     */
    val mediaPlaybackPolicy: MediaPlaybackPolicy = MediaPlaybackPolicy.USER_GESTURE_REQUIRED
) {
    /**
     * Media playback policy options.
     */
    enum class MediaPlaybackPolicy {
        /**
         * Always allow autoplay.
         */
        ALWAYS_ALLOW,

        /**
         * Require user gesture to play.
         */
        USER_GESTURE_REQUIRED,

        /**
         * Never allow autoplay.
         */
        NEVER_ALLOW
    }

    companion object {
        /**
         * Default configuration with common settings.
         */
        val Default = WebViewConfiguration()

        /**
         * Minimal configuration with JavaScript disabled.
         */
        val Minimal = WebViewConfiguration(
            javaScriptEnabled = false,
            allowsZooming = false,
            allowsBackForwardNavigationGestures = false,
            domStorageEnabled = false,
            databaseEnabled = false,
            mediaPlaybackPolicy = MediaPlaybackPolicy.NEVER_ALLOW
        )

        /**
         * Configuration optimized for reading content.
         */
        val Reader = WebViewConfiguration(
            allowsZooming = true,
            maximumZoomScale = 6f,
            mediaPlaybackPolicy = MediaPlaybackPolicy.NEVER_ALLOW
        )

        /**
         * Configuration for kiosk/full-screen mode.
         */
        val Kiosk = WebViewConfiguration(
            allowsZooming = false,
            allowsBackForwardNavigationGestures = false
        )
    }
}

/**
 * The Android View container that hosts the web content.
 *
 * This view manages the actual rendering and interaction with web content.
 * It interfaces with the underlying WHATWG browser engine.
 */
internal class WhatWGWebViewContainer(
    context: Context,
    private val configuration: WebViewConfiguration
) : FrameLayout(context) {

    private var currentUrl: URL? = null
    private var contentView: ContentRenderView? = null

    init {
        setBackgroundColor(configuration.backgroundColor)
        setupContentView()
    }

    private fun setupContentView() {
        contentView = ContentRenderView(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
        }
        addView(contentView)
    }

    /**
     * Updates the container based on browser state.
     */
    fun update(browser: WhatWGBrowser) {
        val stateUrl = browser.navigationState.url

        if (stateUrl != null && stateUrl != currentUrl && browser.isLoading) {
            loadUrl(stateUrl)
        }
    }

    /**
     * Loads the specified URL.
     */
    fun loadUrl(url: URL) {
        currentUrl = url

        // In a real implementation, this would:
        // 1. Create a network request via the WHATWG Fetch API
        // 2. Parse the HTML response using the WHATWG HTML parser
        // 3. Build the DOM tree
        // 4. Execute scripts via the JS engine
        // 5. Render the content

        // For now, display a placeholder
        contentView?.displayPlaceholder(url)
    }

    /**
     * Executes JavaScript in the current context.
     */
    suspend fun evaluateJavaScript(script: String): Any? {
        // Would delegate to the JS engine
        return null
    }
}

/**
 * Internal view for rendering web content.
 */
internal class ContentRenderView(context: Context) : View(context) {

    private var placeholderText: String = ""
    private val textPaint = Paint().apply {
        color = Color.GRAY
        textSize = 40f
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
    }
    private val subTextPaint = Paint().apply {
        color = Color.DKGRAY
        textSize = 28f
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
    }

    init {
        setBackgroundColor(Color.WHITE)
    }

    fun displayPlaceholder(url: URL) {
        placeholderText = url.toString()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val centerX = width / 2f
        val centerY = height / 2f

        // Draw title
        canvas.drawText(
            "WHATWG Browser Engine",
            centerX,
            centerY - 80f,
            textPaint
        )

        // Draw loading message
        canvas.drawText(
            "Loading:",
            centerX,
            centerY,
            subTextPaint
        )

        // Draw URL (truncated if too long)
        val displayUrl = if (placeholderText.length > 40) {
            placeholderText.take(37) + "..."
        } else {
            placeholderText
        }
        canvas.drawText(
            displayUrl,
            centerX,
            centerY + 40f,
            subTextPaint
        )

        // Draw pending message
        canvas.drawText(
            "(Web rendering implementation pending)",
            centerX,
            centerY + 120f,
            subTextPaint.apply { textSize = 24f }
        )
    }
}

/**
 * A composable for displaying loading progress.
 */
@Composable
fun WebViewLoadingIndicator(
    browser: WhatWGBrowser,
    modifier: Modifier = Modifier
) {
    if (browser.isLoading) {
        androidx.compose.material3.LinearProgressIndicator(
            progress = { browser.loadingProgress },
            modifier = modifier
        )
    }
}

/**
 * A composable for displaying the current URL in a secure/insecure indicator.
 */
@Composable
fun WebViewSecurityIndicator(
    browser: WhatWGBrowser,
    modifier: Modifier = Modifier
) {
    val securityState = browser.navigationState.securityState

    androidx.compose.material3.Icon(
        imageVector = when (securityState.level) {
            SecurityState.SecurityLevel.SECURE,
            SecurityState.SecurityLevel.SECURE_EV -> androidx.compose.material.icons.Icons.Default.Lock
            SecurityState.SecurityLevel.INSECURE,
            SecurityState.SecurityLevel.DANGEROUS -> androidx.compose.material.icons.Icons.Default.Warning
            SecurityState.SecurityLevel.NONE -> androidx.compose.material.icons.Icons.Default.Info
        },
        contentDescription = when (securityState.level) {
            SecurityState.SecurityLevel.SECURE,
            SecurityState.SecurityLevel.SECURE_EV -> "Secure connection"
            SecurityState.SecurityLevel.INSECURE -> "Insecure connection"
            SecurityState.SecurityLevel.DANGEROUS -> "Dangerous connection"
            SecurityState.SecurityLevel.NONE -> "Unknown security"
        },
        tint = when (securityState.level) {
            SecurityState.SecurityLevel.SECURE,
            SecurityState.SecurityLevel.SECURE_EV -> androidx.compose.ui.graphics.Color.Green
            SecurityState.SecurityLevel.INSECURE -> androidx.compose.ui.graphics.Color.Yellow
            SecurityState.SecurityLevel.DANGEROUS -> androidx.compose.ui.graphics.Color.Red
            SecurityState.SecurityLevel.NONE -> androidx.compose.ui.graphics.Color.Gray
        },
        modifier = modifier
    )
}
