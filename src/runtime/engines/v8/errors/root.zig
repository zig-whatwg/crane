//! V8 Error Handling for WebIDL
//!
//! Maps Zig errors to V8 exceptions:
//! - Zig errors → V8 exceptions
//! - DOMException implementation
//! - TypeError, RangeError mapping
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## Error Mapping
//!
//! | Zig Error | V8 Exception |
//! |-----------|--------------|
//! | error.InvalidArgument | TypeError |
//! | error.OutOfRange | RangeError |
//! | error.NotImplemented | Error("Not implemented") |
//! | error.NotFound | DOMException("NotFoundError") |
//! | error.InvalidState | DOMException("InvalidStateError") |
//! | error.SyntaxError | DOMException("SyntaxError") |
//!
//! ## DOMException
//!
//! WebIDL DOMException has specific error names:
//! - IndexSizeError, HierarchyRequestError, WrongDocumentError
//! - InvalidCharacterError, NoModificationAllowedError
//! - NotFoundError, NotSupportedError, InvalidStateError
//! - SyntaxError, InvalidModificationError, NamespaceError
//! - InvalidAccessError, TypeMismatchError, SecurityError
//! - NetworkError, AbortError, URLMismatchError
//! - QuotaExceededError, TimeoutError, InvalidNodeTypeError
//! - DataCloneError, EncodingError, NotReadableError
//!
//! ## Usage
//!
//! ```zig
//! const v8_errors = @import("runtime").v8_errors;
//!
//! // Throw V8 exception from Zig error
//! const v8_exception = try v8_errors.toV8Exception(allocator, error.InvalidArgument);
//!
//! // Create DOMException
//! const dom_exc = try v8_errors.DOMException.create(allocator, "NotFoundError", "Element not found");
//! ```

const std = @import("std");
const v8_types = @import("../types/root.zig");

/// DOMException error names
///
/// Standard WebIDL DOMException error names
pub const DOMExceptionName = enum {
    IndexSizeError,
    HierarchyRequestError,
    WrongDocumentError,
    InvalidCharacterError,
    NoModificationAllowedError,
    NotFoundError,
    NotSupportedError,
    InvalidStateError,
    SyntaxError,
    InvalidModificationError,
    NamespaceError,
    InvalidAccessError,
    TypeMismatchError,
    SecurityError,
    NetworkError,
    AbortError,
    URLMismatchError,
    QuotaExceededError,
    TimeoutError,
    InvalidNodeTypeError,
    DataCloneError,
    EncodingError,
    NotReadableError,

    /// Convert to string
    pub fn toString(self: DOMExceptionName) []const u8 {
        return @tagName(self);
    }
};

/// DOMException implementation
///
/// WebIDL DOMException with name and message.
/// In real V8, this would be a v8::Exception with custom properties.
pub const DOMException = struct {
    name: DOMExceptionName,
    message: []const u8,

    /// Create DOMException
    pub fn create(
        allocator: std.mem.Allocator,
        name: DOMExceptionName,
        message: []const u8,
    ) !DOMException {
        const msg_copy = try allocator.dupe(u8, message);
        return .{
            .name = name,
            .message = msg_copy,
        };
    }

    /// Free DOMException
    pub fn deinit(self: DOMException, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }

    /// Get error code (legacy)
    ///
    /// Historical DOMException had numeric error codes.
    /// Now deprecated but some code still checks them.
    pub fn getCode(self: DOMException) u16 {
        return switch (self.name) {
            .IndexSizeError => 1,
            .HierarchyRequestError => 3,
            .WrongDocumentError => 4,
            .InvalidCharacterError => 5,
            .NoModificationAllowedError => 7,
            .NotFoundError => 8,
            .NotSupportedError => 9,
            .InvalidStateError => 11,
            .SyntaxError => 12,
            .InvalidModificationError => 13,
            .NamespaceError => 14,
            .InvalidAccessError => 15,
            .TypeMismatchError => 17,
            .SecurityError => 18,
            .NetworkError => 19,
            .AbortError => 20,
            .URLMismatchError => 21,
            .QuotaExceededError => 22,
            .TimeoutError => 23,
            .InvalidNodeTypeError => 24,
            .DataCloneError => 25,
            .EncodingError => 0,
            .NotReadableError => 0,
        };
    }
};

/// V8 Exception type
///
/// In real V8:
/// - v8::Exception::Error()
/// - v8::Exception::TypeError()
/// - v8::Exception::RangeError()
/// - v8::Exception::SyntaxError()
/// - v8::Exception::ReferenceError()
pub const V8Exception = union(enum) {
    err: []const u8,
    type_error: []const u8,
    range_error: []const u8,
    syntax_error: []const u8,
    reference_error: []const u8,
    dom_exception: DOMException,

    /// Convert to V8Value
    ///
    /// In real V8, would create v8::Exception object
    pub fn toV8Value(self: V8Exception, allocator: std.mem.Allocator) !v8_types.V8Value {
        _ = allocator;
        // Mock: return object handle representing exception
        return .{ .object = @intFromPtr(&self) };
    }
};

