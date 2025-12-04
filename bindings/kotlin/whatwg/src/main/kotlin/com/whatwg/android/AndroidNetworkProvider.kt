package com.whatwg.android

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import com.whatwg.providers.NetworkProvider
import com.whatwg.providers.NetworkRequest as WhatWGNetworkRequest
import com.whatwg.providers.NetworkResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android implementation of NetworkProvider using HttpURLConnection.
 *
 * For production use, consider using OkHttp for better performance and features.
 * This implementation uses the built-in HttpURLConnection to minimize dependencies.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.networkProvider = AndroidNetworkProvider(context)
 * ```
 *
 * @param context Android context used to access ConnectivityManager.
 */
class AndroidNetworkProvider(context: Context) : NetworkProvider {
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val isNetworkAvailable = AtomicBoolean(false)
    
    init {
        // Monitor network connectivity
        val networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                isNetworkAvailable.set(true)
            }
            
            override fun onLost(network: Network) {
                isNetworkAvailable.set(false)
            }
            
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                val hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                isNetworkAvailable.set(hasInternet)
            }
        }
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        connectivityManager.registerNetworkCallback(request, networkCallback)
        
        // Check current network state
        val activeNetwork = connectivityManager.activeNetwork
        val capabilities = activeNetwork?.let { connectivityManager.getNetworkCapabilities(it) }
        isNetworkAvailable.set(
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        )
    }
    
    override suspend fun fetch(request: WhatWGNetworkRequest): NetworkResponse = withContext(Dispatchers.IO) {
        val url = URL(request.url)
        val connection = url.openConnection() as HttpURLConnection
        
        try {
            // Configure connection
            connection.requestMethod = request.method
            connection.connectTimeout = request.timeoutMs.toInt()
            connection.readTimeout = request.timeoutMs.toInt()
            connection.doInput = true
            
            // Set headers
            request.headers.forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            
            // Write body if present
            if (request.body != null && request.method in listOf("POST", "PUT", "PATCH")) {
                connection.doOutput = true
                connection.outputStream.use { os ->
                    os.write(request.body)
                }
            }
            
            // Get response
            val responseCode = connection.responseCode
            
            // Read headers
            val headers = mutableMapOf<String, String>()
            connection.headerFields.forEach { (key, values) ->
                if (key != null && values.isNotEmpty()) {
                    headers[key.lowercase()] = values.joinToString(", ")
                }
            }
            
            // Read body
            val body = try {
                val inputStream = if (responseCode >= 400) {
                    connection.errorStream ?: connection.inputStream
                } else {
                    connection.inputStream
                }
                inputStream.use { it.readBytes() }
            } catch (e: IOException) {
                ByteArray(0)
            }
            
            NetworkResponse(
                statusCode = responseCode,
                headers = headers,
                body = body
            )
        } finally {
            connection.disconnect()
        }
    }
    
    override fun isOnline(): Boolean {
        return isNetworkAvailable.get()
    }
}
