//! A window event loop's rendering opportunities and HTML "update the
//! rendering" (HTML 8.1.7.3): the frame clock, the documents' maps of
//! animation frame callbacks (HTML 8.12), and the steps in the spec's order.
//!
//! Crane draws nothing - layout and pixels are the host's - but HTML's event
//! loop still has rendering opportunities, and a long list of web-observable
//! steps hangs off them: requestAnimationFrame first of all, which WPT uses as
//! its "wait one frame" idiom.
//!
//! ## The frame clock
//!
//! A navigable's rendering opportunities follow its display's refresh rate
//! ("accounting for hardware refresh rate constraints"). Crane emulates a
//! display for the host that has none: the refresh moments are a grid,
//! `origin + k * interval`, with the origin at the loop's creation and the
//! interval the testing platform's 60 Hz. Rendering is ON DEMAND, as every
//! engine renders (WebKit `Document::scheduleRenderingUpdate` ->
//! RenderingUpdateScheduler; Blink `ScheduleAnimation` -> BeginMainFrame only
//! when needed and visible; Gecko's refresh driver stopping its timer when no
//! phase is needed): a document that has animation frame callbacks, or that
//! asked for a frame (`dom.update_the_rendering.requestFrame`), arms ONE timer
//! for the next grid moment after the last rendering opportunity. When it
//! fires, the loop's "last render opportunity time" is the latest grid moment
//! - a vsync - and the rendering task runs. Nothing asked: no timer, so an idle
//! page costs nothing and keeps no work pending.
//!
//! The frame's instant is shared by every document and converted for each
//! with the relative high resolution time of its own global (Blink's
//! BeginFrameArgs.frame_time, Gecko's vsync timestamp, WebKit's frozen now -
//! one instant per frame in all three).
//!
//! ## The rendering task
//!
//! HTML queues "update the rendering" as a task on the rendering task source
//! (whatwg/html#10007). Here the clock's timer callback IS that task: timer
//! callbacks are tasks of the Browser loop, each followed by a microtask
//! checkpoint (event_loop.zig `runOnceBlocking` step 4).
//!
//! ## Ownership
//!
//! The state is the event loop's (`EventLoop.frames`), never a thread's.
//! Each entry OWNS its callback until it runs, is cancelled, its document
//! goes, or the page ends (`endPage`, before the realm ends). The documents a
//! frame visits and the documents that asked for one are BORROWED
//! identities, checked by slab generation before every use.
const std = @import("std");
const log = std.log.scoped(.rendering);
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const platform = @import("platform");
const dom_mod = @import("dom");
const html_mod = @import("html");
const Context = @import("Context.zig");
const EventLoop = @import("event_loop.zig").EventLoop;

const instance_lifecycle = runtime.instance_lifecycle;
const TimerId = runtime.TimerId;
const update_the_rendering = dom_mod.update_the_rendering;
const Allocator = std.mem.Allocator;

/// An entry of a document's map of animation frame callbacks.
pub const AnimationFrameEntry = struct {
    handle: u32,
    /// OWNED: the engine handed it over with requestAnimationFrame. Released
    /// once the callback has run, once it has been cancelled, or at teardown.
    callback: runtime.JSValue,
    /// The realm of the requestAnimationFrame that registered the callback:
    /// each Window has its own map of animation frame callbacks, so the
    /// callback runs, and reports what it throws, in the window it came from.
    /// Not owned: the context manager keeps a realm until teardown, and a
    /// destroyed window's entries go with it (`windowDestroyed`).
    realm: runtime.Context,
    /// Window reuse must not move the old Document's callback map to its
    /// successor. Borrowed identity, checked by slab generation before use.
    target_document: ?*runtime.Instance = null,
    target_document_generation: u64 = 0,
    cancelled: bool = false,
    /// Removed from the callback map immediately before invocation. The local
    /// batch continues to own its callback until the invocation returns.
    consumed: bool = false,

    fn deinit(self: *AnimationFrameEntry) void {
        releaseValue(self.takeCallback());
    }

    fn takeCallback(self: *AnimationFrameEntry) runtime.JSValue {
        const callback = self.callback;
        self.callback = .undefined;
        self.consumed = true;
        return callback;
    }
};

