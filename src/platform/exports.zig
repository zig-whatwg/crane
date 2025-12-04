//! C ABI Exports for PlatformBackend
//!
//! This module provides C-compatible functions for initializing and managing
//! the WHATWG platform backend from foreign languages (Swift, Kotlin, C#, etc.).
//!
//! ## Memory Ownership
//!
//! - `whatwg_platform_create()` allocates a PlatformBackend - caller must call `whatwg_platform_destroy()`
//! - VTable pointers are NOT owned by PlatformBackend - caller manages their lifetime
//! - All string buffers passed to functions are NOT copied unless documented
//!
//! ## Thread Safety
//!
//! - PlatformBackend itself is thread-safe for reads
//! - Individual capability VTables may have their own thread safety requirements
//! - Check capability-specific documentation
//!
//! ## Swift Usage
//!
//! ```swift
//! // Create platform
//! guard let platform = whatwg_platform_create() else { fatalError("Failed to create platform") }
//! defer { whatwg_platform_destroy(platform) }
//!
//! // Check version
//! let version = whatwg_platform_get_version(platform)
//!
//! // Set capabilities
//! whatwg_platform_set_clipboard(platform, &clipboardVTable)
//! whatwg_platform_set_network(platform, &networkVTable)
//!
//! // Check capabilities
//! if whatwg_platform_has_capability(platform, WHATWG_CAP_CLIPBOARD) {
//!     // Clipboard is available
//! }
//! ```
//!
//! ## Kotlin Usage (JNI)
//!
//! ```kotlin
//! val platform = whatwg_platform_create()
//! try {
//!     whatwg_platform_set_network(platform, networkVTable)
//!     // ...
//! } finally {
//!     whatwg_platform_destroy(platform)
//! }
//! ```

const std = @import("std");
const platform_backend = @import("platform_backend.zig");
const vtables = @import("vtables.zig");

const PlatformBackend = platform_backend.PlatformBackend;
const Capability = platform_backend.Capability;

// =============================================================================
// Capability Constants (for C/Swift/Kotlin)
// =============================================================================

/// Capability constants for use in C code
pub export const WHATWG_CAP_CLIPBOARD: u8 = @intFromEnum(Capability.clipboard);
pub export const WHATWG_CAP_TIMER: u8 = @intFromEnum(Capability.timer);
pub export const WHATWG_CAP_NETWORK: u8 = @intFromEnum(Capability.network);
pub export const WHATWG_CAP_STORAGE: u8 = @intFromEnum(Capability.storage);
pub export const WHATWG_CAP_LAYOUT: u8 = @intFromEnum(Capability.layout);
pub export const WHATWG_CAP_UI: u8 = @intFromEnum(Capability.ui);
pub export const WHATWG_CAP_SCREEN: u8 = @intFromEnum(Capability.screen);
pub export const WHATWG_CAP_NOTIFICATION: u8 = @intFromEnum(Capability.notification);
pub export const WHATWG_CAP_PUSH: u8 = @intFromEnum(Capability.push);
pub export const WHATWG_CAP_SHARE: u8 = @intFromEnum(Capability.share);
pub export const WHATWG_CAP_FILESYSTEM: u8 = @intFromEnum(Capability.filesystem);
pub export const WHATWG_CAP_GEOLOCATION: u8 = @intFromEnum(Capability.geolocation);
pub export const WHATWG_CAP_BLUETOOTH: u8 = @intFromEnum(Capability.bluetooth);
pub export const WHATWG_CAP_USB: u8 = @intFromEnum(Capability.usb);
pub export const WHATWG_CAP_SERIAL: u8 = @intFromEnum(Capability.serial);
pub export const WHATWG_CAP_HID: u8 = @intFromEnum(Capability.hid);
pub export const WHATWG_CAP_NFC: u8 = @intFromEnum(Capability.nfc);
pub export const WHATWG_CAP_DEVICE_ORIENTATION: u8 = @intFromEnum(Capability.device_orientation);
pub export const WHATWG_CAP_VIBRATION: u8 = @intFromEnum(Capability.vibration);
pub export const WHATWG_CAP_BATTERY: u8 = @intFromEnum(Capability.battery);
pub export const WHATWG_CAP_WAKE_LOCK: u8 = @intFromEnum(Capability.wake_lock);
pub export const WHATWG_CAP_WEBRTC: u8 = @intFromEnum(Capability.webrtc);
pub export const WHATWG_CAP_MEDIA: u8 = @intFromEnum(Capability.media);
pub export const WHATWG_CAP_AUDIO: u8 = @intFromEnum(Capability.audio);
pub export const WHATWG_CAP_SPEECH: u8 = @intFromEnum(Capability.speech);
pub export const WHATWG_CAP_GAMEPAD: u8 = @intFromEnum(Capability.gamepad);
pub export const WHATWG_CAP_SENSOR: u8 = @intFromEnum(Capability.sensor);
pub export const WHATWG_CAP_CREDENTIALS: u8 = @intFromEnum(Capability.credentials);
pub export const WHATWG_CAP_WEBAUTHN: u8 = @intFromEnum(Capability.webauthn);
pub export const WHATWG_CAP_PERMISSIONS: u8 = @intFromEnum(Capability.permissions);
pub export const WHATWG_CAP_PAYMENT: u8 = @intFromEnum(Capability.payment);

