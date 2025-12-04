package com.whatwg.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.whatwg.WhatWGPlatform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import java.net.URL
import java.util.UUID

/**
 * Main browser controller for Jetpack Compose integration.
 *
 * `WhatWGBrowser` manages browser state and provides navigation, tab management,
 * and JavaScript execution capabilities using Compose state management.
 *
 * ## Example Usage
 *
 * ```kotlin
 * @Composable
 * fun BrowserScreen() {
 *     val browser = rememberWhatWGBrowser()
 *
 *     Column {
 *         WhatWGWebView(browser = browser)
 *
 *         Row {
 *             Button(
 *                 onClick = { browser.goBack() },
 *                 enabled = browser.canGoBack
 *             ) {
 *                 Text("Back")
 *             }
 *
 *             Button(
 *                 onClick = { browser.goForward() },
 *                 enabled = browser.canGoForward
 *             ) {
 *                 Text("Forward")
 *             }
 *
 *             Button(onClick = { browser.reload() }) {
 *                 Text("Reload")
 *             }
 *         }
 *
 *         TextField(
 *             value = browser.urlString,
 *             onValueChange = { browser.urlString = it },
 *             modifier = Modifier.onKeyEvent {
 *                 if (it.key == Key.Enter) {
 *                     browser.loadUrl()
 *                     true
 *                 } else false
 *             }
 *         )
 *     }
 * }
 * ```
 */