/// A rendering turn captures documents, including ones with no callback yet.
/// These identities are borrowed; before each turn, resolve the navigable id
/// again and check both slab generations without dereferencing an old realm.
pub const FrameDocument = struct {
    navigable_id: u64,
    window: *runtime.Instance,
    window_generation: u64,
    document: *runtime.Instance,
    document_generation: u64,
    realm: runtime.Context,

    fn current(self: FrameDocument) bool {
        if (runtime.SlabAllocator.generationOf(self.window) != self.window_generation or
            runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return false;
        if (instance_lifecycle.isCleanupStarted(self.window) or
            instance_lifecycle.isCleanupStarted(self.document)) return false;
        const navigables = dom_mod.browser_state.navigablesOf(self.realm) orelse return false;
        const navigable = navigables.byId(self.navigable_id) orelse return false;
        if (navigable.is_closed or navigable.orphaned) return false;
        if (navigable.active_window != @as(?*anyopaque, @ptrCast(self.window)) or
            navigable.active_document != @as(?*anyopaque, @ptrCast(self.document))) return false;
        return self.window.ctx == self.realm and self.realm.hasEngine();
    }
};

/// A document that asked for a rendering opportunity. `fresh` until a frame
/// visited it; after that it stays only while its owners still have work
/// for a frame (`ownersPending`).
const FrameRequest = struct {
    document: FrameDocument,
    fresh: bool = true,
    /// `Frames.frame_number` when it was last asked: a frame answers only the
    /// requests made before it began, so one made during a frame - after its
    /// document's step may have run - gets the next frame.
    asked_in: u64 = 0,
};

/// One document's animation frame callback identifier.
const Identifier = struct {
    document: *runtime.Instance,
    generation: u64,
    last: u32 = 0,
};

/// A Browser event loop's rendering state (`EventLoop.frames`).
pub const Frames = struct {
    allocator: Allocator,
    /// The refresh interval (ns) of the display the loop's navigables are on.
    interval_ns: i64 = update_the_rendering.default_refresh_interval_ns,
    /// The refresh grid's origin: the loop's creation (monotonic ns).
    origin_ns: i64,
    /// HTML 8.1.7.1: the window event loop's "last render opportunity time"
    /// (monotonic ns); 0 before the first.
    last_render_opportunity_ns: i64 = 0,
    /// The single timer driving the next rendering opportunity, if armed,
    /// and the refresh moment it was armed for.
    timer_id: ?TimerId = null,
    timer_due_ns: i64 = 0,
    /// How many rendering opportunities have begun.
    frame_number: u64 = 0,
    /// Every document's map of animation frame callbacks, interleaved in
    /// registration order. An entry stays here until its document's turn
    /// snapshots its handles (HTML "run the animation frame callbacks" 1-2).
    pending: std.ArrayListUnmanaged(AnimationFrameEntry) = .empty,
    /// The documents that asked for a rendering opportunity
    /// (`requestFrame`). Borrowed identities: their navigables own them.
    requests: std.ArrayListUnmanaged(FrameRequest) = .empty,
    /// The batch currently being run, borrowed from `updateTheRendering`'s
    /// stack for the duration of the loop. cancelAnimationFrame has to be able
    /// to reach it: per HTML's "run the animation frame callbacks", cancelling
    /// from INSIDE a callback must still suppress a later callback in the SAME
    /// frame, and those entries are no longer in `pending`.
    running: []AnimationFrameEntry = &.{},
    /// Borrowed stack identity for the entire rendering turn, including gaps
    /// between document batches. Replaced state never inherits the identity.
    dispatch_token: ?*const u8 = null,
    /// Each target object's "animation frame callback identifier" (HTML
    /// 8.12): a Window's target is its associated Document, whose first
    /// requestAnimationFrame returns 1 (no-interference-timers.html). Keyed
    /// by borrowed document identity and slab generation; a document that
    /// is gone leaves at the next retirement. Handles are their own space,
    /// not the timer id space: cancelAnimationFrame(someTimeoutId) does
    /// nothing.
    identifiers: std.ArrayListUnmanaged(Identifier) = .empty,
    /// The identifier of a Window that has no document to key it by (a
    /// realm that ended, a navigable between documents).
    unkeyed_identifier: u32 = 0,

    pub fn init(allocator: Allocator, origin_ns: i64) Frames {
        return .{ .allocator = allocator, .origin_ns = origin_ns };
    }

    /// The loop ends (EventLoop.deinit, before its agent): what the page's
    /// end left - nothing, normally - is released now, while the engine
    /// lives. The loop's timers end with its timer manager.
    pub fn deinit(self: *Frames) void {
        for (self.running) |*entry| entry.cancelled = true;
        for (self.pending.items) |*entry| entry.deinit();
        self.pending.deinit(self.allocator);
        self.requests.deinit(self.allocator);
        self.identifiers.deinit(self.allocator);
        self.* = .{ .allocator = self.allocator, .origin_ns = self.origin_ns };
    }

    fn loop(self: *Frames) *EventLoop {
        return @fieldParentPtr("frames", self);
    }

    /// The first refresh moment at or after `at_ns`.
    pub fn nextRefreshAtOrAfter(self: *const Frames, at_ns: i64) i64 {
        return update_the_rendering.nextRefreshAtOrAfter(self.origin_ns, self.interval_ns, at_ns);
    }

    /// The latest refresh moment at or before `at_ns`.
    pub fn latestRefreshAtOrBefore(self: *const Frames, at_ns: i64) i64 {
        return update_the_rendering.latestRefreshAtOrBefore(self.origin_ns, self.interval_ns, at_ns);
    }
};

/// computeDeadline's "nextRenderDeadline" (HTML 8.1.7.3 step 5.2.4): the
/// refresh moment the clock is armed for, when a frame is wanted - exact,
/// where the frame timer's own deadline is rounded up to the millisecond.
pub fn nextRenderDeadline(frames: *const Frames) ?i64 {
    if (frames.timer_id == null) return null;
    return frames.timer_due_ns;
}

/// The rendering state of `realm`'s event loop, when it is a Browser loop.
fn framesOf(realm: runtime.Context) ?*Frames {
    const loop = EventLoop.of(realm) orelse return null;
    return &loop.frames;
}

const Disposition = enum { ready, deferred, terminal };

// ============================================================================
// requestAnimationFrame / cancelAnimationFrame (HTML 8.12)
// ============================================================================

/// requestAnimationFrame(callback) - HTML "animation frames", step 2 onwards,
/// after the engine's conversion (`runtime.WindowOperations`). `callback` is
/// handed over.
pub fn requestAnimationFrame(realm: runtime.Context, callback: runtime.JSValue) u32 {
    const frames = framesOf(realm) orelse {
        releaseValue(callback);
        return 0;
    };
    return requestAnimationFrameIn(frames, realm, callback);
}

fn requestAnimationFrameIn(frames: *Frames, realm: runtime.Context, callback: runtime.JSValue) u32 {
    // 2. "Let target be this's target object": the Window's associated
    // Document (a cached page's Window has no navigable: untargeted, its map
    // waits for its document's restore).
    const target = targetDocument(realm);
    // 3. "Increment target's animation frame callback identifier by one,
    // and let handle be the result."
    const handle = nextIdentifier(frames, target);
    if (realmIsTerminal(realm)) {
        // A saved removed Window remains callable, but retaining an engine
        // callback here would root a realm no rendering turn can visit.
        releaseValue(callback);
        return handle;
    }
    frames.pending.append(frames.allocator, .{
        .handle = handle,
        .callback = callback,
        .realm = realm,
        .target_document = target,
        .target_document_generation = if (target) |document| runtime.SlabAllocator.generationOf(document) else 0,
    }) catch {
        releaseValue(callback);
        return 0;
    };
    schedule(frames);
    return handle;
}

/// The active document of `realm`'s Window's navigable: its target object.
/// Null for a realm that ended, or a Window no navigable shows.
fn targetDocument(realm: runtime.Context) ?*runtime.Instance {
    if (!realm.hasEngine()) return null;
    const window = Context.realmWindow(realm) orelse return null;
    const navigable = Context.realmNavigable(realm, window) orelse return null;
    const active = navigable.active_document orelse return null;
    return @ptrCast(@alignCast(active));
}

/// `target`'s animation frame callback identifier, incremented (HTML 8.12
/// requestAnimationFrame step 3).
fn nextIdentifier(frames: *Frames, target: ?*runtime.Instance) u32 {
    const document = target orelse {
        frames.unkeyed_identifier +%= 1;
        return frames.unkeyed_identifier;
    };
    const generation = runtime.SlabAllocator.generationOf(document);
    for (frames.identifiers.items) |*identifier| {
        if (identifier.document == document and identifier.generation == generation) {
            identifier.last +%= 1;
            return identifier.last;
        }
    }
    frames.identifiers.append(frames.allocator, .{ .document = document, .generation = generation, .last = 1 }) catch {
        frames.unkeyed_identifier +%= 1;
        return frames.unkeyed_identifier;
    };
    return 1;
}

/// cancelAnimationFrame(handle). An unknown handle must do nothing.
pub fn cancelAnimationFrame(realm: runtime.Context, handle: u32) void {
    const frames = framesOf(realm) orelse return;
    cancelAnimationFrameIn(frames, realm, handle);
}

fn cancelAnimationFrameIn(frames: *Frames, realm: runtime.Context, handle: u32) void {
    // Mark rather than remove: the batch may already be running, and removing
    // from under the loop in updateTheRendering would shift its indices.
    // The frame in progress first: a callback cancelling a sibling registered
    // for the same frame is the case `pending` alone cannot answer.
    //
    // A handle names a callback in THIS target's map only (each document
    // numbers its own from 1), so another window's callback with that
    // handle - or the previous document's of a reused Window - is not
    // cancelled.
    const target = targetDocument(realm);
    for (frames.running) |*entry| {
        if (!entry.consumed and entry.handle == handle and entry.realm == realm and entry.target_document == target) {
            entry.cancelled = true;
            return;
        }
    }
    for (frames.pending.items) |*entry| {
        if (entry.handle == handle and entry.realm == realm and entry.target_document == target) {
            entry.cancelled = true;
            return;
        }
    }
}

// ============================================================================
// Demand
// ============================================================================

/// dom.update_the_rendering's loop half, installed at process start
/// (Context.installHooks).
pub const loop_hooks: update_the_rendering.Loop = .{ .request_frame = requestFrame };

/// `document` has work for its event loop's next rendering opportunity.
/// The Document owns that work; this records only a borrowed identity, and
/// only for the active document of a live navigable.
pub fn requestFrame(document: *runtime.Instance) void {
    // A document being torn down, or whose realm ended, has no next frame.
    if (instance_lifecycle.isCleanupStarted(document)) return;
    const realm = document.ctx;
    if (!realm.hasEngine()) return;
    const frames = framesOf(realm) orelse return;
    const window = Context.realmWindow(realm) orelse return;
    const navigable = Context.realmNavigable(realm, window) orelse return;
    if (navigable.active_document != @as(?*anyopaque, @ptrCast(document))) return;
    retireRequests(frames);
    for (frames.requests.items) |*request| {
        if (request.document.document == document) {
            request.fresh = true;
            request.asked_in = frames.frame_number;
            schedule(frames);
            return;
        }
    }
    frames.requests.append(frames.allocator, .{ .asked_in = frames.frame_number, .document = .{
        .navigable_id = navigable.id,
        .window = window,
        .window_generation = runtime.SlabAllocator.generationOf(window),
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .realm = realm,
    } }) catch return;
    schedule(frames);
}

/// Whether `document`'s owners still have work for a frame although nothing
/// asked again: autofocus candidates waiting (for a stylesheet, say), CSS
/// resources to select.
fn ownersPending(document: *runtime.Instance) bool {
    return dom_mod.document_autofocus.hasCandidates(document) or
        dom_mod.style.engine.resource_loading.hasPending(document);
}

fn retireRequests(frames: *Frames) void {
    var index: usize = 0;
    while (index < frames.requests.items.len) {
        const request = frames.requests.items[index];
        if (!request.document.current() or (!request.fresh and !ownersPending(request.document.document))) {
            _ = frames.requests.orderedRemove(index);
        } else index += 1;
    }
}

/// Terminal owners cannot be invoked by any future rendering opportunity.
/// A live hidden/inactive/blocked document keeps its owners until a later turn.
/// A document that is gone takes its identifier with it.
fn retireAnimationFrameCallbacks(frames: *Frames) void {
    var at: usize = 0;
    while (at < frames.identifiers.items.len) {
        const identifier = frames.identifiers.items[at];
        if (runtime.SlabAllocator.generationOf(identifier.document) != identifier.generation) {
            _ = frames.identifiers.swapRemove(at);
        } else at += 1;
    }
    var index: usize = 0;
    while (index < frames.pending.items.len) {
        const entry = frames.pending.items[index];
        if (entry.cancelled or realmIsTerminal(entry.realm) or targetReplaced(entry)) {
            var removed = frames.pending.orderedRemove(index);
            removed.deinit();
        } else index += 1;
    }
}

/// Arm the clock for the next rendering opportunity, if anything may use
/// one. Documents that cannot have one - kept by the back/forward cache, or
/// hidden - wait without a timer: their restore, or their becoming visible,
/// asks again.
fn schedule(frames: *Frames) void {
    retireRequests(frames);
    if (frames.timer_id != null) return;
    // A document turn may add callbacks to a later document this frame, but
    // nested loop pumping must never start another rendering turn.
    if (frames.dispatch_token != null) return;
    if (frames.pending.items.len == 0 and frames.requests.items.len == 0) return;
    if (!anyMayRender(frames)) return;
    const timers = frames.loop().timerInterface() orelse return;
    refreshIntervalFromPlatform(frames);
    const now = monotonicNs();
    // The next refresh moment after the last rendering opportunity: at most
    // one opportunity per refresh.
    const due = frames.nextRefreshAtOrAfter(@max(now, frames.last_render_opportunity_ns + 1));
    const wait_ns = due - now;
    const wait_ms: u64 = if (wait_ns <= 0) 0 else @intCast(std.math.divCeil(i64, wait_ns, std.time.ns_per_ms) catch unreachable);
    const id = timers.setTimeout(wait_ms, frameTimerFired, frames);
    // 0 is the failure sentinel; leaving timer_id null lets a later request
    // retry.
    if (id == 0) return;
    frames.timer_id = id;
    frames.timer_due_ns = due;
}

/// Whether a document with callbacks or a request may have a rendering
/// opportunity: not a page the back/forward cache keeps, and not hidden.
fn anyMayRender(frames: *const Frames) bool {
    for (frames.requests.items) |request| {
        if (realmMayRender(request.document.realm)) return true;
    }
    for (frames.pending.items) |entry| {
        if (realmMayRender(entry.realm)) return true;
    }
    return false;
}

fn realmMayRender(realm: runtime.Context) bool {
    if (!realm.hasEngine()) return false;
    const window = Context.realmWindow(realm) orelse return false;
    if (windowIsCached(realm, window)) return false;
    const navigable = Context.realmNavigable(realm, window) orelse return false;
    const document: *runtime.Instance = @ptrCast(@alignCast(navigable.active_document orelse return true));
    if (runtime.SlabAllocator.generationOf(document) == runtime.SlabAllocator.dead_generation) return false;
    return (interfaces.Document.get_visibilityState(document) catch return true) != ._hidden_;
}

/// The refresh interval of the display the loop's navigables are on: the
/// platform's (`displayRefreshInterval`; tab 0 until the platform protocol's
/// recipes step 7 maps documents to tabs, as html.platform_state does).
fn refreshIntervalFromPlatform(frames: *Frames) void {
    const seed = if (frames.pending.items.len != 0)
        frames.pending.items[0].realm
    else if (frames.requests.items.len != 0)
        frames.requests.items[0].document.realm
    else
        return;
    const browser = html_mod.platform_state.of(seed) orelse return;
    const interval = platform.displayRefreshInterval(browser, 0);
    if (interval == 0 or interval > std.math.maxInt(i32)) return;
    frames.interval_ns = @intCast(interval);
}

/// The clock's timer: a rendering opportunity.
fn frameTimerFired(data: ?*anyopaque) void {
    const frames: *Frames = @ptrCast(@alignCast(data orelse return));
    frames.timer_id = null;
    const now = monotonicNs();
    // Never before the refresh moment it was armed for (the timer counts
    // whole milliseconds): a frame's instant is never after its now.
    if (now < frames.timer_due_ns) {
        const timers = frames.loop().timerInterface() orelse return;
        const id = timers.setTimeout(1, frameTimerFired, frames);
        if (id != 0) frames.timer_id = id;
        return;
    }
    // The in-parallel steps 1-2: the last render opportunity time is the
    // latest refresh moment - the one the timer was armed for, or a later
    // one when the loop was busy past it.
    frames.last_render_opportunity_ns = frames.latestRefreshAtOrBefore(now);
    updateTheRendering(frames);
}

// ============================================================================
// Update the rendering
// ============================================================================

/// The rendering task's steps (HTML "update the rendering"). Capture document
/// eligibility globally, then snapshot handles separately when each selected
/// document's tree-ordered turn begins (step 14).
fn updateTheRendering(frames: *Frames) void {
    if (frames.dispatch_token != null) return;
    // Terminal/cancelled owners need no allocation to leave the map, even
    // when reserving the next document snapshot would fail.
    retireAnimationFrameCallbacks(frames);
    retireRequests(frames);
    const seed = if (frames.pending.items.len != 0)
        frames.pending.items[0].realm
    else if (frames.requests.items.len != 0)
        frames.requests.items[0].document.realm
    else
        return;

    // Steps 2-3: every fully active, renderable document of the loop, in
    // order - including documents with no callback and no request: an
    // earlier parent turn can add their first callback.
    var documents = collectDocuments(frames.allocator, seed) catch {
        schedule(frames);
        return;
    };
    defer documents.deinit(frames.allocator);

    // Step 1: frameTimestamp.
    const frame: update_the_rendering.Frame = .{ .timestamp_ns = frames.last_render_opportunity_ns };
    frames.frame_number += 1;
    const frame_number = frames.frame_number;

    var token: u8 = 0;
    frames.dispatch_token = &token;
    defer if (dispatchState(frames, &token)) |current| {
        current.running = &.{};
        current.dispatch_token = null;
        // The requests this frame answered are spent; owners with work left
        // keep theirs (`ownersPending`).
        for (current.requests.items) |*request| {
            if (request.asked_in >= frame_number) continue;
            for (documents.items) |document| {
                if (document.document == request.document.document and document.document_generation == request.document.document_generation) request.fresh = false;
            }
        }
        retireAnimationFrameCallbacks(current);
        schedule(current);
    };

    // 6. Reveal.
    runOwnerStep(frames, &token, documents.items, .reveal, frame);
    // 7. Flush autofocus candidates, for top-level traversables' documents.
    // Every one is visited even when its autofocus handler will request the
    // first script callback. Revalidate after any script ran.
    for (documents.items) |document| {
        if (dispatchState(frames, &token) == null) break;
        if (!document.current()) continue;
        if (html_mod.focus.topLevelDocumentOf(document.document) != document.document) continue;
        html_mod.autofocus.flush(document.document);
    }
    // 8. The resize steps. 9. The scroll steps.
    runOwnerStep(frames, &token, documents.items, .resize, frame);
    runOwnerStep(frames, &token, documents.items, .scroll, frame);
    // 10. Evaluate media queries and report changes (CSSOM View 4.2).
    for (documents.items) |document| {
        if (dispatchState(frames, &token) == null) break;
        if (document.current()) dom_mod.style.reportMediaQueryChanges(document.document);
    }
    // 11. Update animations and send events. 12. The fullscreen steps.
    // 13. The context lost steps.
    runOwnerStep(frames, &token, documents.items, .animations, frame);
    runOwnerStep(frames, &token, documents.items, .fullscreen, frame);
    runOwnerStep(frames, &token, documents.items, .context_lost, frame);

    // 14. Run the animation frame callbacks, passing in the relative high
    // resolution time given frameTimestamp and the document's relevant
    // global.
    var last_realm: ?runtime.Context = null;
    for (documents.items) |document| {
        const current = dispatchState(frames, &token) orelse break;
        // Removal cancels a turn; adding/removing a render blocker does not
        // recalculate the eligibility captured before JS began.
        if (!document.current()) continue;
        var batch = takeAnimationFrameBatch(current.allocator, current, document.realm) catch break;
        defer batch.deinit(current.allocator);
        current.running = batch.items;
        defer if (dispatchState(frames, &token)) |live| {
            live.running = &.{};
        };
        const timestamp = runtime.JSValue{ .number = relativeHighResolutionTime(document.realm, frame.timestamp_ns) };
        for (batch.items) |*entry| {
            defer entry.deinit();
            if (entry.cancelled or dispatchState(frames, &token) == null) continue;
            if (!document.current() or targetReplaced(entry.*)) continue;
            // HTML run-animation-callbacks step 3.2: remove the handle before
            // JS so cancellation of an already-invoked handle is a no-op.
            entry.consumed = true;
            // Only active documents' callbacks were collected.
            dom_mod.bfcache.assertNotCached(entry.realm);
            Context.invokeReporting(entry.realm, entry.callback, &.{timestamp});
            last_realm = entry.realm;
        }
    }
    if (dispatchState(frames, &token) != null) {
        if (last_realm) |realm| if (realm.hasEngine()) Context.performMicrotaskCheckpoint(realm);
    }

    // 16. Style and layout: the used CSS resources are selected here, after
    // the animation callbacks and their microtasks, never by a style getter.
    for (documents.items) |document| {
        if (dispatchState(frames, &token) == null) break;
        if (!document.current()) continue;
        dom_mod.style.engine.resource_loading.updateRendering(document.document);
    }
    runOwnerStep(frames, &token, documents.items, .style_and_layout, frame);
    // 17. The focus fixup. Retain focusedAreaOf's existing no-blur deviation;
    // never fix up in a selector.
    for (documents.items) |document| {
        if (dispatchState(frames, &token) == null) break;
        if (!document.current()) continue;
        if (dom_mod.focused_area.get(document.document) == null) continue;
        if (!dom_mod.document_activity.fullyActive(document.document, document.document_generation)) continue;
        _ = html_mod.focus.focusedAreaOf(document.document);
        // Still an element: the next mutation that may unfocus it asks for
        // the next fixup (dom.update_the_rendering's watch).
        if (!document.current()) continue;
        if (dom_mod.focused_area.get(document.document) != null) update_the_rendering.watchFocusedArea(document.document);
    }
    // 18. View transitions. 19. Intersection observations. 20. Rendering
    // time. 21. Paint timing. 23. Top layer removals. (22, updating the
    // user interface, is the host's.)
    runOwnerStep(frames, &token, documents.items, .view_transitions, frame);
    runOwnerStep(frames, &token, documents.items, .intersection_observations, frame);
    runOwnerStep(frames, &token, documents.items, .rendering_time, frame);
    runOwnerStep(frames, &token, documents.items, .paint_timing, frame);
    runOwnerStep(frames, &token, documents.items, .top_layer_removals, frame);
}

/// One owner-installed step, for each document still current, in order.
fn runOwnerStep(frames: *Frames, token: *const u8, documents: []const FrameDocument, step: update_the_rendering.Step, frame: update_the_rendering.Frame) void {
    if (!update_the_rendering.isInstalled(step)) return;
    for (documents) |document| {
        if (dispatchState(frames, token) == null) return;
        if (!document.current()) continue;
        update_the_rendering.run(step, document.document, frame);
    }
}

/// A token is borrowed from the turn's stack, and covers all document
/// turns. Re-read it after JS: teardown can end the page's state.
fn dispatchState(frames: *Frames, token: *const u8) ?*Frames {
    if (frames.dispatch_token != token) return null;
    return frames;
}

/// HR-Time's relative high resolution time given `moment` (monotonic ns)
/// and the global of `realm`, in milliseconds: the coarsened moment less the
/// time origin of the global's Performance - exactly how performance.now()
/// measures (the navigation's start once a navigation set it), so a frame's
/// timestamp is never after its callback's now.
fn relativeHighResolutionTime(realm: runtime.Context, moment: i64) f64 {
    const unsafe_ms = @as(f64, @floatFromInt(moment)) / std.time.ns_per_ms;
    return dom_mod.performance_timeline.relativeCoarseTime(realm, unsafe_ms) orelse 0;
}

/// Reserve storage before moving any callback owner. Snapshot only THIS
/// document's handles when its turn starts (HTML run-animation-callbacks 1–2).
/// Parent callbacks can therefore register callbacks for a later child turn.
fn takeAnimationFrameBatch(
    allocator: Allocator,
    frames: *Frames,
    realm: runtime.Context,
) error{OutOfMemory}!std.ArrayListUnmanaged(AnimationFrameEntry) {
    var count: usize = 0;
    for (frames.pending.items) |entry| if (entry.realm == realm) {
        count += 1;
    };
    var batch: std.ArrayListUnmanaged(AnimationFrameEntry) = .empty;
    errdefer batch.deinit(allocator);
    try batch.ensureTotalCapacity(allocator, count);
    var index: usize = 0;
    while (index < frames.pending.items.len) {
        if (frames.pending.items[index].realm == realm) {
            batch.appendAssumeCapacity(frames.pending.orderedRemove(index));
        } else index += 1;
    }
    return batch;
}

/// HTML update-rendering steps 2–3 collect and filter all documents before JS.
/// The no-callback documents matter: an earlier parent turn can add their
/// first callback. Documents created during a callback wait until next frame.
fn collectDocuments(
    allocator: Allocator,
    seed: runtime.Context,
) error{OutOfMemory}!std.ArrayListUnmanaged(FrameDocument) {
    const navigables = dom_mod.browser_state.navigablesOf(seed) orelse return .empty;
    const contexts = navigables.contexts();
    var documents: std.ArrayListUnmanaged(FrameDocument) = .empty;
    errdefer documents.deinit(allocator);
    try documents.ensureTotalCapacity(allocator, contexts.len);
    const loop = seed.getOptionalEventLoop();
    for (contexts) |navigable| {
        if (navigable.is_closed or navigable.orphaned) continue;
        const window: *runtime.Instance = @ptrCast(@alignCast(navigable.active_window orelse continue));
        if (runtime.SlabAllocator.generationOf(window) == runtime.SlabAllocator.dead_generation) continue;
        if (instance_lifecycle.isCleanupStarted(window)) continue;
        const realm = window.ctx;
        const document_loop = realm.getOptionalEventLoop();
        if (loop) |expected| {
            const actual = document_loop orelse continue;
            if (actual.ptr != expected.ptr or actual.vtable != expected.vtable) continue;
        } else if (document_loop != null or realm.agent != seed.agent) continue;
        if (disposition(realm) != .ready) continue;
        const document: *runtime.Instance = @ptrCast(@alignCast(navigable.active_document orelse continue));
        documents.appendAssumeCapacity(.{
            .navigable_id = navigable.id,
            .window = window,
            .window_generation = runtime.SlabAllocator.generationOf(window),
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .realm = realm,
        });
    }
    // No script runs while sorting, so the live navigable tree is stable.
    std.mem.sort(FrameDocument, documents.items, @as(*const html_mod.Navigables, navigables), documentLessThan);
    return documents;
}

/// Step 2's order: a document after its container document, and siblings in
/// the shadow-including tree order of their navigable containers.
fn documentLessThan(navigables: *const html_mod.Navigables, a: FrameDocument, b: FrameDocument) bool {
    var left = navigables.byId(a.navigable_id) orelse return false;
    var right = navigables.byId(b.navigable_id) orelse return false;
    var left_depth: usize = 0;
    var right_depth: usize = 0;
    var left_root = left;
    while (left_root.parent) |parent| : (left_depth += 1) left_root = parent;
    var right_root = right;
    while (right_root.parent) |parent| : (right_depth += 1) right_root = parent;
    // HTML permits arbitrary order between unrelated top-level documents.
    if (left_root != right_root) return left_root.id < right_root.id;
    const original_left_depth = left_depth;
    const original_right_depth = right_depth;
    while (left_depth > right_depth) : (left_depth -= 1) left = left.parent.?;
    while (right_depth > left_depth) : (right_depth -= 1) right = right.parent.?;
    if (left == right) return original_left_depth < original_right_depth;
    while (left.parent != right.parent) {
        left = left.parent.?;
        right = right.parent.?;
    }
    const parent = left.parent orelse return left.id < right.id;
    const document: *runtime.Instance = @ptrCast(@alignCast(parent.active_document orelse return left.id < right.id));
    const left_container: *runtime.Instance = @ptrCast(@alignCast(left.container orelse return left.id < right.id));
    const right_container: *runtime.Instance = @ptrCast(@alignCast(right.container orelse return left.id < right.id));
    return shadowIncludingContainerOrder(document, left_container, right_container) orelse (left.id < right.id);
}

/// Visit a host's shadow tree (including closed roots) before its light tree.
/// Pure IDL getters and the owning Element hook; no JS getters or allocations.
fn shadowIncludingContainerOrder(root: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance) ?bool {
    var node = root;
    while (true) {
        if (node == a) return true;
        if (node == b) return false;
        if (dom_mod.shadow_hosts.rootForHost(node)) |shadow| {
            node = shadow;
            continue;
        }
        if (interfaces.Node.get_firstChild(node) catch null) |child| {
            node = child;
            continue;
        }
        while (true) {
            if (node == root) return null;
            if (interfaces.Node.get_nextSibling(node) catch null) |sibling| {
                node = sibling;
                break;
            }
            if (interfaces.Node.get_parentNode(node) catch null) |parent| {
                node = parent;
            } else if (std.mem.eql(u8, node.vtable.name, "ShadowRoot")) {
                const host = interfaces.ShadowRoot.get_host(node) catch return null;
                if (interfaces.Node.get_firstChild(host) catch null) |child| {
                    node = child;
                    break;
                }
                node = host;
            } else return null;
        }
    }
}

// ============================================================================
// Documents and windows
// ============================================================================

/// Whether `realm`'s Window belongs to a page the back/forward cache keeps:
/// asked of the realm's event loop first, where a cached page always has its
/// suspended task group: a realm on no Browser loop, or on one with none,
/// has no cached page (and its Window is not read).
fn windowIsCached(realm: runtime.Context, window: *runtime.Instance) bool {
    const loop = EventLoop.of(realm) orelse return false;
    if (loop.suspended.items.len == 0) return false;
    return dom_mod.bfcache.holds(window);
}

/// A removed/replaced Window has no active navigable; no future frame can
/// invoke its callback map. The realm itself may remain callable from script.
/// A live navigable with no document yet is temporary, and keeps callbacks.
/// So does a Window the back/forward cache keeps: its map of animation frame
/// callbacks is its document's, which may be shown again.
fn realmIsTerminal(realm: runtime.Context) bool {
    if (!realm.hasEngine()) return true;
    const window = Context.realmWindow(realm) orelse return true;
    if (instance_lifecycle.isCleanupStarted(window)) return true;
    const navigable = Context.realmNavigable(realm, window) orelse return !windowIsCached(realm, window);
    if (navigable.is_closed or navigable.orphaned) return true;
    if (navigable.active_document) |ptr| {
        const document: *runtime.Instance = @ptrCast(@alignCast(ptr));
        if (runtime.SlabAllocator.generationOf(document) == runtime.SlabAllocator.dead_generation) return true;
        if (instance_lifecycle.isCleanupStarted(document)) return true;
    }
    return false;
}

/// The rAF map belongs to the associated Document, not a reusable Window.
/// When the Window adopts its successor, retire the old document's owners.
fn targetReplaced(entry: AnimationFrameEntry) bool {
    const target = entry.target_document orelse return false;
    if (entry.target_document_generation == runtime.SlabAllocator.dead_generation) return true;
    if (runtime.SlabAllocator.generationOf(target) != entry.target_document_generation) return true;
    const window = Context.realmWindow(entry.realm) orelse return true;
    // A cached page's map stays its document's (`realmIsTerminal`).
    const navigable = Context.realmNavigable(entry.realm, window) orelse return !windowIsCached(entry.realm, window);
    // A temporarily unassigned active document is deferred. A different
    // document is a permanent replacement of this entry's target map.
    const active = navigable.active_document orelse return false;
    return active != @as(*anyopaque, @ptrCast(target));
}

/// HTML update-rendering steps 2–3: eligibility is a document decision made
/// before any callback, distinct from permanent destruction of its target.
fn disposition(realm: runtime.Context) Disposition {
    if (realmIsTerminal(realm)) return .terminal;
    const window = Context.realmWindow(realm) orelse return .terminal;
    const navigable = Context.realmNavigable(realm, window) orelse return .terminal;
    const document: *runtime.Instance = @ptrCast(@alignCast(navigable.active_document orelse return .deferred));
    if (!dom_mod.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document))) return .deferred;
    if ((interfaces.Document.get_visibilityState(document) catch return .deferred) == ._hidden_) return .deferred;
    if (dom_mod.document_rendering.isBlocked(document)) return .deferred;
    return .ready;
}

