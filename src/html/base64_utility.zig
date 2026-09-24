//! HTML §8.3 Base64 utility methods: the steps of atob() and btoa(), on
//! strings held as UTF-8 (the engine's DOMString representation).
//!
//! Every global that includes WindowOrWorkerGlobalScope answers these - the
//! Window, the WorkerGlobalScope, and the native worker global - so the steps
//! live here, once, rather than in any one of their impls.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#atob

const std = @import("std");
const infra = @import("infra");

pub const Error = error{ InvalidCharacterError, OutOfMemory };

/// atob(data): the decoded bytes, isomorphic-decoded to a string and held
/// as UTF-8. The caller owns the result.
pub fn atob(allocator: std.mem.Allocator, data: []const u8) Error![]u8 {
    // Step 1: Let decodedData be the result of running forgiving-base64
    // decode on data.
    const decoded = infra.base64.forgivingBase64Decode(allocator, data) catch |err| switch (err) {
        // Step 2: If decodedData is failure, then throw an
        // "InvalidCharacterError" DOMException.
        error.InvalidBase64 => return error.InvalidCharacterError,
        error.OutOfMemory => return error.OutOfMemory,
    };
    defer allocator.free(decoded);
    // Step 3: Return decodedData - bytes, which script sees as the code
    // units 0x00-0xFF.
    return infra.bytes.isomorphicDecodeToUtf8(allocator, decoded) catch return error.OutOfMemory;
}

/// btoa(data): the base64 of data's code points as bytes. The caller owns
/// the result.
pub fn btoa(allocator: std.mem.Allocator, data: []const u8) Error![]u8 {
    // "throw an "InvalidCharacterError" DOMException if data contains any
    // character whose code point is greater than U+00FF. Otherwise ...
    // convert data to a byte sequence whose nth byte is the eight-bit
    // representation of the nth code point of data"
    const bytes = infra.bytes.isomorphicEncodeUtf8(allocator, data) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidCharacterError,
    };
    defer allocator.free(bytes);
    // "and then must apply forgiving-base64 encode to that byte sequence
    // and return the result."
    const encoded = try infra.base64.forgivingBase64Encode(allocator, bytes);
    return @constCast(encoded);
}

test "btoa encodes code points up to U+00FF as bytes" {
    const allocator = std.testing.allocator;
    const encoded = try btoa(allocator, "\xc3\xbf\xc3\xbe");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("//4=", encoded);
    try std.testing.expectError(error.InvalidCharacterError, btoa(allocator, "\xc4\x80"));
}

test "atob decodes forgivingly and returns code points" {
    const allocator = std.testing.allocator;
    const decoded = try atob(allocator, " //4 ");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("\xc3\xbf\xc3\xbe", decoded);
    try std.testing.expectError(error.InvalidCharacterError, atob(allocator, "a"));
}
