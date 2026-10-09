//! Clipboard Backend Adapter
//!
//! Provides adapters between the old ClipboardBackend interface and the new
//! unified ClipboardVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `ClipboardBackend` (Zig-native VTable)
//! 2. New embedders implement `ClipboardVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces
//!
//! ## Usage
//!
//! ```zig
//! // Wrap old ClipboardBackend for new unified system
//! const vtable = ClipboardVTableAdapter.fromBackend(old_backend);
//!
//! // Wrap new ClipboardVTable for existing code
//! const backend = ClipboardBackendAdapter.fromVTable(vtable, user_context);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const ClipboardVTable = vtables.ClipboardVTable;
const ClipboardResult = vtables.ClipboardResult;
const OpaquePtr = vtables.OpaquePtr;

const clipboard_backend = @import("clipboard_backend.zig");
const ClipboardBackend = clipboard_backend.ClipboardBackend;
const OldClipboardResult = clipboard_backend.ClipboardResult;
const ClipboardItem = clipboard_backend.ClipboardItem;

// =============================================================================
// ClipboardVTable -> ClipboardBackend Adapter
// =============================================================================

/// Adapter that wraps a ClipboardVTable and provides a ClipboardBackend interface.
///
/// This allows new C ABI embedder implementations to be used with existing
/// Zig code that expects a ClipboardBackend.
pub const ClipboardBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const ClipboardVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter from a ClipboardVTable.
    pub fn init(
        allocator: Allocator,
        vtable: *const ClipboardVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = vtable,
            .user_context = user_context,
            .allocator = allocator,
        };
        return self;
    }

    /// Get a ClipboardBackend interface.
    pub fn backend(self: *Self) ClipboardBackend {
        return ClipboardBackend{
            .ptr = self,
            .vtable = &backend_vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    const backend_vtable = ClipboardBackend.VTable{
        .readText = readTextImpl,
        .writeText = writeTextImpl,
        .readHtml = readHtmlImpl,
        .writeHtml = writeHtmlImpl,
        .read = readImpl,
        .write = writeImpl,
        .canRead = canReadImpl,
        .canWrite = canWriteImpl,
        .hasContent = hasContentImpl,
        .clear = clearImpl,
        .deinit = deinitImpl,
    };

    fn readTextImpl(ptr: *anyopaque, allocator: Allocator) ?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // First call to get size
        const size = self.vtable.call_readText(self.user_context, null, 0);
        if (size <= 0) return null;

        // Allocate buffer
        const buffer = allocator.alloc(u8, @intCast(size)) catch return null;

        // Second call to get data
        const result = self.vtable.call_readText(self.user_context, buffer.ptr, buffer.len);
        if (result < 0) {
            allocator.free(buffer);
            return null;
        }

        return buffer[0..@intCast(result)];
    }

    fn writeTextImpl(ptr: *anyopaque, text: []const u8) OldClipboardResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const result = self.vtable.call_writeText(self.user_context, text.ptr, text.len);
        return convertResult(result);
    }

    fn readHtmlImpl(ptr: *anyopaque, allocator: Allocator) ?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));

        // First call to get size
        const size = self.vtable.readHtml(self.user_context, null, 0);
        if (size <= 0) return null;

        // Allocate buffer
        const buffer = allocator.alloc(u8, @intCast(size)) catch return null;

        // Second call to get data
        const result = self.vtable.readHtml(self.user_context, buffer.ptr, buffer.len);
        if (result < 0) {
            allocator.free(buffer);
            return null;
        }

        return buffer[0..@intCast(result)];
    }

    fn writeHtmlImpl(ptr: *anyopaque, html: []const u8, plain_text: ?[]const u8) OldClipboardResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const result = self.vtable.writeHtml(
            self.user_context,
            html.ptr,
            html.len,
            if (plain_text) |pt| pt.ptr else null,
            if (plain_text) |pt| pt.len else 0,
        );
        return convertResult(result);
    }

    fn readImpl(_: *anyopaque, _: Allocator) ?ClipboardItem {
        // Complex multi-format read not supported through C ABI adapter
        // Would need additional VTable methods
        return null;
    }

    fn writeImpl(_: *anyopaque, _: []const ClipboardItem.FormatData) OldClipboardResult {
        // Complex multi-format write not supported through C ABI adapter
        return .error_unknown;
    }

    fn canReadImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.canRead(self.user_context);
    }

    fn canWriteImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.canWrite(self.user_context);
    }

    fn hasContentImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.vtable.hasContent(self.user_context);
    }

    fn clearImpl(ptr: *anyopaque) OldClipboardResult {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const result = self.vtable.clear(self.user_context);
        return convertResult(result);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn convertResult(result: ClipboardResult) OldClipboardResult {
        return switch (result) {
            .success => .success,
            .permission_denied => .permission_denied,
            .not_available => .not_available,
            .empty => .empty,
            .error_unknown => .error_unknown,
        };
    }
};

