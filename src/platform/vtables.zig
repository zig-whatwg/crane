//! Capability VTable Definitions
//!
//! This module defines the VTable types for each platform capability.
//! All VTables are extern structs with C-compatible function pointers
//! for cross-language FFI.
//!
//! ## Design Principles
//!
//! 1. **Extern Compatible**: All structs use extern layout
//! 2. **C Calling Convention**: All function pointers use `callconv(.c)`
//! 3. **User Context First**: All functions take user_context as first parameter
//! 4. **Error Returns**: Functions return error codes, not Zig errors
//! 5. **No Allocator Capture**: Allocators passed per-call, not stored
//!
//! ## Pattern
//!
//! Each VTable follows this pattern:
//! ```zig
//! pub const FooVTable = extern struct {
//!     operation: *const fn (user_context: ?*anyopaque, ...) ReturnType,
//!     // ... more operations
//! };
//! ```

const std = @import("std");

// =============================================================================
// Common Types
// =============================================================================

/// Opaque pointer type for C compatibility
pub const OpaquePtr = ?*anyopaque;

/// Allocator function type for C callbacks that need allocation
/// Returns null on allocation failure
pub const AllocFn = *const fn (size: usize, user_data: OpaquePtr) callconv(.c) ?[*]u8;

/// Free function type for C callbacks
pub const FreeFn = *const fn (ptr: [*]u8, size: usize, user_data: OpaquePtr) callconv(.c) void;

/// Allocator context for C callbacks
pub const CAllocator = extern struct {
    alloc: AllocFn,
    free: FreeFn,
    user_data: OpaquePtr,
};

// =============================================================================
// Clipboard VTable
// Spec: https://w3c.github.io/clipboard-apis/
// =============================================================================

/// Clipboard data format
pub const ClipboardFormat = enum(u8) {
    text_plain = 0,
    text_html = 1,
    text_rtf = 2,
    image_png = 3,
    image_jpeg = 4,
    image_gif = 5,
    image_bmp = 6,
};

/// Clipboard operation result
pub const ClipboardResult = enum(i32) {
    success = 0,
    permission_denied = -1,
    not_available = -2,
    empty = -3,
    error_unknown = -99,
};

