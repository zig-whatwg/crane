//! A tree of any depth is torn down in constant stack, by every exit a node
//! has (lane crash1 batch 2; the zero-crashes rule).
//!
//! Node.deinit used to call each child's teardown, whose Node.deinit called
//! its children's: one set of frames per tree level, so a 10,000-deep tree
//! overflowed the stack when it went (crash1's sweep: a SIGSEGV in the WPT
//! runner at the teardown of the previous file's tree; Chrome 156 and
//! Firefox 159 build and drop 30,000-deep trees). It now frees the subtree
//! leaves first, each node unlinked before its own teardown
//! (dom.tree_teardown.freeAllDescendants), as WebKit's
//! removeDetachedChildrenInContainer unlinks each child before its last
//! reference goes.
//!
//! Each test builds a 100,000-deep tree by script - of nodes the HTML parser
//! made (innerHTML) or of nodes appendChild nested - and lets it go one way:
//! with its document at the realm's end, with its collected root (the
//! agent's deferred teardown, a slice at a time), as an unwrapped orphan at
//! the realm's end (runtime.orphan_roots), through its template, and through
//! the Browser's final sweep. Each runs on a thread with an 8 MiB stack - a
//! main thread's - under a leak-counting DebugAllocator (0 leaks). The
//! recursive teardown overflowed that stack in a Debug build at 10,000 levels
//! (3 to 4 KiB a level; red before the fix in the three realm-end cases).
//!
//! The trees are built in chunks - 500 levels a chunk, each chunk's root
//! appended to the previous chunk's deepest node - because inserting a node
//! costs O(its depth) today (the queued deep-construction perf item: the
//! insert steps walk the ancestors - mutation.isConnectedThroughShadow,
//! isHostIncludingInclusiveAncestor, rootOf, hasInterestedObservers), so
//! 100,000 single-node appends would take minutes; 200 appends of a chunk
//! take a fraction of a second. A parser chunk stays under the HTML parser's
//! depth cap (512).
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const Browser = @import("browser").Browser;

const depth = 100_000;
const depth_text = std.fmt.comptimePrint("{d}", .{depth});

/// `deepChain(parent, n, viaParser)`: nest `n` new levels under `parent`, in
/// chunks of 500, and answer the deepest node. A chunk is made by innerHTML
/// on a scratch div (`viaParser`: the nodes the HTML parser makes, only each
/// chunk's root and leaf wrapped) or by one appendChild a level; its root is
/// then appended to the previous chunk's leaf.
const chain_helper =
    \\globalThis.deepChain = (parent, n, viaParser) => {
    \\  let leaf = parent;
    \\  for (let made = 0; made < n; made += 500) {
    \\    const k = Math.min(500, n - made);
    \\    let top, bottom;
    \\    if (viaParser) {
    \\      const scratch = document.createElement('div');
    \\      scratch.innerHTML = '<span>'.repeat(k);
    \\      top = scratch.firstChild;
    \\      bottom = scratch.querySelector(':empty');
    \\    } else {
    \\      top = bottom = document.createElement('div');
    \\      for (let i = 1; i < k; i++) bottom = bottom.appendChild(document.createElement('div'));
    \\    }
    \\    leaf.appendChild(top);
    \\    leaf = bottom;
    \\  }
    \\  return leaf;
    \\};
;

/// A slab slot and the generation it had: whether the object is still there.
const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Watched {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Watched) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

const Page = struct {
    browser: *Browser,

    fn open(allocator: std.mem.Allocator) !Page {
        const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        _ = try browser.runEventLoopBlocking(10);
        try page.runScript(chain_helper);
        return .{ .browser = browser };
    }

    /// Run `source`; a thrown error fails the test.
    fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    fn expect(self: Page, source: []const u8, want: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        const got = try page.evaluateScriptToString(source, self.browser.allocator);
        defer self.browser.allocator.free(got);
        if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
        try testing.expectEqualStrings(want, got);
    }

    fn document(self: Page) !*runtime.Instance {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.document_instance orelse error.NoDocument;
    }

    /// The element with id `id`, found natively (nothing is wrapped).
    fn byId(self: Page, id: []const u8) !*runtime.Instance {
        return (try interfaces.Document.call_getElementById(try self.document(), runtime.DOMString.initInterned(id))) orelse error.NoElement;
    }

    fn body(self: Page) !*runtime.Instance {
        return (try interfaces.Document.get_body(try self.document())) orelse error.NoBody;
    }
};

/// How many levels below `root` its first-child chain goes, read natively.
fn levelsBelow(root: *runtime.Instance) !usize {
    var at = root;
    var levels: usize = 0;
    while (try interfaces.Node.get_firstChild(at)) |child| {
        at = child;
        levels += 1;
    }
    return levels;
}

/// A new div of `document`'s, made natively (never wrapped).
fn newDiv(document: *runtime.Instance) !*runtime.Instance {
    return interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
}

