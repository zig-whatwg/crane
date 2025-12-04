/**
 * @file whatwg_backend.h
 * @brief VTable definitions for WHATWG Platform Backend capabilities
 * 
 * This header defines the VTable structures for each platform capability.
 * Embedders implement these VTables to provide platform-specific functionality.
 * 
 * ## Design
 * 
 * Each VTable is a struct containing function pointers. All functions:
 * - Take `void* user_context` as the first parameter
 * - Use C calling convention
 * - Return error codes, not exceptions
 * 
 * ## Example Implementation (C)
 * 
 * ```c
 * static int32_t my_read_text(void* ctx, char* buf, size_t len) {
 *     // Platform-specific clipboard read
 *     return strlen(text);
 * }
 * 
 * static whatwg_clipboard_result_t my_write_text(void* ctx, const char* text, size_t len) {
 *     // Platform-specific clipboard write
 *     return WHATWG_CLIPBOARD_SUCCESS;
 * }
 * 
 * static const whatwg_clipboard_vtable_t my_clipboard = {
 *     .read_text = my_read_text,
 *     .write_text = my_write_text,
 *     // ... other functions
 * };
 * ```
 */

#ifndef WHATWG_BACKEND_H
#define WHATWG_BACKEND_H

#include "whatwg_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Clipboard VTable
 * Spec: https://w3c.github.io/clipboard-apis/
 * ============================================================================ */

/**
 * @brief Clipboard capability VTable.
 * 
 * Provides copy/paste functionality for text and HTML content.
 */
struct whatwg_clipboard_vtable {
    /**
     * @brief Read plain text from clipboard.
     * 
     * @param user_context Embedder context
     * @param buffer Buffer to write text to (NULL to query size)
     * @param buffer_size Size of buffer
     * @return Text length on success, negative error code on failure
     */
    int32_t (*read_text)(void* user_context, char* buffer, size_t buffer_size);
    
    /**
     * @brief Write plain text to clipboard.
     */
    whatwg_clipboard_result_t (*write_text)(void* user_context, const char* text, size_t text_len);
    
    /**
     * @brief Read HTML from clipboard.
     */
    int32_t (*read_html)(void* user_context, char* buffer, size_t buffer_size);
    
    /**
     * @brief Write HTML to clipboard with optional plain text fallback.
     */
    whatwg_clipboard_result_t (*write_html)(
        void* user_context,
        const char* html, size_t html_len,
        const char* plain_text, size_t plain_text_len
    );
    
    /**
     * @brief Check if clipboard read is permitted.
     */
    bool (*can_read)(void* user_context);
    
    /**
     * @brief Check if clipboard write is permitted.
     */
    bool (*can_write)(void* user_context);
    
    /**
     * @brief Check if clipboard has content.
     */
    bool (*has_content)(void* user_context);
    
    /**
     * @brief Clear clipboard contents.
     */
    whatwg_clipboard_result_t (*clear)(void* user_context);
};

/* ============================================================================
 * Timer VTable
 * ============================================================================ */

/**
 * @brief Timer capability VTable.
 * 
 * Provides timing operations for setTimeout, setInterval, and performance APIs.
 */
struct whatwg_timer_vtable {
    /**
     * @brief Get current time in milliseconds since epoch.
     */
    int64_t (*get_current_time)(void* user_context);
    
    /**
     * @brief Get high-resolution time in nanoseconds.
     */
    int64_t (*get_high_res_time)(void* user_context);
    
    /**
     * @brief Schedule a wakeup at the specified time.
     */
    void (*schedule_wakeup)(void* user_context, int64_t time_ms);
    
    /**
     * @brief Cancel any pending wakeup.
     */
    void (*cancel_wakeup)(void* user_context);
    
    /**
     * @brief Sleep until the next scheduled wakeup or timeout.
     * @param timeout_ms Timeout in milliseconds (-1 = no timeout)
     * @return Actual time slept in milliseconds
     */
    int64_t (*sleep_until_wakeup)(void* user_context, int64_t timeout_ms);
};

