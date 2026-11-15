//! The Fullscreen API (https://fullscreen.spec.whatwg.org/, specs/whatwg/fullscreen.md):
//! the model (section 2), requestFullscreen() and exitFullscreen() (section
//! 3), :fullscreen (5.1) and the close request (4), as functional state: an
//! element's fullscreen flag, its document's fullscreen element and the
//! events, with nothing drawn - Crane keeps fullscreen as it keeps :hover
//! (the integrator's ruling of 2026-11-14, lane ifr1: a fullscreenEnabled
//! that said true while requestFullscreen did nothing would break a page
//! that feature-detects).
//!
//! Where the state lives: the fullscreen, iframe fullscreen and keyboard
//! lock flags on the element's own top-layer entry, and each document's list
//! of pending fullscreen events, in the document's top-layer state
//! (dom.top_layer) - held, traced and released with the document, as the
//! popovers and dialogs that share the top layer are.
//!
//! "Fullscreen is supported": yes. Headless Crane has no previously
//! established user preference, security risk or platform limitation that
//! refuses it; the viewport resizes of requestFullscreen step 8 and exit
//! fullscreen step 10 change nothing, because Crane's viewport is the host's
//! screen already (the layout protocol's `viewport`, 6.9), as a headless
//! Chrome's window is its screen.
//!
//! "In parallel": requestFullscreen's steps 8-15 and exit fullscreen's steps
//! 9-16 run in a task queued given the element or document (Blink resolves a
//! request after the browser process answers it, in a later task; WebKit's
//! FullscreenManager likewise), and the events fire at the next rendering
//! opportunity, "update the rendering" step 12 (`runFullscreenSteps`).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const user_activation = @import("user_activation.zig");
const popover = @import("popover.zig");
const layer = dom.top_layer;
const Instance = runtime.Instance;
const EventType = layer.FullscreenEvent.Type;

const log = std.log.scoped(.fullscreen);

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const mathml_namespace = "http://www.w3.org/1998/Math/MathML";

/// "Fullscreen is supported" (section 2): the module comment says why.
pub const supported = true;

// ============================================================================
// The model (section 2)
// ============================================================================

/// `document`'s fullscreen element: the topmost element in its top layer
/// whose fullscreen flag is set, or null.
pub fn fullscreenElementOf(document: *Instance) ?*Instance {
    const state = (layer.ofDocument(document, false) catch null) orelse return null;
    return state.fullscreenElement();
}

/// Whether `element`'s fullscreen flag is set.
pub fn hasFullscreenFlag(element: *Instance) bool {
    const state = (layer.ofElement(element, false) catch null) orelse return false;
    return state.fullscreenEntry(element) != null;
}

/// "Fullscreen an element" within its node document `document`.
fn fullscreenAnElement(element: *Instance, document: *Instance) !void {
    // 1. "Let hideUntil be the result of running topmost popover ancestor
    // given element, null, and false." 2. "Run hide popovers until given
    // element's node document, hideUntil, false, and true." - the steps the
    // dialog show steps take too (html.popover.hidePopoversForDialog).
    popover.hidePopoversForDialog(element) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {},
    };
    // 3-5. "Set element's fullscreen flag", "remove from the top layer
    // immediately given element", "add to the top layer given element".
    const state = (try layer.ofDocument(document, true)) orelse return error.NotSupported;
    _ = try state.addFullscreen(element);
}

/// "Unfullscreen an element": unset its fullscreen, iframe fullscreen and
/// keyboard lock flags, and remove it from the top layer immediately.
fn unfullscreenElement(element: *Instance) void {
    const state = (layer.ofElement(element, false) catch null) orelse return;
    _ = state.removeFullscreen(element);
}

/// "Unfullscreen a document": unfullscreen every element within its top
/// layer whose fullscreen flag is set.
fn unfullscreenDocument(document: *Instance) void {
    const state = (layer.ofDocument(document, false) catch null) orelse return;
    while (state.fullscreenElement()) |element| _ = state.removeFullscreen(element);
}

