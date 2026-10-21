//! IDL member behavior through script, including allocator-checked teardown.
const std = @import("std");
const browser_mod = @import("browser");

fn check(comptime script: []const u8, comptime expected: []const u8) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }

        fn exercise() !void {
            const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.NoPage;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
            const result = try page.evaluateScriptToString(script, std.testing.allocator);
            defer std.testing.allocator.free(result);
            try std.testing.expectEqualStrings(expected, result);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "window external is a cached object with inert legacy methods" {
    try check(
        \\JSON.stringify([external instanceof External, external === window.external,
        \\  external.AddSearchProvider() === undefined, external.IsSearchProviderInstalled() === undefined])
    , "[true,true,true,true]");
}