// ============================================================================
// The window and page lifecycle (Context's window operations and hooks)
// ============================================================================

/// A frame's document is being destroyed, and with it its window's map of
/// animation frame callbacks and its requests.
pub fn windowDestroyed(realm: runtime.Context) void {
    const frames = framesOf(realm) orelse return;
    // The batch in progress sees its own entries through `running`; one of
    // this window's is skipped rather than removed from under the loop.
    for (frames.running) |*entry| {
        if (entry.realm == realm) entry.cancelled = true;
    }
    var index: usize = 0;
    while (index < frames.pending.items.len) {
        if (frames.pending.items[index].realm == realm) {
            var removed = frames.pending.orderedRemove(index);
            removed.deinit();
        } else index += 1;
    }
    index = 0;
    while (index < frames.requests.items.len) {
        if (frames.requests.items[index].document.realm == realm) {
            _ = frames.requests.orderedRemove(index);
        } else index += 1;
    }
}

/// HTML "reactivate" step 2's share: `realm`'s window's animation frame
/// callbacks and its document's pending native work (autofocus candidates)
/// get a rendering opportunity again (lesson: restoring a document must
/// restore native rendering work).
pub fn windowResumed(realm: runtime.Context) void {
    const frames = framesOf(realm) orelse return;
    if (Context.realmWindow(realm)) |window| if (Context.realmNavigable(realm, window)) |navigable| {
        if (navigable.getActiveDocument()) |document| {
            const instance: *runtime.Instance = @ptrCast(@alignCast(document));
            if (ownersPending(instance)) requestFrame(instance);
        }
    };
    schedule(frames);
}