// =============================================================================
// Lifecycle Functions
// =============================================================================

/// Create a new PlatformBackend with default (empty) configuration.
///
/// Returns null on allocation failure.
/// Caller must call `whatwg_platform_destroy()` to free the backend.
///
/// @return Pointer to PlatformBackend, or null on failure
pub export fn whatwg_platform_create() callconv(.c) ?*PlatformBackend {
    const allocator = std.heap.c_allocator;
    const backend = allocator.create(PlatformBackend) catch return null;
    backend.* = platform_backend.empty();
    return backend;
}

/// Create a new PlatformBackend with a user context.
///
/// The user_context is passed to all VTable functions as the first argument.
/// This allows embedders to store custom state accessible from callbacks.
///
/// @param user_context Opaque pointer to embedder-specific context
/// @return Pointer to PlatformBackend, or null on failure
pub export fn whatwg_platform_create_with_context(user_context: ?*anyopaque) callconv(.c) ?*PlatformBackend {
    const allocator = std.heap.c_allocator;
    const backend = allocator.create(PlatformBackend) catch return null;
    backend.* = platform_backend.withContext(user_context orelse return null);
    return backend;
}

/// Destroy a PlatformBackend and free its memory.
///
/// This does NOT free any VTables - those are owned by the embedder.
///
/// @param backend Pointer to PlatformBackend to destroy
pub export fn whatwg_platform_destroy(backend: ?*PlatformBackend) callconv(.c) void {
    if (backend) |b| {
        std.heap.c_allocator.destroy(b);
    }
}

// =============================================================================
// Version & Info Functions
// =============================================================================

/// Get the ABI version of the PlatformBackend.
///
/// Use this to verify compatibility before using other functions.
///
/// @param backend Pointer to PlatformBackend
/// @return ABI version number
pub export fn whatwg_platform_get_version(backend: ?*const PlatformBackend) callconv(.c) u32 {
    if (backend) |b| {
        return b.version;
    }
    return 0;
}

/// Get the expected ABI version for this library.
///
/// Compare with `whatwg_platform_get_version()` to check compatibility.
///
/// @return Expected ABI version number
pub export fn whatwg_platform_expected_version() callconv(.c) u32 {
    return platform_backend.PLATFORM_BACKEND_VERSION;
}

/// Check if a PlatformBackend is ABI-compatible with this library.
///
/// @param backend Pointer to PlatformBackend
/// @return true if compatible, false otherwise
pub export fn whatwg_platform_is_compatible(backend: ?*const PlatformBackend) callconv(.c) bool {
    if (backend) |b| {
        return b.isCompatible();
    }
    return false;
}

