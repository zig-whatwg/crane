//! A Document's back/forward cache state that other code records and reads:
//! HTML "make document unsalvageable" and the document's "bfcache blocking
//! details" (7.4.6.2; the reasons are html_core.navigation.not_restored_reasons).
//!
//! A document is salvageable until something says it cannot be kept in the
//! back/forward cache - an aborted fetch or parser, a WebSocket or a held
//! lock its unload ended - and each such step records its reason. The state
//! is the Document's; Document installs this hook from its installHooks,
//! and the owners of those steps (WebSocket, LockManager, the navigation
//! code) call it without naming Document's impl. Crane keeps no document in
//! the cache yet (phase B of the back/forward cache): unload makes every
//! document unsalvageable (step 9), and the reasons recorded here are what
//! performance.getEntriesByType("navigation")[0].notRestoredReasons reports
//! for the document a later traversal makes in its place.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#make-document-unsalvageable
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bfcache-blocking-details
//!
//! lint-impls: hook for Document
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const not_restored_reasons = @import("html_core").navigation.not_restored_reasons;

pub const Reason = not_restored_reasons.Reason;

/// What Document supplies.
pub const Implementation = struct {
    /// HTML "make document unsalvageable" given `document` and `reason`:
    /// the reason joins its bfcache blocking details, and it is no longer
    /// salvageable.
    make_unsalvageable: *const fn (document: *runtime.Instance, reason: Reason) void,
    /// `document`'s bfcache blocking details, in the order first recorded.
    /// BORROWED: valid until the next reason is recorded for it.
    blocking_details: *const fn (document: *runtime.Instance) []const Reason,
    /// The document's own part of "the user agent intends to keep
    /// oldDocument alive" (unload step 5): it is salvageable and its current
    /// document readiness is "complete" (Blink keeps only a loaded page).
    may_keep: *const fn (document: *runtime.Instance) bool = &neverKeep,
    /// The user agent intends to keep `document` (unload step 5's
    /// intendToKeepInBfcache, the navigable's answer): its next unload keeps
    /// it salvageable if it still may be kept then.
    intend_to_keep: *const fn (document: *runtime.Instance) void = &noIntent,
    /// Whether `document`'s last unload kept it - it was salvageable at
    /// step 20, so it was not destroyed - and nothing has destroyed or
    /// reactivated it since.
    is_kept: *const fn (document: *runtime.Instance) bool = &neverKeep,
    /// HTML "reactivate" `document`, in its realm, once it is its navigable's
    /// active document again: steps 1 and 4 (step 2 is the cache's - its
    /// timers - and step 3, the navigation API's entries, is phase C's).
    reactivate: *const fn (document: *runtime.Instance) void = &noIntent,
};

fn neverKeep(_: *runtime.Instance) bool {
    return false;
}

fn noIntent(_: *runtime.Instance) void {}

// process-wide: function pointers Document installs once at process start (crane.Process), the same for every instance
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// HTML "make document unsalvageable" given `document` and `reason`.
/// Nothing without an installed implementation (a context built for tests).
pub fn makeUnsalvageable(document: *runtime.Instance, reason: Reason) void {
    const impl = implementation orelse return;
    impl.make_unsalvageable(document, reason);
}

/// "Make document unsalvageable" given the associated Document of
/// `environment`'s global, when that global is a Window - the document whose
/// unloading document cleanup steps (dom.unloading_cleanup) are running for
/// the environment. A worker's environment has no document: nothing.
pub fn makeUnsalvageableIn(environment: runtime.Context, reason: Reason) void {
    const record = environment.realm orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    if (global.stateAs(interfaces.Window.State) == null) return;
    // The Window's own record of its document: with the engine running the
    // cross-origin checks (engine.capabilities.cross_origin_objects), the
    // getter's steps are "return this's associated Document" and nothing
    // else - no check against whatever realm is current.
    const document = interfaces.Window.get_document(global) catch return;
    makeUnsalvageable(document, reason);
}

/// `document`'s bfcache blocking details (BORROWED, see Implementation).
/// None without an installed implementation.
pub fn blockingDetails(document: *runtime.Instance) []const Reason {
    const impl = implementation orelse return &.{};
    return impl.blocking_details(document);
}

