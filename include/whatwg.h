/**
 * @file whatwg.h
 * @brief Main C header for WHATWG Platform Backend
 * 
 * This is the unified C API for the WHATWG browser engine implementation.
 * It provides platform abstraction for embedders (iOS/Swift, Android/Kotlin, etc.)
 * 
 * ## Quick Start
 * 
 * ```c
 * #include <whatwg.h>
 * 
 * int main() {
 *     // Create platform backend
 *     whatwg_platform_t* platform = whatwg_platform_create();
 *     if (!platform) return 1;
 *     
 *     // Set capabilities
 *     whatwg_platform_set_clipboard(platform, &my_clipboard_vtable);
 *     whatwg_platform_set_network(platform, &my_network_vtable);
 *     
 *     // Use platform...
 *     
 *     // Cleanup
 *     whatwg_platform_destroy(platform);
 *     return 0;
 * }
 * ```
 * 
 * @version 1.0
 * @copyright MIT License
 */

#ifndef WHATWG_H
#define WHATWG_H

#include "whatwg_types.h"
#include "whatwg_backend.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Version Information
 * ============================================================================ */

/**
 * @brief Get the expected ABI version for this library.
 * @return ABI version number
 */
uint32_t whatwg_platform_expected_version(void);

/**
 * @brief Get the library version string.
 * @return Version string (e.g., "1.0.0")
 */
const char* whatwg_version_string(void);

/* ============================================================================
 * Platform Lifecycle
 * ============================================================================ */

/**
 * @brief Create a new PlatformBackend with default configuration.
 * 
 * Creates an empty backend with no capabilities enabled.
 * Caller must call whatwg_platform_destroy() to free.
 * 
 * @return Pointer to PlatformBackend, or NULL on allocation failure
 */
whatwg_platform_t* whatwg_platform_create(void);

/**
 * @brief Create a new PlatformBackend with a user context.
 * 
 * The user_context is passed to all VTable functions as the first argument.
 * This allows embedders to store custom state accessible from callbacks.
 * 
 * @param user_context Opaque pointer to embedder-specific context
 * @return Pointer to PlatformBackend, or NULL on failure
 */
whatwg_platform_t* whatwg_platform_create_with_context(void* user_context);

/**
 * @brief Destroy a PlatformBackend and free its memory.
 * 
 * This does NOT free any VTables - those are owned by the embedder.
 * Safe to call with NULL.
 * 
 * @param backend Pointer to PlatformBackend to destroy
 */
void whatwg_platform_destroy(whatwg_platform_t* backend);

/* ============================================================================
 * Version & Compatibility
 * ============================================================================ */

/**
 * @brief Get the ABI version of a PlatformBackend.
 * 
 * @param backend Pointer to PlatformBackend
 * @return ABI version number, or 0 if backend is NULL
 */
uint32_t whatwg_platform_get_version(const whatwg_platform_t* backend);

/**
 * @brief Check if a PlatformBackend is ABI-compatible.
 * 
 * @param backend Pointer to PlatformBackend
 * @return true if compatible, false otherwise
 */
bool whatwg_platform_is_compatible(const whatwg_platform_t* backend);

/* ============================================================================
 * User Context
 * ============================================================================ */

/**
 * @brief Get the user context from a PlatformBackend.
 * 
 * @param backend Pointer to PlatformBackend
 * @return User context pointer, or NULL if not set
 */
void* whatwg_platform_get_user_context(const whatwg_platform_t* backend);

/**
 * @brief Set the user context on a PlatformBackend.
 * 
 * @param backend Pointer to PlatformBackend
 * @param user_context New user context pointer
 */
void whatwg_platform_set_user_context(whatwg_platform_t* backend, void* user_context);

/* ============================================================================
 * Capability Query
 * ============================================================================ */

/**
 * @brief Check if a specific capability is available.
 * 
 * @param backend Pointer to PlatformBackend
 * @param capability Capability constant (WHATWG_CAP_*)
 * @return true if capability is available, false otherwise
 */
bool whatwg_platform_has_capability(const whatwg_platform_t* backend, uint8_t capability);

