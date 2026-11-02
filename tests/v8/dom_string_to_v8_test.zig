//! A DOMString reaches script as a string - the empty one too.
//!
//! runtime.DOMString is a tagged union (empty, interned, owned), and
//! conversions.toV8Value converted every union generically - its active
//! field, recursively - before it ever reached its DOMString case. The empty
//! variant's field is `void`, which converts to undefined: an empty DOMString
//! reached script as `undefined` (DOMStringList[0] === undefined while
//! item(0) === "", through the indexed property getter; six IndexedDB
//! empty-name assertions).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
}

/// `value` through toV8Value, as script would read it: a string's UTF-8, or
/// error.NotAString.
fn converted(comptime T: type, value: T, buffer: []u8) ![]const u8 {
    const e = try env();
    const handle = try v8.conversions.toV8Value(T, e.isolate, e.context, value);
    defer ffi.v8_Value_Dispose(handle);
    if (!ffi.v8_Value_IsString(handle)) return error.NotAString;
    const string: *ffi.String = @ptrCast(handle);
    const length = ffi.v8_String_Utf8Length(string);
    if (length < 0 or @as(usize, @intCast(length)) > buffer.len) return error.TooLong;
    if (length == 0) return buffer[0..0];
    const written = ffi.v8_String_WriteUtf8(string, buffer.ptr, length);
    return buffer[0..@intCast(written)];
}

test "an empty DOMString converts to the empty string, not undefined" {
    defer test_agent.close();
    var buffer: [16]u8 = undefined;
    try testing.expectEqualStrings("", try converted(runtime.DOMString, runtime.DOMString.initEmpty(), &buffer));
    // initDupe of "" is the empty variant too.
    const dupe = try runtime.DOMString.initDupe(testing.allocator, "");
    try testing.expectEqualStrings("", try converted(runtime.DOMString, dupe, &buffer));
}

test "interned and owned DOMStrings convert to their text" {
    defer test_agent.close();
    var buffer: [16]u8 = undefined;
    try testing.expectEqualStrings("interned", try converted(runtime.DOMString, runtime.DOMString.initInterned("interned"), &buffer));
    const owned = try testing.allocator.dupe(u8, "owned");
    defer testing.allocator.free(owned);
    try testing.expectEqualStrings("owned", try converted(runtime.DOMString, runtime.DOMString.initOwned(owned), &buffer));
}

test "a nullable DOMString converts to a string, or null" {
    defer test_agent.close();
    var buffer: [16]u8 = undefined;
    try testing.expectEqualStrings("", try converted(?runtime.DOMString, runtime.DOMString.initEmpty(), &buffer));
    const e = try env();
    const null_handle = try v8.conversions.toV8Value(?runtime.DOMString, e.isolate, e.context, null);
    defer ffi.v8_Value_Dispose(null_handle);
    try testing.expect(ffi.v8_Value_IsNull(null_handle));
}
