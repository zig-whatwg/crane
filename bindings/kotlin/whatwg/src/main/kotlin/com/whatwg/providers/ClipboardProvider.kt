package com.whatwg.providers

/**
 * Interface for providing clipboard functionality.
 *
 * Implement this interface to provide clipboard access to the WHATWG platform.
 *
 * ## Example Implementation
 *
 * ```kotlin
 * class AndroidClipboardProvider(context: Context) : ClipboardProvider {
 *     private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE)
 *         as ClipboardManager
 *
 *     override suspend fun readText(): String? {
 *         return clipboardManager.primaryClip?.getItemAt(0)?.text?.toString()
 *     }
 *
 *     override suspend fun writeText(text: String) {
 *         val clip = ClipData.newPlainText("", text)
 *         clipboardManager.setPrimaryClip(clip)
 *     }
 * }
 * ```
 */
interface ClipboardProvider {

    /**
     * Reads text from the clipboard.
     *
     * @return The clipboard text, or `null` if empty.
     * @throws Exception If the operation fails or is denied.
     */
    suspend fun readText(): String?

    /**
     * Writes text to the clipboard.
     *
     * @param text The text to write.
     * @throws Exception If the operation fails or is denied.
     */
    suspend fun writeText(text: String)

    /**
     * Reads arbitrary data from the clipboard.
     *
     * @param type The MIME type to read.
     * @return The clipboard data, or `null` if not available.
     * @throws Exception If the operation fails or is denied.
     */
    suspend fun read(type: String): ByteArray? = null

    /**
     * Writes arbitrary data to the clipboard.
     *
     * @param data The data to write.
     * @param type The MIME type of the data.
     * @throws Exception If the operation fails or is denied.
     */
    suspend fun write(data: ByteArray, type: String) {
        if (type == "text/plain") {
            writeText(String(data, Charsets.UTF_8))
        } else {
            throw UnsupportedOperationException("Unsupported clipboard type: $type")
        }
    }

    /**
     * Checks if the clipboard can be read.
     *
     * @return `true` if reading is permitted.
     */
    fun canRead(): Boolean = true

    /**
     * Checks if the clipboard can be written.
     *
     * @return `true` if writing is permitted.
     */
    fun canWrite(): Boolean = true
}
