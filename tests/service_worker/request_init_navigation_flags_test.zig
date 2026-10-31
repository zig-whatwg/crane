//! Fetch's Request constructor step 13: with a non-empty init, a request made
//! from another - a service worker's new Request(event.request, {...}) of a
//! navigation - leaves navigate mode (13.1), drops the reload- and
//! history-navigation flags (13.2-13.3) and takes "client" as its origin
//! (13.4): the worker's fetch is its own, not the navigation's
//! (navigation-headers.https.html's "service worker that changes the request"
//! cases). With an empty init the copy keeps all three.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");
const testing = std.testing;

const Trial = struct {
    with_init: bool,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        defer runtime.deinitializeRuntime();
        var context = try runtime.ContextData.init(testing.allocator, .{});
        defer context.deinit();
        const Init = @typeInfo(@TypeOf(interfaces.Request.call_constructor)).@"fn".param_types[2].?;
        const input = try interfaces.Request.call_constructor(&context, .{ .usvstring = "https://a.example/page" }, Init.notPassed());
        defer destroyRequest(input);
        // The navigation's request, as a fetch event's Request object holds it.
        const navigation: *fetch.internal.InternalRequest = @ptrCast(@alignCast(dom.fetch_objects.requestOf(input).?));
        try navigation.setOrigin("https://b.example");
        navigation.reload_navigation = true;
        navigation.history_navigation = true;

        const request = try interfaces.Request.call_constructor(&context, .{ .request = input }, if (self.with_init)
            Init.passed(.{ .method = "GET" })
        else
            Init.notPassed());
        defer destroyRequest(request);
        const copied: *fetch.internal.InternalRequest = @ptrCast(@alignCast(dom.fetch_objects.requestOf(request).?));
        if (self.with_init) {
            try testing.expect(copied.origin == .client);
            try testing.expect(!try interfaces.Request.get_isReloadNavigation(request));
            try testing.expect(!try interfaces.Request.get_isHistoryNavigation(request));
        } else {
            switch (copied.origin) {
                .origin => |origin| try testing.expectEqualStrings("https://b.example", origin),
                .client => return error.TestExpectedOrigin,
            }
            try testing.expect(try interfaces.Request.get_isReloadNavigation(request));
            try testing.expect(try interfaces.Request.get_isHistoryNavigation(request));
        }
    }
};

fn destroyRequest(request: *runtime.Instance) void {
    const signal = interfaces.Request.get_signal(request) catch unreachable;
    runtime.Instance.deinit(request);
    runtime.Instance.deinit(signal);
}

fn check(with_init: bool) !void {
    var trial: Trial = .{ .with_init = with_init };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "a Request made from a navigation's with a non-empty init: origin \"client\", no reload or history navigation flag" {
    try check(true);
}

test "a Request made from a navigation's with no init keeps its origin and both flags" {
    try check(false);
}
