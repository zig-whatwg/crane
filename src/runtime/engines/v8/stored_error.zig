//! # Type-Safe Stored Error
//!
//! This module provides `StoredError` - a type-safe replacement for `stored_error: ?*anyopaque`
//! used throughout stream implementations.
//!
//! ## Problem Statement
//!
//! Stream implementations store errors as `?*anyopaque`, which:
//! - Loses type information (is it a V8 Global handle? A Zig error? A string?)
//! - Requires manual memory management with no compile-time safety
//! - Can lead to use-after-free if Global handles aren't disposed
//!
//! ## Solution
//!
//! `StoredError` is a tagged union that explicitly represents:
//! - No error (`.none`)
//! - JavaScript exception stored as V8 Global handle (`.js_exception`)
//! - Zig error code (`.zig_error`)
//! - Error message string (`.message`)
//!
//! ## Usage
//!
//! ```zig
//! const StoredError = @import("stored_error.zig").StoredError;
//!
//! pub const InternalState = struct {
//!     stored_error: StoredError = .none,
//!     // ...
//!
//!     pub fn deinit(self: *InternalState) void {
//!         self.stored_error.dispose();
//!     }
//! };
//!
//! // Store a JavaScript exception
//! internal.stored_error.storeGlobal(global_handle);
//!
//! // Store a Zig error
//! internal.stored_error.storeZigError(error.InvalidState);
//!
//! // Check if there's an error
//! if (internal.stored_error.hasError()) {
//!     // Handle error
//! }
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const GlobalHandle = @import("global_handles.zig").GlobalHandle;
const JSValue = @import("js_value.zig").JSValue;