// =============================================================================
// User Context Functions
// =============================================================================

/// Get the user context from a PlatformBackend.
///
/// @param backend Pointer to PlatformBackend
/// @return User context pointer, or null if not set
pub export fn whatwg_platform_get_user_context(backend: ?*const PlatformBackend) callconv(.c) ?*anyopaque {
    if (backend) |b| {
        return b.user_context;
    }
    return null;
}

/// Set the user context on a PlatformBackend.
///
/// @param backend Pointer to PlatformBackend
/// @param user_context New user context pointer
pub export fn whatwg_platform_set_user_context(backend: ?*PlatformBackend, user_context: ?*anyopaque) callconv(.c) void {
    if (backend) |b| {
        b.user_context = user_context;
    }
}

// =============================================================================
// Capability Query Functions
// =============================================================================

/// Check if a specific capability is available.
///
/// @param backend Pointer to PlatformBackend
/// @param capability Capability constant (WHATWG_CAP_*)
/// @return true if capability is available, false otherwise
pub export fn whatwg_platform_has_capability(backend: ?*const PlatformBackend, capability: u8) callconv(.c) bool {
    if (backend) |b| {
        if (capability <= @intFromEnum(Capability.payment)) {
            const cap: Capability = @enumFromInt(capability);
            return b.hasCapability(cap);
        }
    }
    return false;
}

/// Count the number of available capabilities.
///
/// @param backend Pointer to PlatformBackend
/// @return Number of available capabilities
pub export fn whatwg_platform_capability_count(backend: ?*const PlatformBackend) callconv(.c) u32 {
    if (backend) |b| {
        var count: u32 = 0;
        inline for (std.meta.fields(Capability)) |field| {
            const cap: Capability = @enumFromInt(field.value);
            if (b.hasCapability(cap)) {
                count += 1;
            }
        }
        return count;
    }
    return 0;
}

// =============================================================================
// Capability Setter Functions
// =============================================================================

/// Set the clipboard VTable.
pub export fn whatwg_platform_set_clipboard(backend: ?*PlatformBackend, vtable: ?*const vtables.ClipboardVTable) callconv(.c) void {
    if (backend) |b| {
        b.clipboard = vtable;
    }
}

/// Set the timer VTable.
pub export fn whatwg_platform_set_timer(backend: ?*PlatformBackend, vtable: ?*const vtables.TimerVTable) callconv(.c) void {
    if (backend) |b| {
        b.timer = vtable;
    }
}

/// Set the network VTable.
pub export fn whatwg_platform_set_network(backend: ?*PlatformBackend, vtable: ?*const vtables.NetworkVTable) callconv(.c) void {
    if (backend) |b| {
        b.network = vtable;
    }
}

/// Set the storage VTable.
pub export fn whatwg_platform_set_storage(backend: ?*PlatformBackend, vtable: ?*const vtables.StorageVTable) callconv(.c) void {
    if (backend) |b| {
        b.storage = vtable;
    }
}

/// Set the layout VTable.
pub export fn whatwg_platform_set_layout(backend: ?*PlatformBackend, vtable: ?*const vtables.LayoutVTable) callconv(.c) void {
    if (backend) |b| {
        b.layout = vtable;
    }
}

/// Set the UI VTable.
pub export fn whatwg_platform_set_ui(backend: ?*PlatformBackend, vtable: ?*const vtables.UIVTable) callconv(.c) void {
    if (backend) |b| {
        b.ui = vtable;
    }
}

/// Set the screen VTable.
pub export fn whatwg_platform_set_screen(backend: ?*PlatformBackend, vtable: ?*const vtables.ScreenVTable) callconv(.c) void {
    if (backend) |b| {
        b.screen = vtable;
    }
}

/// Set the notification VTable.
pub export fn whatwg_platform_set_notification(backend: ?*PlatformBackend, vtable: ?*const vtables.NotificationVTable) callconv(.c) void {
    if (backend) |b| {
        b.notification = vtable;
    }
}