/// The page ends (Context.deinit, before its realm ends): the frame timer is
/// cancelled and every callback still in a map is released, never run. A
/// turn in progress only has its entries cancelled: it releases each one
/// exactly once when it reaches it.
pub fn endPage(realm: runtime.Context) void {
    const frames = framesOf(realm) orelse return;
    if (frames.timer_id) |id| {
        if (frames.loop().timerInterface()) |timers| _ = timers.clearTimeout(id);
        frames.timer_id = null;
    }
    for (frames.running) |*entry| entry.cancelled = true;
    for (frames.pending.items) |*entry| entry.deinit();
    frames.pending.clearAndFree(frames.allocator);
    frames.requests.clearAndFree(frames.allocator);
    frames.identifiers.clearAndFree(frames.allocator);
    // A turn in progress keeps its token, and finds its state emptied.
}

// ============================================================================
// Helpers
// ============================================================================

/// Give back a value the engine handed over (OWNED).
fn releaseValue(value: runtime.JSValue) void {
    engine.releaseValue(.{ .value = value });
}

/// The monotonic clock (ns), the platform's: the frame clock's time base,
/// and the time origins'.
fn monotonicNs() i64 {
    return @intCast(platform.monotonicNow().ns);
}

// ============================================================================
// Tests
// ============================================================================

