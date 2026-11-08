//! A tree built one node at a time costs O(nodes), not O(nodes x depth)
//! (lane crash1 batch 3; the deep-construction item of crash1's sweep:
//! 30,000 levels took more than 60 s in Crane's release runner, 2.6 s in
//! Chrome).
//!
//! Each insert under a deep parent walked the parent's whole ancestry several
//! times (a Debug runner's sample over a 30,000-level build:
//! isConnectedThroughShadow 757 samples, isDescendant 375,
//! isHostIncludingInclusiveAncestor 370, rootOf 333, hasInterestedObservers
//! and its registered-observer iteration 426): pre-insertion validity's
//! "host-including inclusive ancestor" check, the connectedness walk to the
//! root, the slot steps' root, and the mutation observers' ancestor walk.
//! Each now answers a new leaf in constant time, as Blink and WebKit do -
//! WebKit's Node::isDescendantOf returns at `!other.hasChildNodes()`, their
//! isConnected flags, Blink's IsInShadowTree bit, and their per-document
//! "has mutation observers of type" flags (here the agent's DOM mutation
//! observer counter).
//!
//! The test is the build itself: 150,000 levels, top-down, in a detached
//! tree and in the document, in a Debug build and under the launcher's
//! timeout. At O(nodes x depth) that is over 10^10 ancestor visits - hours;
//! at O(nodes) it is seconds. The detached tree is then appended to the body
//! and removed again: the insert and remove steps' walks over the moved
//! subtree (its connected flags, its insertion and removing steps) recursed
//! once per level and overflowed the native stack at this depth; they are
//! loops now (tree_helpers.ShadowIncludingWalk). The nodes are made natively: a script-made
//! node is wrapped, and a wrapped node's link still adds its holds up the
//! ancestry (refcount.linkChild's walk, the queued remainder).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const Browser = @import("browser").Browser;

const depth = 150_000;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// Run `body` with a fresh Browser's document under a leak-counting
/// DebugAllocator: the Browser's end must free everything.
fn withDocument(comptime body: fn (*runtime.Instance) anyerror!void) !void {
    var debug: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    {
        const browser = try Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        _ = try browser.runEventLoopBlocking(10);
        try body(page.document_instance orelse return error.NoDocument);
    }
    const leaked = debug.debug.detectLeaks();
    _ = debug.deinit();
    if (leaked != 0) std.debug.print("{d} allocations leaked\n", .{leaked});
    try testing.expectEqual(@as(usize, 0), leaked);
}

/// `levels` divs nested under `parent`, one appendChild a level, each into
/// the deepest; answers the deepest.
fn chain(document: *runtime.Instance, parent: *runtime.Instance, levels: usize) !*runtime.Instance {
    var leaf = parent;
    for (0..levels) |_| {
        const div = try interfaces.Document.call_createElement(document, str("div"), .notPassed());
        _ = try interfaces.Node.call_appendChild(leaf, div);
        leaf = div;
    }
    return leaf;
}

fn levelsBelow(root: *runtime.Instance) !usize {
    var at = root;
    var levels: usize = 0;
    while (try interfaces.Node.get_firstChild(at)) |child| {
        at = child;
        levels += 1;
    }
    return levels;
}

test "150,000 levels appended one at a time into a detached tree" {
    try withDocument(struct {
        fn body(document: *runtime.Instance) !void {
            const root = try interfaces.Document.call_createElement(document, str("div"), .notPassed());
            _ = try chain(document, root, depth);
            try testing.expectEqual(@as(usize, depth), try levelsBelow(root));
            // Into the document whole: the inserted subtree's steps are
            // O(subtree) once (it becomes connected), not per level.
            const body_element = (try interfaces.Document.get_body(document)).?;
            _ = try interfaces.Node.call_appendChild(body_element, root);
            const leaf = try deepest(root);
            try testing.expect(try interfaces.Node.get_isConnected(leaf));
            // And out again: the removal's walks over the subtree are loops too.
            _ = try interfaces.Node.call_removeChild(body_element, root);
            try testing.expect(!try interfaces.Node.get_isConnected(leaf));
        }

        fn deepest(root: *runtime.Instance) !*runtime.Instance {
            var at = root;
            while (try interfaces.Node.get_firstChild(at)) |child| at = child;
            return at;
        }
    }.body);
}

test "150,000 levels appended one at a time in the document" {
    try withDocument(struct {
        fn body(document: *runtime.Instance) !void {
            const body_element = (try interfaces.Document.get_body(document)).?;
            const leaf = try chain(document, body_element, depth);
            try testing.expect(try interfaces.Node.get_isConnected(leaf));
            try testing.expectEqual(@as(usize, depth), try levelsBelow(body_element));
        }
    }.body);
}
