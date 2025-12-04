//! Unified Platform Backend
//!
//! This is the single entry point for all platform capabilities. Embedders
//! (iOS/Swift, Android/Kotlin, Windows/C#) provide implementations through
//! this unified interface.
//!
//! ## Design Principles
//!
//! 1. **Single Entry Point**: All capabilities flow through PlatformBackend
//! 2. **Optional Capabilities**: Null VTable = capability returns undefined to JS
//! 3. **C ABI Compatible**: All structs are extern for FFI
//! 4. **Engine Agnostic**: Works with V8, JavaScriptCore, QuickJS
//!
//! ## Usage (Swift)
//!
//! ```swift
//! let platform = WhatWGPlatform(
//!     clipboard: IOSClipboard(),  // nil = undefined in JS
//!     network: IOSNetwork(),
//!     storage: IOSStorage(),
//!     // ... other capabilities
//! )
//! let browser = try WhatWGBrowser(platform: platform)
//! ```
//!
//! ## Usage (Zig)
//!
//! ```zig
//! const platform = PlatformBackend{
//!     .clipboard = &my_clipboard_vtable,
//!     .network = &my_network_vtable,
//!     // ... other capabilities (null = not implemented)
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import VTable types
const vtables = @import("vtables.zig");
pub const ClipboardVTable = vtables.ClipboardVTable;
pub const TimerVTable = vtables.TimerVTable;
pub const LayoutVTable = vtables.LayoutVTable;
pub const NotificationVTable = vtables.NotificationVTable;
pub const PushVTable = vtables.PushVTable;
pub const NetworkVTable = vtables.NetworkVTable;
pub const StorageVTable = vtables.StorageVTable;
pub const FileSystemVTable = vtables.FileSystemVTable;
pub const UIVTable = vtables.UIVTable;
pub const GeolocationVTable = vtables.GeolocationVTable;
pub const BluetoothVTable = vtables.BluetoothVTable;
pub const USBVTable = vtables.USBVTable;
pub const SerialVTable = vtables.SerialVTable;
pub const HIDVTable = vtables.HIDVTable;
pub const WebRTCVTable = vtables.WebRTCVTable;
pub const MediaVTable = vtables.MediaVTable;
pub const AudioVTable = vtables.AudioVTable;
pub const SpeechVTable = vtables.SpeechVTable;
pub const GamepadVTable = vtables.GamepadVTable;
pub const SensorVTable = vtables.SensorVTable;
pub const VibrationVTable = vtables.VibrationVTable;
pub const BatteryVTable = vtables.BatteryVTable;
pub const ScreenVTable = vtables.ScreenVTable;
pub const WakeLockVTable = vtables.WakeLockVTable;
pub const ShareVTable = vtables.ShareVTable;
pub const PaymentVTable = vtables.PaymentVTable;
pub const CredentialsVTable = vtables.CredentialsVTable;
pub const WebAuthnVTable = vtables.WebAuthnVTable;
pub const DeviceOrientationVTable = vtables.DeviceOrientationVTable;
pub const NFCVTable = vtables.NFCVTable;
pub const PermissionsVTable = vtables.PermissionsVTable;

// Re-export common types
pub const ClipboardFormat = vtables.ClipboardFormat;
pub const ClipboardResult = vtables.ClipboardResult;
pub const NotificationPermission = vtables.NotificationPermission;
pub const NotificationResult = vtables.NotificationResult;

/// Version of the PlatformBackend ABI.
/// Increment when making breaking changes to the struct layout.
pub const PLATFORM_BACKEND_VERSION: u32 = 1;

