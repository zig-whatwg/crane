//! Lane dm2 (batch B of tmp/plans/dom-memory-figure-design.md, sections 3.2 B
//! and 3.3): the trees that die with the node wrappers a full collection
//! found dead leave the figure INSIDE that collection, before the engine
//! computes its next threshold.
//!
//! Batch A took a tree's bytes out of the figure where the counts queue it
//! (tests/html/dm2_dying_figure_test.zig). For a tree only wrappers held that
//! is at the release of the dead wrappers' references - the agent's next
//! safe point, after the collection ended and V8 set its next limit with the
//! tree still counted (105.7 MB after the parser page's first collection,
//! 47 MB alive: lane dm1). Both browsers give their collector survivors only
//! (dom.dying_trees has the sources).
//!
//! Each test drops what it made, then runs ONE full collection inside a
//! teardown hold (engine.holdTeardowns): the hold keeps every release and
//! finalizer waiting, so the state the test reads there is exactly what the
//! engine saw when it computed its limits - the wrappers dead, no reference
//! released, no tree queued. The rule itself (dom.dying_trees.predict) is
//! asked there too, with a set the test owns in place of the collection's.
//! The pool's arithmetic alone is tests/runtime/dm2_predicted_dead_test.zig.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;
const engine = h.engine;

const DeferredTeardown = runtime.gc.DeferredTeardown;
const ExternalMemory = runtime.gc.ExternalMemory;
const DeadWrapper = runtime.lifetime.DeadWrapper;

fn instanceOf(node: *dom.NodeBase) !*runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return error.NotANode));
}

fn memoryOf(page: h.Page) *ExternalMemory {
    return &page.browser.scope.dom_memory;
}

fn queueOf(page: h.Page) *DeferredTeardown {
    return &page.browser.agent_host.deferred_teardown;
}

fn turn(page: h.Page) !void {
    _ = try page.browser.runEventLoopBlocking(20);
}

fn bytesOf(root: *dom.NodeBase) usize {
    return dom.tree_teardown.measureUpTo(root, DeferredTeardown.high_water).bytes;
}

