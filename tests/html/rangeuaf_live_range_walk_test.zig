//! A document's live-range list, walked by the mutation algorithms while the
//! ranges script let go of are torn down under the walk (lane rangeuaf).
//!
//! Each walk step that sets a boundary redraws the range's edge to its node
//! (engine.traceChild), an engine call that allocates; the collection that
//! allocation starts first runs, in its prologue, every teardown the previous
//! collection left pending (V8 Heap::CollectGarbage, "Ensure that all pending
//! phantom callbacks are invoked") - the dropped ranges', each leaving the
//! list. The walks held a slice of it and read a vacated slot: SIGSEGV at
//! 0xaaaaaaaaaaaaaaaa in mutation.runLiveRangePreRemoveSteps, from Codex row
//! 73's sl2-cost-selection.html on main.
//!
//! Script keeps every 997th range, so a walk that skipped a range after a
//! removal, or moved one twice, fails an assertion rather than passing.
//! std.testing.allocator, or a DebugAllocator per Browser in the two-thread
//! case, so a leak fails too.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const onFreshThread = @import("edges_node_holders_helpers.zig").onFreshThread;

/// "remove" steps 4-7 after 300,000 ranges were made in the removed node.
const removal_script =
    \\(() => {
    \\  const paragraph = document.body.appendChild(document.createElement('p'));
    \\  const texts = [];
    \\  for (let i = 0; i < 1000; i++) texts.push(paragraph.appendChild(document.createTextNode('live range')));
    \\  const kept = [];
    \\  for (let i = 0; i < 300000; i++) {
    \\    const range = document.createRange();
    \\    range.setStart(texts[i % 1000], i % 2);
    \\    if (i % 997 === 0) kept.push(range);
    \\  }
    \\  const index = Array.prototype.indexOf.call(document.body.childNodes, paragraph);
    \\  paragraph.remove();
    \\  for (const range of kept) {
    \\    if (range.startContainer !== document.body || range.startOffset !== index)
    \\      throw new Error('start not moved: ' + range.startContainer + ' ' + range.startOffset);
    \\    if (range.endContainer !== document.body || range.endOffset !== index)
    \\      throw new Error('end not moved: ' + range.endContainer + ' ' + range.endOffset);
    \\  }
    \\})();
;

/// "split a Text node" steps 7.2-7.5, the same walk over the same list.
const split_script =
    \\(() => {
    \\  const texts = [];
    \\  for (let i = 0; i < 1000; i++) texts.push(document.body.appendChild(document.createTextNode('selection text')));
    \\  const kept = [];
    \\  for (let i = 0; i < 300000; i++) {
    \\    const range = document.createRange();
    \\    range.setStart(texts[i % 1000], 10);
    \\    if (i % 997 === 0) kept.push([range, texts[i % 1000]]);
    \\  }
    \\  for (const text of texts) text.splitText(5);
    \\  for (const [range, text] of kept) {
    \\    if (range.startContainer !== text.nextSibling || range.startOffset !== 5)
    \\      throw new Error('split did not move the start');
    \\  }
    \\  for (const text of texts) text.nextSibling.remove();
    \\  for (const text of texts) text.remove();
    \\})();
;

fn runPage(allocator: std.mem.Allocator, script: []const u8) !void {
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    page.runScript(script) catch |err| {
        std.debug.print("script failed: {s}\n", .{script});
        return err;
    };
    // The teardowns still pending run at the turn, outside any walk.
    _ = try browser.runEventLoopBlocking(20);
}

fn removalAfterChurn() !void {
    try runPage(testing.allocator, removal_script);
}

fn splitAfterChurn() !void {
    try runPage(testing.allocator, split_script);
}

test "removing a node after 300,000 ranges were made in it moves every live range it holds" {
    try onFreshThread(removalAfterChurn);
}

test "splitting text after 300,000 ranges were made in it moves every live range it holds" {
    try onFreshThread(splitAfterChurn);
}

/// Two Browsers on two threads at once, each walking its own document's
/// list while its own collections tear its ranges down: each Browser's
/// allocator is its own DebugAllocator, so the threads do not take turns on
/// a shared allocator's lock (docs/lessons/testing-a-shared-test-allocator-
/// makes-two-browsers-take-turns.md) and each checks its own leaks.
const Side = struct {
    failure: ?anyerror = null,
    leaked: bool = false,

    fn run(self: *Side) void {
        var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer self.leaked = debug_allocator.deinit() == .leak;
        runPage(debug_allocator.allocator(), removal_script ++ split_script) catch |err| {
            self.failure = err;
        };
    }
};

test "two Browsers on two threads churn live ranges and walk their own lists at once" {
    var sides: [2]Side = .{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| {
        if (side.failure) |err| return err;
        try testing.expect(!side.leaked);
    }
}
