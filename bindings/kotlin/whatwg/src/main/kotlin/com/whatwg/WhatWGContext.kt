package com.whatwg

import com.whatwg.internal.JNIBridge

/**
 * An execution context (realm/window) for running JavaScript.
 *
 * A context represents an isolated JavaScript environment with its own
 * global object and execution state. Multiple contexts can exist within
 * a single platform instance.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * val context = platform.createContext()
 *
 * // Execute JavaScript
 * val result = context.evaluate("1 + 1")
 *
 * // Clean up
 * context.close()
 * ```
 */
class WhatWGContext internal constructor(
    private val platform: WhatWGPlatform
) : AutoCloseable {

    // MARK: - Properties

    /**
     * Native handle to the context.
     */
    private var nativeHandle: Long = 0

    /**
     * Whether the context has been destroyed.
     */
    var isDestroyed: Boolean = false
        private set

    init {
        nativeHandle = JNIBridge.contextCreate(platform.handle)
        if (nativeHandle == 0L) {
            throw WhatWGException("Failed to create execution context")
        }
    }

    // MARK: - JavaScript Execution

    /**
     * Evaluates JavaScript code in this context.
     *
     * @param script The JavaScript code to execute.
     * @return The result of the evaluation as a string representation.
     * @throws WhatWGException if evaluation fails.
     */
    fun evaluate(script: String): String? {
        checkNotDestroyed()
        return JNIBridge.contextEvaluate(nativeHandle, script)
    }

    // MARK: - Event Loop

    /**
     * Runs the event loop until there are no more pending tasks.
     *
     * This is typically used for testing or command-line tools.
     */
    fun runEventLoop() {
        checkNotDestroyed()
        JNIBridge.contextRunEventLoop(nativeHandle)
    }

    /**
     * Performs a single iteration of the event loop.
     *
     * @return `true` if there are more tasks pending.
     */
    fun stepEventLoop(): Boolean {
        checkNotDestroyed()
        return JNIBridge.contextStepEventLoop(nativeHandle)
    }

    // MARK: - Cleanup

    override fun close() {
        if (!isDestroyed && nativeHandle != 0L) {
            JNIBridge.contextDestroy(nativeHandle)
            nativeHandle = 0
            isDestroyed = true
        }
    }

    private fun checkNotDestroyed() {
        if (isDestroyed) {
            throw WhatWGException("Context has been destroyed")
        }
    }
}

/**
 * A realm is a JavaScript execution environment.
 *
 * In WHATWG terminology, a realm is associated with a global object
 * (like Window or WorkerGlobalScope). This type alias provides
 * semantic clarity when working with different execution contexts.
 */
typealias WhatWGRealm = WhatWGContext