/// The record the adapter keeps for a wrapper its collector found dead.
fn deadWrapperOf(node: *dom.NodeBase) !DeadWrapper {
    const instance = try instanceOf(node);
    return .{ .target = node, .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
}

/// The figure and its books at one moment.
const Figures = struct {
    live: usize,
    dying: usize,
    predicted: usize,
    /// What the engine counts as external memory: what it was last told.
    told: usize,
    pending_nodes: usize,
    books: DeferredTeardown.Books,

    fn read(page: h.Page, agent: *engine.Agent) Figures {
        const memory = memoryOf(page);
        const queue = queueOf(page);
        return .{
            .live = memory.live,
            .dying = memory.dying,
            .predicted = memory.predicted,
            .told = engine.heapStatistics(agent).external,
            .pending_nodes = queue.pendingNodes(),
            .books = queue.books,
        };
    }
};

/// `before`: what the test dropped is unreachable, nothing collected yet.
/// `held`: one full collection ran inside a teardown hold - the wrappers are
/// dead, their references not released. `after`: the hold ended, and every
/// finalizer and release it kept waiting ran.
const Phases = struct {
    before: Figures,
    held: Figures,
    after: Figures,
};

/// One full collection inside a teardown hold, with the page's realm
/// entered; `context.whileHeld()` runs while the hold lasts (no script may
/// run there).
fn collectUnderHold(page: h.Page, context: anytype) !Phases {
    const Context = @TypeOf(context.*);
    const Run = struct {
        page: h.Page,
        context: *Context,
        phases: Phases = undefined,
        failure: ?anyerror = null,

        fn run(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const realm = self.page.browser.getRealm() orelse return error.NoRealm;
            const agent = self.page.browser.getAgent() orelse return error.NoAgent;
            self.phases.before = Figures.read(self.page, agent);
            {
                const hold = engine.holdTeardowns(realm);
                defer hold.release();
                engine.requestGarbageCollection(agent);
                self.phases.held = Figures.read(self.page, agent);
                try self.context.whileHeld();
            }
            self.phases.after = Figures.read(self.page, agent);
        }
    };
    var run: Run = .{ .page = page, .context = context };
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    try engine.runInRealm(realm, Run.run, &run);
    if (run.failure) |err| return err;
    return run.phases;
}

/// A collection's memory of the trees it has seen, owned by the test: what
/// dom.dying_trees.predict asks in place of engine.traceVisitOnce's set.
const Seen = struct {
    state: *State,

    const State = struct {
        roots: [32]*const dom.NodeBase = undefined,
        len: usize = 0,
        /// How often the rule asked.
        asked: usize = 0,
        taken: [32]*runtime.Instance = undefined,
        taken_len: usize = 0,

        /// The collection's walk kept `root`'s tree.
        fn keep(self: *State, root: *const dom.NodeBase) void {
            self.roots[self.len] = root;
            self.len += 1;
        }

        fn took(self: *const State, root: *runtime.Instance) bool {
            for (self.taken[0..self.taken_len]) |taken| {
                if (taken == root) return true;
            }
            return false;
        }
    };

    pub fn once(self: Seen, root: *const dom.NodeBase) bool {
        const state = self.state;
        state.asked += 1;
        for (state.roots[0..state.len]) |seen| {
            if (seen == root) return false;
        }
        state.keep(root);
        return true;
    }

    pub fn took(self: Seen, root: *runtime.Instance) void {
        self.state.taken[self.state.taken_len] = root;
        self.state.taken_len += 1;
    }
};

fn predictWith(page: h.Page, state: *Seen.State, dead: []const DeadWrapper) dom.dying_trees.Prediction {
    return dom.dying_trees.predict(memoryOf(page), dead, Seen{ .state = state });
}

const Nothing = struct {
    fn whileHeld(_: *Nothing) !void {}
};

/// Free what the test queued, and check the page ends with nothing dying.
fn settle(page: h.Page) !void {
    for (0..64) |_| {
        if (queueOf(page).isEmpty()) break;
        try turn(page);
    }
    try testing.expect(queueOf(page).isEmpty());
    try testing.expectEqual(@as(usize, 0), memoryOf(page).dying);
    try testing.expectEqual(@as(usize, 0), memoryOf(page).predicted);
}

/// THE DESIGN'S RED FOR BATCH B, on the host's own figure: 20,000 detached
/// divs die in one full collection. On main (and on batch A alone) the
/// figure and V8's count hold all of them when the collection ends - each is
/// taken out only when its wrapper's reference is released, after V8 set its
/// next limit.
fn theDeadLeaveTheFigureInsideTheCollection() !void {
    if (engine.capabilities.external_memory_at_collection == .unsupported or engine.capabilities.heap_statistics == .unsupported) return error.SkipZigTest;
    const page = try h.Page.open();
    defer page.close();
    const count: usize = 20_000;
    try page.run("globalThis.keep = []; for (let i = 0; i < 20000; i++) keep.push(document.createElement('div'));");
    const per_div = bytesOf(try page.node("keep[0]"));
    try testing.expect(per_div >= runtime.SlabAllocator.slot_bytes + @sizeOf(dom.NodeBase));
    const all = count * per_div;
    try testing.expect(all > 16 * ExternalMemory.report_step);
    // A safe point: the engine is told the figure with all of them alive.
    try page.run("void document.body;");
    try page.run("globalThis.keep = null;");

    var nothing: Nothing = .{};
    const phases = try collectUnderHold(page, &nothing);
    const before = phases.before;
    const held = phases.held;
    const after = phases.after;
    const slack = 2 * ExternalMemory.report_step;

    // INSIDE THE COLLECTION, no reference released and no tree queued: the
    // divs are out of the figure, and the engine was told so.
    const fell = before.live -| held.live;
    const told_fell = before.told -| held.told;
    if (fell < all or told_fell + slack < all)
        std.debug.print("20,000 divs ({d} B) died in one collection: before any release the figure fell {d} B ({d} -> {d}) and the engine's count {d} B ({d} -> {d}); predicted {d} B\n", .{ all, fell, before.live, held.live, told_fell, before.told, held.told, held.predicted });
    // Nothing was queued inside the hold.
    try testing.expect(held.pending_nodes <= before.pending_nodes);
    try testing.expect(held.predicted >= all);
    try testing.expect(fell >= all);
    try testing.expect(told_fell + slack >= all);
    try testing.expect(held.books.predicted - before.books.predicted >= count);
    try testing.expect(held.books.predicted_bytes - before.books.predicted_bytes >= all);
    // Still counted: none of them was freed.
    try testing.expect((before.live + before.dying) -| (held.live + held.dying) <= 4096);

    // THE RELEASES: each div is queued and takes its bytes from the pool.
    // The figure does not move, nothing is put back, and none was alive.
    const moved = if (after.live > held.live) after.live - held.live else held.live - after.live;
    if (moved > 4096 or after.predicted != 0)
        std.debug.print("the releases moved the figure {d} B ({d} -> {d}); {d} B still predicted; {d} B put back\n", .{ moved, held.live, after.live, after.predicted, after.books.put_back_bytes - held.books.put_back_bytes });
    try testing.expect(moved <= 4096);
    try testing.expectEqual(@as(usize, 0), after.predicted);
    try testing.expect(after.pending_nodes >= held.pending_nodes + count);
    try testing.expectEqual(held.books.put_back_bytes, after.books.put_back_bytes);
    try testing.expectEqual(held.books.mispredicted, after.books.mispredicted);
    try testing.expect(after.books.queued - held.books.queued >= count);

    try settle(page);
}

test "20,000 divs that die in one full collection leave the figure and the engine's count inside it, before any reference is released" {
    try h.onFreshThread(theDeadLeaveTheFigureInsideTheCollection);
}

/// The rule's shapes for detached trees, each asked while the wrappers are
/// dead and unreleased.
const DetachedShapes = struct {
    page: h.Page,
    /// A div that is its tree's only held node.
    lone: *dom.NodeBase,
    /// A tree two of whose nodes were wrapped: its root and a child.
    root: *dom.NodeBase,
    child: *dom.NodeBase,
    /// A second tree like it.
    kept_root: *dom.NodeBase,
    kept_child: *dom.NodeBase,

    fn whileHeld(self: *DetachedShapes) !void {
        const page = self.page;
        // The wrappers are dead and their references not released.
        for ([_]*dom.NodeBase{ self.lone, self.root, self.child, self.kept_root, self.kept_child }) |node| {
            try testing.expect(node.wrapper.isEmpty());
            try testing.expect(dom.refcount.isHeld(node));
        }
        try testing.expect(!self.root.rc_flags.garbage);

        // A lone root: its tree, without a question to the collection's set.
        {
            var seen: Seen.State = .{};
            const found = predictWith(page, &seen, &.{try deadWrapperOf(self.lone)});
            try testing.expectEqual(@as(usize, 1), found.trees);
            try testing.expectEqual(@as(usize, 1), found.nodes);
            try testing.expectEqual(bytesOf(self.lone), found.bytes);
            try testing.expectEqual(@as(usize, 0), seen.asked);
            try testing.expect(seen.took(try instanceOf(self.lone)));
        }
        // Two dead wrappers of one tree, in either order: the tree once.
        for ([_][2]*dom.NodeBase{ .{ self.root, self.child }, .{ self.child, self.root } }) |order| {
            var seen: Seen.State = .{};
            const found = predictWith(page, &seen, &.{ try deadWrapperOf(order[0]), try deadWrapperOf(order[1]) });
            try testing.expectEqual(@as(usize, 1), found.trees);
            try testing.expectEqual(@as(usize, 61), found.nodes);
            try testing.expectEqual(bytesOf(self.root), found.bytes);
            try testing.expectEqual(@as(usize, 2), seen.asked);
            try testing.expect(seen.took(try instanceOf(self.root)));
        }
        // A tree the collection's walk kept is alive (the walk enters a
        // tree with a held node below its root in the collection's set).
        {
            var seen: Seen.State = .{};
            seen.keep(self.kept_root);
            const found = predictWith(page, &seen, &.{ try deadWrapperOf(self.kept_root), try deadWrapperOf(self.kept_child) });
            try testing.expectEqual(@as(usize, 0), found.trees);
            try testing.expectEqual(@as(usize, 0), found.bytes);
            try testing.expectEqual(@as(usize, 2), seen.asked);
        }
        // A root a remover still works on, and one its creator has not handed
        // on, are natively held: not taken. (The flags are refcount.zig's;
        // set here only for the question, and put back.)
        {
            var seen: Seen.State = .{};
            self.lone.rc_flags.removal_held = true;
            const removing = predictWith(page, &seen, &.{try deadWrapperOf(self.lone)});
            self.lone.rc_flags.removal_held = false;
            self.lone.rc_flags.creator = true;
            const created = predictWith(page, &seen, &.{try deadWrapperOf(self.lone)});
            self.lone.rc_flags.creator = false;
            try testing.expectEqual(@as(usize, 0), removing.trees);
            try testing.expectEqual(@as(usize, 0), created.trees);
        }
        // A record whose node was freed since (its slab generation moved) is
        // not read.
        {
            var seen: Seen.State = .{};
            var stale = try deadWrapperOf(self.lone);
            stale.generation +%= 1;
            try testing.expectEqual(@as(usize, 0), predictWith(page, &seen, &.{stale}).trees);
        }
        // All of them at once: three trees.
        {
            var seen: Seen.State = .{};
            const found = predictWith(page, &seen, &.{ try deadWrapperOf(self.lone), try deadWrapperOf(self.root), try deadWrapperOf(self.child), try deadWrapperOf(self.kept_child), try deadWrapperOf(self.kept_root) });
            try testing.expectEqual(@as(usize, 3), found.trees);
            try testing.expectEqual(bytesOf(self.lone) + bytesOf(self.root) + bytesOf(self.kept_root), found.bytes);
        }
    }
};

fn whichDetachedTreesDie() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.lone = document.createElement('div');
        \\globalThis.root = document.createElement('section');
        \\root.innerHTML = '<p><b>x</b></p>'.repeat(20);
        \\globalThis.child = root.firstChild;
        \\globalThis.keptRoot = document.createElement('section');
        \\keptRoot.innerHTML = '<p><b>x</b></p>'.repeat(20);
        \\globalThis.keptChild = keptRoot.lastChild;
    );
    var shapes: DetachedShapes = .{
        .page = page,
        .lone = try page.node("lone"),
        .root = try page.node("root"),
        .child = try page.node("child"),
        .kept_root = try page.node("keptRoot"),
        .kept_child = try page.node("keptChild"),
    };
    const expected = bytesOf(shapes.lone) + bytesOf(shapes.root) + bytesOf(shapes.kept_root);
    try page.run("lone = root = child = keptRoot = keptChild = null;");
    const phases = try collectUnderHold(page, &shapes);

    // The collection itself decided the same three trees, where the engine
    // can be told inside it; and all three were queued at their releases.
    if (engine.capabilities.external_memory_at_collection != .unsupported) {
        try testing.expect(phases.held.predicted >= expected);
        try testing.expect(phases.held.books.predicted - phases.before.books.predicted >= 3);
        try testing.expectEqual(phases.held.books.put_back_bytes, phases.after.books.put_back_bytes);
        try testing.expectEqual(phases.held.books.mispredicted, phases.after.books.mispredicted);
    }
    try testing.expectEqual(@as(usize, 0), phases.after.predicted);
    try testing.expect(phases.after.books.queued - phases.held.books.queued >= 3);
    try settle(page);
}

