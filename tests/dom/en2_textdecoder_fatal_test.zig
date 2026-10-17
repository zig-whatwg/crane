//! The fatal API boundary discards input and preserves decoder mode.
//! These native cases implement the row 49 Q8 browser-mechanism ruling;
//! the restored-CJK cases are source-derived, not measured browser results.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const allocator = testing.allocator;

fn decode(decoder: *runtime.Instance, bytes: []const u8, stream: bool) ![]const u8 {
    return interfaces.TextDecoder.call_decode(decoder, .passed(.{ .byte_slice = bytes }), .passed(.{ .stream = stream }));
}

fn expectDecoded(decoder: *runtime.Instance, bytes: []const u8, stream: bool, expected: []const u8) !void {
    const actual = try decode(decoder, bytes, stream);
    defer allocator.free(actual);
    try testing.expectEqualStrings(expected, actual);
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();
    ctx.browser_scope = &scope;

    for ([_]usize{ 0, 3 }) |split| {
        const decoder = try interfaces.TextDecoder.call_constructor(&ctx, .passed(runtime.DOMString.initInterned("gb18030")), .passed(.{ .fatal = true }));
        defer runtime.Instance.deinit(decoder);
        const input = "\x81\x30\x81+";
        try expectDecoded(decoder, input[0..split], true, "");
        try testing.expectError(error.DecodingError, decode(decoder, input[split..], true));
        try expectDecoded(decoder, "@", false, "@");
    }

    const cases = .{
        .{ "utf-8", "\xfd\xef", "", "" },
        .{ "utf-16le", "\x00\xd8A\x00", "", "" },
        .{ "utf-16be", "\xd8\x00\x00A", "", "" },
        .{ "iso-2022-jp", "\x1b(J\xff", "~", "‾" },
        .{ "iso-2022-jp", "\x1b(J\x1b(A", "~", "‾" },
    };
    inline for (cases) |case| {
        const decoder = try interfaces.TextDecoder.call_constructor(&ctx, .passed(runtime.DOMString.initInterned(case[0])), .passed(.{ .fatal = true }));
        defer runtime.Instance.deinit(decoder);
        try testing.expectError(error.DecodingError, decode(decoder, case[1], true));
        try expectDecoded(decoder, case[2], false, case[3]);
    }
}

fn onThread(result: *anyerror!void) void {
    result.* = exercise();
}

test "TextDecoder fatal throws discard restored input but keep ISO mode" {
    // tests/dom is one executable. Own the per-thread runtime without
    // reinitializing or tearing down a sibling test's pools or engine state.
    var result: anyerror!void = undefined;
    const thread = try std.Thread.spawn(.{}, onThread, .{&result});
    thread.join();
    try result;
}