/* ============================================================================
 * Storage VTable
 * Spec: https://storage.spec.whatwg.org/
 * ============================================================================ */

/**
 * @brief Storage capability VTable.
 * 
 * Provides localStorage, sessionStorage, and IndexedDB-style storage.
 */
struct whatwg_storage_vtable {
    /**
     * @brief Get an item from storage.
     * @return Value length on success, negative error code on failure
     */
    int32_t (*get_item)(void* user_context, const char* key, size_t key_len, char* buffer, size_t buffer_size);
    
    /**
     * @brief Set an item in storage.
     */
    whatwg_storage_result_t (*set_item)(void* user_context, const char* key, size_t key_len, const char* value, size_t value_len);
    
    /**
     * @brief Remove an item from storage.
     */
    whatwg_storage_result_t (*remove_item)(void* user_context, const char* key, size_t key_len);
    
    /**
     * @brief Clear all storage.
     */
    whatwg_storage_result_t (*clear)(void* user_context);
    
    /**
     * @brief Get the number of items in storage.
     */
    uint32_t (*get_length)(void* user_context);
    
    /**
     * @brief Get key at index.
     * @return Key length on success, negative error code on failure
     */
    int32_t (*key)(void* user_context, uint32_t index, char* buffer, size_t buffer_size);
    
    /**
     * @brief Get storage quota in bytes.
     */
    uint64_t (*get_quota)(void* user_context);
};

/* ============================================================================
 * Network VTable
 * Spec: https://fetch.spec.whatwg.org/
 * ============================================================================ */

/**
 * @brief Network request structure.
 */
typedef struct {
    const char* url;
    size_t url_len;
    const char* method;
    size_t method_len;
    const char* body;
    size_t body_len;
    /* Additional headers can be added as needed */
} whatwg_network_request_t;

/**
 * @brief Network response callback type.
 */
typedef void (*whatwg_network_callback_t)(
    void* callback_data,
    int32_t status_code,
    const char* body,
    size_t body_len,
    whatwg_network_result_t result
);

/**
 * @brief Network capability VTable.
 */
struct whatwg_network_vtable {
    /**
     * @brief Send an HTTP request asynchronously.
     * @return Request ID, or 0 on failure
     */
    uint64_t (*fetch)(
        void* user_context,
        const whatwg_network_request_t* request,
        whatwg_network_callback_t callback,
        void* callback_data
    );
    
    /**
     * @brief Cancel a pending request.
     */
    void (*abort)(void* user_context, uint64_t request_id);
    
    /**
     * @brief Check if the device is online.
     */
    bool (*is_online)(void* user_context);
};

/* ============================================================================
 * Geolocation VTable
 * Spec: https://w3c.github.io/geolocation-api/
 * ============================================================================ */

/**
 * @brief Geolocation success callback type.
 */
typedef void (*whatwg_geolocation_success_t)(void* callback_data, const whatwg_geolocation_position_t* position);

/**
 * @brief Geolocation error callback type.
 */
typedef void (*whatwg_geolocation_error_callback_t)(void* callback_data, whatwg_geolocation_error_t error);

/**
 * @brief Watch ID type.
 */
typedef int64_t whatwg_watch_id_t;

/**
 * @brief Geolocation capability VTable.
 */
struct whatwg_geolocation_vtable {
    /**
     * @brief Get current position asynchronously.
     */
    void (*get_current_position)(
        void* user_context,
        whatwg_geolocation_success_t on_success,
        whatwg_geolocation_error_callback_t on_error,
        void* callback_data,
        bool enable_high_accuracy,
        uint32_t timeout_ms,
        uint32_t maximum_age_ms
    );
    
    /**
     * @brief Watch position changes.
     * @return Watch ID
     */
    whatwg_watch_id_t (*watch_position)(
        void* user_context,
        whatwg_geolocation_success_t on_success,
        whatwg_geolocation_error_callback_t on_error,
        void* callback_data,
        bool enable_high_accuracy,
        uint32_t timeout_ms,
        uint32_t maximum_age_ms
    );
    