test "which detached trees die with their dead wrappers: once a tree, not one the walk kept, not one a remover or a creator holds" {
    try h.onFreshThread(whichDetachedTreesDie);
}

/// THE CASE THE COUNTS CANNOT SEE (design 3.3): a collection of a div's
/// descendants holds a counted reference on the div and dies in the same
/// collection as the div's wrapper. A replay of the release on the counts
/// says the div stays (one reference left); the marks say nothing kept
/// reaches it, and it dies.
const DeadHolder = struct {
    page: h.Page,
    root: *dom.NodeBase,

    fn whileHeld(self: *DeadHolder) !void {
        // The wrapper's reference and the collection's, both unreleased.
        try testing.expect(self.root.wrapper.isEmpty());
        try testing.expect(dom.refcount.count(self.root) >= 2);
        var seen: Seen.State = .{};
        const found = predictWith(self.page, &seen, &.{try deadWrapperOf(self.root)});
        try testing.expectEqual(@as(usize, 1), found.trees);
        try testing.expectEqual(bytesOf(self.root), found.bytes);
    }
};

fn aTreeADeadHolderStillNamesDies() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.root = document.createElement('div');
        \\root.innerHTML = '<p><b>x</b></p>'.repeat(200);
        \\globalThis.paragraphs = root.getElementsByTagName('p');
        \\void paragraphs.length;
    );
    var holder: DeadHolder = .{ .page = page, .root = try page.node("root") };
    const expected = bytesOf(holder.root);
    try testing.expect(dom.refcount.count(holder.root) >= 2);
    try page.run("root = paragraphs = null;");
    const phases = try collectUnderHold(page, &holder);

    if (engine.capabilities.external_memory_at_collection != .unsupported) {
        try testing.expect(phases.held.predicted >= expected);
        try testing.expect(phases.before.live -| phases.held.live >= expected);
        // The holder's finalizer and the wrapper's release both ran: the
        // tree was queued, and nothing went back.
        try testing.expectEqual(phases.held.books.put_back_bytes, phases.after.books.put_back_bytes);
        try testing.expectEqual(phases.held.books.mispredicted, phases.after.books.mispredicted);
    }
    try testing.expectEqual(@as(usize, 0), phases.after.predicted);
    try testing.expect(phases.after.pending_nodes >= phases.held.pending_nodes + 601);
    try settle(page);
}