test "per-document frame batches include parent additions but defer their own additions" {
    const allocator = std.testing.allocator;
    var parent = try runtime.ContextData.init(allocator, .{});
    defer parent.deinit();
    var child = try runtime.ContextData.init(allocator, .{});
    defer child.deinit();
    var frames = Frames.init(allocator, 0);
    defer frames.pending.deinit(allocator);
    try frames.pending.appendSlice(allocator, &.{
        .{ .handle = 1, .callback = .{ .number = 1 }, .realm = &child },
        .{ .handle = 2, .callback = .{ .number = 2 }, .realm = &parent },
    });
    var parent_batch = try takeAnimationFrameBatch(allocator, &frames, &parent);
    defer parent_batch.deinit(allocator);
    try std.testing.expectEqual(@as(u32, 2), parent_batch.items[0].handle);
    try frames.pending.append(allocator, .{ .handle = 3, .callback = .{ .number = 3 }, .realm = &child });
    var child_batch = try takeAnimationFrameBatch(allocator, &frames, &child);
    defer child_batch.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), child_batch.items.len);
    try std.testing.expectEqual(@as(u32, 1), child_batch.items[0].handle);
    try std.testing.expectEqual(@as(u32, 3), child_batch.items[1].handle);
    try frames.pending.append(allocator, .{ .handle = 4, .callback = .{ .number = 4 }, .realm = &child });
    try std.testing.expectEqual(@as(usize, 1), frames.pending.items.len);
    try std.testing.expectEqual(@as(u32, 4), frames.pending.items[0].handle);
    // Three distinct owners moved once; the new child owner remains pending.
    try std.testing.expectEqual(@as(f64, 6), parent_batch.items[0].callback.number + child_batch.items[0].callback.number + child_batch.items[1].callback.number);
}