/// Unified platform backend containing all capability VTables.
///
/// This is an extern struct for C ABI compatibility. All VTable pointers
/// are optional - null means the capability is not implemented and will
/// return undefined to JavaScript.
///
/// ## Memory Safety
///
/// The PlatformBackend does NOT own the VTables - embedders are responsible
/// for ensuring VTables remain valid for the lifetime of the backend.
pub const PlatformBackend = extern struct {
    /// ABI version for compatibility checking
    version: u32 = PLATFORM_BACKEND_VERSION,

    /// Opaque pointer for embedder-specific context data.
    /// This is passed to all VTable functions as the first argument.
    user_context: ?*anyopaque = null,

    // =========================================================================
    // Core Capabilities (commonly implemented)
    // =========================================================================

    /// Clipboard operations (copy/paste)
    /// Spec: https://w3c.github.io/clipboard-apis/
    clipboard: ?*const ClipboardVTable = null,

    /// Timer operations (setTimeout, setInterval, performance timing)
    timer: ?*const TimerVTable = null,

    /// Network operations (fetch, WebSocket)
    /// Spec: https://fetch.spec.whatwg.org/
    network: ?*const NetworkVTable = null,

    /// Storage operations (localStorage, sessionStorage, IndexedDB)
    /// Spec: https://storage.spec.whatwg.org/
    storage: ?*const StorageVTable = null,

    // =========================================================================
    // DOM/Rendering Capabilities
    // =========================================================================

    /// Layout engine operations (getBoundingClientRect, offsetWidth, etc.)
    /// Spec: https://drafts.csswg.org/cssom-view/
    layout: ?*const LayoutVTable = null,

    /// UI operations (alerts, confirms, prompts, focus, scroll)
    ui: ?*const UIVTable = null,

    /// Screen information (screen size, orientation, color depth)
    /// Spec: https://w3c.github.io/screen-orientation/
    screen: ?*const ScreenVTable = null,

    // =========================================================================
    // Notifications & Communication
    // =========================================================================

    /// Notification operations (show, close, permissions)
    /// Spec: https://notifications.spec.whatwg.org/
    notification: ?*const NotificationVTable = null,

    /// Push notification operations
    /// Spec: https://w3c.github.io/push-api/
    push: ?*const PushVTable = null,

    /// Web Share API
    /// Spec: https://w3c.github.io/web-share/
    share: ?*const ShareVTable = null,

    // =========================================================================
    // File & Storage
    // =========================================================================

    /// File system operations (File System Access API)
    /// Spec: https://fs.spec.whatwg.org/
    filesystem: ?*const FileSystemVTable = null,

    // =========================================================================
    // Device APIs
    // =========================================================================

    /// Geolocation operations
    /// Spec: https://w3c.github.io/geolocation-api/
    geolocation: ?*const GeolocationVTable = null,

    /// Web Bluetooth operations
    /// Spec: https://webbluetoothcg.github.io/web-bluetooth/
    bluetooth: ?*const BluetoothVTable = null,

    /// WebUSB operations
    /// Spec: https://wicg.github.io/webusb/
    usb: ?*const USBVTable = null,

    /// Web Serial operations
    /// Spec: https://wicg.github.io/serial/
    serial: ?*const SerialVTable = null,

    /// WebHID operations
    /// Spec: https://wicg.github.io/webhid/
    hid: ?*const HIDVTable = null,

    /// WebNFC operations
    /// Spec: https://w3c.github.io/web-nfc/
    nfc: ?*const NFCVTable = null,

    /// Device orientation and motion
    /// Spec: https://w3c.github.io/deviceorientation/
    device_orientation: ?*const DeviceOrientationVTable = null,

    /// Vibration API
    /// Spec: https://w3c.github.io/vibration/
    vibration: ?*const VibrationVTable = null,

    /// Battery Status API
    /// Spec: https://w3c.github.io/battery/
    battery: ?*const BatteryVTable = null,

    /// Screen Wake Lock API
    /// Spec: https://w3c.github.io/screen-wake-lock/
    wake_lock: ?*const WakeLockVTable = null,

    // =========================================================================
    // Media APIs
    // =========================================================================

    /// WebRTC operations
    /// Spec: https://w3c.github.io/webrtc-pc/
    webrtc: ?*const WebRTCVTable = null,

    /// Media capture and playback
    /// Spec: https://w3c.github.io/mediacapture-main/
    media: ?*const MediaVTable = null,

    /// Web Audio operations
    /// Spec: https://webaudio.github.io/web-audio-api/
    audio: ?*const AudioVTable = null,

    /// Web Speech API (synthesis and recognition)
    /// Spec: https://wicg.github.io/speech-api/
    speech: ?*const SpeechVTable = null,

    // =========================================================================
    // Gaming APIs
    // =========================================================================

    /// Gamepad operations
    /// Spec: https://w3c.github.io/gamepad/
    gamepad: ?*const GamepadVTable = null,

    /// Generic Sensor API
    /// Spec: https://w3c.github.io/sensors/
    sensor: ?*const SensorVTable = null,

    // =========================================================================
    // Security & Credentials
    // =========================================================================

    /// Credential Management API
    /// Spec: https://w3c.github.io/webappsec-credential-management/
    credentials: ?*const CredentialsVTable = null,

    /// Web Authentication (WebAuthn)
    /// Spec: https://w3c.github.io/webauthn/
    webauthn: ?*const WebAuthnVTable = null,

    /// Permissions API
    /// Spec: https://w3c.github.io/permissions/
    permissions: ?*const PermissionsVTable = null,

    // =========================================================================
    // Payment APIs
    // =========================================================================

    /// Payment Request API
    /// Spec: https://w3c.github.io/payment-request/
    payment: ?*const PaymentVTable = null,

    // =========================================================================
    // Reserved for Future Use
    // =========================================================================

    /// Reserved space for future capabilities without breaking ABI.
    /// Embedders should NOT access these fields.
    _reserved: [32]?*const anyopaque = [_]?*const anyopaque{null} ** 32,

    // =========================================================================
    // Convenience Methods
    // =========================================================================

    /// Check if a capability is available.
    pub fn hasCapability(self: *const PlatformBackend, capability: Capability) bool {
        return switch (capability) {
            .clipboard => self.clipboard != null,
            .timer => self.timer != null,
            .network => self.network != null,
            .storage => self.storage != null,
            .layout => self.layout != null,
            .ui => self.ui != null,
            .screen => self.screen != null,
            .notification => self.notification != null,
            .push => self.push != null,
            .share => self.share != null,
            .filesystem => self.filesystem != null,
            .geolocation => self.geolocation != null,
            .bluetooth => self.bluetooth != null,
            .usb => self.usb != null,
            .serial => self.serial != null,
            .hid => self.hid != null,
            .nfc => self.nfc != null,
            .device_orientation => self.device_orientation != null,
            .vibration => self.vibration != null,
            .battery => self.battery != null,
            .wake_lock => self.wake_lock != null,
            .webrtc => self.webrtc != null,
            .media => self.media != null,
            .audio => self.audio != null,
            .speech => self.speech != null,
            .gamepad => self.gamepad != null,
            .sensor => self.sensor != null,
            .credentials => self.credentials != null,
            .webauthn => self.webauthn != null,
            .permissions => self.permissions != null,
            .payment => self.payment != null,
        };
    }

    /// Get list of available capabilities.
    pub fn getAvailableCapabilities(self: *const PlatformBackend, allocator: Allocator) ![]Capability {
        var list = std.ArrayListUnmanaged(Capability){};
        errdefer list.deinit(allocator);

        inline for (std.meta.fields(Capability)) |field| {
            const cap: Capability = @enumFromInt(field.value);
            if (self.hasCapability(cap)) {
                try list.append(allocator, cap);
            }
        }

        return list.toOwnedSlice(allocator);
    }

    /// Validate the backend version is compatible.
    pub fn isCompatible(self: *const PlatformBackend) bool {
        return self.version == PLATFORM_BACKEND_VERSION;
    }
};

