//! WebSocket API validation without opening a socket. The realm has no
//! timer, so successful construction leaves CONNECTING until explicit close.
//! std.testing.allocator checks constructor error cleanup and copied strings.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");

/// `s` repeated `n` times: what `s ** n` was (Zig 0.17 removes `**`; roadmap zig-017).
fn repeat(comptime s: []const u8, comptime n: usize) *const [s.len * n:0]u8 {
    return comptime blk: {
        @setEvalBranchQuota(10 * n + 1000);
        var out: [s.len * n:0]u8 = undefined;
        for (0..n) |i| @memcpy(out[i * s.len ..][0..s.len], s);
        const final = out;
        break :blk &final;
    };
}

const allocator = std.testing.allocator;

test "WebSocket validates URL and protocols without leaking partial state" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();

    for ([_][]const u8{ "ftp://example.test/", "ws://example.test/#", "ws://bad host/" }) |url| {
        try std.testing.expectError(error.SyntaxError, interfaces.WebSocket.call_constructor(
            &ctx,
            url,
            .passed(runtime.JSValue.fromStringRef("chat")),
        ));
    }
    for ([_][]const u8{ "", "a b", "a\x00b", "a/b", "a,b", "\xc3\xa9" }) |protocol| {
        try std.testing.expectError(error.SyntaxError, interfaces.WebSocket.call_constructor(
            &ctx,
            "ws://example.test/",
            .passed(runtime.JSValue.fromStringRef(protocol)),
        ));
    }

    const socket = try interfaces.WebSocket.call_constructor(&ctx, "https://EXAMPLE.test:443/echo", .passed(runtime.JSValue.fromStringRef("chat")));
    defer interfaces.WebSocket.deinit(socket);
    const url = try interfaces.WebSocket.get_url(socket);
    defer allocator.free(url);
    try std.testing.expectEqualStrings("wss://example.test/echo", url);
    try std.testing.expectEqual(@as(u16, 0), try interfaces.WebSocket.get_readyState(socket));
    try std.testing.expectEqual(@as(u64, 0), try interfaces.WebSocket.get_bufferedAmount(socket));
}

test "WebSocket close validation precedes state changes and counts UTF-8 bytes" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();

    const socket = try interfaces.WebSocket.call_constructor(&ctx, "ws://example.test/", .notPassed());
    defer interfaces.WebSocket.deinit(socket);
    try std.testing.expectError(error.InvalidAccessError, interfaces.WebSocket.call_close(socket, .passed(1001), .passed(&@as([124:0]u8, @splat('x')))));
    try std.testing.expectError(error.SyntaxError, interfaces.WebSocket.call_close(socket, .passed(1000), .passed(repeat("\xc3\xa9", 62))));
    try std.testing.expectEqual(@as(u16, 0), try interfaces.WebSocket.get_readyState(socket));

    try interfaces.WebSocket.call_close(socket, .passed(1000), .passed(repeat("\xc3\xa9", 61) ++ "x"));
    try std.testing.expectEqual(@as(u16, 2), try interfaces.WebSocket.get_readyState(socket));
    try std.testing.expectError(error.InvalidAccessError, interfaces.WebSocket.call_close(socket, .passed(1001), .notPassed()));
    try interfaces.WebSocket.call_send(socket, runtime.JSValue.fromStringRef("\xc3\xa9"));
    try std.testing.expectEqual(@as(u64, 2), try interfaces.WebSocket.get_bufferedAmount(socket));
}
