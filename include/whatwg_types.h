/**
 * @file whatwg_types.h
 * @brief Common type definitions for WHATWG Platform Backend
 * 
 * This header defines the fundamental types used throughout the WHATWG C API.
 * It provides cross-platform type definitions and common constants.
 */

#ifndef WHATWG_TYPES_H
#define WHATWG_TYPES_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Boolean Type (C89 Compatible)
 * ============================================================================ */

/**
 * @brief Boolean type for C89 compatibility.
 * 
 * In C99+, this maps to _Bool via stdbool.h.
 * In C89, we use int for maximum compatibility.
 */
#if defined(__cplusplus)
    /* C++ has native bool */
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
    #include <stdbool.h>
#else
    /* C89 fallback */
    #ifndef __bool_true_false_are_defined
        typedef int bool;
        #define true 1
        #define false 0
        #define __bool_true_false_are_defined 1
    #endif
#endif

/* ============================================================================
 * Platform Backend
 * ============================================================================ */

/**
 * @brief Opaque handle to a PlatformBackend instance.
 * 
 * The PlatformBackend is the central orchestration point for all platform
 * capabilities. Embedders create a backend, configure capabilities via VTables,
 * and pass it to the browser engine.
 */
typedef struct whatwg_platform whatwg_platform_t;

/* ============================================================================
 * Capability Constants
 * ============================================================================ */

#define WHATWG_CAP_CLIPBOARD            0
#define WHATWG_CAP_TIMER                1
#define WHATWG_CAP_NETWORK              2
#define WHATWG_CAP_STORAGE              3
#define WHATWG_CAP_LAYOUT               4
#define WHATWG_CAP_UI                   5
#define WHATWG_CAP_SCREEN               6
#define WHATWG_CAP_NOTIFICATION         7
#define WHATWG_CAP_PUSH                 8
#define WHATWG_CAP_SHARE                9
#define WHATWG_CAP_FILESYSTEM           10
#define WHATWG_CAP_GEOLOCATION          11
#define WHATWG_CAP_BLUETOOTH            12
#define WHATWG_CAP_USB                  13
#define WHATWG_CAP_SERIAL               14
#define WHATWG_CAP_HID                  15
#define WHATWG_CAP_NFC                  16
#define WHATWG_CAP_DEVICE_ORIENTATION   17
#define WHATWG_CAP_VIBRATION            18
#define WHATWG_CAP_BATTERY              19
#define WHATWG_CAP_WAKE_LOCK            20
#define WHATWG_CAP_WEBRTC               21
#define WHATWG_CAP_MEDIA                22
#define WHATWG_CAP_AUDIO                23
#define WHATWG_CAP_SPEECH               24
#define WHATWG_CAP_GAMEPAD              25
#define WHATWG_CAP_SENSOR               26
#define WHATWG_CAP_CREDENTIALS          27
#define WHATWG_CAP_WEBAUTHN             28
#define WHATWG_CAP_PERMISSIONS          29
#define WHATWG_CAP_PAYMENT              30

/** @brief Total number of capabilities */
#define WHATWG_CAP_COUNT                31

/* ============================================================================
 * Common Result Types
 * ============================================================================ */

/**
 * @brief Clipboard operation result codes.
 */
typedef enum {
    WHATWG_CLIPBOARD_SUCCESS = 0,
    WHATWG_CLIPBOARD_PERMISSION_DENIED = -1,
    WHATWG_CLIPBOARD_NOT_AVAILABLE = -2,
    WHATWG_CLIPBOARD_EMPTY = -3,
    WHATWG_CLIPBOARD_ERROR = -99
} whatwg_clipboard_result_t;

/**
 * @brief Storage operation result codes.
 */
typedef enum {
    WHATWG_STORAGE_SUCCESS = 0,
    WHATWG_STORAGE_NOT_FOUND = -1,
    WHATWG_STORAGE_QUOTA_EXCEEDED = -2,
    WHATWG_STORAGE_PERMISSION_DENIED = -3,
    WHATWG_STORAGE_ERROR = -99
} whatwg_storage_result_t;

/**
 * @brief Notification permission states.
 */
typedef enum {
    WHATWG_NOTIFICATION_DEFAULT = 0,
    WHATWG_NOTIFICATION_GRANTED = 1,
    WHATWG_NOTIFICATION_DENIED = 2
} whatwg_notification_permission_t;

/**
 * @brief Geolocation error codes.
 */
