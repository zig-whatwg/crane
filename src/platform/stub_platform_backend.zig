//! Stub Platform Backend for Testing
//!
//! This module provides a complete stub implementation of PlatformBackend
//! suitable for unit testing without requiring real platform capabilities.
//!
//! ## Features
//!
//! - **In-Memory Clipboard**: Stores text/HTML in memory
//! - **Mock Timer**: Returns configurable time values
//! - **Mock Layout**: Returns configurable dimensions
//! - **In-Memory Storage**: Key-value store in memory
//! - **Mock Geolocation**: Returns configurable position
//! - **All Capabilities**: Every VTable has a stub implementation
//!
//! ## Usage
//!
//! ```zig
//! const stub = @import("stub_platform_backend.zig");
//!
//! // Create a stub backend with default values
//! var context = stub.StubContext.init(std.testing.allocator);
//! defer context.deinit();
//!
//! const backend = stub.createStubBackend(&context);
//!
//! // Use in tests
//! try std.testing.expect(backend.hasCapability(.clipboard));
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const platform_backend = @import("platform_backend.zig");
const PlatformBackend = platform_backend.PlatformBackend;
const Capability = platform_backend.Capability;

const vtables = @import("vtables.zig");
const ClipboardVTable = vtables.ClipboardVTable;
const ClipboardResult = vtables.ClipboardResult;
const TimerVTable = vtables.TimerVTable;
const LayoutVTable = vtables.LayoutVTable;
const CDOMRect = vtables.CDOMRect;
const NotificationVTable = vtables.NotificationVTable;
const NotificationPermission = vtables.NotificationPermission;
const NotificationResult = vtables.NotificationResult;
const CNotificationOptions = vtables.CNotificationOptions;
const PushVTable = vtables.PushVTable;
const NetworkVTable = vtables.NetworkVTable;
const CNetworkRequest = vtables.CNetworkRequest;
const NetworkResult = vtables.NetworkResult;
const StorageVTable = vtables.StorageVTable;
const StorageResult = vtables.StorageResult;
const FileSystemVTable = vtables.FileSystemVTable;
const FileSystemResult = vtables.FileSystemResult;
const UIVTable = vtables.UIVTable;
const AlertType = vtables.AlertType;
const GeolocationVTable = vtables.GeolocationVTable;
const CGeolocationPosition = vtables.CGeolocationPosition;
const GeolocationError = vtables.GeolocationError;
const ScreenVTable = vtables.ScreenVTable;
const VibrationVTable = vtables.VibrationVTable;
const BatteryVTable = vtables.BatteryVTable;
const ShareVTable = vtables.ShareVTable;
const PermissionsVTable = vtables.PermissionsVTable;
const OpaquePtr = vtables.OpaquePtr;

// =============================================================================
// Stub Context
// =============================================================================

