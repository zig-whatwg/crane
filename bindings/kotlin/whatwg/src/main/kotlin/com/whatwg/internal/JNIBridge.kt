package com.whatwg.internal

/**
 * JNI bridge to the native WHATWG library.
 *
 * This object contains all JNI method declarations that bridge
 * to the C library. All methods are internal to the library.
 */
internal object JNIBridge {

    // MARK: - Version

    /**
     * Returns the library version string.
     */
    @JvmStatic
    external fun versionString(): String

    /**
     * Returns the expected ABI version.
     */
    @JvmStatic
    external fun expectedVersion(): Int

    // MARK: - Platform Lifecycle

    /**
     * Creates a new platform instance.
     *
     * @return Native handle, or 0 on failure.
     */
    @JvmStatic
    external fun platformCreate(): Long

    /**
     * Destroys a platform instance.
     *
     * @param handle Native handle from [platformCreate].
     */
    @JvmStatic
    external fun platformDestroy(handle: Long)

    /**
     * Checks if a capability is available.
     *
     * @param handle Native platform handle.
     * @param capability Capability value from [com.whatwg.Capability].
     * @return `true` if capability is configured.
     */
    @JvmStatic
    external fun platformHasCapability(handle: Long, capability: Int): Boolean

    // MARK: - Context Lifecycle

    /**
     * Creates a new context within a platform.
     *
     * @param platformHandle Native platform handle.
     * @return Native context handle, or 0 on failure.
     */
    @JvmStatic
    external fun contextCreate(platformHandle: Long): Long

    /**
     * Destroys a context.
     *
     * @param handle Native context handle.
     */
    @JvmStatic
    external fun contextDestroy(handle: Long)

    /**
     * Evaluates JavaScript in a context.
     *
     * @param handle Native context handle.
     * @param script JavaScript code to evaluate.
     * @return Result string, or null on error.
     */
    @JvmStatic
    external fun contextEvaluate(handle: Long, script: String): String?

    /**
     * Runs the event loop until no more tasks.
     *
     * @param handle Native context handle.
     */
    @JvmStatic
    external fun contextRunEventLoop(handle: Long)

    /**
     * Performs one event loop iteration.
     *
     * @param handle Native context handle.
     * @return `true` if more tasks pending.
     */
    @JvmStatic
    external fun contextStepEventLoop(handle: Long): Boolean

    // MARK: - Clipboard VTable

    /**
     * Sets the clipboard VTable callbacks.
     *
     * @param handle Native platform handle.
     * @param readText Callback for reading text.
     * @param writeText Callback for writing text.
     */
    @JvmStatic
    external fun setClipboardVTable(
        handle: Long,
        readText: ClipboardReadCallback?,
        writeText: ClipboardWriteCallback?
    )

    // MARK: - Timer VTable

    /**
     * Sets the timer VTable callbacks.
     */
    @JvmStatic
    external fun setTimerVTable(
        handle: Long,
        setTimeout: TimerSetCallback?,
        setInterval: TimerSetCallback?,
        clearTimeout: TimerClearCallback?,
        clearInterval: TimerClearCallback?
    )

    // Callback interfaces for JNI
    
    fun interface ClipboardReadCallback {
        fun read(): String?
    }
    
    fun interface ClipboardWriteCallback {
        fun write(text: String): Boolean
    }
    
    fun interface TimerSetCallback {
        fun set(callback: Runnable, delayMs: Int): Long
    }
    
    fun interface TimerClearCallback {
        fun clear(id: Long)
    }
}