test "a tree whose only other reference belongs to a holder that died in the same collection dies with its wrapper" {
    try h.onFreshThread(aTreeADeadHolderStillNamesDies);
}

/// WHAT THE RULE DOES NOT SEE (design 3.3): a native reference a root's
/// flags do not show. The tree is predicted dead and lives; its bytes are
/// out of the figure from the collection to the releases, and back then.
fn aTreePredictedDeadThatLivesIsPutBack() !void {
    if (engine.capabilities.external_memory_at_collection == .unsupported) return error.SkipZigTest;
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.root = document.createElement('div'); root.innerHTML = '<p><b>x</b></p>'.repeat(700);");
    const root = try page.node("root");
    // A native holder of a node below the root, never wrapped: pending work
    // (an image's load) holds its node this way.
    const below = root.first_child orelse return error.NoChild;
    dom.refcount.holderRef(below);
    var released = false;
    errdefer if (!released) dom.refcount.holderDeref(below);
    const bytes = bytesOf(root);
    try testing.expect(bytes > 2 * ExternalMemory.report_step);
    try page.run("void document.body;");
    try page.run("root = null;");

    var nothing: Nothing = .{};
    const phases = try collectUnderHold(page, &nothing);
    const before = phases.before;
    const held = phases.held;
    const after = phases.after;

    // Predicted dead inside the collection.
    try testing.expect(held.predicted >= bytes);
    try testing.expect(before.live -| held.live >= bytes);
    // The release left it alive (its holder's reference): never queued, and
    // its bytes are back in the figure.
    try testing.expect(!root.rc_flags.garbage);
    try testing.expectEqual(@as(usize, 0), after.predicted);
    try testing.expect(after.live >= held.live + bytes);
    try testing.expect(after.books.put_back_bytes - held.books.put_back_bytes >= bytes);
    if (DeferredTeardown.prediction_checks)
        try testing.expectEqual(held.books.mispredicted + 1, after.books.mispredicted);
    // The engine hears of the growth at the next safe point.
    try page.run("void document.body;");
    const agent = page.browser.getAgent() orelse return error.NoAgent;
    const told_again = engine.heapStatistics(agent).external;
    try testing.expect(told_again + 2 * ExternalMemory.report_step >= held.told + bytes);

    // Its holder lets go: the counts queue it, and it is freed.
    released = true;
    dom.refcount.holderDeref(below);
    try testing.expect(root.rc_flags.garbage);
    try testing.expect(memoryOf(page).dying >= bytes);
    try settle(page);
}

