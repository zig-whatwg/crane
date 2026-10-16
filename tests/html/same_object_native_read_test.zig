//! binding3 item 9(h): a generated [SameObject] getter caches the child it
//! makes in the owner's generated state (`cached_<name>`), as a bare pointer.
//! Script's read wraps the child, and its wrapper owns it from then on. A
//! NATIVE read (Codex row 45 Q14: SVGAElement's extract-an-origin steps
//! calling `interfaces.SVGAElement.get_href`) made the child and nothing
//! wrapped it, so nothing ever freed it: the SVGAnimatedString's state, its
//! attribute name and its namespace leaked with every element (75 `leaked:`
//! markers in origin-from-hyperlinkelementutils.window.js). The owner keeps
//! what nothing wrapped, and its teardown frees it; a child script has seen
//! stays its wrapper's.
//!
//! The Browser runs on `std.testing.allocator`, so a leaked child fails the
//! test at its end.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

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

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

fn platformObject(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

const make_links =
    \\globalThis.links = [];
    \\for (let i = 0; i < 8; i++) {
    \\  const a = document.createElementNS('http://www.w3.org/2000/svg', 'a');
    \\  a.setAttributeNS('http://www.w3.org/1999/xlink', 'xlink:href', 'https://example.test/' + i);
    \\  links.push(a);
    \\}
    \\links[0]
;

/// Native reads of every link's `href`; the children and their generations.
fn readNatively(browser: *browser_mod.Browser, children: []*runtime.Instance, generations: []u64) !void {
    for (children, generations, 0..) |*child, *generation, i| {
        var source_buffer: [32]u8 = undefined;
        const source = try std.fmt.bufPrint(&source_buffer, "links[{d}]", .{i});
        const link = try platformObject(browser, source);
        child.* = try interfaces.SVGAElement.get_href(link);
        generation.* = runtime.SlabAllocator.generationOf(child.*);
        // [SameObject]: a second native read is the same child.
        try testing.expectEqual(child.*, try interfaces.SVGAElement.get_href(link));
    }
}

fn nativeReadsFreedWithOwner() !void {
    const browser = try open();
    defer browser.deinit();
    _ = try platformObject(browser, make_links);
    var children: [8]*runtime.Instance = undefined;
    var generations: [8]u64 = undefined;
    try readNatively(browser, &children, &generations);
    // The owners go: script drops them, the collector takes their wrappers,
    // and the event loop runs their deferred teardown.
    try run(browser, "links = null; 0");
    for (0..4) |_| {
        try collect(browser);
        try browser.runEventLoop(10);
    }
    for (children, generations) |child, generation| {
        try testing.expect(runtime.SlabAllocator.generationOf(child) != generation);
    }
}

test "a [SameObject] child only a native read made is freed with its owner" {
    try onFreshThread(nativeReadsFreedWithOwner);
}

fn nativeReadsFreedAtTheEnd() !void {
    const browser = try open();
    defer browser.deinit();
    _ = try platformObject(browser, make_links);
    var children: [8]*runtime.Instance = undefined;
    var generations: [8]u64 = undefined;
    try readNatively(browser, &children, &generations);
    // The owners stay until the page ends; testing.allocator reports what
    // their children leave behind.
}

test "a [SameObject] child only a native read made is freed when its page ends" {
    try onFreshThread(nativeReadsFreedAtTheEnd);
}

fn scriptReadStaysWrappers() !void {
    const browser = try open();
    defer browser.deinit();
    _ = try platformObject(browser, make_links);
    // Script's read first: each child is wrapped, and kept by script.
    try run(browser, "globalThis.hrefs = links.map((a) => a.href); 0");
    var children: [8]*runtime.Instance = undefined;
    var generations: [8]u64 = undefined;
    try readNatively(browser, &children, &generations);
    try run(browser, "links = null; 0");
    for (0..4) |_| {
        try collect(browser);
        try browser.runEventLoop(10);
    }
    // The children script holds outlive their owners, still themselves.
    for (children, generations) |child, generation| {
        try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(child));
    }
    try expectTrue(browser, "hrefs.every((h, i) => h instanceof SVGAnimatedString && h.baseVal === 'https://example.test/' + i)");
}

test "a [SameObject] child script has read stays its wrapper's when its owner goes" {
    try onFreshThread(scriptReadStaysWrappers);
}
