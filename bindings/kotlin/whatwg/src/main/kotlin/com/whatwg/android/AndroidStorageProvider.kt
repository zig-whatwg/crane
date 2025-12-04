package com.whatwg.android

import android.content.Context
import android.content.SharedPreferences
import com.whatwg.providers.StorageProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Android implementation of StorageProvider using SharedPreferences.
 *
 * For larger data sets, consider using Room or direct file storage instead.
 *
 * ## Example Usage
 *
 * ```kotlin
 * val platform = WhatWGPlatform()
 * platform.storageProvider = AndroidStorageProvider(context)
 * ```
 *
 * @param context Android context used to access SharedPreferences.
 * @param preferenceName Name of the SharedPreferences file.
 */
class AndroidStorageProvider(
    context: Context,
    preferenceName: String = "whatwg_storage"
) : StorageProvider {
    
    private val preferences: SharedPreferences = context.getSharedPreferences(preferenceName, Context.MODE_PRIVATE)
    private val mutex = Mutex()
    
    override suspend fun getItem(key: String): String? = withContext(Dispatchers.IO) {
        mutex.withLock {
            preferences.getString(key, null)
        }
    }
    
    override suspend fun setItem(key: String, value: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            preferences.edit().putString(key, value).apply()
        }
    }
    
    override suspend fun removeItem(key: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            preferences.edit().remove(key).apply()
        }
    }
    
    override suspend fun clear() = withContext(Dispatchers.IO) {
        mutex.withLock {
            preferences.edit().clear().apply()
        }
    }
    
    override suspend fun length(): Int = withContext(Dispatchers.IO) {
        mutex.withLock {
            preferences.all.size
        }
    }
    
    override suspend fun key(index: Int): String? = withContext(Dispatchers.IO) {
        mutex.withLock {
            val keys = preferences.all.keys.toList().sorted()
            if (index >= 0 && index < keys.size) {
                keys[index]
            } else {
                null
            }
        }
    }
}

/**
 * Android implementation of StorageProvider using internal file storage.
 *
 * Stores each key-value pair in a separate file within a directory.
 * More suitable for larger values than SharedPreferences.
 *
 * @param context Android context used to access filesDir.
 * @param directoryName Name of the subdirectory for storage.
 */
class AndroidFileStorageProvider(
    context: Context,
    directoryName: String = "whatwg_storage"
) : StorageProvider {
    
    private val storageDir = context.getDir(directoryName, Context.MODE_PRIVATE)
    private val mutex = Mutex()
    
    override suspend fun getItem(key: String): String? = withContext(Dispatchers.IO) {
        mutex.withLock {
            val file = java.io.File(storageDir, encodeKey(key))
            if (file.exists()) {
                file.readText()
            } else {
                null
            }
        }
    }
    
    override suspend fun setItem(key: String, value: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val file = java.io.File(storageDir, encodeKey(key))
            file.writeText(value)
        }
    }
    
    override suspend fun removeItem(key: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            val file = java.io.File(storageDir, encodeKey(key))
            file.delete()
        }
    }
    
    override suspend fun clear() = withContext(Dispatchers.IO) {
        mutex.withLock {
            storageDir.listFiles()?.forEach { it.delete() }
        }
    }
    
    override suspend fun length(): Int = withContext(Dispatchers.IO) {
        mutex.withLock {
            storageDir.listFiles()?.size ?: 0
        }
    }
    
    override suspend fun key(index: Int): String? = withContext(Dispatchers.IO) {
        mutex.withLock {
            val files = storageDir.listFiles()?.sortedBy { it.name } ?: emptyList()
            if (index >= 0 && index < files.size) {
                decodeKey(files[index].name)
            } else {
                null
            }
        }
    }
    
    private fun encodeKey(key: String): String {
        return java.net.URLEncoder.encode(key, "UTF-8")
    }
    
    private fun decodeKey(encoded: String): String {
        return java.net.URLDecoder.decode(encoded, "UTF-8")
    }
}
