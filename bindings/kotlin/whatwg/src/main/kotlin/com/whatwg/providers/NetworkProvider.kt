package com.whatwg.providers

/**
 * Interface for providing network/fetch functionality.
 *
 * Implement this interface to provide HTTP request support.
 */
interface NetworkProvider {

    /**
     * Performs an HTTP request.
     *
     * @param request The request configuration.
     * @return The response.
     * @throws Exception If the request fails.
     */
    suspend fun fetch(request: NetworkRequest): NetworkResponse

    /**
     * Checks if the device is online.
     *
     * @return `true` if network is available.
     */
    fun isOnline(): Boolean
}

/**
 * Configuration for a network request.
 */
data class NetworkRequest(
    /**
     * The request URL.
     */
    val url: String,
    
    /**
     * The HTTP method.
     */
    val method: String = "GET",
    
    /**
     * Request headers.
     */
    val headers: Map<String, String> = emptyMap(),
    
    /**
     * Request body.
     */
    val body: ByteArray? = null,
    
    /**
     * Request timeout in milliseconds.
     */
    val timeoutMs: Long = 30000
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as NetworkRequest
        return url == other.url &&
                method == other.method &&
                headers == other.headers &&
                body.contentEquals(other.body) &&
                timeoutMs == other.timeoutMs
    }

    override fun hashCode(): Int {
        var result = url.hashCode()
        result = 31 * result + method.hashCode()
        result = 31 * result + headers.hashCode()
        result = 31 * result + (body?.contentHashCode() ?: 0)
        result = 31 * result + timeoutMs.hashCode()
        return result
    }
}

/**
 * Response from a network request.
 */
data class NetworkResponse(
    /**
     * HTTP status code.
     */
    val statusCode: Int,
    
    /**
     * Response headers.
     */
    val headers: Map<String, String>,
    
    /**
     * Response body.
     */
    val body: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as NetworkResponse
        return statusCode == other.statusCode &&
                headers == other.headers &&
                body.contentEquals(other.body)
    }

    override fun hashCode(): Int {
        var result = statusCode
        result = 31 * result + headers.hashCode()
        result = 31 * result + body.contentHashCode()
        return result
    }
}
