//! Comprehensive tests for WebIDL error handling

const std = @import("std");
const webidl = @import("webidl");
const errors = webidl.errors;

const testing = std.testing;
const allocator = testing.allocator;

// DOMException Tests

test "DOMException - all error names have correct strings" {
    const names = [_]errors.DOMExceptionName{
        .IndexSizeError,
        .HierarchyRequestError,
        .WrongDocumentError,
        .InvalidCharacterError,
        .NoModificationAllowedError,
        .NotFoundError,
        .NotSupportedError,
        .InUseAttributeError,
        .InvalidStateError,
        .SyntaxError,
        .InvalidModificationError,
        .NamespaceError,
        .InvalidAccessError,
        .TypeMismatchError,
        .SecurityError,
        .NetworkError,
        .AbortError,
        .URLMismatchError,
        .QuotaExceededError,
        .TimeoutError,
        .InvalidNodeTypeError,
        .DataCloneError,
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
    };

    for (names) |name| {
        const str = name.toString();
        try testing.expect(str.len > 0);
    }
}

test "DOMException - legacy error codes for old names" {
    try testing.expectEqual(@as(u16, 1), errors.DOMExceptionName.IndexSizeError.toCode());
    try testing.expectEqual(@as(u16, 3), errors.DOMExceptionName.HierarchyRequestError.toCode());
    try testing.expectEqual(@as(u16, 4), errors.DOMExceptionName.WrongDocumentError.toCode());
    try testing.expectEqual(@as(u16, 5), errors.DOMExceptionName.InvalidCharacterError.toCode());
    try testing.expectEqual(@as(u16, 7), errors.DOMExceptionName.NoModificationAllowedError.toCode());
    try testing.expectEqual(@as(u16, 8), errors.DOMExceptionName.NotFoundError.toCode());
    try testing.expectEqual(@as(u16, 9), errors.DOMExceptionName.NotSupportedError.toCode());
    try testing.expectEqual(@as(u16, 10), errors.DOMExceptionName.InUseAttributeError.toCode());
    try testing.expectEqual(@as(u16, 11), errors.DOMExceptionName.InvalidStateError.toCode());
    try testing.expectEqual(@as(u16, 12), errors.DOMExceptionName.SyntaxError.toCode());
    try testing.expectEqual(@as(u16, 13), errors.DOMExceptionName.InvalidModificationError.toCode());
    try testing.expectEqual(@as(u16, 14), errors.DOMExceptionName.NamespaceError.toCode());
    try testing.expectEqual(@as(u16, 15), errors.DOMExceptionName.InvalidAccessError.toCode());
    try testing.expectEqual(@as(u16, 17), errors.DOMExceptionName.TypeMismatchError.toCode());
    try testing.expectEqual(@as(u16, 18), errors.DOMExceptionName.SecurityError.toCode());
    try testing.expectEqual(@as(u16, 19), errors.DOMExceptionName.NetworkError.toCode());
    try testing.expectEqual(@as(u16, 20), errors.DOMExceptionName.AbortError.toCode());
    try testing.expectEqual(@as(u16, 21), errors.DOMExceptionName.URLMismatchError.toCode());
    try testing.expectEqual(@as(u16, 22), errors.DOMExceptionName.QuotaExceededError.toCode());
    try testing.expectEqual(@as(u16, 23), errors.DOMExceptionName.TimeoutError.toCode());
    try testing.expectEqual(@as(u16, 24), errors.DOMExceptionName.InvalidNodeTypeError.toCode());
    try testing.expectEqual(@as(u16, 25), errors.DOMExceptionName.DataCloneError.toCode());
}

test "DOMException - new error names have no legacy code" {
    try testing.expectEqual(@as(u16, 0), errors.DOMExceptionName.EncodingError.toCode());
    try testing.expectEqual(@as(u16, 0), errors.DOMExceptionName.NotReadableError.toCode());
    try testing.expectEqual(@as(u16, 0), errors.DOMExceptionName.UnknownError.toCode());
    try testing.expectEqual(@as(u16, 0), errors.DOMExceptionName.NotAllowedError.toCode());
}

test "DOMException - create with empty message" {
    var exception = try errors.DOMException.create(
        allocator,
        .NotFoundError,
        "",
    );
    defer exception.deinit(allocator);

    try testing.expectEqualStrings("NotFoundError", exception.name);
    try testing.expectEqualStrings("", exception.message);
}

test "DOMException - create with long message" {
    const long_message = "This is a very long error message that describes in detail what went wrong with the operation and provides helpful context for debugging the issue.";

    var exception = try errors.DOMException.create(
        allocator,
        .InvalidStateError,
        long_message,
    );
    defer exception.deinit(allocator);

    try testing.expectEqualStrings("InvalidStateError", exception.name);
    try testing.expectEqualStrings(long_message, exception.message);
}

