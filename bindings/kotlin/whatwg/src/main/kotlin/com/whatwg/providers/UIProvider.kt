package com.whatwg.providers

/**
 * Interface for providing UI functionality (alert, confirm, prompt).
 *
 * Implement this interface to provide modal dialog support.
 */
interface UIProvider {

    /**
     * Shows an alert dialog.
     *
     * @param message The message to display.
     */
    suspend fun alert(message: String)

    /**
     * Shows a confirmation dialog.
     *
     * @param message The message to display.
     * @return `true` if confirmed, `false` if cancelled.
     */
    suspend fun confirm(message: String): Boolean

    /**
     * Shows a prompt dialog.
     *
     * @param message The message to display.
     * @param defaultValue The default input value.
     * @return The entered value, or `null` if cancelled.
     */
    suspend fun prompt(message: String, defaultValue: String? = null): String?

    /**
     * Opens a URL.
     *
     * @param url The URL to open.
     * @param target The target window name.
     * @param features Window features.
     * @return A window handle, or `null` if blocked.
     */
    suspend fun open(url: String?, target: String? = null, features: String? = null): WindowHandle?

    /**
     * Prints the current page.
     */
    suspend fun print()

    /**
     * Scrolls the window.
     *
     * @param x X offset.
     * @param y Y offset.
     */
    fun scrollTo(x: Double, y: Double)

    /**
     * Scrolls the window by an offset.
     *
     * @param x X delta.
     * @param y Y delta.
     */
    fun scrollBy(x: Double, y: Double)
}

/**
 * A handle to a window.
 */
interface WindowHandle {
    /**
     * Closes the window.
     */
    fun close()
    
    /**
     * Focuses the window.
     */
    fun focus()
    
    /**
     * Blurs the window.
     */
    fun blur()
    
    /**
     * Posts a message to the window.
     */
    fun postMessage(message: Any, targetOrigin: String)
}
