//! HTML 2.5.7 "Lazy loading attributes": a Document's lazy load intersection
//! observer, and "start" and "stop intersection-observing a lazy loading
//! element".
//!
//! Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#lazy-loading-attributes
//!
//! HTML makes the observer an IntersectionObserver with a callback that runs
//! a target's lazy load resumption steps once its entry says it intersects.
//! Crane keeps it as a list of targets in the document's rare data (one
//! field, made only for a document that has a lazy element), checked at
//! "update the rendering" step 19, "run the update intersection
//! observations steps" (src/browser/rendering.zig calls `updateObservations`
//! for each document, as it calls the other owners outside the impls), and
//! its callback is a task per target that intersects, as IntersectionObserver
//! 3.2.10's "queue an intersection observer task" makes it.
//!
//! Whether a target intersects the viewport is a geometry read, and geometry
//! is a read on the renderer (the platform layout protocol, 6.9). Without
//! one, Crane answers as its IntersectionObserver does today (every box at
//! the origin of the viewport): a target that is being rendered intersects,
//! and one that is not - display:none on it or an ancestor, disconnected,
//! outside the flat tree - intersects nothing (the integrator's ruling of
//! 2026-11-14, lane ifr1; "being rendered" is the layout-less answer of
//! dom.style.engine.isBeingRendered, ruling Q4).
//! TODO(layout protocol 6.9): with a renderer, ask it whether the target's
//! box intersects the viewport expanded by the lazy load scroll margin.
//!
//! Targets are weak links (same_object.Link): the observer keeps no element
//! alive, as [[ObservationTargets]] does not; a collected target is dropped
//! at the next check, and the rare data's end frees the list.
//!
//! Only iframes observe through here today; img, video and audio still load
//! at once (their lazy loading only stops them delaying the load event).
//!
//! lint-impls: hook for HTMLIFrameElement

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const same_object = @import("same_object.zig");
const document_internals = @import("document_internals.zig");
const node_holds = @import("node_holds.zig");
const refcount = @import("refcount.zig");
const update_the_rendering = @import("update_the_rendering.zig");
const style_engine = @import("style/engine.zig");

const log = std.log.scoped(.lazy_load_observer);

/// A target's lazy load resumption steps, invoked from the observer's
/// callback: the owning impl's, which reads and clears the element's own
/// steps (HTML's callback steps 7.1-7.2) - null steps do nothing.
pub const Resume = *const fn (element: *runtime.Instance) void;

/// One observed element.
pub const Target = struct {
    element: same_object.Link,
    resume_steps: Resume,
};

/// The observer's targets, in the order `observe()` was called (IO 3.2.10
/// step 2.2's order). The document's rare data owns it.
pub const Targets = std.ArrayListUnmanaged(Target);

fn targetsOf(document: *runtime.Instance, create: bool) ?*Targets {
    const internal = document_internals.getInternal(document) orelse return null;
    if (!create) {
        const rare = internal.rareData() orelse return null;
        return &rare.lazy_load_targets;
    }
    const rare = internal.ensureRareData(document) catch return null;
    return &rare.lazy_load_targets;
}

/// "Start intersection-observing a lazy loading element" `element`, whose
/// node document is `document`: observe it (an element already observed is
/// not added again, as observe() does not), and ask for the rendering
/// opportunity that checks it. False when out of memory: the caller loads
/// at once rather than never.
pub fn startObserving(document: *runtime.Instance, element: *runtime.Instance, resume_steps: Resume) bool {
    const targets = targetsOf(document, true) orelse return false;
    const allocator = document.ctx.allocator;
    for (targets.items) |*target| {
        if (target.element.isLive() and target.element.instance == element) {
            target.resume_steps = resume_steps;
            update_the_rendering.requestFrame(document);
            return true;
        }
    }
    targets.append(allocator, .{ .element = .to(element), .resume_steps = resume_steps }) catch return false;
    update_the_rendering.requestFrame(document);
    return true;
}

/// "Stop intersection-observing a lazy loading element" `element`: unobserve
/// it in `document`'s observer (nothing when it is not observed).
pub fn stopObserving(document: *runtime.Instance, element: *runtime.Instance) void {
    const targets = targetsOf(document, false) orelse return;
    var index: usize = 0;
    while (index < targets.items.len) {
        const target = targets.items[index];
        if (target.element.isLive() and target.element.instance == element) {
            _ = targets.orderedRemove(index);
            continue;
        }
        index += 1;
    }
}

/// Whether `document`'s observer has a target.
pub fn hasTargets(document: *runtime.Instance) bool {
    const targets = targetsOf(document, false) orelse return false;
    return targets.items.len != 0;
}

/// "Update the rendering" step 19 for `document`: the lazy load intersection
/// observer's part of "run the update intersection observations steps".
/// Each target that intersects now gets the observer's callback, in a task;
/// a collected target, or one that moved to another document, is dropped.
/// While targets remain, the document's next mutation asks for another
/// rendering opportunity - un-hiding a frame is a mutation.
pub fn updateObservations(document: *runtime.Instance) void {
    const targets = targetsOf(document, false) orelse return;
    var index: usize = 0;
    while (index < targets.items.len) {
        const target = targets.items[index];
        if (!target.element.isLive()) {
            _ = targets.orderedRemove(index);
            continue;
        }
        const element = target.element.instance;
        const owner = interfaces.Node.get_ownerDocument(element) catch null;
        if (owner != document or !(interfaces.Node.get_isConnected(element) catch false)) {
            // Removed, or adopted elsewhere: a removed element intersects
            // nothing, and the insertion that connects it again processes
            // its attributes again ("process the iframe attributes" with
            // initialInsertion), which observes it again. Unobservable, and
            // the list does not keep what a page removes.
            _ = targets.orderedRemove(index);
            continue;
        }
        if (intersects(element)) {
            // The callback's steps 6-7 run in its task; the target is
            // unobserved there ("stop intersection-observing").
            if (!CallbackTask.queue(.{element}, .{ .resume_steps = target.resume_steps })) {
                log.warn("a lazy load callback was not queued", .{});
            }
            // One entry per intersection change: it is not checked again
            // until the callback has run (the callback unobserves it).
            _ = targets.orderedRemove(index);
            continue;
        }
        index += 1;
    }
    // Not intersecting yet: the next mutation asks for the next check.
    if (targets.items.len != 0) refcount.watchRendering(document, true);
}

/// Whether `element` intersects the viewport, as headless Crane answers it
/// (the module comment).
fn intersects(element: *runtime.Instance) bool {
    return style_engine.isBeingRendered(element) catch false;
}

/// The lazy load intersection observer's callback for one entry whose
/// isIntersecting is true (HTML 2.5.7, the callback steps 1-7): the
/// target's lazy load resumption steps, taken and invoked by its owner.
const CallbackPayload = struct {
    pub const held_count = 1;
    pub const queued_given_relevant_global = true;

    resume_steps: Resume,

    pub fn steps(self: *CallbackPayload, held: []const node_holds.TaskHold) void {
        const element = held[0].get() orelse return;
        // 6. "Stop intersection-observing a lazy loading element for
        // entry.target" - done when the entry was taken. 7. "If
        // resumptionSteps is not null: set entry.target's lazy load
        // resumption steps to null; invoke resumptionSteps."
        self.resume_steps(element);
    }
};
const CallbackTask = node_holds.ElementTask(CallbackPayload);
