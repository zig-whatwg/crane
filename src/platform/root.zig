//! Platform Abstraction Layer
//!
//! Provides platform-specific backend implementations for:
//! - Timer management (setTimeout, setInterval)
//! - Layout engine integration (for CSSOM View properties)
//! - Clipboard access (copy, cut, paste)
//! - Notifications (Notifications API)
//! - Push messaging (Push API)
//!
//! These backends are designed to be replaceable by embedders.
//!
//! ## Unified Platform Backend
//!
//! For new integrations, use the unified PlatformBackend which consolidates
//! all capabilities into a single entry point:
//!
//! ```zig
//! const platform = PlatformBackend{
//!     .clipboard = &my_clipboard_vtable,
//!     .network = &my_network_vtable,
//!     // ... other capabilities
//! };
//! ```

// === Unified Platform Backend (Recommended) ===
pub const platform_backend = @import("platform_backend.zig");
pub const vtables = @import("vtables.zig");
pub const exports = @import("exports.zig");

// Unified backend types
pub const PlatformBackend = platform_backend.PlatformBackend;
pub const Capability = platform_backend.Capability;
pub const PLATFORM_BACKEND_VERSION = platform_backend.PLATFORM_BACKEND_VERSION;

// C ABI exports (re-export for convenience)
pub const whatwg_platform_create = exports.whatwg_platform_create;
pub const whatwg_platform_destroy = exports.whatwg_platform_destroy;
pub const whatwg_platform_get_version = exports.whatwg_platform_get_version;

// VTable types (C-compatible)
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
pub const PermissionsVTable = vtables.PermissionsVTable;

// === Legacy Backends (For Backward Compatibility) ===
pub const timer_backend = @import("timer_backend.zig");
pub const layout_backend = @import("layout_backend.zig");
pub const clipboard_backend = @import("clipboard_backend.zig");
pub const notification_backend = @import("notification_backend.zig");
pub const push_backend = @import("push_backend.zig");

// Re-export commonly used types
pub const TimerBackend = timer_backend.TimerBackend;
pub const RealTimerBackend = timer_backend.RealTimerBackend;
pub const MockTimerBackend = timer_backend.MockTimerBackend;

pub const LayoutBackend = layout_backend.LayoutBackend;
pub const StubLayoutBackend = layout_backend.StubLayoutBackend;

pub const ClipboardBackend = clipboard_backend.ClipboardBackend;
pub const StubClipboardBackend = clipboard_backend.StubClipboardBackend;
pub const DeniedClipboardBackend = clipboard_backend.DeniedClipboardBackend;
pub const ClipboardFormat = clipboard_backend.ClipboardFormat;
pub const ClipboardItem = clipboard_backend.ClipboardItem;
pub const ClipboardResult = clipboard_backend.ClipboardResult;

pub const NotificationBackend = notification_backend.NotificationBackend;
pub const StubNotificationBackend = notification_backend.StubNotificationBackend;
pub const DeniedNotificationBackend = notification_backend.DeniedNotificationBackend;
pub const Notification = notification_backend.Notification;
pub const NotificationOptions = notification_backend.NotificationOptions;
pub const NotificationAction = notification_backend.NotificationAction;
pub const NotificationPermission = notification_backend.NotificationPermission;
pub const NotificationDirection = notification_backend.NotificationDirection;
pub const NotificationResult = notification_backend.NotificationResult;
pub const NotificationEventType = notification_backend.NotificationEventType;
pub const NotificationEventCallback = notification_backend.NotificationEventCallback;

pub const PushBackend = push_backend.PushBackend;
pub const StubPushBackend = push_backend.StubPushBackend;
pub const DeniedPushBackend = push_backend.DeniedPushBackend;
pub const PushSubscription = push_backend.PushSubscription;
pub const PushSubscriptionOptions = push_backend.PushSubscriptionOptions;
pub const PushSubscriptionKeys = push_backend.PushSubscriptionKeys;
pub const PushMessageData = push_backend.PushMessageData;
pub const PushPermissionState = push_backend.PushPermissionState;
pub const PushEncryptionKeyName = push_backend.PushEncryptionKeyName;
pub const PushResult = push_backend.PushResult;