test "per-document frame reserve failure leaves every owner and handle pending" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var frames = Frames.init(allocator, 0);
    defer frames.pending.deinit(allocator);
    try frames.pending.append(allocator, .{ .handle = 7, .callback = .{ .number = 17 }, .realm = &realm });
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, takeAnimationFrameBatch(failing.allocator(), &frames, &realm));
    try std.testing.expectEqual(@as(usize, 1), frames.pending.items.len);
    try std.testing.expectEqual(@as(u32, 7), frames.pending.items[0].handle);
    try std.testing.expectEqual(@as(f64, 17), frames.pending.items[0].callback.number);
    var batch = try takeAnimationFrameBatch(allocator, &frames, &realm);
    defer batch.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), frames.pending.items.len);
    try std.testing.expectEqual(@as(usize, 1), batch.items.len);
}

test "terminal frame requests advance handles without retaining owners" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var frames = Frames.init(allocator, 0);
    defer frames.pending.deinit(allocator);
    defer frames.identifiers.deinit(allocator);
    try std.testing.expectEqual(Disposition.terminal, disposition(&realm));
    try std.testing.expectEqual(@as(u32, 1), requestAnimationFrameIn(&frames, &realm, .undefined));
    try std.testing.expectEqual(@as(u32, 2), requestAnimationFrameIn(&frames, &realm, .undefined));
    try std.testing.expectEqual(@as(usize, 0), frames.pending.items.len);
    try std.testing.expect(frames.timer_id == null);
    // An entry accepted before its realm ended is retired as well.
    try frames.pending.append(allocator, .{ .handle = 3, .callback = .undefined, .realm = &realm });
    retireAnimationFrameCallbacks(&frames);
    try std.testing.expectEqual(@as(usize, 0), frames.pending.items.len);
}