// ============================================================================
// Keeping a document (the back/forward cache, phase B)
// ============================================================================
//
// Unload step 5 leaves it to the user agent whether it "intends to keep
// oldDocument alive in a session history entry". Crane's answer has three
// parts, asked in this order by the navigation code before it unloads a
// top-level traversable's active document:
//
// 1. the navigable's: a top-level traversable Crane made (a popup), alone
//    in its browsing context group, whose document came from a GET of an
//    HTTP(S) URL answered 200, with no child navigables, in a Browser whose
//    cache keeps pages (the navigation code, with `cacheEnabled`);
// 2. its features': each owner of a feature a kept page cannot keep - a
//    held lock, a worker - says so (`installBlocker`), and the reason is
//    recorded with "make document unsalvageable" before pagehide fires, so
//    pagehide reports persisted false and not restored reasons name it;
// 3. the document's own: salvageable, and loaded (`mayKeep`).
//
// A document kept that way is unloaded without being destroyed. Its unload
// step 18 runs only the STORE steps (`installStoreStep`): the other
// specifications' unloading document cleanup steps (dom.unloading_cleanup)
// end what the page needs once it is restored - its custom element
// registry, its message ports, its blob URLs, its workers - so they run when
// the cached document is destroyed instead. Stated deviation from HTML, which
// runs them at every unload: Blink runs them at
// ExecutionContext::ContextDestroyed, when the document is destroyed, never
// when it is frozen into the cache, and WebKit keeps the page's objects
// alive in its CachedFrame (history/CachedFrame.cpp) until the page leaves
// the cache.

/// Why a feature's owner says a document cannot be kept.
pub const Blocked = union(enum) {
    /// "Make document unsalvageable" given the document and this reason: a
    /// reason the spec or a browser names, which not restored reasons
    /// report.
    reason: Reason,
    /// The user agent does not intend to keep it (unload step 5) - a limit
    /// of Crane's, with no reason any spec or browser reports.
    declined,
};

/// A feature's owner's answer for a document about to be kept: why
/// `environment` - the document's realm - cannot be kept, or null.
pub const BlockerQuery = *const fn (environment: runtime.Context) ?Blocked;

/// A feature's owner's step for a document the cache keeps, at its unload
/// (step 18): what must not outlive the page's leaving even though the page
/// is kept - an open WebSocket is failed.
pub const StoreStep = *const fn (environment: runtime.Context) void;

const max_owner_steps = 8;

/// The owners' queries and steps, installed at process start.
const OwnerSteps = struct {
    blockers: [max_owner_steps]BlockerQuery = undefined,
    blocker_count: usize = 0,
    store_steps: [max_owner_steps]StoreStep = undefined,
    store_step_count: usize = 0,
};

// process-wide: function pointers the feature owners (LockManager, Worker, SharedWorker, WebSocket) install once at process start (crane.Process), the same for every Browser and thread
var owner_steps: OwnerSteps = .{};

/// Install `query` (once, at process start). Idempotent.
pub fn installBlocker(query: BlockerQuery) void {
    process_start.assertInstalling();
    for (owner_steps.blockers[0..owner_steps.blocker_count]) |existing| {
        if (existing == query) return;
    }
    std.debug.assert(owner_steps.blocker_count < max_owner_steps);
    if (owner_steps.blocker_count == max_owner_steps) return;
    owner_steps.blockers[owner_steps.blocker_count] = query;
    owner_steps.blocker_count += 1;
}

/// Install `step` (once, at process start). Idempotent.
pub fn installStoreStep(step: StoreStep) void {
    process_start.assertInstalling();
    for (owner_steps.store_steps[0..owner_steps.store_step_count]) |existing| {
        if (existing == step) return;
    }
    std.debug.assert(owner_steps.store_step_count < max_owner_steps);
    if (owner_steps.store_step_count == max_owner_steps) return;
    owner_steps.store_steps[owner_steps.store_step_count] = step;
    owner_steps.store_step_count += 1;
}

/// Parts 2 and 3 for `document`, the active document of a navigable whose
/// own part said yes: every blocker's reason recorded ("make document
/// unsalvageable"), then whether the document may still be kept.
pub fn mayKeep(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    var declined = false;
    for (owner_steps.blockers[0..owner_steps.blocker_count]) |query| {
        const blocked = query(document.ctx) orelse continue;
        switch (blocked) {
            .reason => |reason| impl.make_unsalvageable(document, reason),
            .declined => declined = true,
        }
    }
    return impl.may_keep(document) and !declined;
}

/// Unload step 5: the user agent intends to keep `document`. Its next
/// unload keeps it if it is still salvageable and loaded then.
pub fn intendToKeep(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.intend_to_keep(document);
}