typedef enum {
    WHATWG_GEO_SUCCESS = 0,
    WHATWG_GEO_PERMISSION_DENIED = 1,
    WHATWG_GEO_POSITION_UNAVAILABLE = 2,
    WHATWG_GEO_TIMEOUT = 3
} whatwg_geolocation_error_t;

/**
 * @brief File system operation result codes.
 */
typedef enum {
    WHATWG_FS_SUCCESS = 0,
    WHATWG_FS_NOT_FOUND = -1,
    WHATWG_FS_PERMISSION_DENIED = -2,
    WHATWG_FS_INVALID_NAME = -3,
    WHATWG_FS_QUOTA_EXCEEDED = -4,
    WHATWG_FS_ERROR = -99
} whatwg_filesystem_result_t;

/**
 * @brief Network operation result codes.
 */
typedef enum {
    WHATWG_NETWORK_SUCCESS = 0,
    WHATWG_NETWORK_ERROR = -1,
    WHATWG_NETWORK_TIMEOUT = -2,
    WHATWG_NETWORK_ABORT = -3,
    WHATWG_NETWORK_OFFLINE = -4
} whatwg_network_result_t;

/* ============================================================================
 * Common Structs
 * ============================================================================ */

/**
 * @brief DOMRect structure for layout measurements.
 */
typedef struct {
    double x;
    double y;
    double width;
    double height;
} whatwg_dom_rect_t;

/**
 * @brief Geolocation position structure.
 */
typedef struct {
    double latitude;
    double longitude;
    double altitude;
    double accuracy;
    double altitude_accuracy;
    double heading;
    double speed;
    int64_t timestamp;
} whatwg_geolocation_position_t;

/* ============================================================================
 * VTable Type Declarations (opaque)
 * 
 * These are forward declarations for the VTable types.
 * Full definitions are in whatwg_backend.h.
 * ============================================================================ */

typedef struct whatwg_clipboard_vtable whatwg_clipboard_vtable_t;
typedef struct whatwg_timer_vtable whatwg_timer_vtable_t;
typedef struct whatwg_network_vtable whatwg_network_vtable_t;
typedef struct whatwg_storage_vtable whatwg_storage_vtable_t;
typedef struct whatwg_layout_vtable whatwg_layout_vtable_t;
typedef struct whatwg_ui_vtable whatwg_ui_vtable_t;
typedef struct whatwg_screen_vtable whatwg_screen_vtable_t;
typedef struct whatwg_notification_vtable whatwg_notification_vtable_t;
typedef struct whatwg_push_vtable whatwg_push_vtable_t;
typedef struct whatwg_share_vtable whatwg_share_vtable_t;
typedef struct whatwg_filesystem_vtable whatwg_filesystem_vtable_t;
typedef struct whatwg_geolocation_vtable whatwg_geolocation_vtable_t;
typedef struct whatwg_bluetooth_vtable whatwg_bluetooth_vtable_t;
typedef struct whatwg_usb_vtable whatwg_usb_vtable_t;
typedef struct whatwg_serial_vtable whatwg_serial_vtable_t;
typedef struct whatwg_hid_vtable whatwg_hid_vtable_t;
typedef struct whatwg_nfc_vtable whatwg_nfc_vtable_t;
typedef struct whatwg_device_orientation_vtable whatwg_device_orientation_vtable_t;
typedef struct whatwg_vibration_vtable whatwg_vibration_vtable_t;
typedef struct whatwg_battery_vtable whatwg_battery_vtable_t;
typedef struct whatwg_wake_lock_vtable whatwg_wake_lock_vtable_t;
typedef struct whatwg_webrtc_vtable whatwg_webrtc_vtable_t;
typedef struct whatwg_media_vtable whatwg_media_vtable_t;
typedef struct whatwg_audio_vtable whatwg_audio_vtable_t;
typedef struct whatwg_speech_vtable whatwg_speech_vtable_t;
typedef struct whatwg_gamepad_vtable whatwg_gamepad_vtable_t;
typedef struct whatwg_sensor_vtable whatwg_sensor_vtable_t;
typedef struct whatwg_credentials_vtable whatwg_credentials_vtable_t;
typedef struct whatwg_webauthn_vtable whatwg_webauthn_vtable_t;
typedef struct whatwg_permissions_vtable whatwg_permissions_vtable_t;
typedef struct whatwg_payment_vtable whatwg_payment_vtable_t;

#ifdef __cplusplus
}
#endif

#endif /* WHATWG_TYPES_H */