/**
 * @brief Count the number of available capabilities.
 * 
 * @param backend Pointer to PlatformBackend
 * @return Number of available capabilities
 */
uint32_t whatwg_platform_capability_count(const whatwg_platform_t* backend);

/* ============================================================================
 * Capability Setters
 * ============================================================================ */

void whatwg_platform_set_clipboard(whatwg_platform_t* backend, const whatwg_clipboard_vtable_t* vtable);
void whatwg_platform_set_timer(whatwg_platform_t* backend, const whatwg_timer_vtable_t* vtable);
void whatwg_platform_set_network(whatwg_platform_t* backend, const whatwg_network_vtable_t* vtable);
void whatwg_platform_set_storage(whatwg_platform_t* backend, const whatwg_storage_vtable_t* vtable);
void whatwg_platform_set_layout(whatwg_platform_t* backend, const whatwg_layout_vtable_t* vtable);
void whatwg_platform_set_ui(whatwg_platform_t* backend, const whatwg_ui_vtable_t* vtable);
void whatwg_platform_set_screen(whatwg_platform_t* backend, const whatwg_screen_vtable_t* vtable);
void whatwg_platform_set_notification(whatwg_platform_t* backend, const whatwg_notification_vtable_t* vtable);
void whatwg_platform_set_push(whatwg_platform_t* backend, const whatwg_push_vtable_t* vtable);
void whatwg_platform_set_share(whatwg_platform_t* backend, const whatwg_share_vtable_t* vtable);
void whatwg_platform_set_filesystem(whatwg_platform_t* backend, const whatwg_filesystem_vtable_t* vtable);
void whatwg_platform_set_geolocation(whatwg_platform_t* backend, const whatwg_geolocation_vtable_t* vtable);
void whatwg_platform_set_bluetooth(whatwg_platform_t* backend, const whatwg_bluetooth_vtable_t* vtable);
void whatwg_platform_set_usb(whatwg_platform_t* backend, const whatwg_usb_vtable_t* vtable);
void whatwg_platform_set_serial(whatwg_platform_t* backend, const whatwg_serial_vtable_t* vtable);
void whatwg_platform_set_hid(whatwg_platform_t* backend, const whatwg_hid_vtable_t* vtable);
void whatwg_platform_set_nfc(whatwg_platform_t* backend, const whatwg_nfc_vtable_t* vtable);
void whatwg_platform_set_device_orientation(whatwg_platform_t* backend, const whatwg_device_orientation_vtable_t* vtable);
void whatwg_platform_set_vibration(whatwg_platform_t* backend, const whatwg_vibration_vtable_t* vtable);
void whatwg_platform_set_battery(whatwg_platform_t* backend, const whatwg_battery_vtable_t* vtable);
void whatwg_platform_set_wake_lock(whatwg_platform_t* backend, const whatwg_wake_lock_vtable_t* vtable);
void whatwg_platform_set_webrtc(whatwg_platform_t* backend, const whatwg_webrtc_vtable_t* vtable);
void whatwg_platform_set_media(whatwg_platform_t* backend, const whatwg_media_vtable_t* vtable);
void whatwg_platform_set_audio(whatwg_platform_t* backend, const whatwg_audio_vtable_t* vtable);
void whatwg_platform_set_speech(whatwg_platform_t* backend, const whatwg_speech_vtable_t* vtable);
void whatwg_platform_set_gamepad(whatwg_platform_t* backend, const whatwg_gamepad_vtable_t* vtable);
void whatwg_platform_set_sensor(whatwg_platform_t* backend, const whatwg_sensor_vtable_t* vtable);
void whatwg_platform_set_credentials(whatwg_platform_t* backend, const whatwg_credentials_vtable_t* vtable);
void whatwg_platform_set_webauthn(whatwg_platform_t* backend, const whatwg_webauthn_vtable_t* vtable);
void whatwg_platform_set_permissions(whatwg_platform_t* backend, const whatwg_permissions_vtable_t* vtable);
void whatwg_platform_set_payment(whatwg_platform_t* backend, const whatwg_payment_vtable_t* vtable);

#ifdef __cplusplus
}
#endif

#endif /* WHATWG_H */
