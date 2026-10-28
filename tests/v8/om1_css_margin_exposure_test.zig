//! CSSOM §6.4.8 / liaison Q110: expose the existing generated margin rule.
//! Each case has a fresh thread and leak-checking allocator.
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
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("om1 margin exposure: {s}\n", .{info.message});
    }
};

fn script(source: []const u8) !void {
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
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, a, .{ .report = Host.report, .host = null });
    defer a.free(result);
    try std.testing.expectEqualStrings("ok", result);
}

fn exposesConstructor() !void {
    try script(
        \\(() => typeof CSSMarginRule === 'function' ? 'ok' : 'missing CSSMarginRule')()
    );
}

test "Q110 CSSMarginRule is a Window interface object" {
    try onThread(exposesConstructor);
}

fn prototypeChain() !void {
    try script(
        \\(() => {
        \\if (Object.getPrototypeOf(CSSMarginRule.prototype) !== CSSRule.prototype) return 'margin prototype';
        \\if (Object.getPrototypeOf(CSSRule.prototype) !== Object.prototype) return 'rule prototype';
        \\return 'ok';
        \\})()
    );
}

test "Q110 CSSMarginRule prototype inherits CSSRule then Object" {
    try onThread(prototypeChain);
}

fn noConstructor() !void {
    try script(
        \\(() => {
        \\try { new CSSMarginRule(); } catch (e) { return e instanceof TypeError ? 'ok' : e.name; }
        \\return 'constructor did not throw';
        \\})()
    );
}

test "Q110 CSSMarginRule has no public constructor" {
    try onThread(noConstructor);
}

fn marginInstance() !void {
    try script(
        \\(() => {
        \\const d = new Document().implementation.createHTMLDocument('margin exposure');
        \\const style = d.createElement('style');
        \\style.textContent = '@page { @top-left { color: red; } }';
        \\d.head.appendChild(style);
        \\const margin = style.sheet.cssRules[0].cssRules[0];
        \\return margin instanceof CSSMarginRule ? 'ok' : 'margin brand';
        \\})()
    );
}

test "Q110 a page margin object has the CSSMarginRule brand" {
    try onThread(marginInstance);
}