test "a tree predicted dead that a native reference keeps is back in the figure after the releases, and counted as a misprediction" {
    try h.onFreshThread(aTreePredictedDeadThatLivesIsPutBack);
}

/// The rule's shapes for Documents.
const DocumentShapes = struct {
    page: h.Page,
    /// A document script made and dropped, with its body wrapped.
    plain: *dom.NodeBase,
    plain_body: *dom.NodeBase,
    /// A document with one held detached element, both dropped.
    owner: *dom.NodeBase,
    detached: *dom.NodeBase,
    /// A document a native holder keeps.
    held: *dom.NodeBase,

    fn whileHeld(self: *DocumentShapes) !void {
        const page = self.page;
        for ([_]*dom.NodeBase{ self.plain, self.plain_body, self.owner, self.detached, self.held }) |node| {
            try testing.expect(node.wrapper.isEmpty());
        }
        // A Document and a node of its tree, in either order: one tree.
        for ([_][2]*dom.NodeBase{ .{ self.plain, self.plain_body }, .{ self.plain_body, self.plain } }) |order| {
            var seen: Seen.State = .{};
            const found = predictWith(page, &seen, &.{ try deadWrapperOf(order[0]), try deadWrapperOf(order[1]) });
            try testing.expectEqual(@as(usize, 1), found.trees);
            try testing.expectEqual(bytesOf(self.plain), found.bytes);
            try testing.expect(seen.took(try instanceOf(self.plain)));
        }
        // Without its own wrapper among the dead its reference is not
        // explained: a Document is judged by its count.
        {
            var seen: Seen.State = .{};
            try testing.expectEqual(@as(usize, 0), predictWith(page, &seen, &.{try deadWrapperOf(self.plain_body)}).trees);
        }
        // A Document a native holder keeps (a Window keeps its document so).
        {
            var seen: Seen.State = .{};
            try testing.expectEqual(@as(usize, 0), predictWith(page, &seen, &.{try deadWrapperOf(self.held)}).trees);
        }
        // A Document waits for its held detached trees (refcount decision
        // D6): with its detached element dying too, both die - in either
        // order; with the element not among the dead, neither is taken as
        // the Document's.
        try testing.expectEqual(@as(?u32, 1), dom.refcount.documentForeignHolds(self.owner));
        for ([_][2]*dom.NodeBase{ .{ self.owner, self.detached }, .{ self.detached, self.owner } }) |order| {
            var seen: Seen.State = .{};
            const found = predictWith(page, &seen, &.{ try deadWrapperOf(order[0]), try deadWrapperOf(order[1]) });
            try testing.expectEqual(@as(usize, 2), found.trees);
            try testing.expectEqual(bytesOf(self.owner) + bytesOf(self.detached), found.bytes);
        }
        {
            var seen: Seen.State = .{};
            try testing.expectEqual(@as(usize, 0), predictWith(page, &seen, &.{try deadWrapperOf(self.owner)}).trees);
        }
    }
};

