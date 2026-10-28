//! Q110 follow-up: throwing after a page-margin access must not strand its model.
//! The public engine reports the uncaught script error; std.testing.allocator
//! checks that realm/agent/runtime teardown releases all parsed rule holders.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const a = std.testing.allocator;

fn onThread(comptime body: fn () anyerror!void) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = body();
        }
    }.run, .{&result});
    thread.join();
    try result;
}

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
};

const Report = struct {
    expected: []const u8,
    count: usize = 0,
    matched: bool = false,
    parse_error: bool = false,

    fn report(data: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Report = @ptrCast(@alignCast(data.?));
        self.count += 1;
        self.matched = std.mem.indexOf(u8, info.message, self.expected) != null;
        self.parse_error = info.parse_error;
    }
};

fn expectScriptThrow(source: []const u8, expected: []const u8) !void {
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(a);
    defer runtime.deinitializeRuntime();
    var scope = runtime.BrowserScope.init(a);
    defer scope.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = a });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = a, .from_snapshot = false, .timer = null, .origin = "https://om1.test", .browser_scope = &scope, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(realm, .global_detached);
    var report: Report = .{ .expected = expected };
    // No script catch: this exercises the same uncaught-exception return and
    // ordinary teardown as the original missing-CSSMarginRule failure.
    if (engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = Report.report, .host = &report })) |result| {
        defer a.free(result);
        return error.ExpectedUncaughtException;
    } else |err| {
        try std.testing.expectEqual(error.ExceptionReported, err);
    }
    try std.testing.expectEqual(@as(usize, 1), report.count);
    try std.testing.expect(report.matched);
    try std.testing.expect(!report.parse_error);
}

const access_margin =
    \\(() => {
    \\const d = new Document().implementation.createHTMLDocument('om1');
    \\const style = d.createElement('style');
    \\style.textContent = '@page { @top-left { color: red; } size: a4; @bottom-right {} }';
    \\d.head.appendChild(style);
    \\const sheet = style.sheet, page = sheet.cssRules[0];
    \\if (page.cssRules.length !== 2 || page.style.size !== 'a4') throw new Error('page setup failed');
    \\const margin = page.cssRules[0], declaration = margin.style;
    \\if (!(margin instanceof CSSMarginRule) || margin.name !== 'top-left') throw new Error('margin setup failed');
    \\if (declaration !== margin.style || declaration.parentRule !== margin || declaration.getPropertyValue('color') !== 'red') throw new Error('declaration setup failed');
;

fn uncaughtError() !void {
    try expectScriptThrow(access_margin ++ "\nthrow new Error('om1 deliberate margin error');\n})()", "om1 deliberate margin error");
}

test "Q110 page margin holders release after an uncaught Error" {
    try onThread(uncaughtError);
}

fn uncaughtReferenceError() !void {
    try expectScriptThrow(access_margin ++ "\nom1UndefinedAfterMarginStyle;\n})()", "ReferenceError: om1UndefinedAfterMarginStyle is not defined");
}

test "Q110 page margin holders release after an undefined global ReferenceError" {
    try onThread(uncaughtReferenceError);
}
