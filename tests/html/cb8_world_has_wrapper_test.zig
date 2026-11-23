//! "Has script seen it" asks every world (main's ruling of 2026-11-23
//! 12:17 PM ET, lane rc8): engine.hasWrapper answers whether ANY world has a
//! wrapper of an instance - an isolated world's (protocol_worlds.zig) as well
//! as its own realm's. A caller that frees an instance "if unwrapped" after
//! script may have reached it must not free it under a world's wrapper: Blink
//! asks DOMDataStore of every world (ScriptWrappable::ContainsWrapper is the
//! main world's only, and an object a world wrapped is kept by that world's
//! wrapper through its C++ reference). Before the ruling V8's hasWrapper read
//! the main realm's cache alone.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const runtime = @import("runtime");
const browser_mod = @import("browser");
const probe = @import("refcount_probe.zig");
const Page = probe.Page;

const isolated_worlds = browser_mod.isolated_worlds;

const navigable: u64 = 1;

const Reports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn expectInWorld(world: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(world, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    testing.expectEqualStrings(expected, got) catch |err| {
        std.debug.print("world script: {s}\n", .{source});
        return err;
    };
}

fn openWithWorld(page: *Page) !runtime.Context {
    const main_realm = (page.browser.current_context orelse return error.NoPage).realm orelse return error.NoRealm;
    return isolated_worlds.createIsolatedWorld(main_realm, navigable, "__cb8_has_wrapper_world__", false);
}

fn templateContentOnlyAWorldHolds() !void {
    var page = try Page.open("");
    defer page.close();
    const world = try openWithWorld(&page);
    // The world keeps a template's content and lets the template go. The
    // template's teardown frees its content only when no script can reach it
    // (HTMLTemplateElement's deinit: "an unwrapped one is freed now") - and
    // the world's script still can.
    try expectInWorld(world,
        \\globalThis.content = (() => {
        \\  const t = document.createElement('template');
        \\  t.innerHTML = '<p id="kept">text</p>';
        \\  return t.content;
        \\})();
        \\'ok'
    , "ok");
    try page.settle();
    try expectInWorld(world, "content.firstChild.id + ' ' + content.firstChild.textContent + ' ' + content.childNodes.length", "kept text 1");
    try expectInWorld(world, "content.appendChild(document.createElement('b')); String(content.childNodes.length)", "2");
}
test "a template's content only a world holds outlives the template" {
    try probe.onFreshThread(templateContentOnlyAWorldHolds);
}

fn quotaExceededCaughtInWorld() !void {
    var page = try Page.open("");
    defer page.close();
    const world = try openWithWorld(&page);
    try expectInWorld(world,
        \\globalThis.caught = null;
        \\try { crypto.getRandomValues(new Uint8Array(70000)); } catch (e) { globalThis.caught = e; }
        \\caught.name
    , "QuotaExceededError");
    try page.settle();
    try expectInWorld(world, "caught.name + ' ' + String(caught.message.length > 0)", "QuotaExceededError true");
}
test "a QuotaExceededError a world caught stays readable after collections" {
    try probe.onFreshThread(quotaExceededCaughtInWorld);
}