/// Clipboard VTable for copy/paste operations
pub const ClipboardVTable = extern struct {
    /// Read plain text from clipboard.
    /// Returns length of text, or negative ClipboardResult on error.
    /// If buffer is null, returns required buffer size.
    read_text: *const fn (
        user_context: OpaquePtr,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Write plain text to clipboard.
    write_text: *const fn (
        user_context: OpaquePtr,
        text: [*]const u8,
        text_len: usize,
    ) callconv(.c) ClipboardResult,

    /// Read HTML from clipboard.
    /// Returns length of HTML, or negative ClipboardResult on error.
    read_html: *const fn (
        user_context: OpaquePtr,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Write HTML to clipboard (with optional plain text fallback).
    write_html: *const fn (
        user_context: OpaquePtr,
        html: [*]const u8,
        html_len: usize,
        plain_text: ?[*]const u8,
        plain_text_len: usize,
    ) callconv(.c) ClipboardResult,

    /// Check if clipboard read is permitted.
    can_read: *const fn (user_context: OpaquePtr) callconv(.c) bool,

    /// Check if clipboard write is permitted.
    can_write: *const fn (user_context: OpaquePtr) callconv(.c) bool,

    /// Check if clipboard has content.
    has_content: *const fn (user_context: OpaquePtr) callconv(.c) bool,

    /// Clear clipboard contents.
    clear: *const fn (user_context: OpaquePtr) callconv(.c) ClipboardResult,
};

// =============================================================================
// Timer VTable
// =============================================================================

/// Timer VTable for timing operations
pub const TimerVTable = extern struct {
    /// Get current time in milliseconds since epoch.
    get_current_time: *const fn (user_context: OpaquePtr) callconv(.c) i64,

    /// Get high-resolution time in nanoseconds.
    get_high_res_time: *const fn (user_context: OpaquePtr) callconv(.c) i64,

    /// Schedule a wakeup at the specified time (milliseconds since epoch).
    schedule_wakeup: *const fn (user_context: OpaquePtr, time_ms: i64) callconv(.c) void,

    /// Cancel any pending wakeup.
    cancel_wakeup: *const fn (user_context: OpaquePtr) callconv(.c) void,

    /// Sleep until the next scheduled wakeup or timeout.
    /// Returns actual time slept in milliseconds.
    sleep_until_wakeup: *const fn (
        user_context: OpaquePtr,
        timeout_ms: i64, // -1 = no timeout
    ) callconv(.c) i64,
};

// =============================================================================
// Layout VTable
// Spec: https://drafts.csswg.org/cssom-view/
// =============================================================================

/// DOMRect for layout measurements (C-compatible)
pub const CDOMRect = extern struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

/// Layout VTable for CSSOM View operations
pub const LayoutVTable = extern struct {
    /// Get element's offsetWidth
    get_offset_width: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetHeight
    get_offset_height: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetTop
    get_offset_top: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetLeft
    get_offset_left: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetParent (returns null if none)
    get_offset_parent: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) OpaquePtr,

    /// Get element's clientWidth
    get_client_width: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's clientHeight
    get_client_height: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's clientTop
    get_client_top: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's clientLeft
    get_client_left: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's scrollWidth
    get_scroll_width: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's scrollHeight
    get_scroll_height: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's scrollTop
    get_scroll_top: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Set element's scrollTop
    set_scroll_top: *const fn (user_context: OpaquePtr, element: OpaquePtr, value: f64) callconv(.c) void,

    /// Get element's scrollLeft
    get_scroll_left: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Set element's scrollLeft
    set_scroll_left: *const fn (user_context: OpaquePtr, element: OpaquePtr, value: f64) callconv(.c) void,

    /// Get element's bounding client rect
    get_bounding_client_rect: *const fn (
        user_context: OpaquePtr,
        element: OpaquePtr,
        out_rect: *CDOMRect,
    ) callconv(.c) void,

    /// Check if element is rendered (not display: none)
    is_element_rendered: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) bool,

    /// Mark element as needing layout recalculation
    mark_dirty: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) void,

    /// Force synchronous layout computation
    force_layout: *const fn (user_context: OpaquePtr) callconv(.c) void,
};

// =============================================================================
// Notification VTable
// Spec: https://notifications.spec.whatwg.org/
// =============================================================================

/// Notification permission state
pub const NotificationPermission = enum(i32) {
    default = 0,
    denied = -1,
    granted = 1,
};

/// Notification operation result
pub const NotificationResult = enum(i32) {
    success = 0,
    permission_denied = -1,
    not_supported = -2,
    invalid_options = -3,
    quota_exceeded = -4,
    error_unknown = -99,
};

/// Notification options (C-compatible)
pub const CNotificationOptions = extern struct {
    title: [*]const u8,
    title_len: usize,
    body: [*]const u8,
    body_len: usize,
    tag: [*]const u8,
    tag_len: usize,
    icon: ?[*]const u8,
    icon_len: usize,
    badge: ?[*]const u8,
    badge_len: usize,
    require_interaction: bool,
    silent: bool,
    timestamp: i64, // -1 = use current time
};

/// Notification handle (opaque)
pub const NotificationHandle = u64;