/// Context for stub implementations.
/// Stores configurable state for testing.
pub const StubContext = struct {
    allocator: Allocator,

    // Clipboard state
    clipboard_text: ?[]u8 = null,
    clipboard_html: ?[]u8 = null,
    clipboard_read_allowed: bool = true,
    clipboard_write_allowed: bool = true,

    // Timer state
    current_time_ms: i64 = 0,
    high_res_time_ns: i64 = 0,

    // Layout state
    default_width: f64 = 100,
    default_height: f64 = 50,
    default_scroll_x: f64 = 0,
    default_scroll_y: f64 = 0,

    // Notification state
    notification_permission: NotificationPermission = .default,
    next_notification_id: u64 = 1,

    // Storage state (simple in-memory key-value)
    storage: std.StringHashMapUnmanaged([]u8) = .{},

    // Geolocation state
    latitude: f64 = 37.7749,
    longitude: f64 = -122.4194,
    accuracy: f64 = 10.0,

    // Screen state
    screen_width: u32 = 1920,
    screen_height: u32 = 1080,
    color_depth: u32 = 24,

    // Battery state
    battery_level: f64 = 1.0,
    battery_charging: bool = true,

    // Network state
    is_online: bool = true,

    // UI state
    last_alert_message: ?[]u8 = null,
    confirm_result: bool = true,
    prompt_result: ?[]const u8 = null,

    pub fn init(allocator: Allocator) StubContext {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StubContext) void {
        if (self.clipboard_text) |text| {
            self.allocator.free(text);
        }
        if (self.clipboard_html) |html| {
            self.allocator.free(html);
        }
        if (self.last_alert_message) |msg| {
            self.allocator.free(msg);
        }

        // Free storage keys and values
        var key_iter = self.storage.keyIterator();
        while (key_iter.next()) |key_ptr| {
            self.allocator.free(key_ptr.*);
        }
        var value_iter = self.storage.valueIterator();
        while (value_iter.next()) |value_ptr| {
            self.allocator.free(value_ptr.*);
        }
        self.storage.deinit(self.allocator);
    }

    /// Advance time by the given milliseconds
    pub fn advanceTime(self: *StubContext, ms: i64) void {
        self.current_time_ms += ms;
        self.high_res_time_ns += ms * 1_000_000;
    }

    /// Set the clipboard text
    pub fn setClipboardText(self: *StubContext, text: []const u8) !void {
        if (self.clipboard_text) |old| {
            self.allocator.free(old);
        }
        self.clipboard_text = try self.allocator.dupe(u8, text);
    }

    /// Set storage value
    pub fn setStorageValue(self: *StubContext, key: []const u8, value: []const u8) !void {
        const value_owned = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_owned);

        // Check if key already exists
        const gop = try self.storage.getOrPut(self.allocator, key);

        if (gop.found_existing) {
            // Free old value
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = value_owned;
        } else {
            // Need to dupe the key since it's not owned
            gop.key_ptr.* = try self.allocator.dupe(u8, key);
            gop.value_ptr.* = value_owned;
        }
    }
};

// =============================================================================
// Clipboard Stub
// =============================================================================

fn stubClipboardReadText(user_context: OpaquePtr, buffer: ?[*]u8, buffer_size: usize) callconv(.c) i32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    if (!ctx.clipboard_read_allowed) {
        return @intFromEnum(ClipboardResult.permission_denied);
    }

    const text = ctx.clipboard_text orelse return @intFromEnum(ClipboardResult.empty);

    if (buffer) |buf| {
        const copy_len = @min(text.len, buffer_size);
        @memcpy(buf[0..copy_len], text[0..copy_len]);
    }

    return @intCast(text.len);
}

fn stubClipboardWriteText(user_context: OpaquePtr, text: [*]const u8, text_len: usize) callconv(.c) ClipboardResult {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    if (!ctx.clipboard_write_allowed) {
        return .permission_denied;
    }

    if (ctx.clipboard_text) |old| {
        ctx.allocator.free(old);
    }

    ctx.clipboard_text = ctx.allocator.dupe(u8, text[0..text_len]) catch return .error_unknown;
    return .success;
}

fn stubClipboardReadHtml(user_context: OpaquePtr, buffer: ?[*]u8, buffer_size: usize) callconv(.c) i32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    if (!ctx.clipboard_read_allowed) {
        return @intFromEnum(ClipboardResult.permission_denied);
    }

    const html = ctx.clipboard_html orelse return @intFromEnum(ClipboardResult.empty);

    if (buffer) |buf| {
        const copy_len = @min(html.len, buffer_size);
        @memcpy(buf[0..copy_len], html[0..copy_len]);
    }

    return @intCast(html.len);
}

fn stubClipboardWriteHtml(
    user_context: OpaquePtr,
    html: [*]const u8,
    html_len: usize,
    _: ?[*]const u8,
    _: usize,
) callconv(.c) ClipboardResult {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    if (!ctx.clipboard_write_allowed) {
        return .permission_denied;
    }

    if (ctx.clipboard_html) |old| {
        ctx.allocator.free(old);
    }

    ctx.clipboard_html = ctx.allocator.dupe(u8, html[0..html_len]) catch return .error_unknown;
    return .success;
}

fn stubClipboardCanRead(user_context: OpaquePtr) callconv(.c) bool {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.clipboard_read_allowed;
}

fn stubClipboardCanWrite(user_context: OpaquePtr) callconv(.c) bool {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.clipboard_write_allowed;
}

fn stubClipboardHasContent(user_context: OpaquePtr) callconv(.c) bool {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.clipboard_text != null or ctx.clipboard_html != null;
}

