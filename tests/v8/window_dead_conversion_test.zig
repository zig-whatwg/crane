//! A Window that has been torn down converts to null, and is never wrapped as
//! an ordinary object (lane winslot1, E3).
//!
//! A Window's one wrapper is its realm's global object: the conversion hands
//! back the global the Window is bound to (Window's bound_v8_global). Its
//! teardown (interfaces.Window.deinit, what a realm's end runs) frees its
//! internal state, and the bound global with it - and the conversion then
//! fell through to the ordinary path: a plain object of the Window template,
//! internal field 0 the torn-down Window, cached in whatever realm was
//! current. That cache's sweep, at its realm's end, then ran the Window's
//! destructor chain a SECOND time and returned its slab slot - a Window
//! freed by a realm that never owned it, while every holder of it read on.
//! Any native holder could reach it: `ev.view`, `ev.source` or `ev.target`
//! read after the source frame's realm ended.
//!
//! Blink's DOMWindow::Wrap answers v8::Null for a window with no frame; a
//! torn-down Window has no global to answer with, so it is null too.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn evalOwned(realm: runtime.Context, source: []const u8) ![]u8 {
    return protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, Ignored.reporter);
}

/// The vtable's own deinit, counted: a second run is the defect.
const Counting = struct {
    var runs: usize = 0;
    var original: *const fn (*runtime.Instance) void = undefined;
    fn deinit(instance: *runtime.Instance) void {
        runs += 1;
        original(instance);
    }
};

test "a torn-down Window converts to null and its slot is not another realm's to free" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });

    // A Window torn down as a realm's end tears its Window down: its
    // destructor chain only; its slot stays issued. Its vtable is a copy
    // that counts how often that chain runs.
    var counting_vtable = interfaces.Window.vtable;
    Counting.original = interfaces.Window.vtable.deinit.?;
    counting_vtable.deinit = &Counting.deinit;
    Counting.runs = 0;
    const window = try interfaces.Window.init(std.heap.c_allocator, realm);
    window.vtable = &counting_vtable;
    window.vtable.deinit.?(window);
    const generation = runtime.SlabAllocator.generationOf(window);

    // A holder hands it to script.
    {
        const global = try protocol.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(realm, global.value, "held", .{ .instance = window });
    }
    const held = try evalOwned(realm, "String(held === null)");
    defer testing.allocator.free(held);

    // The realm that read it ends: its wrapper cache's sweep must neither run
    // the Window's destructor again nor free its slot.
    protocol.destroyWindowRealm(realm, .global_detached);
    const runs = Counting.runs;
    const freed = runtime.SlabAllocator.generationOf(window) != generation;

    if (!std.mem.eql(u8, held, "true") or runs != 1 or freed)
        std.debug.print("held === null: {s}; destructor runs: {d}; slot freed by the other realm: {}\n", .{ held, runs, freed });
    try testing.expectEqualStrings("true", held);
    try testing.expectEqual(@as(usize, 1), runs);
    try testing.expect(!freed);

    // The test's own Window: its storage back now.
    runtime.instance_lifecycle.markCleanupComplete(window);
    runtime.gc.releaseStorage(window);
}
