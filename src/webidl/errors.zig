//! WebIDL Error Handling
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-exceptions
//!
//! This module implements WebIDL exception types and error propagation:
//! - Simple exceptions (TypeError, RangeError, SyntaxError, URIError)
//! - DOMException with 25+ standardized error names
//! - ErrorResult for error propagation in operations
//!
//! # DOMException
//!
//! DOMException is the primary exception type used by Web APIs. Each DOMException
//! has a **name** (identifying the error type) and an optional **message**
//! (describing what went wrong).
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-DOMException
//!
//! # Simple Exceptions
//!
//! Simple exceptions correspond to JavaScript built-in Error types:
//! - TypeError - Type mismatch or invalid argument
//! - RangeError - Numeric value out of range
//! - SyntaxError - Parse error (not to be confused with DOMException "SyntaxError")
//! - URIError - Invalid URI encoding
//!
//! Note: JavaScript SyntaxError is reserved for the parser. Use DOMException
//! "SyntaxError" for Web API parsing errors.
//!
//! # Usage
//!
//! ```zig
//! const webidl = @import("webidl");
//!
//! // Create and throw a DOMException
//! var result = webidl.errors.ErrorResult{};
//! result.throwDOMException("NotFoundError", "Element not found");
//!
//! if (result.hasFailed()) {
//!     // Handle the error
//!     const exception = result.getException() orelse unreachable;
//!     std.debug.print("Error: {s}\n", .{exception.message});
//! }
//!
//! // Throw a simple TypeError
//! result.throwTypeError("Expected a number");
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// DOMException represents a Web API error with a name and message.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-DOMException
///
/// Each DOMException has:
/// - **name**: One of the standardized error names (see DOMExceptionName)
/// - **message**: Human-readable description of what went wrong
/// - **code**: Legacy numeric error code (deprecated, use name instead)
///
/// Example:
/// ```zig
/// const exception = DOMException.create(
///     allocator,
///     .NotFoundError,
///     "The requested element was not found in the document"
/// );
/// defer exception.deinit(allocator);
/// ```
pub const DOMException = struct {
    name: []const u8,
    message: []const u8,
    code: u16,

    /// Creates a new DOMException with the given name and message.
    ///
    /// The message string is duplicated and must be freed with deinit().
    pub fn create(
        allocator: Allocator,
        name: DOMExceptionName,
        message: []const u8,
    ) !DOMException {
        const name_str = name.toString();
        const message_copy = try allocator.dupe(u8, message);
        errdefer allocator.free(message_copy);

        return DOMException{
            .name = name_str,
            .message = message_copy,
            .code = name.toCode(),
        };
    }

    /// Frees the message string allocated during creation.
    pub fn deinit(self: *DOMException, allocator: Allocator) void {
        allocator.free(self.message);
    }
};

/// DOMException names standardized by the WebIDL specification.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-DOMException-error-names
///
/// Each name has a specific meaning and legacy numeric code. Some names are
/// deprecated but kept for backwards compatibility.
///
/// Note: When throwing errors, prefer specific names like NotFoundError or
/// InvalidStateError over deprecated names like InvalidAccessError.
pub const DOMExceptionName = enum {
    // Deprecated - use RangeError instead
    IndexSizeError,

    HierarchyRequestError,
    WrongDocumentError,
    InvalidCharacterError,
    NoModificationAllowedError,
    NotFoundError,
    NotSupportedError,
    InUseAttributeError,
    InvalidStateError,

    // Common API errors
    SyntaxError,
    InvalidModificationError,
    NamespaceError,

    // Deprecated - use TypeError, NotSupportedError, or NotAllowedError instead
    InvalidAccessError,

    // Deprecated - use TypeError instead
    TypeMismatchError,

    SecurityError,
    NetworkError,
    AbortError,

    // Deprecated
    URLMismatchError,

    // Note: QuotaExceededError is now a DOMException-derived interface
    // Use the specific QuotaExceededError type instead
    QuotaExceededError,

    TimeoutError,
    InvalidNodeTypeError,
    DataCloneError,
    EncodingError,
    NotReadableError,
    UnknownError,
    ConstraintError,
    DataError,
    TransactionInactiveError,
    ReadOnlyError,
    VersionError,
    OperationError,
    NotAllowedError,
    OptOutError,

    /// Converts the DOMException name to its string representation.
    pub fn toString(self: DOMExceptionName) []const u8 {
        return switch (self) {
            .IndexSizeError => "IndexSizeError",
            .HierarchyRequestError => "HierarchyRequestError",
            .WrongDocumentError => "WrongDocumentError",
            .InvalidCharacterError => "InvalidCharacterError",
            .NoModificationAllowedError => "NoModificationAllowedError",
            .NotFoundError => "NotFoundError",
            .NotSupportedError => "NotSupportedError",
            .InUseAttributeError => "InUseAttributeError",
            .InvalidStateError => "InvalidStateError",
            .SyntaxError => "SyntaxError",
            .InvalidModificationError => "InvalidModificationError",
            .NamespaceError => "NamespaceError",
            .InvalidAccessError => "InvalidAccessError",
            .TypeMismatchError => "TypeMismatchError",
            .SecurityError => "SecurityError",
            .NetworkError => "NetworkError",
            .AbortError => "AbortError",
            .URLMismatchError => "URLMismatchError",
            .QuotaExceededError => "QuotaExceededError",
            .TimeoutError => "TimeoutError",
            .InvalidNodeTypeError => "InvalidNodeTypeError",
            .DataCloneError => "DataCloneError",
            .EncodingError => "EncodingError",
            .NotReadableError => "NotReadableError",
            .UnknownError => "UnknownError",
            .ConstraintError => "ConstraintError",
            .DataError => "DataError",
            .TransactionInactiveError => "TransactionInactiveError",
            .ReadOnlyError => "ReadOnlyError",
            .VersionError => "VersionError",
            .OperationError => "OperationError",
            .NotAllowedError => "NotAllowedError",
            .OptOutError => "OptOutError",
        };
    }

    /// Returns the legacy numeric error code for this DOMException name.
    ///
    /// Note: These codes are deprecated. Always use the name property to
    /// identify exception types. The code property exists only for legacy
    /// compatibility.
    pub fn toCode(self: DOMExceptionName) u16 {
        return switch (self) {
            .IndexSizeError => 1,
            .HierarchyRequestError => 3,
            .WrongDocumentError => 4,
            .InvalidCharacterError => 5,
            .NoModificationAllowedError => 7,
            .NotFoundError => 8,
            .NotSupportedError => 9,
            .InUseAttributeError => 10,
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
            // New exception names have no legacy code
            .EncodingError,
            .NotReadableError,
            .UnknownError,
            .ConstraintError,
            .DataError,
            .TransactionInactiveError,
            .ReadOnlyError,
            .VersionError,
            .OperationError,
            .NotAllowedError,
            .OptOutError,
            => 0,
        };
    }
};