fn stubClipboardClear(user_context: OpaquePtr) callconv(.c) ClipboardResult {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    if (ctx.clipboard_text) |text| {
        ctx.allocator.free(text);
        ctx.clipboard_text = null;
    }
    if (ctx.clipboard_html) |html| {
        ctx.allocator.free(html);
        ctx.clipboard_html = null;
    }

    return .success;
}

pub const stub_clipboard_vtable = ClipboardVTable{
    .call_readText = stubClipboardReadText,
    .call_writeText = stubClipboardWriteText,
    .readHtml = stubClipboardReadHtml,
    .writeHtml = stubClipboardWriteHtml,
    .canRead = stubClipboardCanRead,
    .canWrite = stubClipboardCanWrite,
    .hasContent = stubClipboardHasContent,
    .clear = stubClipboardClear,
};

// =============================================================================
// Timer Stub
// =============================================================================

fn stubTimerGetCurrentTime(user_context: OpaquePtr) callconv(.c) i64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.current_time_ms;
}

fn stubTimerGetHighResTime(user_context: OpaquePtr) callconv(.c) i64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.high_res_time_ns;
}

fn stubTimerScheduleWakeup(_: OpaquePtr, _: i64) callconv(.c) void {
    // Stub: no-op
}

fn stubTimerCancelWakeup(_: OpaquePtr) callconv(.c) void {
    // Stub: no-op
}

fn stubTimerSleepUntilWakeup(_: OpaquePtr, timeout_ms: i64) callconv(.c) i64 {
    // Stub: return immediately
    return if (timeout_ms > 0) timeout_ms else 0;
}

pub const stub_timer_vtable = TimerVTable{
    .getCurrentTime = stubTimerGetCurrentTime,
    .getHighResTime = stubTimerGetHighResTime,
    .scheduleWakeup = stubTimerScheduleWakeup,
    .cancelWakeup = stubTimerCancelWakeup,
    .sleepUntilWakeup = stubTimerSleepUntilWakeup,
};

// =============================================================================
// Layout Stub
// =============================================================================

fn stubLayoutGetOffsetWidth(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_width;
}

fn stubLayoutGetOffsetHeight(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_height;
}

fn stubLayoutGetOffsetTop(_: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    return 0;
}

fn stubLayoutGetOffsetLeft(_: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    return 0;
}

fn stubLayoutGetOffsetParent(_: OpaquePtr, _: OpaquePtr) callconv(.c) OpaquePtr {
    return null;
}

fn stubLayoutGetClientWidth(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_width;
}

fn stubLayoutGetClientHeight(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_height;
}

fn stubLayoutGetClientTop(_: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    return 0;
}

fn stubLayoutGetClientLeft(_: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    return 0;
}

fn stubLayoutGetScrollWidth(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_width;
}

fn stubLayoutGetScrollHeight(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_height;
}

fn stubLayoutGetScrollTop(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_scroll_y;
}

fn stubLayoutSetScrollTop(user_context: OpaquePtr, _: OpaquePtr, value: f64) callconv(.c) void {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    ctx.default_scroll_y = value;
}

fn stubLayoutGetScrollLeft(user_context: OpaquePtr, _: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.default_scroll_x;
}

fn stubLayoutSetScrollLeft(user_context: OpaquePtr, _: OpaquePtr, value: f64) callconv(.c) void {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    ctx.default_scroll_x = value;
}

fn stubLayoutGetBoundingClientRect(user_context: OpaquePtr, _: OpaquePtr, out_rect: *CDOMRect) callconv(.c) void {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    out_rect.* = .{
        .x = 0,
        .y = 0,
        .width = ctx.default_width,
        .height = ctx.default_height,
    };
}

fn stubLayoutIsElementRendered(_: OpaquePtr, _: OpaquePtr) callconv(.c) bool {
    return true;
}

fn stubLayoutMarkDirty(_: OpaquePtr, _: OpaquePtr) callconv(.c) void {
    // Stub: no-op
}

fn stubLayoutForceLayout(_: OpaquePtr) callconv(.c) void {
    // Stub: no-op
}