    /**
     * @brief Clear a watch.
     */
    void (*clear_watch)(void* user_context, whatwg_watch_id_t watch_id);
};

/* ============================================================================
 * Layout VTable
 * Spec: https://drafts.csswg.org/cssom-view/
 * ============================================================================ */

/**
 * @brief Layout capability VTable.
 * 
 * Provides CSSOM View measurements (offsetWidth, getBoundingClientRect, etc.)
 */
struct whatwg_layout_vtable {
    double (*get_offset_width)(void* user_context, void* element);
    double (*get_offset_height)(void* user_context, void* element);
    double (*get_offset_top)(void* user_context, void* element);
    double (*get_offset_left)(void* user_context, void* element);
    void* (*get_offset_parent)(void* user_context, void* element);
    double (*get_client_width)(void* user_context, void* element);
    double (*get_client_height)(void* user_context, void* element);
    double (*get_client_top)(void* user_context, void* element);
    double (*get_client_left)(void* user_context, void* element);
    double (*get_scroll_width)(void* user_context, void* element);
    double (*get_scroll_height)(void* user_context, void* element);
    double (*get_scroll_top)(void* user_context, void* element);
    void (*set_scroll_top)(void* user_context, void* element, double value);
    double (*get_scroll_left)(void* user_context, void* element);
    void (*set_scroll_left)(void* user_context, void* element, double value);
    void (*get_bounding_client_rect)(void* user_context, void* element, whatwg_dom_rect_t* rect);
};

/* ============================================================================
 * Screen VTable
 * Spec: https://w3c.github.io/screen-orientation/
 * ============================================================================ */

/**
 * @brief Screen capability VTable.
 */
struct whatwg_screen_vtable {
    uint32_t (*get_width)(void* user_context);
    uint32_t (*get_height)(void* user_context);
    uint32_t (*get_avail_width)(void* user_context);
    uint32_t (*get_avail_height)(void* user_context);
    uint32_t (*get_color_depth)(void* user_context);
    uint32_t (*get_pixel_depth)(void* user_context);
};

/* ============================================================================
 * Battery VTable
 * Spec: https://w3c.github.io/battery/
 * ============================================================================ */

/**
 * @brief Battery capability VTable.
 */
struct whatwg_battery_vtable {
    double (*get_level)(void* user_context);
    bool (*get_charging)(void* user_context);
    double (*get_charging_time)(void* user_context);
    double (*get_discharging_time)(void* user_context);
};

/* ============================================================================
 * Vibration VTable
 * Spec: https://w3c.github.io/vibration/
 * ============================================================================ */

/**
 * @brief Vibration capability VTable.
 */
struct whatwg_vibration_vtable {
    bool (*vibrate)(void* user_context, const uint32_t* pattern, size_t pattern_len);
    void (*cancel)(void* user_context);
};

/* ============================================================================
 * Permissions VTable
 * Spec: https://w3c.github.io/permissions/
 * ============================================================================ */

/**
 * @brief Permission state values.
 */
typedef enum {
    WHATWG_PERMISSION_GRANTED = 0,
    WHATWG_PERMISSION_DENIED = 1,
    WHATWG_PERMISSION_PROMPT = 2
} whatwg_permission_state_t;

/**
 * @brief Permissions capability VTable.
 */
struct whatwg_permissions_vtable {
    /**
     * @brief Query permission state.
     * @return Permission state
     */
    whatwg_permission_state_t (*query)(void* user_context, const char* name, size_t name_len);
    
    /**
     * @brief Request permission.
     * @return Permission state after request
     */
    whatwg_permission_state_t (*request)(void* user_context, const char* name, size_t name_len);
};

/* ============================================================================
 * UI VTable
 * ============================================================================ */

/**
 * @brief Alert dialog type.
 */
typedef enum {
    WHATWG_ALERT_INFO = 0,
    WHATWG_ALERT_WARNING = 1,
    WHATWG_ALERT_ERROR = 2
} whatwg_alert_type_t;

/**
 * @brief UI capability VTable.
 */