test "animation frame callback owner is released exactly once after transfer" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var frames = Frames.init(allocator, 0);
    defer frames.pending.deinit(allocator);
    try frames.pending.append(allocator, .{ .handle = 7, .callback = .{ .number = 17 }, .realm = &realm });
    var batch = try takeAnimationFrameBatch(allocator, &frames, &realm);
    defer batch.deinit(allocator);
    const Counter = struct {
        fn release(count: *usize, value: runtime.JSValue) void {
            if (value == .number) {
                std.debug.assert(value.number == 17);
                count.* += 1;
            }
        }
    };
    var released: usize = 0;
    Counter.release(&released, batch.items[0].takeCallback());
    Counter.release(&released, batch.items[0].takeCallback());
    try std.testing.expectEqual(@as(usize, 1), released);
    try std.testing.expect(batch.items[0].consumed);
    try std.testing.expect(batch.items[0].callback == .undefined);
    try std.testing.expectEqual(@as(usize, 0), frames.pending.items.len);
}

test "frame cancellation reaches pending and running maps without canceling a consumed handle" {
    const allocator = std.testing.allocator;
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    var frames = Frames.init(allocator, 0);
    defer frames.pending.deinit(allocator);
    var running = [_]AnimationFrameEntry{
        .{ .handle = 1, .callback = .undefined, .realm = &realm, .consumed = true },
        .{ .handle = 2, .callback = .undefined, .realm = &realm },
    };
    frames.running = &running;
    try frames.pending.append(allocator, .{ .handle = 3, .callback = .undefined, .realm = &realm });
    cancelAnimationFrameIn(&frames, &realm, 1);
    try std.testing.expect(!running[0].cancelled);
    cancelAnimationFrameIn(&frames, &realm, 2);
    try std.testing.expect(running[1].cancelled);
    cancelAnimationFrameIn(&frames, &realm, 3);
    retireAnimationFrameCallbacks(&frames);
    try std.testing.expectEqual(@as(usize, 0), frames.pending.items.len);
}

test "callable removed Window is terminal but a live navigable awaiting its document is deferred" {
    const allocator = std.testing.allocator;
    var dummy_engine: u32 = 0;
    // The realm's Browser, whose list its navigable is on.
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var realm = try runtime.ContextData.init(allocator, .{ .engine_ctx = &dummy_engine });
    defer realm.deinit();
    realm.browser_scope = &scope;
    // No engine operation reaches the fake context. These objects are only
    // read as runtime identities, and no slab-generation check is needed.
    var window: runtime.Instance = undefined;
    const record = try runtime.Realm.init(allocator, .{ .global_object = &window });
    defer record.deinit();
    realm.setRealm(record);
    defer realm.clearRealm();
    const navigable = try html_mod.window.BrowsingContext.init(allocator, try scope.table(.navigables, html_mod.Navigables));
    defer navigable.deinit();
    navigable.active_window = &window;
    try std.testing.expectEqual(Disposition.deferred, disposition(&realm));
    navigable.is_closed = true;
    try std.testing.expectEqual(Disposition.terminal, disposition(&realm));
    navigable.is_closed = false;
    navigable.orphaned = true;
    try std.testing.expectEqual(Disposition.terminal, disposition(&realm));
    navigable.orphaned = false;
    navigable.active_window = null;
    try std.testing.expectEqual(Disposition.terminal, disposition(&realm));
    try std.testing.expect(realm.hasEngine());
}

test "frame document collection reserve failure leaves callback owners untouched" {
    const allocator = std.testing.allocator;
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    realm.browser_scope = &scope;
    const navigable = try html_mod.window.BrowsingContext.init(allocator, try scope.table(.navigables, html_mod.Navigables));
    defer navigable.deinit();
    var frames = Frames.init(allocator, 0);
    defer frames.pending.deinit(allocator);
    try frames.pending.append(allocator, .{ .handle = 7, .callback = .{ .number = 17 }, .realm = &realm });
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, collectDocuments(failing.allocator(), &realm));
    try std.testing.expectEqual(@as(usize, 1), frames.pending.items.len);
    try std.testing.expectEqual(@as(f64, 17), frames.pending.items[0].callback.number);
    try std.testing.expectEqual(@as(u32, 7), frames.pending.items[0].handle);
}