pub const stub_layout_vtable = LayoutVTable{
    .get_offsetWidth = stubLayoutGetOffsetWidth,
    .get_offsetHeight = stubLayoutGetOffsetHeight,
    .get_offsetTop = stubLayoutGetOffsetTop,
    .get_offsetLeft = stubLayoutGetOffsetLeft,
    .get_offsetParent = stubLayoutGetOffsetParent,
    .get_clientWidth = stubLayoutGetClientWidth,
    .get_clientHeight = stubLayoutGetClientHeight,
    .get_clientTop = stubLayoutGetClientTop,
    .get_clientLeft = stubLayoutGetClientLeft,
    .get_scrollWidth = stubLayoutGetScrollWidth,
    .get_scrollHeight = stubLayoutGetScrollHeight,
    .get_scrollTop = stubLayoutGetScrollTop,
    .set_scrollTop = stubLayoutSetScrollTop,
    .get_scrollLeft = stubLayoutGetScrollLeft,
    .set_scrollLeft = stubLayoutSetScrollLeft,
    .call_getBoundingClientRect = stubLayoutGetBoundingClientRect,
    .isElementRendered = stubLayoutIsElementRendered,
    .markDirty = stubLayoutMarkDirty,
    .forceLayout = stubLayoutForceLayout,
};

// =============================================================================
// Notification Stub
// =============================================================================

fn stubNotificationGetPermission(user_context: OpaquePtr) callconv(.c) NotificationPermission {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.notification_permission;
}

fn stubNotificationRequestPermission(user_context: OpaquePtr) callconv(.c) NotificationPermission {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    // Simulate granting permission
    ctx.notification_permission = .granted;
    return .granted;
}

fn stubNotificationShow(user_context: OpaquePtr, _: *const CNotificationOptions) callconv(.c) u64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    const id = ctx.next_notification_id;
    ctx.next_notification_id += 1;
    return id;
}

fn stubNotificationClose(_: OpaquePtr, _: u64) callconv(.c) NotificationResult {
    return .success;
}

fn stubNotificationGetMaxActions(_: OpaquePtr) callconv(.c) u32 {
    return 2;
}

pub const stub_notification_vtable = NotificationVTable{
    .get_permission = stubNotificationGetPermission,
    .call_requestPermission = stubNotificationRequestPermission,
    .show = stubNotificationShow,
    .call_close = stubNotificationClose,
    .get_maxActions = stubNotificationGetMaxActions,
};

// =============================================================================
// Push Stub
// =============================================================================

fn stubPushSubscribe(_: OpaquePtr, _: [*]const u8, _: usize) callconv(.c) u64 {
    return 1; // Return fake subscription handle
}

fn stubPushUnsubscribe(_: OpaquePtr, _: u64) callconv(.c) bool {
    return true;
}

fn stubPushGetSubscription(_: OpaquePtr) callconv(.c) u64 {
    return 0; // No existing subscription
}

fn stubPushIsSupported(_: OpaquePtr) callconv(.c) bool {
    return true;
}

pub const stub_push_vtable = PushVTable{
    .call_subscribe = stubPushSubscribe,
    .call_unsubscribe = stubPushUnsubscribe,
    .call_getSubscription = stubPushGetSubscription,
    .isSupported = stubPushIsSupported,
};

// =============================================================================
// Network Stub
// =============================================================================

fn stubNetworkFetch(
    _: OpaquePtr,
    _: *const CNetworkRequest,
    _: vtables.NetworkResponseCallback,
    on_error: vtables.NetworkErrorCallback,
    callback_user_data: OpaquePtr,
) callconv(.c) u64 {
    // Stub: immediately call error callback (no real network)
    on_error(callback_user_data, .network_error);
    return 0;
}

fn stubNetworkAbort(_: OpaquePtr, _: u64) callconv(.c) void {
    // Stub: no-op
}

fn stubNetworkGetOnLine(user_context: OpaquePtr) callconv(.c) bool {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.is_online;
}

pub const stub_network_vtable = NetworkVTable{
    .call_fetch = stubNetworkFetch,
    .call_abort = stubNetworkAbort,
    .get_onLine = stubNetworkGetOnLine,
};

// =============================================================================
// Storage Stub
// =============================================================================

fn stubStorageGetItem(
    user_context: OpaquePtr,
    key: [*]const u8,
    key_len: usize,
    buffer: ?[*]u8,
    buffer_size: usize,
) callconv(.c) i32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    const key_slice = key[0..key_len];

    const value = ctx.storage.get(key_slice) orelse return @intFromEnum(StorageResult.not_found);

    if (buffer) |buf| {
        const copy_len = @min(value.len, buffer_size);
        @memcpy(buf[0..copy_len], value[0..copy_len]);
    }

    return @intCast(value.len);
}

