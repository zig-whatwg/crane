package com.whatwg.providers

/**
 * Interface for providing notification functionality.
 *
 * Implement this interface to provide system notification support.
 */
interface NotificationProvider {

    /**
     * Requests notification permission.
     *
     * @return The permission status.
     */
    suspend fun requestPermission(): NotificationPermission

    /**
     * Gets the current permission status.
     */
    val permission: NotificationPermission

    /**
     * Shows a notification.
     *
     * @param options Notification options.
     * @return A notification handle.
     * @throws Exception If permission is denied.
     */
    suspend fun show(options: NotificationOptions): NotificationHandle
}

/**
 * Notification permission states.
 */
enum class NotificationPermission(val value: String) {
    DEFAULT("default"),
    GRANTED("granted"),
    DENIED("denied")
}

/**
 * Options for creating a notification.
 */
data class NotificationOptions(
    /**
     * The notification title.
     */
    val title: String,
    
    /**
     * The notification body.
     */
    val body: String? = null,
    
    /**
     * The notification icon URL.
     */
    val icon: String? = null,
    
    /**
     * The notification badge URL.
     */
    val badge: String? = null,
    
    /**
     * The notification image URL.
     */
    val image: String? = null,
    
    /**
     * The notification tag.
     */
    val tag: String? = null,
    
    /**
     * Data associated with the notification.
     */
    val data: Any? = null,
    
    /**
     * Whether to require interaction.
     */
    val requireInteraction: Boolean = false,
    
    /**
     * Whether to suppress sound.
     */
    val silent: Boolean = false,
    
    /**
     * Vibration pattern.
     */
    val vibrate: List<Long>? = null,
    
    /**
     * Actions for the notification.
     */
    val actions: List<NotificationAction> = emptyList()
)

/**
 * An action button for a notification.
 */
data class NotificationAction(
    /**
     * Action identifier.
     */
    val action: String,
    
    /**
     * Action title.
     */
    val title: String,
    
    /**
     * Action icon URL.
     */
    val icon: String? = null
)

/**
 * A handle to an active notification.
 */
interface NotificationHandle {
    /**
     * The notification tag.
     */
    val tag: String?
    
    /**
     * Closes the notification.
     */
    fun close()
}
