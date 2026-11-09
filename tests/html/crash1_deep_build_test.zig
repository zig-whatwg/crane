//! A tree 150,000 levels deep moves into a document and out again without a
//! native frame per level (lane crash1 batch 3; the zero-crashes rule).
//!
//! The insert and remove steps walk the moved subtree: its connected flags
//! (mutation.setConnectedRecursive), its insertion and removing steps in
//! shadow-including tree order (tree_helpers.collectShadowIncludingDescendants,
//! behind insert step 7.7 and remove step 14). Both recursed once per level,
//! so appending a deep detached tree to the body, or removing it, overflowed
//! the native stack - unreachable while building such a tree cost O(nodes x
//! depth), reachable once the per-insert ancestor walks answer a new leaf in
//! O(1) (this batch). They are loops now (tree_helpers.ShadowIncludingWalk),
//! as Blink's NotifyNodeInsertedInternal walks NodeTraversal.
//!
//! The tree is built natively, 500 levels at a time, each chunk built
//! top-down in a detached root and then appended to the previous chunk's
//! leaf: a test build checks the reference counts around every mutation
//! (refcount.checkAround, O(depth) per insert by design), so a single chain
//! built one node at a time is quadratic in any test build however cheap the
//! insert steps are. The insert steps' own cost at depth is measured in the
//! release runner instead (the batch's probes).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const Browser = @import("browser").Browser;

const depth = 150_000;
const chunk = 500;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// Run `body` with a fresh Browser's document under a leak-counting
/// DebugAllocator, on a thread with a pinned 8 MiB stack (a main thread's):
/// the Browser's end must free everything.
fn withDocument(comptime body: fn (*runtime.Instance) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            runBody() catch |err| {
                failure.* = err;
            };
        }

        fn runBody() !void {
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
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{ .stack_size = 8 * 1024 * 1024 }, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn newDiv(document: *runtime.Instance) !*runtime.Instance {
    return interfaces.Document.call_createElement(document, str("div"), .notPassed());
}

/// `levels` divs nested under `parent`, built a chunk at a time; answers the
/// deepest.
fn chain(document: *runtime.Instance, parent: *runtime.Instance, levels: usize) !*runtime.Instance {
    var leaf = parent;
    var made: usize = 0;
    while (made < levels) {
        const k = @min(chunk, levels - made);
        const top = try newDiv(document);
        var bottom = top;
        for (1..k) |_| bottom = try interfaces.Node.call_appendChild(bottom, try newDiv(document));
        _ = try interfaces.Node.call_appendChild(leaf, top);
        leaf = bottom;
        made += k;
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

test "a 150,000-level detached tree appended to the body and removed again" {
    try withDocument(struct {
        fn body(document: *runtime.Instance) !void {
            const root = try newDiv(document);
            const leaf = try chain(document, root, depth);
            try testing.expectEqual(@as(usize, depth), try levelsBelow(root));
            try testing.expect(!try interfaces.Node.get_isConnected(leaf));
            const body_element = (try interfaces.Document.get_body(document)).?;
            _ = try interfaces.Node.call_appendChild(body_element, root);
            try testing.expect(try interfaces.Node.get_isConnected(leaf));
            _ = try interfaces.Node.call_removeChild(body_element, root);
            try testing.expect(!try interfaces.Node.get_isConnected(leaf));
            // In again, to go with the document at the Browser's end.
            _ = try interfaces.Node.call_appendChild(body_element, root);
        }
    }.body);
}

test "a 150,000-level tree built under the body, a chunk at a time, is connected to its leaf" {
    try withDocument(struct {
        fn body(document: *runtime.Instance) !void {
            const body_element = (try interfaces.Document.get_body(document)).?;
            const leaf = try chain(document, body_element, depth);
            try testing.expect(try interfaces.Node.get_isConnected(leaf));
            try testing.expectEqual(@as(usize, depth), try levelsBelow(body_element));
        }
    }.body);
}