// =============================================================================
// ClipboardBackend -> ClipboardVTable Adapter
// =============================================================================

/// Context for ClipboardVTable that wraps a ClipboardBackend.
///
/// This allows existing Zig ClipboardBackend implementations (like StubClipboardBackend)
/// to be used with the new unified PlatformBackend system.
pub const ClipboardVTableAdapter = struct {
    /// The wrapped backend
    backend: ClipboardBackend,
    /// Allocator for operations that need allocation
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter context.
    pub fn init(allocator: Allocator, backend: ClipboardBackend) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .backend = backend,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Get a pointer to the static VTable.
    pub fn getVTable() *const ClipboardVTable {
        return &vtable;
    }

    /// Get the user context pointer (pass this to PlatformBackend.user_context).
    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    const vtable = ClipboardVTable{
        .call_readText = readTextImpl,
        .call_writeText = writeTextImpl,
        .readHtml = readHtmlImpl,
        .writeHtml = writeHtmlImpl,
        .canRead = canReadImpl,
        .canWrite = canWriteImpl,
        .hasContent = hasContentImpl,
        .clear = clearImpl,
    };

    fn readTextImpl(user_context: OpaquePtr, buffer: ?[*]u8, buffer_size: usize) callconv(.c) i32 {
        const self: *Self = @ptrCast(@alignCast(user_context));

        // Read text from backend
        const text = self.backend.readText(self.allocator) orelse return @intFromEnum(ClipboardResult.empty);
        defer self.allocator.free(text);

        // If buffer is null, return required size
        if (buffer == null) {
            return @intCast(text.len);
        }

        // Copy to buffer
        const copy_len = @min(buffer_size, text.len);
        @memcpy(buffer.?[0..copy_len], text[0..copy_len]);
        return @intCast(copy_len);
    }

    fn writeTextImpl(user_context: OpaquePtr, text: [*]const u8, text_len: usize) callconv(.c) ClipboardResult {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const result = self.backend.writeText(text[0..text_len]);
        return convertOldResult(result);
    }

    fn readHtmlImpl(user_context: OpaquePtr, buffer: ?[*]u8, buffer_size: usize) callconv(.c) i32 {
        const self: *Self = @ptrCast(@alignCast(user_context));

        const html = self.backend.readHtml(self.allocator) orelse return @intFromEnum(ClipboardResult.empty);
        defer self.allocator.free(html);

        if (buffer == null) {
            return @intCast(html.len);
        }

        const copy_len = @min(buffer_size, html.len);
        @memcpy(buffer.?[0..copy_len], html[0..copy_len]);
        return @intCast(copy_len);
    }

    fn writeHtmlImpl(
        user_context: OpaquePtr,
        html: [*]const u8,
        html_len: usize,
        plain_text: ?[*]const u8,
        plain_text_len: usize,
    ) callconv(.c) ClipboardResult {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const pt: ?[]const u8 = if (plain_text) |p| p[0..plain_text_len] else null;
        const result = self.backend.writeHtml(html[0..html_len], pt);
        return convertOldResult(result);
    }

    fn canReadImpl(user_context: OpaquePtr) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.canRead();
    }

    fn canWriteImpl(user_context: OpaquePtr) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.canWrite();
    }

    fn hasContentImpl(user_context: OpaquePtr) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));
        return self.backend.hasContent();
    }

    fn clearImpl(user_context: OpaquePtr) callconv(.c) ClipboardResult {
        const self: *Self = @ptrCast(@alignCast(user_context));
        const result = self.backend.clear();
        return convertOldResult(result);
    }

    fn convertOldResult(result: OldClipboardResult) ClipboardResult {
        return switch (result) {
            .success => .success,
            .permission_denied => .permission_denied,
            .not_available => .not_available,
            .empty => .empty,
            .error_unknown => .error_unknown,
        };
    }
};

