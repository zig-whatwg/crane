package com.whatwg

/**
 * JavaScript engine selection for the WHATWG Platform.
 *
 * The platform supports multiple JavaScript engines. Choose the engine
 * based on your target platform and requirements.
 *
 * ## Engine Comparison
 *
 * | Engine | Performance | Size | Notes |
 * |--------|-------------|------|-------|
 * | V8 | Excellent | ~10MB | Chrome's engine |
 * | QuickJS | Good | ~500KB | Lightweight |
 *
 */
enum class JSEngine(val value: String) {
    /**
     * Google's V8 engine.
     *
     * High-performance engine used by Chrome and Node.js.
     * Best for performance-critical applications.
     */
    V8("v8"),

    /**
     * Fabrice Bellard's QuickJS engine.
     *
     * Lightweight engine with small binary size.
     * Good for embedded systems or when binary size matters.
     */
    QUICKJS("quickjs");

    /**
     * Human-readable name for the engine.
     */
    val displayName: String
        get() = when (this) {
            V8 -> "V8"
            QUICKJS -> "QuickJS"
        }

    companion object {
        /**
         * Returns the recommended engine for Android.
         */
        val recommended: JSEngine = QUICKJS
    }
}