fn stubStorageSetItem(
    user_context: OpaquePtr,
    key: [*]const u8,
    key_len: usize,
    value: [*]const u8,
    value_len: usize,
) callconv(.c) StorageResult {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    ctx.setStorageValue(key[0..key_len], value[0..value_len]) catch return .error_unknown;
    return .success;
}

fn stubStorageRemoveItem(
    user_context: OpaquePtr,
    key: [*]const u8,
    key_len: usize,
) callconv(.c) StorageResult {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    const key_slice = key[0..key_len];

    if (ctx.storage.fetchRemove(key_slice)) |entry| {
        // Free the key that was stored in the map
        ctx.allocator.free(entry.key);
        // Free the value
        ctx.allocator.free(entry.value);
        return .success;
    }

    return .not_found;
}

fn stubStorageClear(user_context: OpaquePtr) callconv(.c) StorageResult {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    // Free both keys and values
    var key_iter = ctx.storage.keyIterator();
    while (key_iter.next()) |key| {
        ctx.allocator.free(key.*);
    }
    var value_iter = ctx.storage.valueIterator();
    while (value_iter.next()) |value| {
        ctx.allocator.free(value.*);
    }
    ctx.storage.clearRetainingCapacity();

    return .success;
}

fn stubStorageGetLength(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return @intCast(ctx.storage.count());
}

fn stubStorageKey(
    user_context: OpaquePtr,
    index: u32,
    buffer: ?[*]u8,
    buffer_size: usize,
) callconv(.c) i32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    var iter = ctx.storage.keyIterator();
    var i: u32 = 0;
    while (iter.next()) |key_ptr| {
        if (i == index) {
            const key = key_ptr.*;
            if (buffer) |buf| {
                const copy_len = @min(key.len, buffer_size);
                for (0..copy_len) |j| {
                    buf[j] = key[j];
                }
            }
            return @intCast(key.len);
        }
        i += 1;
    }

    return @intFromEnum(StorageResult.not_found);
}

fn stubStorageGetQuota(
    _: OpaquePtr,
    out_usage: *u64,
    out_quota: *u64,
) callconv(.c) StorageResult {
    out_usage.* = 0;
    out_quota.* = 10 * 1024 * 1024; // 10MB fake quota
    return .success;
}

pub const stub_storage_vtable = StorageVTable{
    .call_getItem = stubStorageGetItem,
    .call_setItem = stubStorageSetItem,
    .call_removeItem = stubStorageRemoveItem,
    .call_clear = stubStorageClear,
    .get_length = stubStorageGetLength,
    .call_key = stubStorageKey,
    .getQuota = stubStorageGetQuota,
};

// =============================================================================
// FileSystem Stub
// =============================================================================

fn stubFSGetDirectory(_: OpaquePtr) callconv(.c) u64 {
    return 1; // Return fake root handle
}

fn stubFSGetFileHandle(_: OpaquePtr, _: u64, _: [*]const u8, _: usize, _: vtables.FileMode, _: bool) callconv(.c) u64 {
    return 0; // Not found
}

fn stubFSGetDirectoryHandle(_: OpaquePtr, _: u64, _: [*]const u8, _: usize, _: bool) callconv(.c) u64 {
    return 0; // Not found
}

fn stubFSRead(_: OpaquePtr, _: u64, _: u64, _: [*]u8, _: usize) callconv(.c) i64 {
    return @intFromEnum(FileSystemResult.not_found);
}

fn stubFSWrite(_: OpaquePtr, _: u64, _: u64, _: [*]const u8, _: usize) callconv(.c) i64 {
    return @intFromEnum(FileSystemResult.not_found);
}

fn stubFSGetSize(_: OpaquePtr, _: u64) callconv(.c) i64 {
    return @intFromEnum(FileSystemResult.not_found);
}

fn stubFSCloseFile(_: OpaquePtr, _: u64) callconv(.c) void {}

fn stubFSCloseDirectory(_: OpaquePtr, _: u64) callconv(.c) void {}

fn stubFSRemoveEntry(_: OpaquePtr, _: u64, _: [*]const u8, _: usize, _: bool) callconv(.c) FileSystemResult {
    return .not_found;
}