fn whichDocumentsDie() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.plain = document.implementation.createHTMLDocument('plain');
        \\plain.body.innerHTML = '<p>x</p>'.repeat(50);
        \\globalThis.plainBody = plain.body;
        \\globalThis.owner = document.implementation.createHTMLDocument('owner');
        \\globalThis.detached = owner.createElement('article');
        \\globalThis.held = document.implementation.createHTMLDocument('held');
    );
    var shapes: DocumentShapes = .{
        .page = page,
        .plain = try page.node("plain"),
        .plain_body = try page.node("plainBody"),
        .owner = try page.node("owner"),
        .detached = try page.node("detached"),
        .held = try page.node("held"),
    };
    dom.refcount.holderRef(shapes.held);
    var released = false;
    errdefer if (!released) dom.refcount.holderDeref(shapes.held);
    const expected = bytesOf(shapes.plain) + bytesOf(shapes.owner) + bytesOf(shapes.detached);
    try page.run("plain = plainBody = owner = detached = held = null;");
    const phases = try collectUnderHold(page, &shapes);

    if (engine.capabilities.external_memory_at_collection != .unsupported) {
        // The collection decided the same: the plain document, the owner
        // and its detached element - and not the document a holder keeps.
        try testing.expect(phases.held.predicted >= expected);
        try testing.expect(phases.held.books.predicted - phases.before.books.predicted >= 3);
        try testing.expectEqual(phases.held.books.put_back_bytes, phases.after.books.put_back_bytes);
        try testing.expectEqual(phases.held.books.mispredicted, phases.after.books.mispredicted);
    }
    try testing.expectEqual(@as(usize, 0), phases.after.predicted);
    try testing.expect(phases.after.books.queued - phases.held.books.queued >= 3);
    try testing.expect(!shapes.held.rc_flags.garbage);

    released = true;
    dom.refcount.holderDeref(shapes.held);
    try testing.expect(shapes.held.rc_flags.garbage);
    try settle(page);
}

test "which Documents die with their dead wrappers: judged by their count, and with their held detached trees" {
    try h.onFreshThread(whichDocumentsDie);
}
