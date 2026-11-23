//! A Browser's heap and its window event loop (lane hard1, allocator-
//! hardening batch A; tmp/plans/allocator-hardening-design.md 3.5, 5.1,
//! items 5-7 of section 7's batch A): the loop runs the heap's task-scoped
//! quarantine while it runs a task and purges it as the task ends, gives the
//! heap's empty spans back once it has been idle a while, and a Browser that
//! asked for poisoned frees (the bug-finding runner's) runs the heap's
//! bug-finding configuration. The span engine's own tests:
//! tests/runtime/hard1_state_heap_test.zig.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const platform = @import("platform");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;

fn engineOf(browser: *Browser) !@TypeOf(browser.scope.existingHeapEngine().?) {
    return browser.scope.existingHeapEngine() orelse error.NoHeap;
}

fn realNs() i64 {
    return @intCast(platform.monotonicNow().ns);
}

test "a Browser's window loop holds what a task frees until the task ends" {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const engine = try engineOf(browser);
    const loop = browser.event_loop orelse return error.NoEventLoop;
    try testing.expectEqual(engine, loop.heap.?);

    const Scope = @TypeOf(browser.scope.*);
    const Probe = struct {
        scope: *Scope,
        engine: @TypeOf(engine),
        active: bool = false,
        held: bool = false,
        block: ?[*]u8 = null,

        fn run(context: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.active = self.engine.quarantine.active.load(.monotonic);
            const block = self.scope.arena.createRaw(112, 8) catch return;
            self.scope.arena.destroyRaw(block, 112, 8);
            self.held = self.engine.isQuarantined(block);
            self.block = block;
        }
    };
    var probe: Probe = .{ .scope = browser.scope, .engine = engine };
    loop.eventLoop().queueTask(.{ .callback = Probe.run, .context = &probe });
    _ = try browser.runEventLoopBlocking(50);
    try testing.expect(probe.active);
    try testing.expect(probe.held);
    // The task ended: nothing is held, and nothing is held between turns.
    try testing.expect(!engine.isQuarantined(probe.block.?));
    try testing.expectEqual(@as(usize, 0), engine.stats().quarantine_bytes);
    try testing.expect(!engine.quarantine.active.load(.monotonic));
}

test "an idle Browser gives its heap's empty spans back" {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const engine = try engineOf(browser);
    const loop = browser.event_loop orelse return error.NoEventLoop;
    _ = try browser.runEventLoopBlocking(20);
    const start = engine.stats().objects.committed_span_bytes;

    // A churn of 50,000 State-sized blocks, made and freed outside a task.
    const count = 50_000;
    const blocks = try testing.allocator.alloc([*]u8, count);
    defer testing.allocator.free(blocks);
    for (blocks) |*block| block.* = try browser.scope.arena.createRaw(112, 8);
    try testing.expect(engine.stats().objects.committed_span_bytes >= start + count * 112);
    for (blocks) |block| browser.scope.arena.destroyRaw(block, 112, 8);

    // The loop idles: past its idle delay (200 ms) and the spans' age (1 s),
    // its idle turns decommit them.
    const began = realNs();
    while (realNs() - began < 1_800 * std.time.ns_per_ms) _ = loop.runOnceBlocking(100);
    const after = engine.stats().objects;
    try testing.expect(after.spans_decommitted > 0);
    // Back to within a span (at most 64 KiB, on any host) of the start.
    try testing.expect(after.committed_span_bytes <= start + 64 * 1024);
}

test "a Browser's heap runs the build's configuration, and the bug-finding one where the Browser asked for poisoned frees" {
    const plain = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer plain.deinit();
    const engine = try engineOf(plain);
    // A Debug build's Browser poisons (the unit tests, the bug-finding
    // runner's Crane modules); a release build's zeroes.
    try testing.expectEqual(builtin.mode == .debug, engine.config.fill == .poison);
    try testing.expect(!engine.config.retire_freed_spans);

    const asked = try Browser.init(testing.allocator, .{ .snapshot_path = "", .poison_freed_state = true });
    defer asked.deinit();
    const bug_finding = try engineOf(asked);
    try testing.expect(bug_finding.config.fill == .poison);
    try testing.expect(bug_finding.config.retire_freed_spans);
    try testing.expect(bug_finding.config.record_sites);
    try testing.expectEqual(@as(usize, 8 * 1024 * 1024), bug_finding.config.quarantine_cap);
}