/// Run `body` with a fresh Browser on a thread with an 8 MiB stack, under a
/// leak-counting DebugAllocator: the Browser's end must free everything.
fn withPage(comptime body: fn (Page) anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            runBody() catch |err| {
                failure.* = err;
            };
        }

        fn runBody() !void {
            var debug: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
            {
                const page = try Page.open(debug.allocator());
                defer page.browser.deinit();
                try body(page);
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

test "a 100,000-deep appendChild chain in the document goes with its realm" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run("deepChain(document.body, " ++ depth_text ++ ", false).id = 'leaf';");
            try testing.expectEqual(@as(usize, depth), try levelsBelow(try page.body()));
            // The Browser's end tears the document down: its realm's
            // coordinated teardown, through Node.deinit.
        }
    }.body);
}

test "a 100,000-deep tree of parser-made nodes in the document goes with its realm" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run("deepChain(document.body, " ++ depth_text ++ ", true);");
            try testing.expectEqual(@as(usize, depth), try levelsBelow(try page.body()));
        }
    }.body);
}

test "a 100,000-deep detached tree goes with its collected root, a slice at a time" {
    try withPage(struct {
        fn body(page: Page) !void {
            // Built in the document so the native walk finds it, then
            // removed: the agent's deferred teardown frees the tree once the
            // root's wrapper - and the few wrappers below it - are collected.
            try page.run("document.body.innerHTML = '<div id=root></div>'; deepChain(document.getElementById('root'), " ++ depth_text ++ ", true).id = 'leaf';");
            const leaf = Watched.of(try page.byId("leaf"));
            try testing.expectEqual(@as(usize, depth), try levelsBelow(try page.byId("root")));
            try page.run("document.getElementById('root').remove();");
            for (0..3) |_| {
                try page.run("TestUtils.gc(); TestUtils.gc();");
                for (0..10) |_| _ = try page.browser.runEventLoopBlocking(10);
            }
            try testing.expect(!leaf.alive());
        }
    }.body);
}

test "a 100,000-deep appendChild chain, detached and dropped, goes with its collected root" {
    try withPage(struct {
        fn body(page: Page) !void {
            // Every node wrapped: the collection takes the whole tree's
            // wrappers, and the root's teardown frees what is left.
            try page.run("globalThis.root = document.createElement('div'); deepChain(root, " ++ depth_text ++ ", false).id = 'leaf'; document.body.appendChild(root);");
            const leaf = Watched.of(try page.byId("leaf"));
            try page.run("root.remove(); delete globalThis.root;");
            for (0..3) |_| {
                try page.run("TestUtils.gc(); TestUtils.gc();");
                for (0..10) |_| _ = try page.browser.runEventLoopBlocking(10);
            }
            try testing.expect(!leaf.alive());
        }
    }.body);
}

test "a 100,000-deep tree whose root script never reached goes as an orphan at its realm's end" {
    try withPage(struct {
        fn body(page: Page) !void {
            // The root, the parser's <section>, is never wrapped: removed by
            // innerHTML = '' it is an orphan, which the realm's end frees
            // (runtime.orphan_roots) through deinitNodeByType.
            try page.run("document.body.innerHTML = '<section><p></p></section>'; deepChain(document.querySelector('p'), " ++ depth_text ++ ", true);");
            try testing.expectEqual(@as(usize, depth + 2), try levelsBelow(try page.body()));
            try page.run("document.body.innerHTML = '';");
            try page.expect("document.body.childNodes.length", "0");
        }
    }.body);
}

test "a 100,000-deep tree in a template's contents goes with its template" {
    try withPage(struct {
        fn body(page: Page) !void {
            try page.run("{ const t = document.createElement('template'); t.id = 't'; document.body.appendChild(t); deepChain(t.content, " ++ depth_text ++ ", true); }");
            try page.expect("document.getElementById('t').content.firstChild.localName", "span");
        }
    }.body);
}

test "a 100,000-deep tree no script ever reached goes in the Browser's final sweep" {
    try withPage(struct {
        fn body(page: Page) !void {
            // Made natively, never inserted into the document or wrapped: an
            // orphan only the final registry sweep frees. In chunks, as the
            // script builds do.
            dom.refcount_teardown.allowLiveNodesAtAgentEnd(&page.browser.agent_host.deferred_teardown, "a deep orphan tree reaches the final sweep, which is what this tests");
            const document = try page.document();
            const root = try newDiv(document);
            var leaf = root;
            var made: usize = 0;
            while (made < depth) : (made += 500) {
                const top = try newDiv(document);
                var bottom = top;
                for (1..500) |_| bottom = try interfaces.Node.call_appendChild(bottom, try newDiv(document));
                _ = try interfaces.Node.call_appendChild(leaf, top);
                leaf = bottom;
            }
            try testing.expectEqual(@as(usize, depth), try levelsBelow(root));
        }
    }.body);
}
