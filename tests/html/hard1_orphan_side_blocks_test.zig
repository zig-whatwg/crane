//! Lane hard1: what a node held past every realm's end keeps outside its
//! State block is freed at its Browser's end.
//!
//! A node alive when its agent ends is never torn down one by one: the final
//! sweep (dom.teardown_sweeps, refcount decision D9) frees its side tables,
//! and the scope's end releases its State block and slot
//! (BrowserScope.releaseSweptNodes). Two node types still keep a block of
//! their own outside the State, made in their init and freed by their deinit
//! - a ProcessingInstruction's and an HTMLLinkElement's InternalState - and
//! the sweep never returned it: the old state arena freed it wholesale. The
//! span engine frees per block, and its leak report at each Browser's end
//! named them in the full worklist's bug-finding sweep (84ca03d13, 4 Browser
//! ends): ProcessingInstruction.InternalState 76 blocks of 80 B,
//! HTMLLinkElement.InternalState 27 of 64 B.
//!
//! Each test makes such nodes natively, never inserted or wrapped, and keeps
//! them past every realm's end with a counted hold of its own (as
//! nodeholds_teardown_test does), let go in a sweep of its own after the
//! Document's. It reads what the heap still holds once the final sweep's
//! nodes went (BrowserScope.heap_leak_count_out).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

const held_count = 8;

/// The test's holds, let go by its sweep after the Document's - the window
/// nodeholds_teardown_test's probe reads a node in.
const Holds = struct {
    var counted: [held_count]dom.node_holds.CountedRef = @splat(.{});
    var nodes: [held_count]?*runtime.Instance = @splat(null);

    fn sweep(_: *runtime.BrowserScope) void {
        for (&counted, &nodes) |*hold, *node| {
            if (node.*) |n| hold.release(n);
            node.* = null;
        }
    }
};

const Kind = enum { processing_instruction, link };

/// The heap blocks a Browser's end still finds after `held_count` nodes of
/// `kind` were kept past every realm's end.
fn blocksLeftAfterHolding(kind: Kind) !usize {
    var left: usize = std.math.maxInt(usize);
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    var browser_alive = true;
    defer if (browser_alive) browser.deinit();
    dom.refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "the test's holds keep its nodes past every realm's end: the final sweep is what it tests");
    browser.scope.heap_leak_count_out = &left;
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const document = context.document_instance orelse return error.NoDocument;

    for (&Holds.counted, &Holds.nodes) |*hold, *slot| {
        const node = switch (kind) {
            .processing_instruction => try interfaces.Document.call_createProcessingInstruction(document, runtime.DOMString.initInterned("x-pi"), runtime.DOMString.initInterned("data")),
            .link => try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("link"), .{ .was_passed = false, .value = undefined }),
        };
        const base = dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse return error.NoNodeBase;
        hold.take(node, base);
        slot.* = node;
    }

    const probe = dom.teardown_sweeps.withSweepForTest(.documents, &Holds.sweep);
    defer probe.restore();
    browser_alive = false;
    browser.deinit();
    return left;
}

fn processingInstructionsLeaveNothing() !void {
    const left = try blocksLeftAfterHolding(.processing_instruction);
    if (left != 0) std.debug.print("{d} heap block(s) left at the Browser's end\n", .{left});
    try testing.expectEqual(@as(usize, 0), left);
}

test "ProcessingInstructions held past every realm's end leave no InternalState block behind" {
    try helpers.onFreshThread(processingInstructionsLeaveNothing);
}

fn linksLeaveNothing() !void {
    const left = try blocksLeftAfterHolding(.link);
    if (left != 0) std.debug.print("{d} heap block(s) left at the Browser's end\n", .{left});
    try testing.expectEqual(@as(usize, 0), left);
}

test "link elements held past every realm's end leave no InternalState block behind" {
    try helpers.onFreshThread(linksLeaveNothing);
}