/// Type-safe stored error replacement for `?*anyopaque`
///
/// Used in stream implementations to store errors that occur during
/// async operations. Properly manages V8 Global handle lifetimes.
pub const StoredError = union(enum) {
    /// No error stored
    none: void,

    /// JavaScript exception stored as V8 Global handle
    /// The Global handle must be disposed when the error is cleared
    js_exception: GlobalHandle,

    /// Zig error code (for internal errors)
    zig_error: anyerror,

    /// Error message string (for simple string errors)
    /// The string is NOT owned - caller must ensure it lives long enough
    message: []const u8,

    // ========================================================================
    // Storage Methods
    // ========================================================================

    /// Store a JavaScript exception from a V8 Global handle
    ///
    /// Takes ownership of the Global handle. The handle will be disposed
    /// when `dispose()` or `clear()` is called.
    pub fn storeGlobal(self: *StoredError, handle: GlobalHandle) void {
        self.dispose(); // Clean up any previous error
        self.* = .{ .js_exception = handle };
    }

    /// Store a JavaScript exception from a raw V8 Global pointer
    ///
    /// Creates a GlobalHandle wrapper around the raw pointer.
    /// The handle will be disposed when `dispose()` or `clear()` is called.
    pub fn storeGlobalPtr(self: *StoredError, ptr: *anyopaque) void {
        self.dispose();
        self.* = .{ .js_exception = .{ .ptr = ptr } };
    }

    /// Store a JavaScript value as an error (creates Global handle if needed)
    ///
    /// If the JSValue is a local handle, this will create a Global handle.
    /// If it's already a Global handle, ownership transfers to StoredError.
    /// Primitives and null/undefined are converted to message strings.
    pub fn storeJSValue(self: *StoredError, value: JSValue, isolate: *v8.Isolate) !void {
        self.dispose();

        switch (value) {
            .undefined_value, .null_value => {
                self.* = .{ .message = "undefined error" };
            },
            .boolean => |b| {
                self.* = .{ .message = if (b) "true" else "false" };
            },
            .number => {
                self.* = .{ .message = "numeric error" };
            },
            .string => |s| {
                self.* = .{ .message = s.data };
            },
            .global => |g| {
                self.* = .{ .js_exception = g };
            },
            .instance => {
                self.* = .{ .message = "instance error" };
            },
            .local => |l| {
                // Convert Local to Global for safe storage
                const global_ptr = v8.v8_Value_ToGlobal(isolate, l.ptr) orelse {
                    return error.GlobalHandleCreationFailed;
                };
                self.* = .{ .js_exception = .{ .ptr = global_ptr } };
            },
        }
    }

    /// Store a Zig error code
    pub fn storeZigError(self: *StoredError, err: anyerror) void {
        self.dispose();
        self.* = .{ .zig_error = err };
    }

    /// Store an error message string
    ///
    /// NOTE: The string is NOT owned - caller must ensure it lives long enough.
    /// Use for static strings or strings with known lifetimes.
    pub fn storeMessage(self: *StoredError, msg: []const u8) void {
        self.dispose();
        self.* = .{ .message = msg };
    }

    /// Store from a raw anyopaque pointer (legacy compatibility)
    ///
    /// This tries to interpret the pointer as a V8 Global handle.
    /// Use only for transitional code - prefer type-safe methods.
    pub fn storeRawPtr(self: *StoredError, ptr: ?*anyopaque) void {
        self.dispose();
        if (ptr) |p| {
            // Assume it's a V8 Global handle (legacy behavior)
            self.* = .{ .js_exception = .{ .ptr = p } };
        } else {
            self.* = .none;
        }
    }

    // ========================================================================
    // Query Methods
    // ========================================================================

    /// Check if an error is stored
    pub fn hasError(self: StoredError) bool {
        return self != .none;
    }

    /// Check if this is a JavaScript exception
    pub fn isJSException(self: StoredError) bool {
        return self == .js_exception;
    }

    /// Check if this is a Zig error
    pub fn isZigError(self: StoredError) bool {
        return self == .zig_error;
    }

    /// Check if this is a message error
    pub fn isMessage(self: StoredError) bool {
        return self == .message;
    }

    // ========================================================================
    // Extraction Methods
    // ========================================================================

    /// Get the Global handle if this is a JS exception
    pub fn getGlobalHandle(self: StoredError) ?GlobalHandle {
        return switch (self) {
            .js_exception => |g| g,
            else => null,
        };
    }

    /// Get the raw Global pointer if this is a JS exception
    pub fn getGlobalPtr(self: StoredError) ?*anyopaque {
        return switch (self) {
            .js_exception => |g| g.ptr,
            else => null,
        };
    }

    /// Get the Zig error if this is a Zig error
    pub fn getZigError(self: StoredError) ?anyerror {
        return switch (self) {
            .zig_error => |e| e,
            else => null,
        };
    }

    /// Get the error message if this is a message error
    pub fn getMessage(self: StoredError) ?[]const u8 {
        return switch (self) {
            .message => |m| m,
            else => null,
        };
    }

    /// Convert to V8 Value for passing back to JavaScript
    ///
    /// Returns the stored V8 value, or creates an Error object for Zig errors/messages.
    pub fn toV8(self: StoredError, isolate: *v8.Isolate) ?*v8.Value {
        return switch (self) {
            .none => null,
            .js_exception => |g| v8.v8_Global_Get(isolate, g.ptr),
            .zig_error => |e| blk: {
                // Create a V8 Error from the Zig error name
                const err_name = @errorName(e);
                const str = v8.v8_String_NewFromUtf8(isolate, err_name.ptr, @intCast(err_name.len)) orelse {
                    break :blk v8.v8_Undefined(isolate);
                };
                break :blk v8.v8_Error_New(isolate, @ptrCast(str));
            },
            .message => |m| blk: {
                const str = v8.v8_String_NewFromUtf8(isolate, m.ptr, @intCast(m.len)) orelse {
                    break :blk v8.v8_Undefined(isolate);
                };
                break :blk v8.v8_Error_New(isolate, @ptrCast(str));
            },
        };
    }

    /// Convert to raw anyopaque pointer (legacy compatibility)
    ///
    /// Returns the Global handle pointer for JS exceptions, null otherwise.
    /// Use only for transitional code.
    pub fn toRawPtr(self: StoredError) ?*anyopaque {
        return switch (self) {
            .js_exception => |g| g.ptr,
            else => null,
        };
    }

    // ========================================================================
    // Lifecycle Methods
    // ========================================================================

    /// Clear the stored error without disposing V8 handles
    ///
    /// Use when ownership of the Global handle is transferred elsewhere.
    pub fn clear(self: *StoredError) void {
        self.* = .none;
    }

    /// Dispose any owned resources and clear
    ///
    /// This MUST be called when done with the error, or Global handles will leak!
    pub fn dispose(self: *StoredError) void {
        switch (self.*) {
            .js_exception => |g| {
                v8.v8_Global_Dispose(g.ptr);
            },
            else => {},
        }
        self.* = .none;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "StoredError none" {
    var err = StoredError{ .none = {} };
    try std.testing.expect(!err.hasError());
    try std.testing.expect(!err.isJSException());
    try std.testing.expect(!err.isZigError());
}

test "StoredError zig_error" {
    var err = StoredError{ .none = {} };
    err.storeZigError(error.InvalidState);

    try std.testing.expect(err.hasError());
    try std.testing.expect(err.isZigError());
    try std.testing.expect(!err.isJSException());
    try std.testing.expectEqual(error.InvalidState, err.getZigError().?);
}

test "StoredError message" {
    var err = StoredError{ .none = {} };
    err.storeMessage("test error message");

    try std.testing.expect(err.hasError());
    try std.testing.expect(err.isMessage());
    try std.testing.expectEqualStrings("test error message", err.getMessage().?);
}

test "StoredError clear" {
    var err = StoredError{ .none = {} };
    err.storeZigError(error.OutOfMemory);

    try std.testing.expect(err.hasError());

    err.clear();
    try std.testing.expect(!err.hasError());
}

test "StoredError storeRawPtr null" {
    var err = StoredError{ .none = {} };
    err.storeRawPtr(null);

    try std.testing.expect(!err.hasError());
}