/// "Fully exit fullscreen" a document.
pub fn fullyExitFullscreen(document: *Instance) void {
    // 1. "If document's fullscreen element is null, terminate these steps."
    const state = (layer.ofDocument(document, false) catch null) orelse return;
    const fullscreen_element = state.fullscreenElement() orelse return;
    // 2. "Unfullscreen elements whose fullscreen flag is set, within
    // document's top layer, except for document's fullscreen element."
    while (true) {
        const other = otherFullscreenElement(state, fullscreen_element) orelse break;
        _ = state.removeFullscreen(other);
    }
    // 3. "Exit fullscreen document."
    _ = exitFullscreenSteps(document, null);
}

/// A fullscreen-flagged element of `state` other than `except`.
fn otherFullscreenElement(state: *layer.State, except: *Instance) ?*Instance {
    for (state.entries.items) |entry| {
        if (!entry.fullscreen) continue;
        const node = entry.node() orelse continue;
        if (node != except) return node;
    }
    return null;
}

/// The fullscreen removing steps, "whenever the removing steps run with a
/// removedNode" - registered with dom.mutation by Document. DOM runs the
/// removing steps for the removed node and then for each of its
/// shadow-including descendants, in shadow-including tree order, so step 2's
/// list is `node` itself, each time: the result is the spec's.
pub fn removingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    _ = old_parent;
    if (node.node_type != dom.NodeBase.ELEMENT_NODE) return;
    // A document with no top-layer state has no fullscreen element: the
    // common case reads one pointer.
    const document_node = node.documentBase() orelse return;
    const document: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(document_node) orelse return));
    const state = (layer.ofDocument(document, false) catch null) orelse return;
    const element: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return));
    // 2. nodes: removedNode's shadow-including inclusive descendants that
    // have their fullscreen flag set.
    if (state.fullscreenEntry(element) == null) return;
    // 3.1 "If node is document's fullscreen element, exit fullscreen
    // document."
    if (state.fullscreenElement() == element) {
        _ = exitFullscreenSteps(document, null);
    }
    // 3.2 "Otherwise, unfullscreen node." (Exit fullscreen step 7 already
    // unfullscreened the fullscreen element: it is not connected.)
    unfullscreenElement(element);
    // 3.3 "If document's top layer contains node, remove from the top layer
    // immediately given node." - its fullscreen entry is gone with its
    // flag; a dialog's or a popover's membership is theirs to end.
}

/// HTML's unloading document cleanup steps: "fully exit fullscreen
/// document" (section 2), for the document whose Window `environment`'s
/// global is - registered with dom.unloading_cleanup by Document.
pub fn unloadingCleanup(environment: runtime.Context) void {
    const window = user_activation.windowOfRealm(environment) orelse return;
    const document = (interfaces.Window.get_document(window) catch null) orelse return;
    fullyExitFullscreen(document);
}

/// "Run the fullscreen steps" for `document`: "update the rendering" step
/// 12 (dom.update_the_rendering, installed by Document).
pub fn runFullscreenSteps(document: *Instance) void {
    const state = (layer.ofDocument(document, false) catch null) orelse return;
    if (state.fullscreen_events.items.len == 0) return;
    // The document is held while its events run script.
    var document_hold: dom.node_holds.TaskHold = .{};
    document_hold.take(document);
    defer document_hold.release();
    // 1. "Let pendingEvents be document's list of pending fullscreen events."
    // 2. "Empty document's list of pending fullscreen events."
    const pending = state.takeFullscreenEvents(document.ctx.allocator) catch return;
    defer {
        for (pending) |*event| event.hold.release();
        document.ctx.allocator.free(pending);
    }
    // 3. "For each (type, element) in pendingEvents:"
    for (pending) |*event| {
        // An event's listener can navigate the document away.
        if (document_hold.get() == null) break;
        const element = event.hold.get();
        // 1. "Let target be element if element is connected and its node
        // document is document, and otherwise let target be document."
        const target: *Instance = blk: {
            const e = element orelse break :blk document;
            if (!(interfaces.Node.get_isConnected(e) catch false)) break :blk document;
            const owner = (interfaces.Node.get_ownerDocument(e) catch null) orelse break :blk document;
            break :blk if (owner == document) e else document;
        };
        // 2. "Fire an event named type, with its bubbles and composed
        // attributes set to true, at target."
        fireEvent(target, event.type);
    }
}