/// Whether `document`'s last unload kept it (see Implementation.is_kept).
pub fn isKept(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.is_kept(document);
}

/// Unload step 18 for a kept document: the store steps, for its realm.
pub fn runStoreSteps(environment: runtime.Context) void {
    for (owner_steps.store_steps[0..owner_steps.store_step_count]) |step| step(environment);
}

// ============================================================================
// The cache (the browser layer's: src/browser/back_forward_cache.zig)
// ============================================================================

/// A page the back/forward cache keeps: a top-level traversable's document
/// that its unload kept, its Window and realm - never detached, its global
/// still attached to its own WindowProxy - and what the navigation code
/// needs to evict or restore it.
pub const KeptPage = struct {
    /// The traversable (an html BrowsingContext) whose entry shows it.
    traversable: *anyopaque,
    /// Its session history entry's document state (joint_history).
    document_state: u64,
    document: *runtime.Instance,
    document_generation: u64,
    window: *runtime.Instance,
    window_generation: u64,
    realm: runtime.Context,
    /// The navigation code's record - what restoring the page needs back
    /// on its navigable - OWNED by the entry until `steps.evict` or the
    /// restore that takes it.
    data: *anyopaque,
    steps: *const PageSteps,

    /// Whether `object` - a Window or a Document - is this page's.
    pub fn has(self: *const KeptPage, object: *const anyopaque) bool {
        return object == @as(*const anyopaque, @ptrCast(self.window)) or object == @as(*const anyopaque, @ptrCast(self.document));
    }
};

/// What the navigation code does for a page leaving the cache.
pub const PageSteps = struct {
    /// Evict the page: its document destroyed, its tasks dropped, its realm
    /// ended, `data` freed. Called from a task (never inside the collector,
    /// never with the page's script on the stack); the page has left the
    /// cache already.
    evict: *const fn (page: *const KeptPage) void,
};

/// What the browser layer supplies (installed at process start).
pub const Cache = struct {
    /// Whether the Browser `realm` belongs to keeps pages
    /// (BrowserConfig.back_forward_cache_size > 0).
    enabled: *const fn (realm: runtime.Context) bool,
    /// Keep `page`: its tasks and timers suspended. False when it is not
    /// kept (no room, out of memory): the caller then destroys it as it
    /// would have without a cache.
    store: *const fn (page: KeptPage) bool,
    /// The page `traversable` keeps whose document is `document`, taken out
    /// of the cache for a restore - its tasks and timers still suspended
    /// until `resume_page`; null when the cache does not hold it.
    take: *const fn (traversable: *anyopaque, document: *const anyopaque) ?KeptPage,
    /// A taken page is its navigable's active one again: its tasks run, its
    /// timers wait what they had left (HTML "reactivate" step 2).
    resume_page: *const fn (page: *const KeptPage) void,
    /// A taken page that cannot be shown after all is evicted: its tasks
    /// dropped, then its steps.
    evict_taken: *const fn (page: *const KeptPage) void,
    /// Whether `object` - a Window or a Document - is a kept page's.
    holds: *const fn (object: *const anyopaque) bool,
    /// The page holding `object` leaves the cache to be destroyed, at a task
    /// queued now; `reason`, when given, is recorded for it first.
    evict: *const fn (object: *const anyopaque, reason: ?Reason) void,
    /// Every page `traversable` keeps is destroyed now (the traversable is
    /// closing; HTML "destroy a top-level traversable" destroys every entry's
    /// document). `realm` names the Browser: one of its realms.
    evict_traversable: *const fn (realm: runtime.Context, traversable: *anyopaque) void,
    /// Every page `traversable` keeps whose session history entry is gone
    /// (`has_state` says no for its document state) is destroyed now: HTML
    /// "clear the forward session history" destroys each removed entry's
    /// document. `realm` names the Browser.
    prune: *const fn (realm: runtime.Context, traversable: *anyopaque, context: *anyopaque, has_state: *const fn (context: *anyopaque, document_state: u64) bool) void,
};

// process-wide: function pointers the browser layer installs once at process start (crane.Process), the same for every Browser; each Browser's cache is its own (a supplement of its scope)
var cache: ?Cache = null;

/// Called by the browser layer's installHooks, once, at process start.
pub fn installCache(impl: Cache) void {
    process_start.assertInstalling();
    cache = impl;
}

/// Whether `realm`'s Browser keeps pages. False with no cache installed.
pub fn cacheEnabled(realm: runtime.Context) bool {
    const impl = cache orelse return false;
    return impl.enabled(realm);
}

