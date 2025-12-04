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
    /// Read plain text from clipboard (clipboard.readText())
    /// Returns length of text, or negative ClipboardResult on error.
    /// If buffer is null, returns required buffer size.
    call_readText: *const fn (
        user_context: OpaquePtr,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Write plain text to clipboard (clipboard.writeText())
    call_writeText: *const fn (
        user_context: OpaquePtr,
        text: [*]const u8,
        text_len: usize,
    ) callconv(.c) ClipboardResult,

    /// Read HTML from clipboard.
    /// Returns length of HTML, or negative ClipboardResult on error.
    readHtml: *const fn (
        user_context: OpaquePtr,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Write HTML to clipboard (with optional plain text fallback).
    writeHtml: *const fn (
        user_context: OpaquePtr,
        html: [*]const u8,
        html_len: usize,
        plain_text: ?[*]const u8,
        plain_text_len: usize,
    ) callconv(.c) ClipboardResult,

    /// Check if clipboard read is permitted.
    canRead: *const fn (user_context: OpaquePtr) callconv(.c) bool,

    /// Check if clipboard write is permitted.
    canWrite: *const fn (user_context: OpaquePtr) callconv(.c) bool,

    /// Check if clipboard has content.
    hasContent: *const fn (user_context: OpaquePtr) callconv(.c) bool,

    /// Clear clipboard contents.
    clear: *const fn (user_context: OpaquePtr) callconv(.c) ClipboardResult,
};

// =============================================================================
// Timer VTable
// =============================================================================

/// Timer VTable for timing operations
pub const TimerVTable = extern struct {
    /// Get current time in milliseconds since epoch (Date.now())
    getCurrentTime: *const fn (user_context: OpaquePtr) callconv(.c) i64,

    /// Get high-resolution time in nanoseconds (performance.now())
    getHighResTime: *const fn (user_context: OpaquePtr) callconv(.c) i64,

    /// Schedule a wakeup at the specified time (milliseconds since epoch)
    scheduleWakeup: *const fn (user_context: OpaquePtr, time_ms: i64) callconv(.c) void,

    /// Cancel any pending wakeup
    cancelWakeup: *const fn (user_context: OpaquePtr) callconv(.c) void,

    /// Sleep until the next scheduled wakeup or timeout.
    /// Returns actual time slept in milliseconds.
    sleepUntilWakeup: *const fn (
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
    get_offsetWidth: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetHeight
    get_offsetHeight: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetTop
    get_offsetTop: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetLeft
    get_offsetLeft: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's offsetParent (returns null if none)
    get_offsetParent: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) OpaquePtr,

    /// Get element's clientWidth
    get_clientWidth: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's clientHeight
    get_clientHeight: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's clientTop
    get_clientTop: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's clientLeft
    get_clientLeft: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's scrollWidth
    get_scrollWidth: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's scrollHeight
    get_scrollHeight: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Get element's scrollTop
    get_scrollTop: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Set element's scrollTop
    set_scrollTop: *const fn (user_context: OpaquePtr, element: OpaquePtr, value: f64) callconv(.c) void,

    /// Get element's scrollLeft
    get_scrollLeft: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) f64,

    /// Set element's scrollLeft
    set_scrollLeft: *const fn (user_context: OpaquePtr, element: OpaquePtr, value: f64) callconv(.c) void,

    /// Get element's bounding client rect (getBoundingClientRect)
    call_getBoundingClientRect: *const fn (
        user_context: OpaquePtr,
        element: OpaquePtr,
        out_rect: *CDOMRect,
    ) callconv(.c) void,

    /// Check if element is rendered (not display: none)
    isElementRendered: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) bool,

    /// Mark element as needing layout recalculation
    markDirty: *const fn (user_context: OpaquePtr, element: OpaquePtr) callconv(.c) void,

    /// Force synchronous layout computation
    forceLayout: *const fn (user_context: OpaquePtr) callconv(.c) void,
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

/// Notification options (C-compatible) - NotificationOptions
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
    requireInteraction: bool,
    silent: bool,
    timestamp: i64, // -1 = use current time
};

/// Notification handle (opaque)
pub const NotificationHandle = u64;