/// Enumeration of all capabilities.
pub const Capability = enum(u8) {
    clipboard = 0,
    timer = 1,
    network = 2,
    storage = 3,
    layout = 4,
    ui = 5,
    screen = 6,
    notification = 7,
    push = 8,
    share = 9,
    filesystem = 10,
    geolocation = 11,
    bluetooth = 12,
    usb = 13,
    serial = 14,
    hid = 15,
    nfc = 16,
    device_orientation = 17,
    vibration = 18,
    battery = 19,
    wake_lock = 20,
    webrtc = 21,
    media = 22,
    audio = 23,
    speech = 24,
    gamepad = 25,
    sensor = 26,
    credentials = 27,
    webauthn = 28,
    permissions = 29,
    payment = 30,

    /// Get human-readable name.
    pub fn name(self: Capability) []const u8 {
        return @tagName(self);
    }
};

/// Create an empty PlatformBackend with no capabilities.
pub fn empty() PlatformBackend {
    return PlatformBackend{};
}

/// Create a PlatformBackend with a user context.
pub fn withContext(user_context: *anyopaque) PlatformBackend {
    return PlatformBackend{
        .user_context = user_context,
    };
}

// =============================================================================
// Tests
// =============================================================================

test "PlatformBackend - empty backend has no capabilities" {
    const backend = empty();

    try std.testing.expect(!backend.hasCapability(.clipboard));
    try std.testing.expect(!backend.hasCapability(.network));
    try std.testing.expect(!backend.hasCapability(.storage));
}

test "PlatformBackend - version check" {
    const backend = empty();

    try std.testing.expect(backend.isCompatible());
    try std.testing.expectEqual(PLATFORM_BACKEND_VERSION, backend.version);
}

test "PlatformBackend - getAvailableCapabilities" {
    const allocator = std.testing.allocator;
    const backend = empty();

    const caps = try backend.getAvailableCapabilities(allocator);
    defer allocator.free(caps);

    try std.testing.expectEqual(@as(usize, 0), caps.len);
}

test "PlatformBackend - extern struct is C compatible" {
    // Verify the struct is extern (for C FFI)
    const info = @typeInfo(PlatformBackend);
    try std.testing.expect(info == .@"struct");
    try std.testing.expect(info.@"struct".layout == .@"extern");
}

test "Capability - name" {
    try std.testing.expectEqualStrings("clipboard", Capability.clipboard.name());
    try std.testing.expectEqualStrings("network", Capability.network.name());
}