// =============================================================================
// Convenience Functions
// =============================================================================

/// Create a ClipboardVTable adapter from a StubClipboardBackend.
///
/// This is a common use case for testing.
pub fn createStubVTableAdapter(
    allocator: Allocator,
    stub: *clipboard_backend.StubClipboardBackend,
) !*ClipboardVTableAdapter {
    return ClipboardVTableAdapter.init(allocator, stub.backend());
}

// =============================================================================
// Tests
// =============================================================================

test "ClipboardVTableAdapter - wraps StubClipboardBackend" {
    const allocator = std.testing.allocator;

    // Create stub backend
    const stub = try clipboard_backend.StubClipboardBackend.init(allocator);
    defer stub.deinit();

    // Create adapter
    const adapter = try ClipboardVTableAdapter.init(allocator, stub.backend());
    defer adapter.deinit();

    // Get VTable
    const vtable = ClipboardVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Test write
    const result = vtable.call_writeText(ctx, "Hello", 5);
    try std.testing.expectEqual(ClipboardResult.success, result);

    // Test read (get size first)
    const size = vtable.call_readText(ctx, null, 0);
    try std.testing.expectEqual(@as(i32, 5), size);

    // Test read (get data)
    var buffer: [10]u8 = undefined;
    const read_len = vtable.call_readText(ctx, &buffer, buffer.len);
    try std.testing.expectEqual(@as(i32, 5), read_len);
    try std.testing.expectEqualStrings("Hello", buffer[0..5]);

    // Test permissions
    try std.testing.expect(vtable.canRead(ctx));
    try std.testing.expect(vtable.canWrite(ctx));
}

test "ClipboardBackendAdapter - wraps ClipboardVTable" {
    const allocator = std.testing.allocator;

    // Create stub backend first (to get a VTable)
    const stub = try clipboard_backend.StubClipboardBackend.init(allocator);
    defer stub.deinit();

    // Create VTable adapter
    const vtable_adapter = try ClipboardVTableAdapter.init(allocator, stub.backend());
    defer vtable_adapter.deinit();

    // Create backend adapter from VTable
    const backend_adapter = try ClipboardBackendAdapter.init(
        allocator,
        ClipboardVTableAdapter.getVTable(),
        vtable_adapter.getUserContext(),
    );
    defer backend_adapter.deinit();

    // Get ClipboardBackend interface
    const backend = backend_adapter.backend();

    // Test write
    try std.testing.expectEqual(OldClipboardResult.success, backend.writeText("Test"));

    // Test read
    const text = backend.readText(allocator);
    try std.testing.expect(text != null);
    defer allocator.free(text.?);
    try std.testing.expectEqualStrings("Test", text.?);

    // Test permissions
    try std.testing.expect(backend.canRead());
    try std.testing.expect(backend.canWrite());
}

test "ClipboardVTableAdapter - HTML operations" {
    const allocator = std.testing.allocator;

    const stub = try clipboard_backend.StubClipboardBackend.init(allocator);
    defer stub.deinit();

    const adapter = try ClipboardVTableAdapter.init(allocator, stub.backend());
    defer adapter.deinit();

    const vtable = ClipboardVTableAdapter.getVTable();
    const ctx = adapter.getUserContext();

    // Write HTML
    const html = "<b>Bold</b>";
    const plain = "Bold";
    const result = vtable.writeHtml(ctx, html.ptr, html.len, plain.ptr, plain.len);
    try std.testing.expectEqual(ClipboardResult.success, result);

    // Read HTML
    var html_buffer: [20]u8 = undefined;
    const html_len = vtable.readHtml(ctx, &html_buffer, html_buffer.len);
    try std.testing.expect(html_len > 0);
    try std.testing.expectEqualStrings("<b>Bold</b>", html_buffer[0..@intCast(html_len)]);

    // Read plain text
    var text_buffer: [10]u8 = undefined;
    const text_len = vtable.call_readText(ctx, &text_buffer, text_buffer.len);
    try std.testing.expect(text_len > 0);
    try std.testing.expectEqualStrings("Bold", text_buffer[0..@intCast(text_len)]);
}
