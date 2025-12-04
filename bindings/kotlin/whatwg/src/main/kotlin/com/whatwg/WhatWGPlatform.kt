package com.whatwg

import com.whatwg.internal.JNIBridge
import com.whatwg.providers.*

/**
 * Main entry point for the WHATWG Platform Backend.
 *
 * `WhatWGPlatform` is the unified interface for embedders to provide platform
 * capabilities to the WHATWG browser engine. It wraps the native library and
 * provides a Kotlin-native API.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 *
 * // Configure capabilities
 * platform.clipboardProvider = MyClipboardProvider()
 * platform.storageProvider = MyStorageProvider()
 *
 * // Create a context
 * val context = platform.createContext()
 *
 * // Use the context...
 * ```
 */
class WhatWGPlatform : AutoCloseable {

    // MARK: - Properties

    /**
     * Native handle to the platform instance.
     */
    private var nativeHandle: Long = 0

    /**
     * The JavaScript engine to use.
     */
    var engine: JSEngine = JSEngine.QUICKJS

    // MARK: - Provider Properties

    /**
     * Clipboard capability provider.
     */
    var clipboardProvider: ClipboardProvider? = null

    /**
     * Timer capability provider.
     */
    var timerProvider: TimerProvider? = null

    /**
     * Network capability provider.
     */
    var networkProvider: NetworkProvider? = null

    /**
     * Storage capability provider.
     */
    var storageProvider: StorageProvider? = null

    /**
     * File system capability provider.
     */
    var fileSystemProvider: FileSystemProvider? = null

    /**
     * Geolocation capability provider.
     */
    var geolocationProvider: GeolocationProvider? = null

    /**
     * Notification capability provider.
     */
    var notificationProvider: NotificationProvider? = null

    /**
     * UI capability provider.
     */
    var uiProvider: UIProvider? = null

    // MARK: - Initialization

    /**
     * Initializes the platform with configured capabilities.
     *
     * @throws WhatWGException if initialization fails.
     */
    fun initialize() {
        if (nativeHandle != 0L) return

        nativeHandle = JNIBridge.platformCreate()
        if (nativeHandle == 0L) {
            throw WhatWGException("Failed to initialize WHATWG Platform")
        }

        // Configure VTables based on providers
        configureVTables()
    }

    /**
     * Creates a new execution context (realm/window).
     *
     * @return A new [WhatWGContext] instance.
     * @throws WhatWGException if context creation fails.
     */
    fun createContext(): WhatWGContext {
        initialize()
        return WhatWGContext(this)
    }

    // MARK: - Capabilities

    /**
     * Checks if a capability is available.
     *
     * @param capability The capability to check.
     * @return `true` if the capability is configured.
     */
    fun hasCapability(capability: Capability): Boolean {
        if (nativeHandle == 0L) return false
        return JNIBridge.platformHasCapability(nativeHandle, capability.value)
    }

    /**
     * Returns a list of all configured capabilities.
     */
    val configuredCapabilities: List<Capability>
        get() = Capability.entries.filter { hasCapability(it) }

    // MARK: - Internal

    internal val handle: Long
        get() = nativeHandle

    private fun configureVTables() {
        // VTable configuration will call back to providers via JNI
    }

    // MARK: - Cleanup

    override fun close() {
        if (nativeHandle != 0L) {
            JNIBridge.platformDestroy(nativeHandle)
            nativeHandle = 0
        }
    }

    companion object {
        /**
         * Returns the library version string.
         */
        val version: String
            get() = JNIBridge.versionString()

        /**
         * Returns the expected ABI version.
         */
        val abiVersion: Int
            get() = JNIBridge.expectedVersion()

        /**
         * Loads the native library.
         */
        init {
            System.loadLibrary("whatwg")
        }
    }
}

/**
 * Errors that can occur when using WhatWGPlatform.
 */
class WhatWGException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Platform capabilities that can be provided.
 */
enum class Capability(val value: Int) {
    CLIPBOARD(0),
    TIMER(1),
    NETWORK(2),
    STORAGE(3),
    LAYOUT(4),
    UI(5),
    SCREEN(6),
    NOTIFICATION(7),
    PUSH(8),
    SHARE(9),
    FILE_SYSTEM(10),
    GEOLOCATION(11),
    BLUETOOTH(12),
    USB(13),
    SERIAL(14),
    HID(15),
    NFC(16),
    DEVICE_ORIENTATION(17),
    VIBRATION(18),
    BATTERY(19),
    WAKE_LOCK(20),
    WEBRTC(21),
    MEDIA(22),
    AUDIO(23),
    SPEECH(24),
    GAMEPAD(25),
    SENSOR(26),
    CREDENTIALS(27),
    WEBAUTHN(28),
    PERMISSIONS(29),
    PAYMENT(30);
}