pub const stub_filesystem_vtable = FileSystemVTable{
    .call_getDirectory = stubFSGetDirectory,
    .call_getFileHandle = stubFSGetFileHandle,
    .call_getDirectoryHandle = stubFSGetDirectoryHandle,
    .call_read = stubFSRead,
    .call_write = stubFSWrite,
    .call_getSize = stubFSGetSize,
    .call_closeFile = stubFSCloseFile,
    .closeDirectory = stubFSCloseDirectory,
    .call_removeEntry = stubFSRemoveEntry,
};

// =============================================================================
// UI Stub
// =============================================================================

fn stubUIAlert(user_context: OpaquePtr, alert_type: AlertType, message: [*]const u8, message_len: usize) callconv(.c) bool {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    // Store last alert message
    if (ctx.last_alert_message) |old| {
        ctx.allocator.free(old);
    }
    ctx.last_alert_message = ctx.allocator.dupe(u8, message[0..message_len]) catch null;

    return switch (alert_type) {
        .alert => true,
        .confirm => ctx.confirm_result,
        .prompt => ctx.prompt_result != null,
    };
}

fn stubUIPrompt(
    user_context: OpaquePtr,
    _: [*]const u8,
    _: usize,
    _: ?[*]const u8,
    _: usize,
    buffer: ?[*]u8,
    buffer_size: usize,
) callconv(.c) i32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    const result = ctx.prompt_result orelse return -1;

    if (buffer) |buf| {
        const copy_len = @min(result.len, buffer_size);
        @memcpy(buf[0..copy_len], result[0..copy_len]);
    }

    return @intCast(result.len);
}

fn stubUIFocus(_: OpaquePtr) callconv(.c) void {}
fn stubUIBlur(_: OpaquePtr) callconv(.c) void {}
fn stubUIPrint(_: OpaquePtr) callconv(.c) void {}

pub const stub_ui_vtable = UIVTable{
    .call_alert = stubUIAlert,
    .call_prompt = stubUIPrompt,
    .call_focus = stubUIFocus,
    .call_blur = stubUIBlur,
    .call_print = stubUIPrint,
};

// =============================================================================
// Geolocation Stub
// =============================================================================

fn stubGeoGetCurrentPosition(
    user_context: OpaquePtr,
    on_success: vtables.GeolocationSuccessCallback,
    _: vtables.GeolocationErrorCallback,
    callback_user_data: OpaquePtr,
    _: bool,
    _: u32,
    _: u32,
) callconv(.c) void {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    const position = CGeolocationPosition{
        .latitude = ctx.latitude,
        .longitude = ctx.longitude,
        .altitude = std.math.nan(f64),
        .accuracy = ctx.accuracy,
        .altitudeAccuracy = std.math.nan(f64),
        .heading = std.math.nan(f64),
        .speed = std.math.nan(f64),
        .timestamp = ctx.current_time_ms,
    };

    on_success(callback_user_data, &position);
}

fn stubGeoWatchPosition(
    user_context: OpaquePtr,
    on_success: vtables.GeolocationSuccessCallback,
    _: vtables.GeolocationErrorCallback,
    callback_user_data: OpaquePtr,
    _: bool,
    _: u32,
    _: u32,
) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));

    // Call success immediately for stub
    const position = CGeolocationPosition{
        .latitude = ctx.latitude,
        .longitude = ctx.longitude,
        .altitude = std.math.nan(f64),
        .accuracy = ctx.accuracy,
        .altitudeAccuracy = std.math.nan(f64),
        .heading = std.math.nan(f64),
        .speed = std.math.nan(f64),
        .timestamp = ctx.current_time_ms,
    };

    on_success(callback_user_data, &position);

    return 1; // Return watch ID
}

fn stubGeoClearWatch(_: OpaquePtr, _: u32) callconv(.c) void {}

pub const stub_geolocation_vtable = GeolocationVTable{
    .call_getCurrentPosition = stubGeoGetCurrentPosition,
    .call_watchPosition = stubGeoWatchPosition,
    .call_clearWatch = stubGeoClearWatch,
};

// =============================================================================
// Screen Stub
// =============================================================================

fn stubScreenGetWidth(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.screen_width;
}

fn stubScreenGetHeight(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.screen_height;
}

fn stubScreenGetAvailWidth(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.screen_width;
}

fn stubScreenGetAvailHeight(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.screen_height - 40; // Simulated taskbar
}

