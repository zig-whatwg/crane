//! Fetch Response static algorithms, through generated interfaces.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const testing = std.testing;

const Trial = struct {
    kind: enum { error_guard, redirect_guard, redirect_url, redirect_error_order },
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
        const receiver = try interfaces.Response.init(testing.allocator, &context);
        defer runtime.Instance.deinit(receiver);

        if (self.kind == .redirect_error_order) {
            const response = interfaces.Response.call_static_redirect(receiver, "http://:invalid", webidl.Opt(u16).passed(200)) catch |err| {
                try testing.expectEqual(error.TypeError, err);
                return;
            };
            defer runtime.Instance.deinit(response);
            return error.ExpectedTypeError;
        }

        const response = if (self.kind == .error_guard)
            try interfaces.Response.call_static_error(receiver)
        else
            try interfaces.Response.call_static_redirect(receiver, "https://EXAMPLE.test:443/a/../b?x=ÿ#z", webidl.Opt(u16).notPassed());
        defer runtime.Instance.deinit(response);
        const headers = try interfaces.Response.get_headers(response);
        defer runtime.Instance.deinit(headers);

        if (self.kind == .redirect_url) {
            const location = (try interfaces.Headers.call_get(headers, "location")) orelse return error.MissingLocation;
            defer testing.allocator.free(location);
            try testing.expectEqualStrings("https://example.test/b?x=%C3%BF#z", location);
        } else {
            try testing.expectError(error.TypeError, interfaces.Headers.call_append(headers, "x-test", "value"));
            try testing.expectError(error.TypeError, interfaces.Headers.call_delete(headers, "absent"));
        }
    }
};

fn check(kind: @FieldType(Trial, "kind")) !void {
    var trial: Trial = .{ .kind = kind };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "Response.error uses immutable headers" {
    try check(.error_guard);
}

test "Response.redirect uses immutable headers" {
    try check(.redirect_guard);
}

test "Response.redirect serializes the parsed URL" {
    try check(.redirect_url);
}

test "Response.redirect URL error precedes status error" {
    try check(.redirect_error_order);
}