test "whole frame dispatch token survives empty document batches and detects replaced state" {
    var frames = Frames.init(std.testing.allocator, 0);
    var token: u8 = 0;
    frames.dispatch_token = &token;
    try std.testing.expect(frames.running.len == 0);
    try std.testing.expect(dispatchState(&frames, &token) != null);
    frames.dispatch_token = null;
    try std.testing.expect(dispatchState(&frames, &token) == null);
}

test "frame document identities reject replacement and slab reuse of the same address" {
    // This test needs a fresh per-thread slab, independent of earlier files'
    // Browser/V8 startup. No engine operation reaches the fake engine pointer.
    const Worker = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
        fn body() !void {
            const allocator = std.testing.allocator;
            var slab_value = runtime.SlabAllocator.init(allocator);
            defer slab_value.deinit();
            var scope = runtime.BrowserScope.init(allocator);
            defer scope.deinit();
            var dummy_engine: u32 = 0;
            var realm = try runtime.ContextData.init(allocator, .{ .engine_ctx = &dummy_engine });
            defer realm.deinit();
            realm.browser_scope = &scope;
            const vtable: runtime.VTable = .{ .name = "Window", .deinit = null, .methods_ptr = &dummy_engine };
            const slab = &slab_value;
            const window = try slab.alloc(&vtable);
            defer slab.free(window);
            window.ctx = &realm;
            const original = try slab.alloc(&vtable);
            var original_alive = true;
            defer if (original_alive) slab.free(original);
            original.ctx = &realm;
            const replacement = try slab.alloc(&vtable);
            defer slab.free(replacement);
            replacement.ctx = &realm;
            const record = try runtime.Realm.init(allocator, .{ .global_object = window });
            defer record.deinit();
            realm.setRealm(record);
            defer realm.clearRealm();
            const navigable = try html_mod.window.BrowsingContext.init(allocator, try scope.table(.navigables, html_mod.Navigables));
            defer navigable.deinit();
            navigable.active_window = window;
            navigable.active_document = original;
            const document: FrameDocument = .{
                .navigable_id = navigable.id,
                .window = window,
                .window_generation = runtime.SlabAllocator.generationOf(window),
                .document = original,
                .document_generation = runtime.SlabAllocator.generationOf(original),
                .realm = &realm,
            };
            const callback: AnimationFrameEntry = .{
                .handle = 1,
                .callback = .undefined,
                .realm = &realm,
                .target_document = original,
                .target_document_generation = document.document_generation,
            };
            try std.testing.expect(document.current());
            try std.testing.expect(!targetReplaced(callback));
            navigable.active_document = replacement;
            try std.testing.expect(!document.current());
            try std.testing.expect(targetReplaced(callback));
            navigable.active_document = original;
            slab.free(original);
            original_alive = false;
            const reused = try slab.alloc(&vtable);
            defer slab.free(reused);
            reused.ctx = &realm;
            try std.testing.expect(reused == original);
            try std.testing.expect(!document.current());
            try std.testing.expect(targetReplaced(callback));
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Worker.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "native autofocus rendering retires replaced and destroyed documents and exhausted queues" {
    const Exercise = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.exercise() catch |err| {
                self.failure = err;
            };
        }
        fn exercise(_: *@This()) !void {
            const browser = try @import("Browser.zig").Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const context = browser.current_context.?;
            const frames = &browser.event_loop.?.frames;
            try context.loadHTML("<!doctype html><body><input autofocus>", .{ .base_url = "about:blank" });
            const old_document = context.document_instance.?;
            try std.testing.expect(frames.requests.items.len == 1);
            const request = frames.requests.items[0];
            // Replacement changes the navigable's active Document while the
            // old identity can still exist. A rendering request must not move
            // to the replacement along with its reusable Window.
            try context.loadHTML("<!doctype html><body>replacement", .{ .base_url = "about:blank" });
            try std.testing.expect(context.document_instance.? != old_document);
            try std.testing.expect(!request.document.current());
            retireRequests(frames);
            try std.testing.expectEqual(@as(usize, 0), frames.requests.items.len);

            try context.runScript("document.body.innerHTML = '<input autofocus>'");
            try std.testing.expect(frames.requests.items.len == 1);
            windowDestroyed(context.document_instance.?.ctx);
            try std.testing.expectEqual(@as(usize, 0), frames.requests.items.len);
            // Register its live document again and process the last candidate.
            requestFrame(context.document_instance.?);
            try std.testing.expect(frames.requests.items.len == 1);
            html_mod.autofocus.flush(context.document_instance.?);
            _ = try browser.runEventLoopBlocking(50);
            try std.testing.expectEqual(@as(usize, 0), frames.requests.items.len);
            try std.testing.expect(frames.timer_id == null);
        }
    };
    var exercise: Exercise = .{};
    const thread = try std.Thread.spawn(.{}, Exercise.run, .{&exercise});
    thread.join();
    if (exercise.failure) |err| return err;
}

test "reactivation restores pending native autofocus rendering without an idle timer" {
    const Exercise = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.exercise() catch |err| {
                self.failure = err;
            };
        }
        fn exercise(_: *@This()) !void {
            const browser = try @import("Browser.zig").Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const context = browser.current_context.?;
            const frames = &browser.event_loop.?.frames;
            try context.loadHTML("<!doctype html><body><input autofocus>", .{ .base_url = "about:blank" });
            const document = context.document_instance.?;
            const realm = document.ctx;
            const window = Context.realmWindow(realm).?;
            const navigable = Context.realmNavigable(realm, window).?;
            const saved = navigable.active_document;
            defer navigable.active_document = saved;
            // A cached Document is retained but not the active document of
            // its navigable. Keep its native owner while simulating that gap.
            navigable.active_document = null;
            _ = try browser.runEventLoopBlocking(50);
            try std.testing.expectEqual(@as(usize, 0), frames.requests.items.len);
            try std.testing.expect(frames.timer_id == null);

            navigable.active_document = saved;
            windowResumed(realm);
            try std.testing.expectEqual(@as(usize, 1), frames.requests.items.len);
            try std.testing.expect(frames.timer_id != null);
            html_mod.autofocus.flush(document);
            _ = try browser.runEventLoopBlocking(50);
            windowResumed(realm);
            try std.testing.expectEqual(@as(usize, 0), frames.requests.items.len);
            try std.testing.expect(frames.timer_id == null);
        }
    };
    var exercise: Exercise = .{};
    const thread = try std.Thread.spawn(.{}, Exercise.run, .{&exercise});
    thread.join();
    if (exercise.failure) |err| return err;
}