/// Notification VTable
pub const NotificationVTable = extern struct {
    /// Get current permission state
    get_permission: *const fn (user_context: OpaquePtr) callconv(.c) NotificationPermission,

    /// Request permission from user
    request_permission: *const fn (user_context: OpaquePtr) callconv(.c) NotificationPermission,

    /// Show a notification. Returns handle on success, 0 on failure.
    show: *const fn (
        user_context: OpaquePtr,
        options: *const CNotificationOptions,
    ) callconv(.c) NotificationHandle,

    /// Close a notification
    close: *const fn (user_context: OpaquePtr, handle: NotificationHandle) callconv(.c) NotificationResult,

    /// Get maximum number of actions supported
    get_max_actions: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

// =============================================================================
// Push VTable
// Spec: https://w3c.github.io/push-api/
// =============================================================================

/// Push subscription handle (opaque)
pub const PushSubscriptionHandle = u64;

/// Push VTable
pub const PushVTable = extern struct {
    /// Subscribe to push notifications.
    /// Returns subscription handle on success, 0 on failure.
    subscribe: *const fn (
        user_context: OpaquePtr,
        application_server_key: [*]const u8,
        key_len: usize,
    ) callconv(.c) PushSubscriptionHandle,

    /// Unsubscribe from push notifications
    unsubscribe: *const fn (user_context: OpaquePtr, handle: PushSubscriptionHandle) callconv(.c) bool,

    /// Get existing subscription (0 if none)
    get_subscription: *const fn (user_context: OpaquePtr) callconv(.c) PushSubscriptionHandle,

    /// Check if push is supported
    is_supported: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

// =============================================================================
// Network VTable
// Spec: https://fetch.spec.whatwg.org/
// =============================================================================

/// HTTP method enum
pub const HttpMethod = enum(u8) {
    GET = 0,
    POST = 1,
    PUT = 2,
    DELETE = 3,
    HEAD = 4,
    OPTIONS = 5,
    PATCH = 6,
    CONNECT = 7,
    TRACE = 8,
};

/// Network request handle (opaque)
pub const NetworkRequestHandle = u64;

/// Network result codes
pub const NetworkResult = enum(i32) {
    success = 0,
    dns_failed = -1,
    connection_refused = -2,
    connection_timeout = -3,
    request_timeout = -4,
    ssl_error = -5,
    too_many_redirects = -6,
    invalid_url = -7,
    aborted = -8,
    network_error = -99,
};

/// Network request options (C-compatible)
pub const CNetworkRequest = extern struct {
    url: [*]const u8,
    url_len: usize,
    method: HttpMethod,
    headers: ?[*]const CHeader,
    headers_count: usize,
    body: ?[*]const u8,
    body_len: usize,
    timeout_ms: u32,
    follow_redirects: bool,
};

/// Header for network requests
pub const CHeader = extern struct {
    name: [*]const u8,
    name_len: usize,
    value: [*]const u8,
    value_len: usize,
};

/// Callback for network response
pub const NetworkResponseCallback = *const fn (
    user_data: OpaquePtr,
    status: u16,
    headers: [*]const CHeader,
    headers_count: usize,
    body: [*]const u8,
    body_len: usize,
) callconv(.c) void;

/// Callback for network errors
pub const NetworkErrorCallback = *const fn (
    user_data: OpaquePtr,
    result: NetworkResult,
) callconv(.c) void;

/// Network VTable
pub const NetworkVTable = extern struct {
    /// Start a network request (async).
    /// Returns request handle for cancellation.
    start_request: *const fn (
        user_context: OpaquePtr,
        request: *const CNetworkRequest,
        on_response: NetworkResponseCallback,
        on_error: NetworkErrorCallback,
        callback_user_data: OpaquePtr,
    ) callconv(.c) NetworkRequestHandle,

    /// Abort a pending request
    abort_request: *const fn (user_context: OpaquePtr, handle: NetworkRequestHandle) callconv(.c) void,

    /// Check if online
    is_online: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

// =============================================================================
// Storage VTable
// Spec: https://storage.spec.whatwg.org/
// =============================================================================

/// Storage operation result
pub const StorageResult = enum(i32) {
    success = 0,
    not_found = -1,
    quota_exceeded = -2,
    permission_denied = -3,
    io_error = -4,
    error_unknown = -99,
};

/// Storage VTable
pub const StorageVTable = extern struct {
    /// Get item from storage.
    /// Returns length of value, or negative StorageResult on error.
    /// If buffer is null, returns required buffer size.
    get_item: *const fn (
        user_context: OpaquePtr,
        key: [*]const u8,
        key_len: usize,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Set item in storage.
    set_item: *const fn (
        user_context: OpaquePtr,
        key: [*]const u8,
        key_len: usize,
        value: [*]const u8,
        value_len: usize,
    ) callconv(.c) StorageResult,

    /// Remove item from storage.
    remove_item: *const fn (
        user_context: OpaquePtr,
        key: [*]const u8,
        key_len: usize,
    ) callconv(.c) StorageResult,

    /// Clear all items from storage.
    clear: *const fn (user_context: OpaquePtr) callconv(.c) StorageResult,

    /// Get number of items in storage.
    get_length: *const fn (user_context: OpaquePtr) callconv(.c) u32,

    /// Get key at index.
    /// Returns length of key, or negative StorageResult on error.
    get_key: *const fn (
        user_context: OpaquePtr,
        index: u32,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Get storage quota info.
    get_quota: *const fn (
        user_context: OpaquePtr,
        out_usage: *u64,
        out_quota: *u64,
    ) callconv(.c) StorageResult,
};

// =============================================================================
// FileSystem VTable
// Spec: https://fs.spec.whatwg.org/
// =============================================================================

/// File handle (opaque)
pub const FileHandle = u64;

/// Directory handle (opaque)
pub const DirectoryHandle = u64;

/// File open mode
pub const FileMode = enum(u8) {
    read = 0,
    write = 1,
    read_write = 2,
};

/// FileSystem result
pub const FileSystemResult = enum(i32) {
    success = 0,
    not_found = -1,
    permission_denied = -2,
    already_exists = -3,
    is_directory = -4,
    not_directory = -5,
    not_empty = -6,
    io_error = -7,
    quota_exceeded = -8,
    error_unknown = -99,
};

/// FileSystem VTable
pub const FileSystemVTable = extern struct {
    /// Open the root directory
    get_root: *const fn (user_context: OpaquePtr) callconv(.c) DirectoryHandle,

    /// Open a file in directory
    open_file: *const fn (
        user_context: OpaquePtr,
        dir: DirectoryHandle,
        name: [*]const u8,
        name_len: usize,
        mode: FileMode,
        create: bool,
    ) callconv(.c) FileHandle,

    /// Open a subdirectory
    open_directory: *const fn (
        user_context: OpaquePtr,
        parent: DirectoryHandle,
        name: [*]const u8,
        name_len: usize,
        create: bool,
    ) callconv(.c) DirectoryHandle,

    /// Read from file. Returns bytes read or negative error.
    read_file: *const fn (
        user_context: OpaquePtr,
        handle: FileHandle,
        offset: u64,
        buffer: [*]u8,
        buffer_size: usize,
    ) callconv(.c) i64,

    /// Write to file. Returns bytes written or negative error.
    write_file: *const fn (
        user_context: OpaquePtr,
        handle: FileHandle,
        offset: u64,
        data: [*]const u8,
        data_len: usize,
    ) callconv(.c) i64,

    /// Get file size
    get_file_size: *const fn (user_context: OpaquePtr, handle: FileHandle) callconv(.c) i64,

    /// Close file handle
    close_file: *const fn (user_context: OpaquePtr, handle: FileHandle) callconv(.c) void,

    /// Close directory handle
    close_directory: *const fn (user_context: OpaquePtr, handle: DirectoryHandle) callconv(.c) void,

    /// Remove file or directory
    remove: *const fn (
        user_context: OpaquePtr,
        parent: DirectoryHandle,
        name: [*]const u8,
        name_len: usize,
        recursive: bool,
    ) callconv(.c) FileSystemResult,
};

// =============================================================================
// UI VTable
// =============================================================================

/// Alert type
pub const AlertType = enum(u8) {
    alert = 0,
    confirm = 1,
    prompt = 2,
};

/// UI VTable
pub const UIVTable = extern struct {
    /// Show an alert dialog. Returns true if confirmed (for confirm dialogs).
    show_alert: *const fn (
        user_context: OpaquePtr,
        alert_type: AlertType,
        message: [*]const u8,
        message_len: usize,
    ) callconv(.c) bool,

    /// Show a prompt dialog.
    /// Returns length of response, or -1 if cancelled.
    show_prompt: *const fn (
        user_context: OpaquePtr,
        message: [*]const u8,
        message_len: usize,
        default_value: ?[*]const u8,
        default_len: usize,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Focus the window
    focus: *const fn (user_context: OpaquePtr) callconv(.c) void,

    /// Blur the window
    blur: *const fn (user_context: OpaquePtr) callconv(.c) void,

    /// Print the page
    print: *const fn (user_context: OpaquePtr) callconv(.c) void,
};

// =============================================================================
// Geolocation VTable
// Spec: https://w3c.github.io/geolocation-api/
// =============================================================================

/// Geolocation position (C-compatible)
pub const CGeolocationPosition = extern struct {
    latitude: f64,
    longitude: f64,
    altitude: f64, // NaN if unavailable
    accuracy: f64,
    altitude_accuracy: f64, // NaN if unavailable
    heading: f64, // NaN if unavailable
    speed: f64, // NaN if unavailable
    timestamp: i64,
};

/// Geolocation error codes
pub const GeolocationError = enum(i32) {
    success = 0,
    permission_denied = 1,
    position_unavailable = 2,
    timeout = 3,
};

/// Geolocation watch ID
pub const WatchId = u32;

/// Callback for geolocation success
pub const GeolocationSuccessCallback = *const fn (
    user_data: OpaquePtr,
    position: *const CGeolocationPosition,
) callconv(.c) void;

/// Callback for geolocation error
pub const GeolocationErrorCallback = *const fn (
    user_data: OpaquePtr,
    error_code: GeolocationError,
) callconv(.c) void;

/// Geolocation VTable
pub const GeolocationVTable = extern struct {
    /// Get current position (async)
    get_current_position: *const fn (
        user_context: OpaquePtr,
        on_success: GeolocationSuccessCallback,
        on_error: GeolocationErrorCallback,
        callback_user_data: OpaquePtr,
        enable_high_accuracy: bool,
        timeout_ms: u32,
        maximum_age_ms: u32,
    ) callconv(.c) void,

    /// Watch position (async, repeating)
    watch_position: *const fn (
        user_context: OpaquePtr,
        on_success: GeolocationSuccessCallback,
        on_error: GeolocationErrorCallback,
        callback_user_data: OpaquePtr,
        enable_high_accuracy: bool,
        timeout_ms: u32,
        maximum_age_ms: u32,
    ) callconv(.c) WatchId,

    /// Clear watch
    clear_watch: *const fn (user_context: OpaquePtr, watch_id: WatchId) callconv(.c) void,
};

// =============================================================================
// Stub VTables for Less Common APIs
// These will be expanded as needed
// =============================================================================

/// Bluetooth VTable (stub)
pub const BluetoothVTable = extern struct {
    request_device: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    get_availability: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// USB VTable (stub)
pub const USBVTable = extern struct {
    request_device: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    get_devices: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// Serial VTable (stub)
pub const SerialVTable = extern struct {
    request_port: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    get_ports: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// HID VTable (stub)
pub const HIDVTable = extern struct {
    request_device: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    get_devices: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// WebRTC VTable (stub)
pub const WebRTCVTable = extern struct {
    create_peer_connection: *const fn (user_context: OpaquePtr) callconv(.c) u64,
    close_peer_connection: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

/// Media VTable (stub)
pub const MediaVTable = extern struct {
    get_user_media: *const fn (user_context: OpaquePtr, audio: bool, video: bool) callconv(.c) u64,
    stop_stream: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

/// Audio VTable (stub)
pub const AudioVTable = extern struct {
    create_context: *const fn (user_context: OpaquePtr) callconv(.c) u64,
    close_context: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

/// Speech VTable (stub)
pub const SpeechVTable = extern struct {
    speak: *const fn (user_context: OpaquePtr, text: [*]const u8, len: usize) callconv(.c) bool,
    cancel: *const fn (user_context: OpaquePtr) callconv(.c) void,
    is_speaking: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// Gamepad VTable (stub)
pub const GamepadVTable = extern struct {
    get_gamepads: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// Sensor VTable (stub)
pub const SensorVTable = extern struct {
    is_supported: *const fn (user_context: OpaquePtr, sensor_type: u32) callconv(.c) bool,
};

/// Vibration VTable
pub const VibrationVTable = extern struct {
    vibrate: *const fn (
        user_context: OpaquePtr,
        pattern: [*]const u32,
        pattern_len: usize,
    ) callconv(.c) bool,
};

/// Battery VTable
pub const BatteryVTable = extern struct {
    get_level: *const fn (user_context: OpaquePtr) callconv(.c) f64,
    is_charging: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    get_charging_time: *const fn (user_context: OpaquePtr) callconv(.c) f64,
    get_discharging_time: *const fn (user_context: OpaquePtr) callconv(.c) f64,
};

/// Screen VTable
pub const ScreenVTable = extern struct {
    get_width: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_height: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_avail_width: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_avail_height: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_color_depth: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_pixel_depth: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_orientation: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// WakeLock VTable
pub const WakeLockVTable = extern struct {
    request: *const fn (user_context: OpaquePtr, lock_type: u32) callconv(.c) u64,
    release: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

/// Share VTable
pub const ShareVTable = extern struct {
    can_share: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    share: *const fn (
        user_context: OpaquePtr,
        title: ?[*]const u8,
        title_len: usize,
        text: ?[*]const u8,
        text_len: usize,
        url: ?[*]const u8,
        url_len: usize,
    ) callconv(.c) bool,
};

/// Payment VTable (stub)
pub const PaymentVTable = extern struct {
    can_make_payment: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// Credentials VTable (stub)
pub const CredentialsVTable = extern struct {
    get: *const fn (user_context: OpaquePtr, mediation: u32) callconv(.c) u64,
    store: *const fn (user_context: OpaquePtr, credential: u64) callconv(.c) bool,
};

/// WebAuthn VTable (stub)
pub const WebAuthnVTable = extern struct {
    is_available: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// DeviceOrientation VTable
pub const DeviceOrientationVTable = extern struct {
    start_listening: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    stop_listening: *const fn (user_context: OpaquePtr) callconv(.c) void,
    get_orientation: *const fn (
        user_context: OpaquePtr,
        out_alpha: *f64,
        out_beta: *f64,
        out_gamma: *f64,
    ) callconv(.c) bool,
};

/// NFC VTable (stub)
pub const NFCVTable = extern struct {
    is_available: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// Permissions VTable
pub const PermissionsVTable = extern struct {
    /// Query permission state.
    /// Returns: 0 = granted, 1 = denied, 2 = prompt, -1 = error
    query: *const fn (
        user_context: OpaquePtr,
        permission_name: [*]const u8,
        name_len: usize,
    ) callconv(.c) i32,

    /// Request permission.
    /// Returns: 0 = granted, 1 = denied, -1 = error
    request: *const fn (
        user_context: OpaquePtr,
        permission_name: [*]const u8,
        name_len: usize,
    ) callconv(.c) i32,
};

// =============================================================================
// Tests
// =============================================================================

test "VTable structs are extern" {
    // Verify all VTable structs are extern for C FFI
    const vtable_types = .{
        ClipboardVTable,
        TimerVTable,
        LayoutVTable,
        NotificationVTable,
        PushVTable,
        NetworkVTable,
        StorageVTable,
        FileSystemVTable,
        UIVTable,
        GeolocationVTable,
    };

    inline for (vtable_types) |T| {
        const info = @typeInfo(T);
        try std.testing.expect(info == .@"struct");
        try std.testing.expect(info.@"struct".layout == .@"extern");
    }
}

test "Enum types are C compatible" {
    // Verify enums have explicit integer backing
    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(ClipboardResult.success));
    try std.testing.expectEqual(@as(i32, -1), @intFromEnum(ClipboardResult.permission_denied));
    try std.testing.expectEqual(@as(i32, 0), @intFromEnum(NotificationPermission.default));
    try std.testing.expectEqual(@as(i32, 1), @intFromEnum(NotificationPermission.granted));
}
