//! Lane wr1 batch 10, the deep review's appendix-wr1 F6
//! (tmp/redesign/review/source/appendix-wr1.md): the Debug check the wrapper
//! design promised and nobody built - "a Debug check in the batch free asserts
//! every slot is empty" (tmp/redesign/wrapper-redesign-design.md 4.9,
//! "Browser end"; risk 8 of tmp/redesign/node-memory-architecture.md).
//!
//! The check lives in Node.zig's releaseNodeBase, which both frees reach: a
//! node's own teardown and the Browser's final sweep (Node.sweepOne). In a
//! Debug build it panics, naming the node's interface, when the NodeBase is
//! released with its engine wrapper slot still bound - an engine reference
//! to the slot (V8's node anchor) would outlive the bytes it names. Today
//! the order alone keeps it empty: Browser.deinit ends every node wrapper
//! (engine.releaseNodeWrappers) before the drain and the sweeps.
//!
//! This file ends a Browser whose script still holds wrapped nodes - detached
//! ones, a detached tree, a node in the document - so every one of them is
//! released after its wrapper ended, under the check. Its negative control,
//! run once by hand (lane wr1 batch 10's report): with releaseNodeWrappers
//! taken out of Browser.deinit, the held nodes survive the drain, the sweep
//! releases them with their slots bound, and the check panics here.

const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn endWithWrappedNodes() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  globalThis.kept = [];
        \\  for (let i = 0; i < 100; i++) kept.push(document.createElement('div'));
        \\  const tree = document.createElement('section');
        \\  tree.append(document.createElement('p'), 'text');
        \\  kept.push(tree, tree.firstChild, tree.lastChild);
        \\  document.body.append(document.createElement('span'));
        \\  kept.push(document.body.lastChild);
        \\  return String(kept.length);
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("104", result);
}

test "wr10 F6: a Browser that ends while script holds wrapped nodes releases every one with its wrapper slot empty" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            endWithWrappedNodes() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
