//! A realm's end frees the objects only its wrapper cache kept - and reads
//! nothing of their slots after (lane tsanfix1, F2 of
//! docs/testing/test-variant-findings-2026-11-02.tsv).
//!
//! WrapperCache.deinit freed an entry's instance (gc.onObjectFreed) and THEN
//! disposed the entry's wrapper, which asked the node bridge for the
//! instance's node (instance_bridge.getNodeBase -> SlabAllocator.generationOf)
//! - a read of the slot it had just given back. The slab is the Browser's,
//! shared by its window thread and its workers' threads, and its free list is
//! LIFO: the next allocation on any thread takes that slot. ThreadSanitizer
//! caught a worker's realm reading the slot while the window thread issued
//! it to a MessageEvent (mx2_data_worker_test, tt4_worker_cookie_threads_test).
//! On one thread the read answers null and changes nothing, so this test
//! counts it instead: the bridge counts every getNodeBase of a freed slot
//! (instance_bridge.deadSlotLookups), and a realm's end must make none.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const test_process = @import("test_process.zig");

const Host = struct {
    fn window(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    try testing.expectEqualStrings(expected, got);
}

test "a realm's end reads nothing of an instance its wrapper cache freed" {
    test_process.start();
    // The objects come from a Browser scope of the test's own, whose node
    // bridge counts the reads (`deadSlotLookups`).
    const own_runtime = test_process.OwnRuntime.begin(testing.allocator);
    defer own_runtime.end();
    var browser = runtime.BrowserScope.init(testing.allocator);
    defer browser.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = testing.allocator });
    defer engine.destroyAgent(agent);
    const page = try engine.createWindowRealm(&.{ .agent = agent, .allocator = testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://example.test", .browser_scope = &browser, .create_global_object = Host.window });
    var page_live = true;
    defer if (page_live) engine.destroyWindowRealm(page, .global_detached);

    // Script node constructors use the current Window's associated Document.
    const record = page.getRealm() orelse return error.NoWindow;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
    const document = try interfaces.Document.init(testing.allocator, page);
    try dom.document_internals.setDocumentType(document, .html);
    dom.window_globals.setDocument(window, document);
    dom.document_browsing_context.setWindow(document, window);

    // Detached nodes and an event that only their wrappers keep: the realm's
    // end frees each (the wrapper cache's last branch, gc.onObjectFreed).
    try expect(page,
        \\globalThis.kept = [new Text('a'), new Comment('b'), new DocumentFragment(),
        \\  document.createElement('p'), new Event('e'), new AbortController()];
        \\String(kept.length)
    , "6");

    const before = dom.instance_bridge.deadSlotLookups(&browser);
    page_live = false;
    engine.destroyWindowRealm(page, .global_detached);
    // No getNodeBase of a slot the realm's end gave back.
    try testing.expectEqual(before, dom.instance_bridge.deadSlotLookups(&browser));
}