@Stable
class WhatWGBrowser internal constructor(
    private val platform: WhatWGPlatform
) {
    // MARK: - Coroutine Scope

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // MARK: - Observable State

    /**
     * The current URL as a string for binding.
     */
    var urlString: String by mutableStateOf("")

    /**
     * The current navigation state.
     */
    var navigationState: NavigationState by mutableStateOf(NavigationState.Empty)
        private set

    /**
     * All open tabs.
     */
    private val _tabs = mutableStateListOf<BrowserTab>()
    val tabs: List<BrowserTab> get() = _tabs

    /**
     * Index of the currently active tab.
     */
    var activeTabIndex: Int by mutableIntStateOf(0)
        private set

    /**
     * The most recent error, if any.
     */
    var lastError: BrowserError? by mutableStateOf(null)
        private set

    // MARK: - Derived State

    /**
     * The current page title.
     */
    val title: String get() = navigationState.title

    /**
     * Whether the page is currently loading.
     */
    val isLoading: Boolean get() = navigationState.isLoading

    /**
     * The estimated loading progress (0.0 to 1.0).
     */
    val loadingProgress: Float get() = navigationState.loadingProgress

    /**
     * Whether navigation can go back.
     */
    val canGoBack: Boolean get() = navigationState.canGoBack

    /**
     * Whether navigation can go forward.
     */
    val canGoForward: Boolean get() = navigationState.canGoForward

    /**
     * Whether the connection is secure (HTTPS).
     */
    val isSecure: Boolean get() = navigationState.isSecure

    /**
     * The currently active tab.
     */
    val activeTab: BrowserTab?
        get() = _tabs.getOrNull(activeTabIndex)

    // MARK: - Events

    private val _navigationEvents = MutableSharedFlow<NavigationEvent>()

    /**
     * Flow of navigation events.
     */
    val navigationEvents: SharedFlow<NavigationEvent> = _navigationEvents.asSharedFlow()

    private val _consoleMessages = MutableSharedFlow<ConsoleMessage>()

    /**
     * Flow of console messages from JavaScript.
     */
    val consoleMessages: SharedFlow<ConsoleMessage> = _consoleMessages.asSharedFlow()

    // MARK: - History

    private val _history = mutableListOf<HistoryEntry>()

    /**
     * History entries for the current tab.
     */
    val history: List<HistoryEntry> get() = _history.toList()

    // MARK: - Initialization

    init {
        // Create initial tab
        _tabs.add(BrowserTab(isActive = true))
    }

    // MARK: - Navigation

    /**
     * Loads the URL from the current [urlString].
     */
    fun loadUrl() {
        if (urlString.isBlank()) return

        // Add scheme if missing
        var urlToLoad = urlString
        if (!urlToLoad.contains("://")) {
            urlToLoad = "https://$urlToLoad"
        }

        val url = try {
            URL(urlToLoad)
        } catch (e: Exception) {
            lastError = BrowserError.InvalidUrl(urlString)
            return
        }

        loadUrl(url)
    }

    /**
     * Loads a specific URL.
     *
     * @param url The URL to load.
     * @param options Navigation options.
     */
    fun loadUrl(url: URL, options: NavigationOptions = NavigationOptions.Default) {
        lastError = null

        // Update URL string
        urlString = url.toString()

        // Update navigation state
        navigationState = NavigationState.loading(url)

        // Update tab state
        updateActiveTabState()

        // Emit navigation event
        scope.launch {
            _navigationEvents.emit(NavigationEvent.Started(url))
        }

        // Simulate loading (actual loading would be handled by the engine)
        simulateLoading(url)
    }

    /**
     * Loads a URL string.
     *
     * @param urlString The URL string to load.
     */
    fun loadUrl(urlString: String) {
        this.urlString = urlString
        loadUrl()
    }

    /**
     * Navigates back in history.
     */
    fun goBack() {
        if (!canGoBack) return

        scope.launch {
            _navigationEvents.emit(NavigationEvent.GoingBack)
        }

        // Actual back navigation would be handled by the engine
    }

    /**
     * Navigates forward in history.
     */
    fun goForward() {
        if (!canGoForward) return

        scope.launch {
            _navigationEvents.emit(NavigationEvent.GoingForward)
        }

        // Actual forward navigation would be handled by the engine
    }

    /**
     * Reloads the current page.
     *
     * @param bypassCache Whether to bypass the cache.
     */
    fun reload(bypassCache: Boolean = false) {
        val url = navigationState.url ?: return

        scope.launch {
            _navigationEvents.emit(NavigationEvent.Reloading)
        }

        loadUrl(
            url,
            if (bypassCache) NavigationOptions.ForceReload else NavigationOptions.Default
        )
    }

    /**
     * Stops loading the current page.
     */
    fun stopLoading() {
        navigationState = navigationState.copy(isLoading = false)
        updateActiveTabState()

        scope.launch {
            _navigationEvents.emit(NavigationEvent.Stopped)
        }
    }

    // MARK: - Tab Management

    /**
     * Creates a new tab.
     *
     * @param makeActive Whether to switch to the new tab.
     * @return The new tab's ID.
     */
    fun newTab(makeActive: Boolean = true): UUID {
        val tab = BrowserTab(isActive = makeActive)

        if (makeActive) {
            // Deactivate current tab
            if (activeTabIndex < _tabs.size) {
                _tabs[activeTabIndex] = _tabs[activeTabIndex].copy(isActive = false)
            }
            _tabs.add(tab)
            activeTabIndex = _tabs.size - 1
            navigationState = NavigationState.Empty
            urlString = ""
        } else {
            _tabs.add(tab)
        }

        return tab.id
    }

    /**
     * Closes a tab.
     *
     * @param id The tab's ID.
     */
    fun closeTab(id: UUID) {
        val index = _tabs.indexOfFirst { it.id == id }
        if (index == -1) return

        _tabs.removeAt(index)

        // If we closed the active tab, switch to another
        when {
            _tabs.isEmpty() -> {
                newTab()
            }
            index == activeTabIndex -> {
                activeTabIndex = maxOf(0, index - 1)
                updateFromActiveTab()
            }
            index < activeTabIndex -> {
                activeTabIndex -= 1
            }
        }
    }

    /**
     * Switches to a specific tab.
     *
     * @param id The tab's ID.
     */
    fun switchToTab(id: UUID) {
        val index = _tabs.indexOfFirst { it.id == id }
        if (index == -1) return

        switchToTab(index)
    }

    /**
     * Switches to a tab by index.
     *
     * @param index The tab index.
     */
    fun switchToTab(index: Int) {
        if (index < 0 || index >= _tabs.size) return
        if (index == activeTabIndex) return

        // Deactivate current tab
        if (activeTabIndex < _tabs.size) {
            _tabs[activeTabIndex] = _tabs[activeTabIndex].copy(isActive = false)
        }

        // Activate new tab
        activeTabIndex = index
        _tabs[index] = _tabs[index].copy(
            isActive = true,
            lastAccessedAt = System.currentTimeMillis()
        )

        updateFromActiveTab()
    }

    // MARK: - JavaScript Execution

    /**
     * Executes JavaScript code in the current page.
     *
     * @param script The JavaScript code to execute.
     * @return The result of the script execution.
     */
    suspend fun evaluateJavaScript(script: String): JavaScriptResult {
        // This would delegate to the underlying engine
        // For now, return success with null
        return JavaScriptResult.Success(null)
    }

    // MARK: - Internal

    private fun updateActiveTabState() {
        if (activeTabIndex < _tabs.size) {
            _tabs[activeTabIndex] = _tabs[activeTabIndex].copy(
                state = navigationState,
                lastAccessedAt = System.currentTimeMillis()
            )
        }
    }

    private fun updateFromActiveTab() {
        val tab = _tabs.getOrNull(activeTabIndex) ?: return
        navigationState = tab.state
        urlString = tab.state.urlString
    }

    private fun simulateLoading(url: URL) {
        scope.launch {
            // Simulate loading progress
            for (progress in listOf(0.1f, 0.3f, 0.5f, 0.7f, 0.9f, 1.0f)) {
                delay(50)
                navigationState = navigationState.copy(loadingProgress = progress)
                updateActiveTabState()
            }

            // Finished loading
            navigationState = NavigationState.loaded(url, url.host ?: "Untitled").copy(
                canGoBack = true
            )

            // Add to history
            _history.add(HistoryEntry(url = url, title = navigationState.title))

            updateActiveTabState()

            _navigationEvents.emit(NavigationEvent.Finished(url))
        }
    }

    // MARK: - Cleanup

    internal fun dispose() {
        scope.cancel()
    }
}

/**
 * Creates and remembers a [WhatWGBrowser] instance.
 *
 * @param platform The platform to use. Creates a default one if null.
 * @return A remembered [WhatWGBrowser] instance.
 */
@Composable
fun rememberWhatWGBrowser(
    platform: WhatWGPlatform = remember { WhatWGPlatform() }
): WhatWGBrowser {
    val browser = remember(platform) { WhatWGBrowser(platform) }

    DisposableEffect(browser) {
        onDispose {
            browser.dispose()
        }
    }

    return browser
}