/// Keep `page` (see Cache.store).
pub fn store(page: KeptPage) bool {
    const impl = cache orelse return false;
    return impl.store(page);
}

/// Take the page of `traversable` showing `document` out of the cache.
pub fn take(traversable: *anyopaque, document: *const anyopaque) ?KeptPage {
    const impl = cache orelse return null;
    return impl.take(traversable, document);
}

/// A taken page is active again (see Cache.resume_page), then HTML
/// "reactivate" for its document.
pub fn reactivate(page: *const KeptPage) void {
    if (cache) |impl| impl.resume_page(page);
    if (implementation) |impl| impl.reactivate(page.document);
}

/// Evict a page `take` handed out that will not be shown.
pub fn evictTaken(page: *const KeptPage) void {
    const impl = cache orelse return page.steps.evict(page);
    impl.evict_taken(page);
}

/// Whether `object` (a Window or a Document) belongs to a kept page.
pub fn holds(object: *const anyopaque) bool {
    const impl = cache orelse return false;
    return impl.holds(object);
}

/// Debug check, at the points host code enters a Window's realm to run its
/// script for a task or a callback (timers, animation frames, a socket's
/// events, a channel's message): `realm` is not a page the cache keeps. A
/// kept realm is never detached, so the engine's own guard - it refuses a
/// callback of a detached realm (protocol_callbacks CallbackRealm.runnable) -
/// does not cover it; phase B relies on nothing reaching a cached page's
/// script (its tasks wait in their group, its timers are suspended, nothing
/// outside it holds its objects), and this says so where it is relied on.
/// Phase C, whose cached pages keep frames, must revisit an engine-level
/// suspension (engine.suspendRealm) instead.
pub fn assertNotCached(realm: runtime.Context) void {
    if (!std.debug.runtime_safety) return;
    if (!realm.hasEngine()) return;
    const record = realm.realm orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    if (global.stateAs(interfaces.Window.State) == null) return;
    if (holds(global)) @panic("script of a page the back/forward cache keeps was about to run");
}

/// Evict the page holding `object`, recording `reason` (Chrome's
/// "broadcastchannel-message", for one) - the page cannot answer what is
/// being delivered to it (Blink kIgnoreEventAndEvict). Nothing when no page
/// holds it.
pub fn evict(object: *const anyopaque, reason: ?Reason) void {
    const impl = cache orelse return;
    impl.evict(object, reason);
}

/// Evict every page `traversable` keeps, now. `realm` names the Browser.
pub fn evictTraversable(realm: runtime.Context, traversable: *anyopaque) void {
    const impl = cache orelse return;
    impl.evict_traversable(realm, traversable);
}

/// Evict every page `traversable` keeps whose document state `has_state`
/// no longer finds, now (see Cache.prune).
pub fn prune(realm: runtime.Context, traversable: *anyopaque, context: *anyopaque, has_state: *const fn (context: *anyopaque, document_state: u64) bool) void {
    const impl = cache orelse return;
    impl.prune(realm, traversable, context, has_state);
}

// ============================================================================
// Building not restored reasons
// ============================================================================

const std = @import("std");
const Allocator = std.mem.Allocator;
const NotRestoredReasons = not_restored_reasons.NotRestoredReasons;
const navigables = @import("navigables.zig");
const global_settings = @import("global_settings.zig");
const origin_record = @import("origin_record.zig");
const reflection = @import("reflection.zig");

/// HTML "build not restored reasons for a top-level traversable and its
/// descendants", given the traversable's active `document`: the tree, OWNED
/// by `allocator`, which the caller keeps with the traversable's active
/// session history entry's document state ("build not restored reasons for
/// document state" step 7 - Crane's session history is the navigation
/// code's, which holds the tree). `Builder.begin` then `finish`, at once.
pub fn buildForTopLevelTraversable(document: *runtime.Instance, allocator: Allocator) Allocator.Error!NotRestoredReasons {
    var builder = try Builder.begin(document, allocator);
    defer builder.deinit();
    return builder.finish();
}