/// Map Zig error to V8 exception
///
/// Common error mappings:
/// - InvalidArgument → TypeError
/// - OutOfRange → RangeError
/// - NotFound → DOMException(NotFoundError)
/// - NotImplemented → Error("Not implemented")
pub fn toV8Exception(allocator: std.mem.Allocator, err: anyerror) !V8Exception {
    const err_name = @errorName(err);

    return switch (err) {
        error.InvalidArgument => .{
            .type_error = try std.fmt.allocPrint(allocator, "TypeError: {s}", .{err_name}),
        },
        error.TypeMismatch => .{
            .type_error = try std.fmt.allocPrint(allocator, "TypeError: {s}", .{err_name}),
        },
        error.WrongType => .{
            .type_error = try std.fmt.allocPrint(allocator, "TypeError: {s}", .{err_name}),
        },

        error.OutOfRange => .{
            .range_error = try std.fmt.allocPrint(allocator, "RangeError: {s}", .{err_name}),
        },
        error.Overflow => .{
            .range_error = try std.fmt.allocPrint(allocator, "RangeError: {s}", .{err_name}),
        },
        error.InvalidIndex => .{
            .range_error = try std.fmt.allocPrint(allocator, "RangeError: {s}", .{err_name}),
        },

        error.NotImplemented => .{
            .err = try allocator.dupe(u8, "Not implemented"),
        },

        error.NotFound => .{
            .dom_exception = try DOMException.create(
                allocator,
                .NotFoundError,
                "The object cannot be found",
            ),
        },

        error.InvalidState => .{
            .dom_exception = try DOMException.create(
                allocator,
                .InvalidStateError,
                "The object is in an invalid state",
            ),
        },

        error.SyntaxError => .{
            .dom_exception = try DOMException.create(
                allocator,
                .SyntaxError,
                "Syntax error",
            ),
        },

        else => .{
            .err = try std.fmt.allocPrint(allocator, "Error: {s}", .{err_name}),
        },
    };
}

/// Throw V8 exception
///
/// In real V8:
/// ```c++
/// v8::Local<v8::Value> throwException(v8::Isolate* isolate, V8Exception exc) {
///     v8::Local<v8::String> msg = v8::String::NewFromUtf8(isolate, exc.message);
///     v8::Local<v8::Value> exception = v8::Exception::Error(msg);
///     return isolate->ThrowException(exception);
/// }
/// ```
pub fn throwV8Exception(allocator: std.mem.Allocator, exception: V8Exception) !v8_types.V8Value {
    return try exception.toV8Value(allocator);
}

// Unit tests

const testing = std.testing;

test "DOMException create and deinit" {
    const exc = try DOMException.create(
        testing.allocator,
        .NotFoundError,
        "Element not found",
    );
    defer exc.deinit(testing.allocator);

    try testing.expectEqual(DOMExceptionName.NotFoundError, exc.name);
    try testing.expectEqualStrings("Element not found", exc.message);
}

test "DOMException getCode returns correct code" {
    const exc = try DOMException.create(
        testing.allocator,
        .NotFoundError,
        "Test",
    );
    defer exc.deinit(testing.allocator);

    try testing.expectEqual(@as(u16, 8), exc.getCode());
}

test "DOMExceptionName toString" {
    const name = DOMExceptionName.InvalidStateError;
    try testing.expectEqualStrings("InvalidStateError", name.toString());
}

test "toV8Exception maps InvalidArgument to TypeError" {
    const exc = try toV8Exception(testing.allocator, error.InvalidArgument);

    try testing.expect(exc == .type_error);
    testing.allocator.free(exc.type_error);
}

test "toV8Exception maps OutOfRange to RangeError" {
    const exc = try toV8Exception(testing.allocator, error.OutOfRange);

    try testing.expect(exc == .range_error);
    testing.allocator.free(exc.range_error);
}

test "toV8Exception maps NotFound to DOMException" {
    const exc = try toV8Exception(testing.allocator, error.NotFound);
    defer exc.dom_exception.deinit(testing.allocator);

    try testing.expect(exc == .dom_exception);
    try testing.expectEqual(DOMExceptionName.NotFoundError, exc.dom_exception.name);
}

test "toV8Exception maps InvalidState to DOMException" {
    const exc = try toV8Exception(testing.allocator, error.InvalidState);
    defer exc.dom_exception.deinit(testing.allocator);

    try testing.expect(exc == .dom_exception);
    try testing.expectEqual(DOMExceptionName.InvalidStateError, exc.dom_exception.name);
}

test "toV8Exception maps SyntaxError to DOMException" {
    const exc = try toV8Exception(testing.allocator, error.SyntaxError);
    defer exc.dom_exception.deinit(testing.allocator);

    try testing.expect(exc == .dom_exception);
    try testing.expectEqual(DOMExceptionName.SyntaxError, exc.dom_exception.name);
}

test "toV8Exception maps NotImplemented to Error" {
    const exc = try toV8Exception(testing.allocator, error.NotImplemented);
    defer testing.allocator.free(exc.err);

    try testing.expect(exc == .err);
    try testing.expectEqualStrings("Not implemented", exc.err);
}

test "toV8Exception maps unknown errors to generic Error" {
    const exc = try toV8Exception(testing.allocator, error.OutOfMemory);
    defer testing.allocator.free(exc.err);

    try testing.expect(exc == .err);
}

test "V8Exception toV8Value creates object" {
    const exc = V8Exception{
        .type_error = "test error",
    };

    const v8_value = try exc.toV8Value(testing.allocator);
    try testing.expect(v8_value.isObject());
}