fn fireEvent(target: *Instance, event_type: EventType) void {
    const event = interfaces.Event.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(@tagName(event_type)),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = true, .cancelable = false, .composed = true }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = dom.fire_event.dispatchTrusted(target, event) catch {};
}

/// Append (type, element) to `document`'s list of pending fullscreen events,
/// and ask for the rendering opportunity whose step 12 fires it.
fn appendEvent(document: *Instance, event_type: EventType, element: *Instance) void {
    const state = (layer.ofDocument(document, true) catch null) orelse return;
    state.appendFullscreenEvent(event_type, element) catch |err| {
        log.warn("a {s} event was not queued: {}", .{ @tagName(event_type), err });
        return;
    };
    dom.update_the_rendering.requestFrame(document);
}

// ============================================================================
// The API (section 3)
// ============================================================================

/// The fullscreenEnabled getter: "true if this is allowed to use the
/// "fullscreen" feature and fullscreen is supported, and false otherwise".
/// No violation report: a read is not a use (Blink's
/// Fullscreen::FullscreenEnabled reads the policy with kDoNotReport).
pub fn fullscreenEnabled(document: *Instance) bool {
    const allowed = dom.policy_containers.allowedToUseWith(document, .fullscreen, .{ .report = false }) catch false;
    return allowed and supported;
}

/// The "fullscreen element ready check" for `element`. `report`: whether a
/// policy that disables the feature reports this use (requestFullscreen's
/// first check is the attempted use; its second, in parallel, is not
/// another one).
fn readyCheck(element: *Instance, report: bool) bool {
    // "element is connected."
    if (!(interfaces.Node.get_isConnected(element) catch false)) return false;
    // "element's node document is allowed to use the "fullscreen" feature."
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    const allowed = dom.policy_containers.allowedToUseWith(document, .fullscreen, .{ .report = report }) catch false;
    if (!allowed) return false;
    // "element namespace is not the HTML namespace or element's popover
    // visibility state is hidden."
    if (isHtml(element) and layer.showing(element)) return false;
    return true;
}

fn isHtml(element: *Instance) bool {
    const data = dom.element_data.of(element) orelse return false;
    return std.mem.eql(u8, data.namespaceSlice() orelse "", html_namespace);
}

/// requestFullscreen step 5's first condition: "This's namespace is the
/// HTML namespace or this is an SVG svg or MathML math element."
fn mayBeFullscreen(element: *Instance) bool {
    const data = dom.element_data.of(element) orelse return false;
    const namespace = data.namespaceSlice() orelse return false;
    if (std.mem.eql(u8, namespace, html_namespace)) return true;
    if (std.mem.eql(u8, namespace, svg_namespace)) return std.mem.eql(u8, data.localName(), "svg");
    if (std.mem.eql(u8, namespace, mathml_namespace)) return std.mem.eql(u8, data.localName(), "math");
    return false;
}

fn nodeDocumentOf(node: *Instance) ?*Instance {
    return interfaces.Node.get_ownerDocument(node) catch null;
}

fn isFullyActive(document: *Instance) bool {
    return dom.document_activity.fullyActive(document, runtime.SlabAllocator.generationOf(document));
}

/// A document's node navigable's container, or null (a top-level
/// traversable's document, or a document no navigable shows).
fn containerOf(document: *Instance) ?*Instance {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
    return dom.navigable_container.of(window);
}

/// `document`'s node navigable's top-level traversable's active document.
fn topLevelDocumentOf(document: *Instance) *Instance {
    var current = document;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const container = containerOf(current) orelse return current;
        current = nodeDocumentOf(container) orelse return current;
    }
    return current;
}