/// "Build not restored reasons for a top-level traversable and its
/// descendants" in two halves. HTML runs it at "unload a document" step 19,
/// after step 18's unloading document cleanup steps - which record reasons
/// ("websocket", "lock") - and before step 20 destroys the document. Crane's
/// navigation code runs the cleanup steps for the whole tree after every
/// document's unload, which destroys each one and with it its window
/// (Document.defaultView answers null), so the frame tree can no longer be
/// read then. So `begin` reads the tree while every document is still
/// fully active - each document's URL, its container's src, id and name,
/// whether it is same origin with the top-level document - and `finish`,
/// once the cleanup steps have run, copies each document's bfcache blocking
/// details (steps 5) and masks the cross-origin descendants (steps 2-6).
pub const Builder = struct {
    allocator: Allocator,
    /// The tree, reasons not yet filled in. Its nodes do not move after
    /// `begin`: `captured` points into it.
    tree: NotRestoredReasons,
    /// Each document of the tree, in tree order (the root first), with the
    /// node it fills in.
    captured: std.ArrayListUnmanaged(Captured) = .empty,
    finished: bool = false,

    const Captured = struct {
        /// Its node in `tree`; null for the root, `tree` itself (the
        /// Builder is returned by value, so its address is not kept).
        node: ?*NotRestoredReasons,
        document: *runtime.Instance,
        generation: u64,
        /// Not same origin with the top-level traversable's document: its
        /// node is masked (steps 3-5).
        cross_origin: bool,
    };

    /// Read `document`'s frame tree ("build not restored reasons for
    /// document state" steps 1-4 and 6, for it and each descendant).
    pub fn begin(document: *runtime.Instance, allocator: Allocator) Allocator.Error!Builder {
        var builder: Builder = .{ .allocator = allocator, .tree = .{} };
        errdefer builder.deinit();
        const top_window = (interfaces.Document.get_defaultView(document) catch null);
        try builder.read(&builder.tree, document, top_window, false, 0);
        return builder;
    }

    /// Fill in every document's reasons and mask the cross-origin ones: the
    /// tree, which the caller then owns. "Masked" is the top-level
    /// document's when a cross-origin descendant had reasons (step 6) - in
    /// the tree too, not only in the document's details: the spec builds
    /// the tree (step 1) before step 6 adds it, but Chromium - the one
    /// engine that ships NotRestoredReasons - reports it on the top-level
    /// document, and WPT's
    /// performance-navigation-timing-cross-origin-bfcache.tentative expects
    /// [masked] there (Edge 157 passes it on wpt.fyi).
    pub fn finish(self: *Builder) Allocator.Error!NotRestoredReasons {
        // Step 5 of each: a clone of its bfcache blocking details. A
        // document freed meanwhile has none to report.
        for (self.captured.items) |entry| {
            const details: []const Reason = if (runtime.SlabAllocator.generationOf(entry.document) == entry.generation)
                blockingDetails(entry.document)
            else
                &.{};
            (entry.node orelse &self.tree).reasons = try self.allocator.dupe(Reason, details);
        }
        // Steps 3-5: every cross-origin descendant's own reasons decide
        // step 6 before any of them is masked; then each is masked, the
        // deepest first (masking a node frees the nodes below it).
        var masked = false;
        for (self.captured.items) |entry| {
            if (entry.cross_origin and (entry.node orelse &self.tree).hasReasons()) masked = true;
        }
        var i = self.captured.items.len;
        while (i > 0) {
            i -= 1;
            const entry = self.captured.items[i];
            if (entry.cross_origin) (entry.node orelse &self.tree).mask(self.allocator);
        }
        // Step 6.
        if (masked) {
            if (self.captured.items.len > 0) {
                const root = self.captured.items[0];
                if (runtime.SlabAllocator.generationOf(root.document) == root.generation) makeUnsalvageable(root.document, .masked);
            }
            try appendReason(&self.tree, .masked, self.allocator);
        }
        self.finished = true;
        const tree = self.tree;
        self.tree = .{};
        return tree;
    }

    pub fn deinit(self: *Builder) void {
        self.tree.deinit(self.allocator);
        self.captured.deinit(self.allocator);
    }

    fn read(self: *Builder, node: *NotRestoredReasons, document: *runtime.Instance, top_window: ?*runtime.Instance, cross_origin: bool, depth: usize) Allocator.Error!void {
        try self.captured.append(self.allocator, .{
            .node = if (depth == 0) null else node,
            .document = document,
            .generation = runtime.SlabAllocator.generationOf(document),
            .cross_origin = cross_origin,
        });
        // Step 2: the document's URL.
        if (interfaces.Document.get_URL(document)) |url| {
            defer document.ctx.allocator.free(url);
            node.url = try self.allocator.dupe(u8, url);
        } else |_| {}
        // Step 6: its document-tree child navigables' active documents, in
        // tree order, each with its container's src, id and name (steps
        // 3-4). The slice is made whole before any child is read, so the
        // nodes `captured` points at never move.
        var children = navigables.childNavigablesOf(document, self.allocator);
        defer children.deinit(self.allocator);
        var documents: std.ArrayListUnmanaged(ChildDocument) = .empty;
        defer documents.deinit(self.allocator);
        if (depth < max_depth) for (children.items) |child| {
            const child_document: *runtime.Instance = @ptrCast(@alignCast(child.browsing_context.getActiveDocument() orelse continue));
            try documents.append(self.allocator, .{ .document = child_document, .container = child.container });
        };
        const nodes = try self.allocator.alloc(NotRestoredReasons, documents.items.len);
        for (nodes) |*made| made.* = .{};
        node.children = nodes;
        for (documents.items, nodes) |child, *child_node| {
            try containerAttributes(child_node, child.container, self.allocator);
            const child_cross_origin = if (top_window) |top| !sameOriginWithTop(child.document, top) else false;
            try self.read(child_node, child.document, top_window, child_cross_origin, depth + 1);
        }
    }

    const ChildDocument = struct { document: *runtime.Instance, container: *runtime.Instance };
};