fn stubScreenGetColorDepth(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.color_depth;
}

fn stubScreenGetPixelDepth(user_context: OpaquePtr) callconv(.c) u32 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.color_depth;
}

fn stubScreenGetOrientation(_: OpaquePtr) callconv(.c) u32 {
    return 0; // landscape-primary
}

pub const stub_screen_vtable = ScreenVTable{
    .get_width = stubScreenGetWidth,
    .get_height = stubScreenGetHeight,
    .get_availWidth = stubScreenGetAvailWidth,
    .get_availHeight = stubScreenGetAvailHeight,
    .get_colorDepth = stubScreenGetColorDepth,
    .get_pixelDepth = stubScreenGetPixelDepth,
    .get_orientation = stubScreenGetOrientation,
};

// =============================================================================
// Vibration Stub
// =============================================================================

fn stubVibrate(_: OpaquePtr, _: [*]const u32, _: usize) callconv(.c) bool {
    return true;
}

pub const stub_vibration_vtable = VibrationVTable{
    .call_vibrate = stubVibrate,
};

// =============================================================================
// Battery Stub
// =============================================================================

fn stubBatteryGetLevel(user_context: OpaquePtr) callconv(.c) f64 {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.battery_level;
}

fn stubBatteryGetCharging(user_context: OpaquePtr) callconv(.c) bool {
    const ctx: *StubContext = @ptrCast(@alignCast(user_context));
    return ctx.battery_charging;
}

fn stubBatteryGetChargingTime(_: OpaquePtr) callconv(.c) f64 {
    return std.math.inf(f64);
}

fn stubBatteryGetDischargingTime(_: OpaquePtr) callconv(.c) f64 {
    return std.math.inf(f64);
}

pub const stub_battery_vtable = BatteryVTable{
    .get_level = stubBatteryGetLevel,
    .get_charging = stubBatteryGetCharging,
    .get_chargingTime = stubBatteryGetChargingTime,
    .get_dischargingTime = stubBatteryGetDischargingTime,
};

// =============================================================================
// Share Stub
// =============================================================================

fn stubShareCanShare(_: OpaquePtr) callconv(.c) bool {
    return true;
}

fn stubShareShare(_: OpaquePtr, _: ?[*]const u8, _: usize, _: ?[*]const u8, _: usize, _: ?[*]const u8, _: usize) callconv(.c) bool {
    return true;
}

pub const stub_share_vtable = ShareVTable{
    .call_canShare = stubShareCanShare,
    .call_share = stubShareShare,
};

// =============================================================================
// Permissions Stub
// =============================================================================

fn stubPermissionsQuery(_: OpaquePtr, _: [*]const u8, _: usize) callconv(.c) i32 {
    return 0; // granted
}

fn stubPermissionsRequest(_: OpaquePtr, _: [*]const u8, _: usize) callconv(.c) i32 {
    return 0; // granted
}

pub const stub_permissions_vtable = PermissionsVTable{
    .call_query = stubPermissionsQuery,
    .call_request = stubPermissionsRequest,
};

// =============================================================================
// Create Stub Backend
// =============================================================================

/// Create a PlatformBackend with all stub VTables configured.
///
/// The returned backend has ALL capabilities enabled with stub implementations.
/// The context must remain valid for the lifetime of the backend.
pub fn createStubBackend(context: *StubContext) PlatformBackend {
    return PlatformBackend{
        .user_context = context,

        // Core capabilities
        .clipboard = &stub_clipboard_vtable,
        .timer = &stub_timer_vtable,
        .network = &stub_network_vtable,
        .storage = &stub_storage_vtable,

        // DOM/Rendering
        .layout = &stub_layout_vtable,
        .ui = &stub_ui_vtable,
        .screen = &stub_screen_vtable,

        // Notifications
        .notification = &stub_notification_vtable,
        .push = &stub_push_vtable,
        .share = &stub_share_vtable,

        // File & Storage
        .filesystem = &stub_filesystem_vtable,

        // Device APIs
        .geolocation = &stub_geolocation_vtable,
        .vibration = &stub_vibration_vtable,
        .battery = &stub_battery_vtable,

        // Security
        .permissions = &stub_permissions_vtable,

        // Remaining capabilities are null (not implemented in stub)
        // bluetooth, usb, serial, hid, nfc, device_orientation, wake_lock
        // webrtc, media, audio, speech, gamepad, sensor
        // credentials, webauthn, payment
    };
}

