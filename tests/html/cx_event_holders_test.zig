//! A FocusEvent keeps its relatedTarget, and a ToggleEvent its source, by a
//! traced edge from the event (engine.traceChild). An event made natively -
//! html/focus.zig's focus and blur, a details toggle - has no wrapper yet, so
//! the protocol holds the target until the event's wrapper exists; an event
//! freed without ever being wrapped (dispatched to no listener, then
//! releaseIfUnwrapped) must let that hold go in its deinit, or the target
//! leaks. And the event never frees the target it was given.
//!
//! Each test runs on a thread of its own: it starts a Browser, and tests/html
//! is one process.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const browser_mod = @import("browser");
const testing = std.testing;

fn counter(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
    return error.NoSuchCounter;
}

/// The global handles of THIS Browser's agent: the engine's
/// `global_handle_bytes`, V8's used global handle bytes of the isolate
/// current on this thread - the Browser's, whose top-level realm keeps it
/// entered here. Not the process's live Global<Object> count, which every
/// Browser of the process moves (beside the many-Browsers variant's busy
/// Browser it moved by 30: docs/testing/test-variant-findings-2026-11-02.tsv
/// M2; docs/lessons/testing-a-test-that-measures-a-process-wide-counter-
/// assumes-it-is-alone.md).
fn browserHandleBytes() !i64 {
    return counter("global_handle_bytes");
}

/// That the bytes are the Browser's, shown rather than assumed: a value of
/// `realm` held raises them, and its release lowers them back.
fn expectReadsTheBrowsersIsolate(realm: runtime.Context, instance: *runtime.Instance) !void {
    const before = try browserHandleBytes();
    const held = try engine.retainValue(realm, .{ .instance = instance });
    const holding = try browserHandleBytes();
    held.release();
    try testing.expect(holding > before);
    try testing.expectEqual(before, try browserHandleBytes());
}

const Kind = enum { focus, toggle };

fn makeEvent(kind: Kind, realm: runtime.Context, target: *runtime.Instance) !*runtime.Instance {
    return switch (kind) {
        .focus => interfaces.FocusEvent.call_constructor(realm, runtime.DOMString.initInterned("blur"), .passed(.{
            .base = .{ .base = .{} },
            .relatedTarget = target,
        })),
        .toggle => interfaces.ToggleEvent.call_constructor(realm, runtime.DOMString.initInterned("toggle"), .passed(.{
            .base = .{},
            .source = target,
        })),
    };
}

fn heldTarget(kind: Kind, event: *runtime.Instance) !?*runtime.Instance {
    return switch (kind) {
        .focus => interfaces.FocusEvent.get_relatedTarget(event),
        .toggle => interfaces.ToggleEvent.get_source(event),
    };
}

fn exercise(kind: Kind) !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const button = try interfaces.HTMLButtonElement.init(testing.allocator, realm);
    const generation = runtime.SlabAllocator.generationOf(button);
    // The button has a wrapper before the event exists, so what the event
    // adds is only its own hold.
    (try engine.retainValue(realm, .{ .instance = button })).release();
    try testing.expect(engine.hasWrapper(button));
    try expectReadsTheBrowsersIsolate(realm, button);

    const before = try browserHandleBytes();
    for (0..8) |_| {
        const event = try makeEvent(kind, realm, button);
        try testing.expect(!engine.hasWrapper(event));
        try testing.expectEqual(button, (try heldTarget(kind, event)).?);
        event.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(event));
    }
    const after = try browserHandleBytes();
    if (after != before) std.debug.print("{s}: the Browser's global handle bytes {d} -> {d} after 8 unwrapped events\n", .{ @tagName(kind), before, after });
    try testing.expectEqual(before, after);
    // The event never frees what it was given.
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(button));
    try testing.expect(!runtime.instance_lifecycle.isCleanedUp(button));
}

fn onThread(kind: Kind) !void {
    const Run = struct {
        fn run(k: Kind, result: *?anyerror) void {
            exercise(k) catch |err| {
                std.debug.print("{s} holder fixture failed: {s}\n", .{ @tagName(k), @errorName(err) });
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ kind, &result });
    thread.join();
    if (result) |err| return err;
}

test "an unwrapped FocusEvent lets its relatedTarget hold go, and never frees the target" {
    try onThread(.focus);
}

test "an unwrapped ToggleEvent lets its source hold go, and never frees the source" {
    try onThread(.toggle);
}

test "engine-free: a FocusEvent and a ToggleEvent report their target and free only their own state" {
    @import("interfaces").process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var ctx_data = try runtime.ContextData.init(testing.allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;
    const div = try interfaces.HTMLDivElement.init(testing.allocator, ctx);
    defer runtime.Instance.deinit(div);
    inline for (.{ Kind.focus, Kind.toggle }) |kind| {
        const event = try makeEvent(kind, ctx, div);
        try testing.expectEqual(div, (try heldTarget(kind, event)).?);
        runtime.Instance.deinit(event);
    }
}
