package com.whatwg.providers

/**
 * Interface for providing timer functionality.
 *
 * Implement this interface to provide setTimeout/setInterval support.
 */
interface TimerProvider {

    /**
     * Schedules a one-time callback.
     *
     * @param delayMs Delay in milliseconds.
     * @param callback The callback to invoke.
     * @return A timer ID that can be used to cancel.
     */
    fun setTimeout(delayMs: Long, callback: () -> Unit): Long

    /**
     * Schedules a repeating callback.
     *
     * @param intervalMs Interval in milliseconds.
     * @param callback The callback to invoke.
     * @return A timer ID that can be used to cancel.
     */
    fun setInterval(intervalMs: Long, callback: () -> Unit): Long

    /**
     * Cancels a timeout.
     *
     * @param id The timer ID returned by [setTimeout].
     */
    fun clearTimeout(id: Long)

    /**
     * Cancels an interval.
     *
     * @param id The timer ID returned by [setInterval].
     */
    fun clearInterval(id: Long)
}