// SimpleException Tests

test "SimpleException - all types have correct strings" {
    try testing.expectEqualStrings("TypeError", errors.SimpleException.TypeError.toString());
    try testing.expectEqualStrings("RangeError", errors.SimpleException.RangeError.toString());
    try testing.expectEqualStrings("SyntaxError", errors.SimpleException.SyntaxError.toString());
    try testing.expectEqualStrings("URIError", errors.SimpleException.URIError.toString());
}

// ErrorResult Tests

test "ErrorResult - initial state is no error" {
    const result = errors.ErrorResult{};
    try testing.expect(!result.hasFailed());
    try testing.expectEqual(@as(?*const errors.Exception, null), result.getException());
}

test "ErrorResult - throwTypeError sets exception" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "Invalid type");

    try testing.expect(result.hasFailed());
    const exception = result.getException().?;
    try testing.expectEqual(errors.SimpleException.TypeError, exception.simple.type);
    try testing.expectEqualStrings("Invalid type", exception.simple.message);
}

test "ErrorResult - throwRangeError sets exception" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwRangeError(allocator, "Out of bounds");

    try testing.expect(result.hasFailed());
    const exception = result.getException().?;
    try testing.expectEqual(errors.SimpleException.RangeError, exception.simple.type);
    try testing.expectEqualStrings("Out of bounds", exception.simple.message);
}

test "ErrorResult - throwDOMException sets exception" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwDOMException(allocator, .NetworkError, "Connection failed");

    try testing.expect(result.hasFailed());
    const exception = result.getException().?;
    try testing.expectEqualStrings("NetworkError", exception.dom.name);
    try testing.expectEqualStrings("Connection failed", exception.dom.message);
    try testing.expectEqual(@as(u16, 19), exception.dom.code);
}

test "ErrorResult - clear removes exception" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "Test");
    try testing.expect(result.hasFailed());

    result.clear(allocator);
    try testing.expect(!result.hasFailed());
}

test "ErrorResult - clear on no exception is safe" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try testing.expect(!result.hasFailed());
    result.clear(allocator);
    try testing.expect(!result.hasFailed());
}

test "ErrorResult - multiple clear calls are safe" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "Test");
    result.clear(allocator);
    result.clear(allocator);
    result.clear(allocator);

    try testing.expect(!result.hasFailed());
}

test "ErrorResult - deinit without exception is safe" {
    var result = errors.ErrorResult{};
    result.deinit(allocator);
    try testing.expect(!result.hasFailed());
}

// Memory leak tests

test "ErrorResult - no leaks with TypeError" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "Memory leak test");
    try testing.expect(result.hasFailed());
}

test "ErrorResult - no leaks with RangeError" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwRangeError(allocator, "Memory leak test");
    try testing.expect(result.hasFailed());
}

test "ErrorResult - no leaks with DOMException" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwDOMException(allocator, .DataCloneError, "Memory leak test");
    try testing.expect(result.hasFailed());
}

test "ErrorResult - no leaks with multiple throws and clears" {
    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try result.throwTypeError(allocator, "First error");
    result.clear(allocator);

    try result.throwRangeError(allocator, "Second error");
    result.clear(allocator);

    try result.throwDOMException(allocator, .NotFoundError, "Third error");
    result.clear(allocator);

    try testing.expect(!result.hasFailed());
}

// Usage pattern tests

test "ErrorResult - operation pattern with TypeError" {
    const Op = struct {
        fn doSomething(value: i32, result: *errors.ErrorResult) !void {
            if (value < 0) {
                try result.throwTypeError(allocator, "Value must be non-negative");
                return;
            }
            // Operation succeeds
        }
    };

    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try Op.doSomething(-5, &result);
    try testing.expect(result.hasFailed());
}

test "ErrorResult - operation pattern with DOMException" {
    const Op = struct {
        fn findElement(id: []const u8, result: *errors.ErrorResult) !void {
            if (id.len == 0) {
                try result.throwDOMException(allocator, .NotFoundError, "Element ID cannot be empty");
                return;
            }
            // Operation succeeds
        }
    };

    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try Op.findElement("", &result);
    try testing.expect(result.hasFailed());

    const exception = result.getException().?;
    try testing.expectEqualStrings("NotFoundError", exception.dom.name);
}

test "ErrorResult - operation pattern with success" {
    const Op = struct {
        fn doSomething(value: i32, result: *errors.ErrorResult) !void {
            _ = result;
            if (value >= 0) {
                // Operation succeeds, no error thrown
                return;
            }
        }
    };

    var result = errors.ErrorResult{};
    defer result.deinit(allocator);

    try Op.doSomething(42, &result);
    try testing.expect(!result.hasFailed());
}