/// Notification VTable
pub const NotificationVTable = extern struct {
    /// Get current permission state (Notification.permission)
    get_permission: *const fn (user_context: OpaquePtr) callconv(.c) NotificationPermission,

    /// Request permission from user (Notification.requestPermission())
    call_requestPermission: *const fn (user_context: OpaquePtr) callconv(.c) NotificationPermission,

    /// Show a notification (new Notification()). Returns handle on success, 0 on failure.
    show: *const fn (
        user_context: OpaquePtr,
        options: *const CNotificationOptions,
    ) callconv(.c) NotificationHandle,

    /// Close a notification (notification.close())
    call_close: *const fn (user_context: OpaquePtr, handle: NotificationHandle) callconv(.c) NotificationResult,

    /// Get maximum number of actions supported (Notification.maxActions)
    get_maxActions: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

// =============================================================================
// Push VTable
// Spec: https://w3c.github.io/push-api/
// =============================================================================

/// Push subscription handle (opaque)
pub const PushSubscriptionHandle = u64;

/// Push VTable - PushManager
pub const PushVTable = extern struct {
    /// Subscribe to push notifications (pushManager.subscribe())
    /// Returns subscription handle on success, 0 on failure.
    call_subscribe: *const fn (
        user_context: OpaquePtr,
        applicationServerKey: [*]const u8,
        keyLen: usize,
    ) callconv(.c) PushSubscriptionHandle,

    /// Unsubscribe from push notifications (subscription.unsubscribe())
    call_unsubscribe: *const fn (user_context: OpaquePtr, handle: PushSubscriptionHandle) callconv(.c) bool,

    /// Get existing subscription (pushManager.getSubscription())
    call_getSubscription: *const fn (user_context: OpaquePtr) callconv(.c) PushSubscriptionHandle,

    /// Check if push is supported
    isSupported: *const fn (user_context: OpaquePtr) callconv(.c) bool,
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

/// Network request options (C-compatible) - RequestInit
pub const CNetworkRequest = extern struct {
    url: [*]const u8,
    url_len: usize,
    method: HttpMethod,
    headers: ?[*]const CHeader,
    headersCount: usize,
    body: ?[*]const u8,
    bodyLen: usize,
    timeout_ms: u32,
    followRedirects: bool,
};

/// Header for network requests
pub const CHeader = extern struct {
    name: [*]const u8,
    nameLen: usize,
    value: [*]const u8,
    valueLen: usize,
};

/// Callback for network response
pub const NetworkResponseCallback = *const fn (
    userData: OpaquePtr,
    status: u16,
    headers: [*]const CHeader,
    headersCount: usize,
    body: [*]const u8,
    bodyLen: usize,
) callconv(.c) void;

/// Callback for network errors
pub const NetworkErrorCallback = *const fn (
    userData: OpaquePtr,
    result: NetworkResult,
) callconv(.c) void;

/// Network VTable (fetch API)
pub const NetworkVTable = extern struct {
    /// Start a network request (async) - fetch()
    /// Returns request handle for cancellation.
    call_fetch: *const fn (
        user_context: OpaquePtr,
        request: *const CNetworkRequest,
        onResponse: NetworkResponseCallback,
        onError: NetworkErrorCallback,
        callbackUserData: OpaquePtr,
    ) callconv(.c) NetworkRequestHandle,

    /// Abort a pending request (AbortController.abort())
    call_abort: *const fn (user_context: OpaquePtr, handle: NetworkRequestHandle) callconv(.c) void,

    /// Check if online (navigator.onLine)
    get_onLine: *const fn (user_context: OpaquePtr) callconv(.c) bool,
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

/// Storage VTable (localStorage/sessionStorage)
pub const StorageVTable = extern struct {
    /// Get item from storage (storage.getItem())
    /// Returns length of value, or negative StorageResult on error.
    /// If buffer is null, returns required buffer size.
    call_getItem: *const fn (
        user_context: OpaquePtr,
        key: [*]const u8,
        key_len: usize,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Set item in storage (storage.setItem())
    call_setItem: *const fn (
        user_context: OpaquePtr,
        key: [*]const u8,
        key_len: usize,
        value: [*]const u8,
        value_len: usize,
    ) callconv(.c) StorageResult,

    /// Remove item from storage (storage.removeItem())
    call_removeItem: *const fn (
        user_context: OpaquePtr,
        key: [*]const u8,
        key_len: usize,
    ) callconv(.c) StorageResult,

    /// Clear all items from storage (storage.clear())
    call_clear: *const fn (user_context: OpaquePtr) callconv(.c) StorageResult,

    /// Get number of items in storage (storage.length)
    get_length: *const fn (user_context: OpaquePtr) callconv(.c) u32,

    /// Get key at index (storage.key())
    /// Returns length of key, or negative StorageResult on error.
    call_key: *const fn (
        user_context: OpaquePtr,
        index: u32,
        buffer: ?[*]u8,
        buffer_size: usize,
    ) callconv(.c) i32,

    /// Get storage quota info (StorageManager.estimate())
    getQuota: *const fn (
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

/// FileSystem VTable - File System Access API
pub const FileSystemVTable = extern struct {
    /// Open the root directory (navigator.storage.getDirectory())
    call_getDirectory: *const fn (user_context: OpaquePtr) callconv(.c) DirectoryHandle,

    /// Open a file in directory (directoryHandle.getFileHandle())
    call_getFileHandle: *const fn (
        user_context: OpaquePtr,
        dir: DirectoryHandle,
        name: [*]const u8,
        nameLen: usize,
        mode: FileMode,
        create: bool,
    ) callconv(.c) FileHandle,

    /// Open a subdirectory (directoryHandle.getDirectoryHandle())
    call_getDirectoryHandle: *const fn (
        user_context: OpaquePtr,
        parent: DirectoryHandle,
        name: [*]const u8,
        nameLen: usize,
        create: bool,
    ) callconv(.c) DirectoryHandle,

    /// Read from file (FileSystemSyncAccessHandle.read())
    call_read: *const fn (
        user_context: OpaquePtr,
        handle: FileHandle,
        offset: u64,
        buffer: [*]u8,
        bufferSize: usize,
    ) callconv(.c) i64,

    /// Write to file (FileSystemSyncAccessHandle.write())
    call_write: *const fn (
        user_context: OpaquePtr,
        handle: FileHandle,
        offset: u64,
        data: [*]const u8,
        dataLen: usize,
    ) callconv(.c) i64,

    /// Get file size (FileSystemSyncAccessHandle.getSize())
    call_getSize: *const fn (user_context: OpaquePtr, handle: FileHandle) callconv(.c) i64,

    /// Close file handle (FileSystemSyncAccessHandle.close())
    call_closeFile: *const fn (user_context: OpaquePtr, handle: FileHandle) callconv(.c) void,

    /// Close directory handle
    closeDirectory: *const fn (user_context: OpaquePtr, handle: DirectoryHandle) callconv(.c) void,

    /// Remove file or directory (directoryHandle.removeEntry())
    call_removeEntry: *const fn (
        user_context: OpaquePtr,
        parent: DirectoryHandle,
        name: [*]const u8,
        nameLen: usize,
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

/// UI VTable - window dialogs
pub const UIVTable = extern struct {
    /// Show an alert dialog (window.alert/confirm). Returns true if confirmed.
    call_alert: *const fn (
        user_context: OpaquePtr,
        alertType: AlertType,
        message: [*]const u8,
        messageLen: usize,
    ) callconv(.c) bool,

    /// Show a prompt dialog (window.prompt())
    /// Returns length of response, or -1 if cancelled.
    call_prompt: *const fn (
        user_context: OpaquePtr,
        message: [*]const u8,
        messageLen: usize,
        defaultValue: ?[*]const u8,
        defaultLen: usize,
        buffer: ?[*]u8,
        bufferSize: usize,
    ) callconv(.c) i32,

    /// Focus the window (window.focus())
    call_focus: *const fn (user_context: OpaquePtr) callconv(.c) void,

    /// Blur the window (window.blur())
    call_blur: *const fn (user_context: OpaquePtr) callconv(.c) void,

    /// Print the page (window.print())
    call_print: *const fn (user_context: OpaquePtr) callconv(.c) void,
};

// =============================================================================
// Geolocation VTable
// Spec: https://w3c.github.io/geolocation-api/
// =============================================================================

/// Geolocation position (C-compatible) - GeolocationCoordinates
pub const CGeolocationPosition = extern struct {
    latitude: f64,
    longitude: f64,
    altitude: f64, // NaN if unavailable
    accuracy: f64,
    altitudeAccuracy: f64, // NaN if unavailable
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
    userData: OpaquePtr,
    position: *const CGeolocationPosition,
) callconv(.c) void;

/// Callback for geolocation error
pub const GeolocationErrorCallback = *const fn (
    userData: OpaquePtr,
    errorCode: GeolocationError,
) callconv(.c) void;

/// Geolocation VTable
pub const GeolocationVTable = extern struct {
    /// Get current position (async) - navigator.geolocation.getCurrentPosition()
    call_getCurrentPosition: *const fn (
        user_context: OpaquePtr,
        on_success: GeolocationSuccessCallback,
        on_error: GeolocationErrorCallback,
        callback_user_data: OpaquePtr,
        enableHighAccuracy: bool,
        timeout_ms: u32,
        maximumAge_ms: u32,
    ) callconv(.c) void,

    /// Watch position (async, repeating) - navigator.geolocation.watchPosition()
    call_watchPosition: *const fn (
        user_context: OpaquePtr,
        on_success: GeolocationSuccessCallback,
        on_error: GeolocationErrorCallback,
        callback_user_data: OpaquePtr,
        enableHighAccuracy: bool,
        timeout_ms: u32,
        maximumAge_ms: u32,
    ) callconv(.c) WatchId,

    /// Clear watch - navigator.geolocation.clearWatch()
    call_clearWatch: *const fn (user_context: OpaquePtr, watchId: WatchId) callconv(.c) void,
};

// =============================================================================
// Stub VTables for Less Common APIs
// These will be expanded as needed
// =============================================================================

/// Bluetooth VTable (stub) - navigator.bluetooth
pub const BluetoothVTable = extern struct {
    call_requestDevice: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    call_getAvailability: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// USB VTable (stub) - navigator.usb
pub const USBVTable = extern struct {
    call_requestDevice: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    call_getDevices: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// Serial VTable (stub) - navigator.serial
pub const SerialVTable = extern struct {
    call_requestPort: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    call_getPorts: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// HID VTable (stub) - navigator.hid
pub const HIDVTable = extern struct {
    call_requestDevice: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    call_getDevices: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// WebRTC VTable (stub) - RTCPeerConnection
pub const WebRTCVTable = extern struct {
    createPeerConnection: *const fn (user_context: OpaquePtr) callconv(.c) u64,
    call_close: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

// =============================================================================
// Media VTable
// Specs: Media Source Extensions (MSE) + Encrypted Media Extensions (EME) +
//        MediaDevices API
// =============================================================================

/// MediaSource ready state
pub const MediaSourceReadyState = enum(u8) {
    closed = 0,
    open = 1,
    ended = 2,
};

/// Media operation result
pub const MediaResult = enum(i32) {
    success = 0,
    invalid_state = -1,
    not_supported = -2,
    quota_exceeded = -3,
    invalid_access = -4,
    type_error = -5,
    error_unknown = -99,
};

/// MediaSource handle (opaque)
pub const MediaSourceHandle = u64;

/// SourceBuffer handle (opaque)
pub const SourceBufferHandle = u64;

/// MediaKeys handle (opaque) - for EME
pub const MediaKeysHandle = u64;

/// MediaKeySession handle (opaque) - for EME
pub const MediaKeySessionHandle = u64;

/// MediaStream handle (opaque) - for getUserMedia
pub const MediaStreamHandle = u64;

/// Media VTable - MediaDevices + MediaSource + MediaKeys
/// Specs:
/// - https://w3c.github.io/mediacapture-main/ (MediaDevices)
/// - https://w3c.github.io/media-source/ (MSE)
/// - https://w3c.github.io/encrypted-media/ (EME)
pub const MediaVTable = extern struct {
    // === MediaDevices API ===

    /// Get user media stream (navigator.mediaDevices.getUserMedia())
    /// Returns stream handle on success, 0 on failure.
    call_getUserMedia: *const fn (user_context: OpaquePtr, audio: bool, video: bool) callconv(.c) MediaStreamHandle,

    /// Stop a media stream
    stopStream: *const fn (user_context: OpaquePtr, handle: MediaStreamHandle) callconv(.c) void,

    // === Media Source Extensions (MSE) ===

    /// Create a MediaSource (new MediaSource())
    /// Returns handle on success, 0 on failure.
    createMediaSource: *const fn (user_context: OpaquePtr) callconv(.c) MediaSourceHandle,

    /// Destroy a MediaSource
    destroyMediaSource: *const fn (user_context: OpaquePtr, handle: MediaSourceHandle) callconv(.c) void,

    /// Get MediaSource ready state (mediaSource.readyState)
    getReadyState: *const fn (user_context: OpaquePtr, handle: MediaSourceHandle) callconv(.c) MediaSourceReadyState,

    /// Set MediaSource duration (mediaSource.duration)
    setDuration: *const fn (user_context: OpaquePtr, handle: MediaSourceHandle, duration: f64) callconv(.c) MediaResult,

    /// Get MediaSource duration (mediaSource.duration)
    getDuration: *const fn (user_context: OpaquePtr, handle: MediaSourceHandle) callconv(.c) f64,

    /// Add SourceBuffer (mediaSource.addSourceBuffer())
    /// Returns buffer handle on success, 0 on failure.
    addSourceBuffer: *const fn (
        user_context: OpaquePtr,
        media_source: MediaSourceHandle,
        mime_type: [*]const u8,
        mime_type_len: usize,
    ) callconv(.c) SourceBufferHandle,

    /// Remove SourceBuffer (mediaSource.removeSourceBuffer())
    removeSourceBuffer: *const fn (
        user_context: OpaquePtr,
        media_source: MediaSourceHandle,
        source_buffer: SourceBufferHandle,
    ) callconv(.c) MediaResult,

    /// End of stream (mediaSource.endOfStream())
    endOfStream: *const fn (user_context: OpaquePtr, handle: MediaSourceHandle) callconv(.c) MediaResult,

    /// Append buffer data (sourceBuffer.appendBuffer())
    appendBuffer: *const fn (
        user_context: OpaquePtr,
        source_buffer: SourceBufferHandle,
        data: [*]const u8,
        data_len: usize,
    ) callconv(.c) MediaResult,

    /// Remove buffered data (sourceBuffer.remove())
    removeBufferedData: *const fn (
        user_context: OpaquePtr,
        source_buffer: SourceBufferHandle,
        start: f64,
        end: f64,
    ) callconv(.c) MediaResult,

    /// Abort current operation (sourceBuffer.abort())
    abortSourceBuffer: *const fn (user_context: OpaquePtr, source_buffer: SourceBufferHandle) callconv(.c) MediaResult,

    /// Check if SourceBuffer is updating (sourceBuffer.updating)
    isUpdating: *const fn (user_context: OpaquePtr, source_buffer: SourceBufferHandle) callconv(.c) bool,

    // === Encrypted Media Extensions (EME) ===

    /// Request MediaKeySystemAccess (navigator.requestMediaKeySystemAccess())
    /// Returns true if the key system is supported.
    isKeySystemSupported: *const fn (
        user_context: OpaquePtr,
        key_system: [*]const u8,
        key_system_len: usize,
    ) callconv(.c) bool,

    /// Create MediaKeys (mediaKeySystemAccess.createMediaKeys())
    /// Returns handle on success, 0 on failure.
    createMediaKeys: *const fn (
        user_context: OpaquePtr,
        key_system: [*]const u8,
        key_system_len: usize,
    ) callconv(.c) MediaKeysHandle,

    /// Destroy MediaKeys
    destroyMediaKeys: *const fn (user_context: OpaquePtr, handle: MediaKeysHandle) callconv(.c) void,

    /// Create MediaKeySession (mediaKeys.createSession())
    /// Returns session handle on success, 0 on failure.
    createSession: *const fn (
        user_context: OpaquePtr,
        media_keys: MediaKeysHandle,
        session_type: u8, // 0 = temporary, 1 = persistent-license
    ) callconv(.c) MediaKeySessionHandle,

    /// Close MediaKeySession (session.close())
    closeSession: *const fn (user_context: OpaquePtr, session: MediaKeySessionHandle) callconv(.c) MediaResult,

    /// Generate license request (session.generateRequest())
    generateRequest: *const fn (
        user_context: OpaquePtr,
        session: MediaKeySessionHandle,
        init_data_type: [*]const u8,
        init_data_type_len: usize,
        init_data: [*]const u8,
        init_data_len: usize,
    ) callconv(.c) MediaResult,

    /// Update session with license (session.update())
    updateSession: *const fn (
        user_context: OpaquePtr,
        session: MediaKeySessionHandle,
        response: [*]const u8,
        response_len: usize,
    ) callconv(.c) MediaResult,
};

/// Audio VTable (stub) - AudioContext
pub const AudioVTable = extern struct {
    createContext: *const fn (user_context: OpaquePtr) callconv(.c) u64,
    call_close: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

/// Speech VTable (stub) - speechSynthesis
pub const SpeechVTable = extern struct {
    call_speak: *const fn (user_context: OpaquePtr, text: [*]const u8, len: usize) callconv(.c) bool,
    call_cancel: *const fn (user_context: OpaquePtr) callconv(.c) void,
    get_speaking: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// Gamepad VTable (stub) - navigator.getGamepads()
pub const GamepadVTable = extern struct {
    call_getGamepads: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// Sensor VTable (stub) - Generic Sensor API
pub const SensorVTable = extern struct {
    isSupported: *const fn (user_context: OpaquePtr, sensorType: u32) callconv(.c) bool,
};

/// Vibration VTable - navigator.vibrate()
pub const VibrationVTable = extern struct {
    call_vibrate: *const fn (
        user_context: OpaquePtr,
        pattern: [*]const u32,
        patternLen: usize,
    ) callconv(.c) bool,
};

/// Battery VTable
pub const BatteryVTable = extern struct {
    get_level: *const fn (user_context: OpaquePtr) callconv(.c) f64,
    get_charging: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    get_chargingTime: *const fn (user_context: OpaquePtr) callconv(.c) f64,
    get_dischargingTime: *const fn (user_context: OpaquePtr) callconv(.c) f64,
};

/// Screen VTable
pub const ScreenVTable = extern struct {
    get_width: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_height: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_availWidth: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_availHeight: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_colorDepth: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_pixelDepth: *const fn (user_context: OpaquePtr) callconv(.c) u32,
    get_orientation: *const fn (user_context: OpaquePtr) callconv(.c) u32,
};

/// WakeLock VTable - navigator.wakeLock
pub const WakeLockVTable = extern struct {
    call_request: *const fn (user_context: OpaquePtr, lockType: u32) callconv(.c) u64,
    call_release: *const fn (user_context: OpaquePtr, handle: u64) callconv(.c) void,
};

/// Share VTable - navigator.share()
pub const ShareVTable = extern struct {
    call_canShare: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    call_share: *const fn (
        user_context: OpaquePtr,
        title: ?[*]const u8,
        titleLen: usize,
        text: ?[*]const u8,
        textLen: usize,
        url: ?[*]const u8,
        urlLen: usize,
    ) callconv(.c) bool,
};

/// Payment VTable (stub) - PaymentRequest
pub const PaymentVTable = extern struct {
    call_canMakePayment: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// Credentials VTable (stub) - navigator.credentials
pub const CredentialsVTable = extern struct {
    call_get: *const fn (user_context: OpaquePtr, mediation: u32) callconv(.c) u64,
    call_store: *const fn (user_context: OpaquePtr, credential: u64) callconv(.c) bool,
};

/// WebAuthn VTable (stub) - PublicKeyCredential
pub const WebAuthnVTable = extern struct {
    isAvailable: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// DeviceOrientation VTable - DeviceOrientationEvent
pub const DeviceOrientationVTable = extern struct {
    startListening: *const fn (user_context: OpaquePtr) callconv(.c) bool,
    stopListening: *const fn (user_context: OpaquePtr) callconv(.c) void,
    getOrientation: *const fn (
        user_context: OpaquePtr,
        outAlpha: *f64,
        outBeta: *f64,
        outGamma: *f64,
    ) callconv(.c) bool,
};

/// NFC VTable (stub) - NDEFReader
pub const NFCVTable = extern struct {
    isAvailable: *const fn (user_context: OpaquePtr) callconv(.c) bool,
};

/// Permissions VTable - navigator.permissions
pub const PermissionsVTable = extern struct {
    /// Query permission state (permissions.query())
    /// Returns: 0 = granted, 1 = denied, 2 = prompt, -1 = error
    call_query: *const fn (
        user_context: OpaquePtr,
        permissionName: [*]const u8,
        nameLen: usize,
    ) callconv(.c) i32,

    /// Request permission.
    /// Returns: 0 = granted, 1 = denied, -1 = error
    call_request: *const fn (
        user_context: OpaquePtr,
        permissionName: [*]const u8,
        nameLen: usize,
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