/// Set the push VTable.
pub export fn whatwg_platform_set_push(backend: ?*PlatformBackend, vtable: ?*const vtables.PushVTable) callconv(.c) void {
    if (backend) |b| {
        b.push = vtable;
    }
}

/// Set the share VTable.
pub export fn whatwg_platform_set_share(backend: ?*PlatformBackend, vtable: ?*const vtables.ShareVTable) callconv(.c) void {
    if (backend) |b| {
        b.share = vtable;
    }
}

/// Set the filesystem VTable.
pub export fn whatwg_platform_set_filesystem(backend: ?*PlatformBackend, vtable: ?*const vtables.FileSystemVTable) callconv(.c) void {
    if (backend) |b| {
        b.filesystem = vtable;
    }
}

/// Set the geolocation VTable.
pub export fn whatwg_platform_set_geolocation(backend: ?*PlatformBackend, vtable: ?*const vtables.GeolocationVTable) callconv(.c) void {
    if (backend) |b| {
        b.geolocation = vtable;
    }
}

/// Set the bluetooth VTable.
pub export fn whatwg_platform_set_bluetooth(backend: ?*PlatformBackend, vtable: ?*const vtables.BluetoothVTable) callconv(.c) void {
    if (backend) |b| {
        b.bluetooth = vtable;
    }
}

/// Set the USB VTable.
pub export fn whatwg_platform_set_usb(backend: ?*PlatformBackend, vtable: ?*const vtables.USBVTable) callconv(.c) void {
    if (backend) |b| {
        b.usb = vtable;
    }
}

/// Set the serial VTable.
pub export fn whatwg_platform_set_serial(backend: ?*PlatformBackend, vtable: ?*const vtables.SerialVTable) callconv(.c) void {
    if (backend) |b| {
        b.serial = vtable;
    }
}

/// Set the HID VTable.
pub export fn whatwg_platform_set_hid(backend: ?*PlatformBackend, vtable: ?*const vtables.HIDVTable) callconv(.c) void {
    if (backend) |b| {
        b.hid = vtable;
    }
}

/// Set the NFC VTable.
pub export fn whatwg_platform_set_nfc(backend: ?*PlatformBackend, vtable: ?*const vtables.NFCVTable) callconv(.c) void {
    if (backend) |b| {
        b.nfc = vtable;
    }
}

/// Set the device orientation VTable.
pub export fn whatwg_platform_set_device_orientation(backend: ?*PlatformBackend, vtable: ?*const vtables.DeviceOrientationVTable) callconv(.c) void {
    if (backend) |b| {
        b.device_orientation = vtable;
    }
}

/// Set the vibration VTable.
pub export fn whatwg_platform_set_vibration(backend: ?*PlatformBackend, vtable: ?*const vtables.VibrationVTable) callconv(.c) void {
    if (backend) |b| {
        b.vibration = vtable;
    }
}

/// Set the battery VTable.
pub export fn whatwg_platform_set_battery(backend: ?*PlatformBackend, vtable: ?*const vtables.BatteryVTable) callconv(.c) void {
    if (backend) |b| {
        b.battery = vtable;
    }
}

/// Set the wake lock VTable.
pub export fn whatwg_platform_set_wake_lock(backend: ?*PlatformBackend, vtable: ?*const vtables.WakeLockVTable) callconv(.c) void {
    if (backend) |b| {
        b.wake_lock = vtable;
    }
}

/// Set the WebRTC VTable.
pub export fn whatwg_platform_set_webrtc(backend: ?*PlatformBackend, vtable: ?*const vtables.WebRTCVTable) callconv(.c) void {
    if (backend) |b| {
        b.webrtc = vtable;
    }
}

/// Set the media VTable.
pub export fn whatwg_platform_set_media(backend: ?*PlatformBackend, vtable: ?*const vtables.MediaVTable) callconv(.c) void {
    if (backend) |b| {
        b.media = vtable;
    }
}