/// Create an empty PlatformBackend with no capabilities.
/// Useful for testing code that handles missing capabilities.
pub fn createEmptyBackend() PlatformBackend {
    return PlatformBackend{};
}

// =============================================================================
// Tests
// =============================================================================

test "StubContext - init and deinit" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(i64, 0), ctx.current_time_ms);
}

test "StubContext - advance time" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    ctx.advanceTime(1000);
    try std.testing.expectEqual(@as(i64, 1000), ctx.current_time_ms);
    try std.testing.expectEqual(@as(i64, 1_000_000_000), ctx.high_res_time_ns);
}

test "StubContext - clipboard operations" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    try ctx.setClipboardText("Hello, World!");

    try std.testing.expectEqualStrings("Hello, World!", ctx.clipboard_text.?);
}

test "createStubBackend - has all core capabilities" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    const backend = createStubBackend(&ctx);

    try std.testing.expect(backend.hasCapability(.clipboard));
    try std.testing.expect(backend.hasCapability(.timer));
    try std.testing.expect(backend.hasCapability(.network));
    try std.testing.expect(backend.hasCapability(.storage));
    try std.testing.expect(backend.hasCapability(.layout));
    try std.testing.expect(backend.hasCapability(.geolocation));
}

test "createEmptyBackend - has no capabilities" {
    const backend = createEmptyBackend();

    try std.testing.expect(!backend.hasCapability(.clipboard));
    try std.testing.expect(!backend.hasCapability(.timer));
    try std.testing.expect(!backend.hasCapability(.network));
}

test "stub clipboard vtable - read/write" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    // Write text
    const result = stub_clipboard_vtable.call_writeText(&ctx, "test", 4);
    try std.testing.expectEqual(ClipboardResult.success, result);

    // Read text
    var buffer: [100]u8 = undefined;
    const len = stub_clipboard_vtable.call_readText(&ctx, &buffer, buffer.len);
    try std.testing.expectEqual(@as(i32, 4), len);
    try std.testing.expectEqualStrings("test", buffer[0..@intCast(len)]);
}

test "stub storage vtable - get/set/remove" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    // Set item
    const set_result = stub_storage_vtable.call_setItem(&ctx, "key", 3, "value", 5);
    try std.testing.expectEqual(StorageResult.success, set_result);

    // Get item
    var buffer: [100]u8 = undefined;
    const len = stub_storage_vtable.call_getItem(&ctx, "key", 3, &buffer, buffer.len);
    try std.testing.expectEqual(@as(i32, 5), len);
    try std.testing.expectEqualStrings("value", buffer[0..@intCast(len)]);

    // Length
    try std.testing.expectEqual(@as(u32, 1), stub_storage_vtable.get_length(&ctx));

    // Remove item
    const remove_result = stub_storage_vtable.call_removeItem(&ctx, "key", 3);
    try std.testing.expectEqual(StorageResult.success, remove_result);

    // Length after remove
    try std.testing.expectEqual(@as(u32, 0), stub_storage_vtable.get_length(&ctx));
}

test "stub timer vtable - get time" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    ctx.current_time_ms = 12345;
    ctx.high_res_time_ns = 12345_000_000;

    try std.testing.expectEqual(@as(i64, 12345), stub_timer_vtable.getCurrentTime(&ctx));
    try std.testing.expectEqual(@as(i64, 12345_000_000), stub_timer_vtable.getHighResTime(&ctx));
}

test "stub layout vtable - get dimensions" {
    var ctx = StubContext.init(std.testing.allocator);
    defer ctx.deinit();

    ctx.default_width = 800;
    ctx.default_height = 600;

    try std.testing.expectEqual(@as(f64, 800), stub_layout_vtable.get_offsetWidth(&ctx, null));
    try std.testing.expectEqual(@as(f64, 600), stub_layout_vtable.get_offsetHeight(&ctx, null));

    var rect: CDOMRect = undefined;
    stub_layout_vtable.call_getBoundingClientRect(&ctx, null, &rect);
    try std.testing.expectEqual(@as(f64, 800), rect.width);
    try std.testing.expectEqual(@as(f64, 600), rect.height);
}