/// A new promise in `realm`, rejected with a TypeError, as an owned value.
fn rejectedWithTypeError(realm: runtime.Context, message: []const u8) !runtime.JSValue {
    const exception = try engine.createSimpleException(realm, .TypeError, message);
    defer exception.release();
    return (try engine.createRejectedPromise(realm, exception.value)).take();
}

fn rejectWithTypeError(realm: runtime.Context, capability: *engine.PromiseCapability, message: []const u8) void {
    const exception = engine.createSimpleException(realm, .TypeError, message) catch return;
    defer exception.release();
    engine.rejectPromise(capability, exception.value) catch {};
}

/// The requestFullscreen(options) method steps, for `this`.
pub fn requestFullscreen(this: *Instance, options: dictionaries.FullscreenOptions) !runtime.JSValue {
    const realm = this.ctx;
    // 1. "Let pendingDoc be this's node document."
    const pending_doc = nodeDocumentOf(this) orelse return rejectedWithTypeError(realm, "The element has no node document.");
    // 3. "If pendingDoc is not fully active, then reject promise with a
    // TypeError exception and return promise."
    if (!isFullyActive(pending_doc)) return rejectedWithTypeError(realm, "The document is not fully active.");
    // 2. "Let promise be a new promise."
    var capability = try engine.createPromise(realm);
    const result = engine.retainValue(realm, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    // From here the queued task's payload owns the capability, or its
    // queueing released it.
    errdefer result.release();
    // 4. "Let error be false."
    var failed = false;
    // 5. "If any of the following conditions are false, then set error to
    // true:" - the namespace, not a dialog, the ready check, fullscreen is
    // supported, and this's relevant global object has transient activation
    // (no orientation change triggers one in Crane).
    const window = user_activation.windowOfRealm(realm);
    if (!mayBeFullscreen(this) or
        this.stateAs(interfaces.HTMLDialogElement.State) != null or
        !readyCheck(this, true) or
        !supported or
        !(if (window) |w| user_activation.hasTransientActivation(w) else false))
    {
        failed = true;
    }
    // 6. "If error is false, then consume user activation given pendingDoc's
    // relevant global object."
    if (!failed) {
        if (user_activation.windowOfRealm(pending_doc.ctx)) |w| user_activation.consume(w);
    }
    // 7. "Return promise, and run the remaining steps in parallel."
    const queued = RequestTask.queue(.{ this, pending_doc }, .{
        .capability = capability,
        .failed = failed,
        // 14 reads options["keyboardLock"]: "browser" sets the flag, "none"
        // (the default) unsets it.
        .keyboard_lock = if (options.keyboardLock) |lock| lock == ._browser_ else false,
    });
    if (!queued) return error.OutOfMemory;
    return result.take();
}

/// requestFullscreen steps 8-15, in a task queued given `this`.
const RequestPayload = struct {
    pub const held_count = 2;
    pub const queued_given_relevant_global = true;

    capability: engine.PromiseCapability,
    failed: bool,
    /// options["keyboardLock"] is "browser".
    keyboard_lock: bool,

    pub fn deinit(self: *RequestPayload) void {
        engine.releasePromiseCapability(&self.capability);
    }

    pub fn steps(self: *RequestPayload, held: []const dom.node_holds.TaskHold) void {
        const this = held[0].get() orelse return;
        const pending_doc = held[1].get() orelse return;
        requestInParallel(this, pending_doc, self) catch |err| {
            log.warn("requestFullscreen did not complete: {}", .{err});
            rejectWithTypeError(this.ctx, &self.capability, "Fullscreen request failed.");
        };
    }
};
const RequestTask = dom.node_holds.ElementTask(RequestPayload);

fn requestInParallel(this: *Instance, pending_doc: *Instance, payload: *RequestPayload) !void {
    var failed = payload.failed;
    // 8. Resize the viewport: Crane's viewport is the screen already (the
    // module comment).
    // 9. "If any of the following conditions are false, then set error to
    // true: This's node document is pendingDoc. The fullscreen element
    // ready check for this returns true."
    if (nodeDocumentOf(this) != pending_doc or !readyCheck(this, false)) failed = true;
    // 10. "If error is true: append (fullscreenerror, this) to pendingDoc's
    // list of pending fullscreen events. Reject promise with a TypeError
    // exception and terminate these steps."
    if (failed) {
        appendEvent(pending_doc, .fullscreenerror, this);
        rejectWithTypeError(this.ctx, &payload.capability, "Fullscreen request denied.");
        return;
    }
    // 11. "Let fullscreenElements be an ordered set initially consisting of
    // this." 12. "While true: ... container ... append container" - each
    // held, as step 13 runs script (the popovers it hides).
    var elements: std.ArrayListUnmanaged(dom.node_holds.TaskHold) = .empty;
    defer {
        for (elements.items) |*hold| hold.release();
        elements.deinit(this.ctx.allocator);
    }
    try elements.append(this.ctx.allocator, .{});
    elements.items[0].take(this);
    var last = this;
    while (elements.items.len < 64) {
        const doc = nodeDocumentOf(last) orelse break;
        const container = containerOf(doc) orelse break;
        try elements.append(this.ctx.allocator, .{});
        elements.items[elements.items.len - 1].take(container);
        last = container;
    }
    // 13. "For each element in fullscreenElements:"
    for (elements.items) |*hold| {
        const element = hold.get() orelse continue;
        // 1. "Let doc be element's node document."
        const doc = nodeDocumentOf(element) orelse continue;
        // 2. "If element is doc's fullscreen element, continue."
        if (fullscreenElementOf(doc) == element) continue;
        // 4. "Fullscreen element within doc."
        try fullscreenAnElement(element, doc);
        // 3. "If element is this and this is an iframe element, then set
        // element's iframe fullscreen flag." (After 4, which makes the
        // entry the flag is kept on; nothing reads it between.)
        if (element == this and this.stateAs(interfaces.HTMLIFrameElement.State) != null) {
            const state: ?*layer.State = layer.ofDocument(doc, false) catch null;
            if (state) |s| if (s.fullscreenEntry(element)) |entry| {
                entry.iframe_fullscreen = true;
            };
        }
        // 5. "Append (fullscreenchange, element) to doc's list of pending
        // fullscreen events."
        appendEvent(doc, .fullscreenchange, element);
    }
    // 14. "Depending on the value of options["keyboardLock"]": "browser"
    // sets this's keyboard lock flag, "none" unsets it.
    if (nodeDocumentOf(this)) |doc| {
        if (layer.ofDocument(doc, false) catch null) |state| {
            if (state.fullscreenEntry(this)) |entry| entry.keyboard_lock = payload.keyboard_lock;
        }
    }
    // 15. "Resolve promise with undefined."
    engine.resolvePromise(&payload.capability, .undefined) catch {};
}

/// The exitFullscreen() method steps: "return the result of running exit
/// fullscreen on this".
pub fn exitFullscreen(document: *Instance) !runtime.JSValue {
    const realm = document.ctx;
    // 1. "Let promise be a new promise."
    // 2. "If doc is not fully active or doc's fullscreen element is null,
    // then reject promise with a TypeError exception and return promise."
    if (!isFullyActive(document) or fullscreenElementOf(document) == null) {
        return rejectedWithTypeError(realm, "The document is not in fullscreen.");
    }
    var capability = try engine.createPromise(realm);
    const result = engine.retainValue(realm, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    // From here the queued task's payload owns the capability, or its
    // queueing released it.
    errdefer result.release();
    if (!exitFullscreenSteps(document, capability)) return error.OutOfMemory;
    return result.take();
}

/// "Exit fullscreen" `doc`, steps 1-8, with the promise `capability` (taken)
/// - null when nothing can observe it (the removing steps, fully exit
/// fullscreen). Steps 9-16 run in a task. False only when the task could
/// not be queued.
fn exitFullscreenSteps(document: *Instance, capability: ?engine.PromiseCapability) bool {
    var owned = capability;
    // 2. Not fully active, or no fullscreen element: rejected (the method
    // checks first; the other callers have a fullscreen element).
    if (!isFullyActive(document) or fullscreenElementOf(document) == null) {
        if (owned) |*c| {
            rejectWithTypeError(document.ctx, c, "The document is not in fullscreen.");
            engine.releasePromiseCapability(c);
        }
        return true;
    }
    // 3. "Let resize be false."
    var resize = false;
    var doc = document;
    // 4. "Let docs be the result of collecting documents to unfullscreen
    // given doc."
    var docs = collectDocumentsToUnfullscreen(doc);
    defer docs.deinit(doc.ctx.allocator);
    // 5. "Let topLevelDoc be doc's node navigable's top-level traversable's
    // active document."
    const top_level_doc = topLevelDocumentOf(doc);
    // 6. "If topLevelDoc is in docs, and it is a simple fullscreen document,
    // then set doc to topLevelDoc and resize to true."
    if (contains(docs.items, top_level_doc) and isSimpleFullscreenDocument(top_level_doc)) {
        doc = top_level_doc;
        resize = true;
    }
    // 7. "If doc's fullscreen element is not connected: append
    // (fullscreenchange, doc's fullscreen element) to doc's list of pending
    // fullscreen events; unfullscreen doc's fullscreen element."
    if (fullscreenElementOf(doc)) |fullscreen_element| {
        if (!(interfaces.Node.get_isConnected(fullscreen_element) catch false)) {
            appendEvent(doc, .fullscreenchange, fullscreen_element);
            unfullscreenElement(fullscreen_element);
        }
    }
    // 8. "Return promise, and run the remaining steps in parallel."
    const queued = ExitTask.queue(.{doc}, .{ .capability = owned, .resize = resize });
    owned = null;
    return queued;
}

/// Exit fullscreen steps 9-16, in a task queued given `doc`.
const ExitPayload = struct {
    pub const held_count = 1;
    pub const queued_given_relevant_global = true;

    capability: ?engine.PromiseCapability,
    resize: bool,

    pub fn deinit(self: *ExitPayload) void {
        if (self.capability) |*c| engine.releasePromiseCapability(c);
    }

    pub fn steps(self: *ExitPayload, held: []const dom.node_holds.TaskHold) void {
        const doc = held[0].get() orelse return;
        exitInParallel(doc, self.resize);
        // 11 and 16. "Resolve promise with undefined."
        if (self.capability) |*c| engine.resolvePromise(c, .undefined) catch {};
    }
};
const ExitTask = dom.node_holds.ElementTask(ExitPayload);

fn exitInParallel(doc: *Instance, resize: bool) void {
    // 9. The fully unlock the screen orientation steps: Crane locks no
    // screen orientation. 10. Resizing the viewport changes nothing (the
    // module comment).
    // 11. "If doc's fullscreen element is null, then resolve promise with
    // undefined and terminate these steps."
    if (fullscreenElementOf(doc) == null) return;
    const allocator = doc.ctx.allocator;
    // 12. "Let exitDocs be the result of collecting documents to
    // unfullscreen given doc."
    var exit_docs = collectDocumentsToUnfullscreen(doc);
    defer exit_docs.deinit(allocator);
    // 13. "Let descendantDocs be an ordered set consisting of doc's
    // descendant navigables' active documents whose fullscreen element is
    // non-null, if any, in tree order." (The order is not observable: each
    // document's events fire in its own step 12.)
    var descendants = dom.navigables.inclusiveDescendantDocuments(doc, allocator);
    defer descendants.deinit(allocator);
    // 14. "For each exitDoc in exitDocs:"
    for (exit_docs.items) |exit_doc| {
        const fullscreen_element = fullscreenElementOf(exit_doc) orelse continue;
        // 1. "Append (fullscreenchange, exitDoc's fullscreen element) to
        // exitDoc's list of pending fullscreen events."
        appendEvent(exit_doc, .fullscreenchange, fullscreen_element);
        // 2. "If resize is true, unfullscreen exitDoc." 3. "Otherwise,
        // unfullscreen exitDoc's fullscreen element."
        if (resize) unfullscreenDocument(exit_doc) else unfullscreenElement(fullscreen_element);
    }
    // 15. "For each descendantDoc in descendantDocs:"
    const start: usize = if (descendants.items.len > 0) 1 else 0;
    for (descendants.items[start..]) |entry| {
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        const fullscreen_element = fullscreenElementOf(entry.document) orelse continue;
        // 1. "Append (fullscreenchange, descendantDoc's fullscreen element)
        // to descendantDoc's list of pending fullscreen events."
        appendEvent(entry.document, .fullscreenchange, fullscreen_element);
        // 2. "Unfullscreen descendantDoc."
        unfullscreenDocument(entry.document);
    }
}

/// "A simple fullscreen document": exactly one element in its top layer has
/// its fullscreen flag set.
fn isSimpleFullscreenDocument(document: *Instance) bool {
    const state = (layer.ofDocument(document, false) catch null) orelse return false;
    return state.fullscreenCount() == 1;
}

fn contains(documents: []const *Instance, document: *Instance) bool {
    for (documents) |d| if (d == document) return true;
    return false;
}

/// "Collect documents to unfullscreen" given `doc`. OWNED by doc's
/// context allocator; out of memory stops the walk where it is.
fn collectDocumentsToUnfullscreen(doc: *Instance) std.ArrayListUnmanaged(*Instance) {
    const allocator = doc.ctx.allocator;
    // 1. "Let docs be an ordered set consisting of doc."
    var docs: std.ArrayListUnmanaged(*Instance) = .empty;
    docs.append(allocator, doc) catch return docs;
    // 2. "While true:"
    while (docs.items.len < 64) {
        // 1. "Let lastDoc be docs's last document."
        const last_doc = docs.items[docs.items.len - 1];
        // 2. "Assert: lastDoc's fullscreen element is not null."
        // 3. "If lastDoc is not a simple fullscreen document, break."
        if (!isSimpleFullscreenDocument(last_doc)) break;
        // 4. "Let container be lastDoc's node navigable's container."
        // 5. "If container is null, then break."
        const container = containerOf(last_doc) orelse break;
        // 6. "If container's iframe fullscreen flag is set, break."
        const container_doc = nodeDocumentOf(container) orelse break;
        if (layer.ofDocument(container_doc, false) catch null) |state| {
            if (state.fullscreenEntry(container)) |entry| if (entry.iframe_fullscreen) break;
        }
        // 7. "Append container's node document to docs."
        if (contains(docs.items, container_doc)) break;
        docs.append(allocator, container_doc) catch break;
    }
    // 3. "Return docs."
    return docs;
}

// ============================================================================
// :fullscreen (section 5.1)
// ============================================================================

/// ":fullscreen must match any element element for which one of the
/// following conditions is true: element's fullscreen flag is set; element
/// is a shadow host and the result of retargeting its node document's
/// fullscreen element against element is element."
pub fn matchesFullscreenPseudoClass(element: *Instance) bool {
    const node = dom.instance_bridge.getNodeBase(element) orelse return false;
    const document_node = node.documentBase() orelse return false;
    const document: *Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(document_node) orelse return false));
    // The common case: a document with no top-layer state, one pointer read.
    const state = (layer.ofDocument(document, false) catch null) orelse return false;
    if (state.fullscreenEntry(element) != null) return true;
    const fullscreen_element = state.fullscreenElement() orelse return false;
    if (dom.shadow_hosts.rootForHost(element) == null) return false;
    const retargeted = dom.retarget.retarget(fullscreen_element, element) catch return false;
    return retargeted == element;
}

// ============================================================================
// The close request (section 4)
// ============================================================================

/// HTML close request steps step 1, given `document`: "If document's
/// fullscreen element is not null: fully exit fullscreen given document's
/// node navigable's top-level traversable's active document, and return."
/// Whether the request ended there.
pub fn closeRequestEndsInFullscreen(document: *Instance) bool {
    if (fullscreenElementOf(document) == null) return false;
    fullyExitFullscreen(topLevelDocumentOf(document));
    return true;
}
