//! attachShadow's `customElementRegistry` member is a `CustomElementRegistry?`
//! (CE2-M1, tmp/analysis/fix-list.md). The binding converts interface-typed
//! dictionary members to any platform object, so Element.attachShadow must
//! brand-check it: another platform object is a TypeError (WebIDL 3.2.21),
//! and is never read as a registry. The Crane fixture
//! crane/lf1-attachshadow-registry-brand.html covers the script side.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");

/// ShadowRootInit, as Element.attachShadow takes it.
const ShadowRootInit = @typeInfo(@TypeOf(interfaces.Element.call_attachShadow)).@"fn".params[1].type.?;

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn platformObject(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn nonRegistryIsTypeError() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });

    const host = try platformObject(browser, "globalThis.host = document.createElement('div'); host");
    const body = try platformObject(browser, "document.body");
    const text = try platformObject(browser, "globalThis.text = document.createTextNode(''); text");
    for ([_]*runtime.Instance{ body, text }) |not_a_registry| {
        const init: ShadowRootInit = .{ .mode = ._open_, .customElementRegistry = .{ .was_passed = true, .value = not_a_registry } };
        try testing.expectError(error.TypeError, interfaces.Element.call_attachShadow(host, init));
        try testing.expect((try interfaces.Element.get_shadowRoot(host)) == null);
    }

    // A registry is still taken.
    const registry = try platformObject(browser, "globalThis.registry = new CustomElementRegistry(); registry");
    const init: ShadowRootInit = .{ .mode = ._open_, .customElementRegistry = .{ .was_passed = true, .value = registry } };
    const root = try interfaces.Element.call_attachShadow(host, init);
    try testing.expectEqual(root, (try interfaces.Element.get_shadowRoot(host)) orelse return error.NoShadowRoot);
}

test "attachShadow with a platform object that is no CustomElementRegistry throws TypeError and attaches nothing" {
    try onFreshThread(nonRegistryIsTypeError);
}
