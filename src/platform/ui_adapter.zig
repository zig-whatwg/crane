//! UI Backend Adapter
//!
//! Provides adapters between the old UIBackend interface and the new
//! unified UIVTable (C ABI compatible) interface.
//!
//! ## Migration Path
//!
//! 1. Existing code uses `UIBackend` (Zig-native VTable) in src/html/window/ui_backend.zig
//! 2. New embedders implement `UIVTable` (C ABI compatible)
//! 3. Adapters bridge between the two interfaces

const std = @import("std");
const Allocator = std.mem.Allocator;

const vtables = @import("vtables.zig");
const UIVTable = vtables.UIVTable;
const AlertType = vtables.AlertType;
const OpaquePtr = vtables.OpaquePtr;

// =============================================================================
// UIVTable -> UIBackend Adapter
// =============================================================================

/// Adapter that wraps a UIVTable and provides UIBackend-like operations.
///
/// This allows new C ABI embedder implementations to be used with existing
/// Zig code that expects a UIBackend-like interface.
pub const UIBackendAdapter = struct {
    /// The wrapped VTable
    vtable: *const UIVTable,
    /// User context passed to VTable functions
    user_context: OpaquePtr,
    /// Allocator for internal operations
    allocator: Allocator,

    const Self = @This();

    /// Create an adapter from a UIVTable.
    pub fn init(
        allocator: Allocator,
        c_vtable: *const UIVTable,
        user_context: OpaquePtr,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .vtable = c_vtable,
            .user_context = user_context,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    // ========================================================================
    // UI Operations (matching UIBackend interface)
    // ========================================================================

    /// Show an alert dialog
    pub fn showAlert(self: *Self, message: []const u8) void {
        _ = self.vtable.call_alert(self.user_context, .alert, message.ptr, message.len);
    }

    /// Show a confirm dialog
    pub fn showConfirm(self: *Self, message: []const u8) bool {
        return self.vtable.call_alert(self.user_context, .confirm, message.ptr, message.len);
    }

    /// Show a prompt dialog
    /// Returns allocated string that caller must free, or null if cancelled.
    pub fn showPrompt(self: *Self, message: []const u8, default_value: []const u8) ?[]const u8 {
        var buffer: [4096]u8 = undefined;
        const result = self.vtable.call_prompt(
            self.user_context,
            message.ptr,
            message.len,
            if (default_value.len > 0) default_value.ptr else null,
            default_value.len,
            &buffer,
            buffer.len,
        );

        if (result < 0) return null;
        if (result == 0) return "";

        // Copy result to allocated memory
        const len: usize = @intCast(result);
        return self.allocator.dupe(u8, buffer[0..len]) catch null;
    }

    /// Show print dialog
    pub fn showPrint(self: *Self) void {
        self.vtable.call_print(self.user_context);
    }

    /// Free a string returned by showPrompt
    pub fn freeString(self: *Self, str: []const u8) void {
        self.allocator.free(str);
    }

    /// Focus the window
    pub fn focus(self: *Self) void {
        self.vtable.call_focus(self.user_context);
    }

    /// Blur the window
    pub fn blur(self: *Self) void {
        self.vtable.call_blur(self.user_context);
    }
};

// =============================================================================
// UIBackend -> UIVTable Adapter
// =============================================================================

/// Context for UIVTable that provides in-memory stub implementation.
/// This is useful for testing and headless environments.
pub const StubUIContext = struct {
    allocator: Allocator,
    /// Default return value for confirm dialogs
    confirm_result: bool,
    /// Default return value for prompt dialogs (null = cancelled)
    prompt_result: ?[]const u8,
    /// Record of operations for testing
    alert_count: usize,
    confirm_count: usize,
    prompt_count: usize,
    print_count: usize,
    focus_count: usize,
    blur_count: usize,
    /// Last message shown
    last_message: ?[]const u8,

    const Self = @This();

    /// Create a new stub context
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .allocator = allocator,
            .confirm_result = false,
            .prompt_result = null,
            .alert_count = 0,
            .confirm_count = 0,
            .prompt_count = 0,
            .print_count = 0,
            .focus_count = 0,
            .blur_count = 0,
            .last_message = null,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.last_message) |msg| {
            self.allocator.free(msg);
        }
        self.allocator.destroy(self);
    }

    /// Set the confirm result
    pub fn setConfirmResult(self: *Self, result: bool) void {
        self.confirm_result = result;
    }

    /// Set the prompt result
    pub fn setPromptResult(self: *Self, result: ?[]const u8) void {
        self.prompt_result = result;
    }

    /// Get the VTable pointer
    pub fn getVTable() *const UIVTable {
        return &vtable_impl;
    }

    /// Get the user context pointer
    pub fn getUserContext(self: *Self) OpaquePtr {
        return self;
    }

    /// Reset counters
    pub fn resetCounters(self: *Self) void {
        self.alert_count = 0;
        self.confirm_count = 0;
        self.prompt_count = 0;
        self.print_count = 0;
        self.focus_count = 0;
        self.blur_count = 0;
    }

    const vtable_impl = UIVTable{
        .call_alert = alertImpl,
        .call_prompt = promptImpl,
        .call_focus = focusImpl,
        .call_blur = blurImpl,
        .call_print = printImpl,
    };

    fn alertImpl(
        user_context: OpaquePtr,
        alertType: AlertType,
        message: [*]const u8,
        messageLen: usize,
    ) callconv(.c) bool {
        const self: *Self = @ptrCast(@alignCast(user_context));

        // Store last message
        if (self.last_message) |old| {
            self.allocator.free(old);
        }
        self.last_message = self.allocator.dupe(u8, message[0..messageLen]) catch null;

        switch (alertType) {
            .alert => {
                self.alert_count += 1;
                return true; // Alert always returns true
            },
            .confirm => {
                self.confirm_count += 1;
                return self.confirm_result;
            },
            .prompt => {
                // Prompt uses call_prompt, not call_alert
                return false;
            },
        }
    }

    fn promptImpl(
        user_context: OpaquePtr,
        message: [*]const u8,
        messageLen: usize,
        _: ?[*]const u8, // defaultValue
        _: usize, // defaultLen
        buffer: ?[*]u8,
        bufferSize: usize,
    ) callconv(.c) i32 {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.prompt_count += 1;

        // Store last message
        if (self.last_message) |old| {
            self.allocator.free(old);
        }
        self.last_message = self.allocator.dupe(u8, message[0..messageLen]) catch null;

        // Return configured result
        if (self.prompt_result) |result| {
            if (buffer != null) {
                const copy_len = @min(bufferSize, result.len);
                @memcpy(buffer.?[0..copy_len], result[0..copy_len]);
                return @intCast(copy_len);
            }
            return @intCast(result.len);
        }

        return -1; // Cancelled
    }

    fn focusImpl(user_context: OpaquePtr) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.focus_count += 1;
    }

    fn blurImpl(user_context: OpaquePtr) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.blur_count += 1;
    }

    fn printImpl(user_context: OpaquePtr) callconv(.c) void {
        const self: *Self = @ptrCast(@alignCast(user_context));
        self.print_count += 1;
    }
};