/// The depth past which descendants are not walked (a frame tree that deep
/// is a cycle, or hostile).
const max_depth = 64;

/// Steps 3-4: `container`'s src, id and name, when it is an iframe element.
///
/// A missing id or name attribute is null, an empty one "". Deviation,
/// stated: HTML gives the empty string for both ("or the empty string if it
/// has no such attribute"). Chromium is the only engine that ships
/// NotRestoredReasons, so its answer is the browsers' (golden rule 2), and
/// it reports null: on wpt.fyi (Edge 157, run 5124401950621696) it passes
/// performance-navigation-timing-iframes-without-attributes.tentative
/// ("missing attributes are reported as null") and fails
/// performance-navigation-timing-same-origin-bfcache.tentative on exactly
/// this ("expected "" but got null") - the two tentative files disagree,
/// and neither is in the worklist.
fn containerAttributes(node: *NotRestoredReasons, container: *runtime.Instance, allocator: Allocator) Allocator.Error!void {
    const kind = navigables.containerKind(container) orelse return;
    if (kind != .iframe) return;
    // 4.1-4.2: "src", encoding-parsed-and-serialized relative to the
    // container's node document, else its value as is - the reflection of
    // src as a URL, which is "" without the attribute.
    const src = reflection.get(runtime.USVString, container, .{ .name = "src", .url = true }) catch "";
    defer if (src.len > 0) container.ctx.allocator.free(src);
    node.src = try allocator.dupe(u8, src);
    node.id = try attributeOrNull(container, "id", allocator);
    node.name = try attributeOrNull(container, "name", allocator);
}

fn attributeOrNull(element: *runtime.Instance, comptime name: []const u8, allocator: Allocator) Allocator.Error!?[]const u8 {
    var value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(name)) catch return null) orelse return null;
    defer value.deinit(element.ctx.allocator);
    return try allocator.dupe(u8, value.asSlice());
}

/// Whether `document`'s origin is same origin with `top_window`'s
/// associated Document's - read from their settings objects (a Window's is
/// its document's), never through an access-checked getter.
fn sameOriginWithTop(document: *runtime.Instance, top_window: *runtime.Instance) bool {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    if (window == top_window) return true;
    const a_settings = global_settings.of(window) orelse return false;
    const b_settings = global_settings.of(top_window) orelse return false;
    const a = a_settings.origin(window) catch return false;
    defer window.ctx.allocator.free(a);
    const b = b_settings.origin(top_window) catch return false;
    defer top_window.ctx.allocator.free(b);
    return origin_record.sameOrigin(
        .{ .serialized = a, .record = global_settings.originRecordOf(window) },
        .{ .serialized = b, .record = global_settings.originRecordOf(top_window) },
    );
}

/// `reason` added to `tree`'s own reasons, unless it is there already.
fn appendReason(tree: *NotRestoredReasons, reason: Reason, allocator: Allocator) Allocator.Error!void {
    const reasons = tree.reasons orelse &.{};
    if (std.mem.indexOfScalar(Reason, reasons, reason) != null) return;
    const grown = try allocator.alloc(Reason, reasons.len + 1);
    @memcpy(grown[0..reasons.len], reasons);
    grown[reasons.len] = reason;
    if (tree.reasons) |old| allocator.free(old);
    tree.reasons = grown;
}