/// Simple exception types corresponding to JavaScript built-in errors.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-exceptions
///
/// These exceptions map directly to JavaScript Error constructors:
/// - TypeError → new TypeError()
/// - RangeError → new RangeError()
/// - SyntaxError → new SyntaxError() (reserved for parser errors)
/// - URIError → new URIError()
///
/// Note: JavaScript SyntaxError is reserved for the JavaScript parser.
/// For Web API parsing errors, use DOMException with name "SyntaxError" instead.
pub const SimpleException = enum {
    /// Type mismatch or invalid argument type.
    /// Example: Passing a string where a number is required.
    TypeError,

    /// Numeric value out of valid range.
    /// Example: Array index < 0 or clamped value exceeds bounds.
    RangeError,

    /// JavaScript syntax error (reserved for parser).
    /// Note: Web APIs should use DOMException "SyntaxError" instead.
    SyntaxError,

    /// Invalid URI encoding.
    /// Example: Malformed percent-encoded string.
    URIError,

    pub fn toString(self: SimpleException) []const u8 {
        return switch (self) {
            .TypeError => "TypeError",
            .RangeError => "RangeError",
            .SyntaxError => "SyntaxError",
            .URIError => "URIError",
        };
    }
};

/// Exception type discriminator for ErrorResult.
pub const Exception = union(enum) {
    /// A simple JavaScript exception (TypeError, RangeError, etc.)
    simple: struct {
        type: SimpleException,
        message: []const u8,
    },

    /// A DOMException with name, message, and legacy code
    dom: DOMException,

    /// Create a TypeError exception from a string message
    pub fn typeError(allocator: Allocator, message: []const u8) !Exception {
        const msg_copy = try allocator.dupe(u8, message);
        return .{
            .simple = .{
                .type = .TypeError,
                .message = msg_copy,
            },
        };
    }

    /// Create a simple exception from a string message (defaults to TypeError)
    pub fn fromString(allocator: Allocator, message: []const u8) !Exception {
        return typeError(allocator, message);
    }

    /// Convert exception to a string message for display
    pub fn toString(self: Exception) []const u8 {
        return switch (self) {
            .simple => |s| s.message,
            .dom => |d| d.message,
        };
    }

    /// Frees any allocated memory in the exception.
    pub fn deinit(self: *Exception, allocator: Allocator) void {
        switch (self.*) {
            .simple => |simple| {
                allocator.free(simple.message);
            },
            .dom => |*dom| {
                dom.deinit(allocator);
            },
        }
    }
};