struct whatwg_ui_vtable {
    void (*alert)(void* user_context, const char* message, size_t message_len, whatwg_alert_type_t type);
    bool (*confirm)(void* user_context, const char* message, size_t message_len);
    int32_t (*prompt)(void* user_context, const char* message, size_t message_len, const char* default_value, size_t default_len, char* buffer, size_t buffer_size);
    void (*focus)(void* user_context, void* element);
    void (*blur)(void* user_context, void* element);
    void (*scroll_to)(void* user_context, double x, double y);
    void (*scroll_by)(void* user_context, double x, double y);
};

/* ============================================================================
 * Notification VTable
 * Spec: https://notifications.spec.whatwg.org/
 * ============================================================================ */

/**
 * @brief Notification options structure.
 */
typedef struct {
    const char* body;
    size_t body_len;
    const char* icon;
    size_t icon_len;
    const char* tag;
    size_t tag_len;
    bool require_interaction;
} whatwg_notification_options_t;

/**
 * @brief Notification callback type.
 */
typedef void (*whatwg_notification_callback_t)(void* callback_data, uint64_t notification_id, const char* event_type);

/**
 * @brief Notification capability VTable.
 */
struct whatwg_notification_vtable {
    whatwg_notification_permission_t (*get_permission)(void* user_context);
    whatwg_notification_permission_t (*request_permission)(void* user_context);
    uint64_t (*show)(void* user_context, const char* title, size_t title_len, const whatwg_notification_options_t* options);
    void (*close)(void* user_context, uint64_t notification_id);
    void (*set_callback)(void* user_context, whatwg_notification_callback_t callback, void* callback_data);
};

/* ============================================================================
 * Share VTable
 * Spec: https://w3c.github.io/web-share/
 * ============================================================================ */

/**
 * @brief Share capability VTable.
 */
struct whatwg_share_vtable {
    bool (*can_share)(void* user_context);
    bool (*share)(void* user_context, const char* title, size_t title_len, const char* text, size_t text_len, const char* url, size_t url_len);
};

/* ============================================================================
 * Stub VTables for Less Common APIs
 * ============================================================================ */

/* Push VTable - for push notifications */
struct whatwg_push_vtable {
    void* _reserved;  /* Implementation-specific */
};

/* FileSystem VTable - for File System Access API */
struct whatwg_filesystem_vtable {
    void* _reserved;
};

/* Bluetooth VTable - for Web Bluetooth */
struct whatwg_bluetooth_vtable {
    void* _reserved;
};

/* USB VTable - for WebUSB */
struct whatwg_usb_vtable {
    void* _reserved;
};

/* Serial VTable - for Web Serial */
struct whatwg_serial_vtable {
    void* _reserved;
};

/* HID VTable - for WebHID */
struct whatwg_hid_vtable {
    void* _reserved;
};

/* NFC VTable - for Web NFC */
struct whatwg_nfc_vtable {
    void* _reserved;
};

/* Device Orientation VTable */
struct whatwg_device_orientation_vtable {
    void* _reserved;
};

/* Wake Lock VTable */
struct whatwg_wake_lock_vtable {
    void* _reserved;
};

/* WebRTC VTable */
struct whatwg_webrtc_vtable {
    void* _reserved;
};

/* Media VTable */
struct whatwg_media_vtable {
    void* _reserved;
};

/* Audio VTable */
struct whatwg_audio_vtable {
    void* _reserved;
};

/* Speech VTable */
struct whatwg_speech_vtable {
    void* _reserved;
};

/* Gamepad VTable */
struct whatwg_gamepad_vtable {
    void* _reserved;
};

/* Sensor VTable */
struct whatwg_sensor_vtable {
    void* _reserved;
};

/* Credentials VTable */
struct whatwg_credentials_vtable {
    void* _reserved;
};

/* WebAuthn VTable */
struct whatwg_webauthn_vtable {
    void* _reserved;
};

/* Payment VTable */
struct whatwg_payment_vtable {
    void* _reserved;
};

#ifdef __cplusplus
}
#endif

#endif /* WHATWG_BACKEND_H */