/// Set the audio VTable.
pub export fn whatwg_platform_set_audio(backend: ?*PlatformBackend, vtable: ?*const vtables.AudioVTable) callconv(.c) void {
    if (backend) |b| {
        b.audio = vtable;
    }
}

/// Set the speech VTable.
pub export fn whatwg_platform_set_speech(backend: ?*PlatformBackend, vtable: ?*const vtables.SpeechVTable) callconv(.c) void {
    if (backend) |b| {
        b.speech = vtable;
    }
}

/// Set the gamepad VTable.
pub export fn whatwg_platform_set_gamepad(backend: ?*PlatformBackend, vtable: ?*const vtables.GamepadVTable) callconv(.c) void {
    if (backend) |b| {
        b.gamepad = vtable;
    }
}

/// Set the sensor VTable.
pub export fn whatwg_platform_set_sensor(backend: ?*PlatformBackend, vtable: ?*const vtables.SensorVTable) callconv(.c) void {
    if (backend) |b| {
        b.sensor = vtable;
    }
}

/// Set the credentials VTable.
pub export fn whatwg_platform_set_credentials(backend: ?*PlatformBackend, vtable: ?*const vtables.CredentialsVTable) callconv(.c) void {
    if (backend) |b| {
        b.credentials = vtable;
    }
}

/// Set the WebAuthn VTable.
pub export fn whatwg_platform_set_webauthn(backend: ?*PlatformBackend, vtable: ?*const vtables.WebAuthnVTable) callconv(.c) void {
    if (backend) |b| {
        b.webauthn = vtable;
    }
}

/// Set the permissions VTable.
pub export fn whatwg_platform_set_permissions(backend: ?*PlatformBackend, vtable: ?*const vtables.PermissionsVTable) callconv(.c) void {
    if (backend) |b| {
        b.permissions = vtable;
    }
}

/// Set the payment VTable.
pub export fn whatwg_platform_set_payment(backend: ?*PlatformBackend, vtable: ?*const vtables.PaymentVTable) callconv(.c) void {
    if (backend) |b| {
        b.payment = vtable;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "C ABI exports - create and destroy" {
    const backend = whatwg_platform_create();
    try std.testing.expect(backend != null);
    whatwg_platform_destroy(backend);
}

test "C ABI exports - version check" {
    const backend = whatwg_platform_create();
    defer whatwg_platform_destroy(backend);

    try std.testing.expectEqual(platform_backend.PLATFORM_BACKEND_VERSION, whatwg_platform_get_version(backend));
    try std.testing.expectEqual(platform_backend.PLATFORM_BACKEND_VERSION, whatwg_platform_expected_version());
    try std.testing.expect(whatwg_platform_is_compatible(backend));
}

test "C ABI exports - user context" {
    const backend = whatwg_platform_create();
    defer whatwg_platform_destroy(backend);

    // Initially null
    try std.testing.expectEqual(@as(?*anyopaque, null), whatwg_platform_get_user_context(backend));

    // Set context
    var ctx: u32 = 42;
    whatwg_platform_set_user_context(backend, &ctx);
    try std.testing.expectEqual(@as(?*anyopaque, &ctx), whatwg_platform_get_user_context(backend));
}

test "C ABI exports - capability check" {
    const backend = whatwg_platform_create();
    defer whatwg_platform_destroy(backend);

    // Initially no capabilities
    try std.testing.expect(!whatwg_platform_has_capability(backend, WHATWG_CAP_CLIPBOARD));
    try std.testing.expectEqual(@as(u32, 0), whatwg_platform_capability_count(backend));
}

test "C ABI exports - capability constants match enum" {
    try std.testing.expectEqual(@as(u8, 0), WHATWG_CAP_CLIPBOARD);
    try std.testing.expectEqual(@as(u8, 1), WHATWG_CAP_TIMER);
    try std.testing.expectEqual(@as(u8, 2), WHATWG_CAP_NETWORK);
}