/// ErrorResult is used to propagate errors from WebIDL operations.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-exceptions
///
/// ErrorResult follows the pattern used by browser implementations (Chromium's
/// ErrorResult, Firefox's ErrorResult) to propagate exceptions without using
/// Zig's error return mechanism, which allows for more JavaScript-like exception
/// semantics.
///
/// # Usage Pattern
///
/// ```zig
/// fn someOperation(arg: i32, result: *ErrorResult) void {
///     if (arg < 0) {
///         result.throwTypeError("Argument must be non-negative");
///         return;
///     }
///     // ... operation logic
/// }
///
/// var result = ErrorResult{};
/// someOperation(-5, &result);
/// if (result.hasFailed()) {
///     // Handle error
/// }
/// ```
pub const ErrorResult = struct {
    exception: ?Exception = null,

    /// Throws a simple TypeError exception.
    ///
    /// The message string is duplicated and stored in the ErrorResult.
    pub fn throwTypeError(self: *ErrorResult, allocator: Allocator, message: []const u8) !void {
        const message_copy = try allocator.dupe(u8, message);
        self.exception = .{
            .simple = .{
                .type = .TypeError,
                .message = message_copy,
            },
        };
    }

    /// Throws a simple RangeError exception.
    ///
    /// The message string is duplicated and stored in the ErrorResult.
    pub fn throwRangeError(self: *ErrorResult, allocator: Allocator, message: []const u8) !void {
        const message_copy = try allocator.dupe(u8, message);
        self.exception = .{
            .simple = .{
                .type = .RangeError,
                .message = message_copy,
            },
        };
    }

    /// Throws a DOMException with the specified name and message.
    ///
    /// Example:
    /// ```zig
    /// result.throwDOMException(allocator, .NotFoundError, "Element not found");
    /// ```
    pub fn throwDOMException(
        self: *ErrorResult,
        allocator: Allocator,
        name: DOMExceptionName,
        message: []const u8,
    ) !void {
        const exception = try DOMException.create(allocator, name, message);
        self.exception = .{ .dom = exception };
    }

    /// Returns true if an exception has been thrown.
    pub fn hasFailed(self: *const ErrorResult) bool {
        return self.exception != null;
    }

    /// Returns the exception if one was thrown, or null otherwise.
    pub fn getException(self: *const ErrorResult) ?*const Exception {
        if (self.exception) |*ex| {
            return ex;
        }
        return null;
    }

    /// Clears any exception, freeing allocated memory.
    ///
    /// After calling clear(), hasFailed() will return false.
    pub fn clear(self: *ErrorResult, allocator: Allocator) void {
        if (self.exception) |*ex| {
            ex.deinit(allocator);
            self.exception = null;
        }
    }

    /// Frees any allocated memory without clearing the exception flag.
    ///
    /// This is typically called when the ErrorResult goes out of scope.
    pub fn deinit(self: *ErrorResult, allocator: Allocator) void {
        self.clear(allocator);
    }
};

// Tests
test "DOMException creation and cleanup" {
    const allocator = std.testing.allocator;

    var exception = try DOMException.create(
        allocator,
        .NotFoundError,
        "Element not found",
    );
    defer exception.deinit(allocator);

    try std.testing.expectEqualStrings("NotFoundError", exception.name);
    try std.testing.expectEqualStrings("Element not found", exception.message);
    try std.testing.expectEqual(@as(u16, 8), exception.code);
}

test "DOMException name to string conversion" {
    try std.testing.expectEqualStrings("NotFoundError", DOMExceptionName.NotFoundError.toString());
    try std.testing.expectEqualStrings("InvalidStateError", DOMExceptionName.InvalidStateError.toString());
    try std.testing.expectEqualStrings("SyntaxError", DOMExceptionName.SyntaxError.toString());
}

test "DOMException legacy error codes" {
    try std.testing.expectEqual(@as(u16, 1), DOMExceptionName.IndexSizeError.toCode());
    try std.testing.expectEqual(@as(u16, 8), DOMExceptionName.NotFoundError.toCode());
    try std.testing.expectEqual(@as(u16, 0), DOMExceptionName.NotAllowedError.toCode()); // New name, no code
}

test "ErrorResult - throw TypeError" {
    const allocator = std.testing.allocator;

    var result = ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "Expected a number");

    try std.testing.expect(result.hasFailed());

    const exception = result.getException().?;
    try std.testing.expectEqual(SimpleException.TypeError, exception.simple.type);
    try std.testing.expectEqualStrings("Expected a number", exception.simple.message);
}

test "ErrorResult - throw RangeError" {
    const allocator = std.testing.allocator;

    var result = ErrorResult{};
    defer result.deinit(allocator);

    try result.throwRangeError(allocator, "Value out of range");

    try std.testing.expect(result.hasFailed());

    const exception = result.getException().?;
    try std.testing.expectEqual(SimpleException.RangeError, exception.simple.type);
    try std.testing.expectEqualStrings("Value out of range", exception.simple.message);
}

test "ErrorResult - throw DOMException" {
    const allocator = std.testing.allocator;

    var result = ErrorResult{};
    defer result.deinit(allocator);

    try result.throwDOMException(allocator, .InvalidStateError, "Object is in invalid state");

    try std.testing.expect(result.hasFailed());

    const exception = result.getException().?;
    try std.testing.expectEqualStrings("InvalidStateError", exception.dom.name);
    try std.testing.expectEqualStrings("Object is in invalid state", exception.dom.message);
}

test "ErrorResult - clear exception" {
    const allocator = std.testing.allocator;

    var result = ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "Test error");
    try std.testing.expect(result.hasFailed());

    result.clear(allocator);
    try std.testing.expect(!result.hasFailed());
}

test "ErrorResult - no exception initially" {
    var result = ErrorResult{};
    try std.testing.expect(!result.hasFailed());
    try std.testing.expectEqual(@as(?*const Exception, null), result.getException());
}
