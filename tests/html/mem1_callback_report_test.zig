//! A DOM-heavy callback that allocates little on V8's own heap: the growth
//! it reports at its bindings' returns makes V8 collect inside it, and the
//! trees whose wrappers that collection found dead are freed inside it
//! (lane mem1, the report step of follow-up A).
//!
//! Before, the report was owed only to depth zero, which a callback's
//! bindings never reach: one timer callback that replaces a wrapped 100 KB
//! subtree 1,500 times told V8 nothing, V8 ran no full collection inside it,
//! and every replaced subtree stayed whole - held by a wrapper nothing
//! collected - until the callback returned. V8 reacts to reported growth
//! past 64 MB above its low since the last mark-compact
//! (v8::internal::Internals::kExternalAllocationSoftLimit, include/
//! v8-internal.h:1122; Heap::HandleExternalMemoryInterrupt, src/heap/
//! heap.cc:1445-1496, V8 15.7.112.43), so the loop grows the DOM by 150 MB.
//!
//! The figures are read from inside the callback, at its last statement, by
//! a developer-console host (console.log('end')).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const loop_settle = @import("loop_settle.zig");
const dev = browser_mod.Browser.developer_console;

const replacements = 1500;

/// The current isolate's full collections so far (the adapter's diagnostic
/// counters).
fn fullCollections() i64 {
    var bytes: [64 * @sizeOf(engine.Counter)]u8 align(@alignOf(engine.Counter)) = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&bytes);
    const read = engine.diagnosticCounters(fixed.allocator()) catch return -1;
    for (read) |c| if (std.mem.eql(u8, c.name, "full_gc_count")) return c.value;
    return -1;
}

/// What the callback's last statement saw.
const AtEnd = struct {
    browser: *browser_mod.Browser,
    seen: bool = false,
    full_collections: i64 = 0,
    freed_in_callbacks: usize = 0,
    live_objects: usize = 0,

    fn report(context: *anyopaque, message: *const dev.Message) void {
        const self: *AtEnd = @ptrCast(@alignCast(context));
        if (!std.mem.eql(u8, message.text, "end")) return;
        self.seen = true;
        self.full_collections = fullCollections();
        self.freed_in_callbacks = self.browser.agent_host.deferred_teardown.freed_in_callbacks;
        self.live_objects = self.browser.scope.slab.stats().currently_allocated;
    }
};

const Run = struct { full_collections: i64, freed_in_callbacks: usize, live_objects: usize };

fn replaceInOneCallback() !Run {
    var churn = @import("root").poisoning.ChurnAllocator.init("mem1_callback_report_test: replaced subtrees in one timer callback");
    var run: Run = undefined;
    {
        const browser = try browser_mod.Browser.init(churn.allocator(), .{ .snapshot_path = "" });
        defer browser.deinit();
        var at_end: AtEnd = .{ .browser = browser };
        try browser.attachDeveloperConsole(.{ .context = &at_end, .report = AtEnd.report });
        defer browser.detachDeveloperConsole();
        try browser.navigate("about:blank", .window);
        const context = browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        // One shared string (no V8 allocation per replacement): a 100 KB
        // subtree of 51 nodes. Reading `firstChild` wraps its root, so the
        // replaced subtree is held by that wrapper until V8 collects it.
        try context.runScript(
            \\globalThis.host = document.body.appendChild(document.createElement('div'));
            \\globalThis.subtree = '<div>' + ('<p>' + 'x'.repeat(4000) + '</p>').repeat(25) + '</div>';
            \\globalThis.replace = (n) => {
            \\  for (let i = 0; i < n; i++) {
            \\    host.innerHTML = subtree;
            \\    void host.firstChild;
            \\  }
            \\  console.log('end');
            \\};
        );
        const before = fullCollections();
        try context.runScript(std.fmt.comptimePrint("setTimeout(() => replace({d}), 0);", .{replacements}));
        try loop_settle.settle(browser);
        if (!at_end.seen) return error.CallbackDidNotEnd;
        run = .{
            .full_collections = at_end.full_collections - before,
            .freed_in_callbacks = at_end.freed_in_callbacks,
            .live_objects = at_end.live_objects,
        };
    }
    try churn.deinit();
    return run;
}

fn collectsInsideTheCallback() !void {
    const run = try replaceInOneCallback();
    std.debug.print("{d} replacements in one timer callback: {d} full collections inside it, {d} nodes freed inside callbacks, {d} live objects at its end\n", .{ replacements, run.full_collections, run.freed_in_callbacks, run.live_objects });
    try testing.expect(run.full_collections > 0);
    try testing.expect(run.freed_in_callbacks > 0);
}

test "a DOM-heavy timer callback's reported growth makes V8 collect inside it, and the trees it found dead are freed there" {
    const Thread = struct {
        fn go(failure: *?anyerror) void {
            collectsInsideTheCallback() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Thread.go, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
