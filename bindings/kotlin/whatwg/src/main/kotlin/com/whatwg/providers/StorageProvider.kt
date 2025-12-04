package com.whatwg.providers

/**
 * Interface for providing storage functionality (localStorage/sessionStorage).
 *
 * Implement this interface to provide key-value storage support.
 */
interface StorageProvider {

    /**
     * Gets a value from storage.
     *
     * @param key The key to retrieve.
     * @return The value, or `null` if not found.
     */
    suspend fun getItem(key: String): String?

    /**
     * Sets a value in storage.
     *
     * @param key The key to set.
     * @param value The value to store.
     * @throws Exception If storage is full or denied.
     */
    suspend fun setItem(key: String, value: String)

    /**
     * Removes a value from storage.
     *
     * @param key The key to remove.
     */
    suspend fun removeItem(key: String)

    /**
     * Clears all storage.
     */
    suspend fun clear()

    /**
     * Returns the number of items in storage.
     */
    suspend fun length(): Int

    /**
     * Returns the key at the given index.
     *
     * @param index The index.
     * @return The key, or `null` if out of bounds.
     */
    suspend fun key(index: Int): String?
}
