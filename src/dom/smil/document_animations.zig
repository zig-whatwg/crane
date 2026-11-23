//! SVG animation elements in a document: where the timing model
//! (timed_element.zig, time_container.zig) meets the DOM.
//!
//! - An outermost svg element that is connected has a timeline (SVG
//!   Animations 2 4.1: "The outermost svg element of an SVG document
//!   fragment defines a timeline"); its document lists it. The timeline
//!   begins when the document's load event has fired, or at once for an svg
//!   element inserted into a document that has loaded (SVG Animations 2 4.1
//!   'timelinebegin' "loadend"; Blink SVGSVGElement::InsertedInto and
//!   Document::DispatchLoadAndPageshowEvents -> StartAnimations).
//!
//!   Whose timeline an animation element is on: its outermost svg
//!   element's, as SVG Animations 2 4.1 and 5.8 define it and Firefox does
//!   (SVGAnimationElement::GetTimeContainer -> the outer svg element).
//!   Chrome and Safari give every svg element a timeline of its own and an
//!   animation element its nearest svg ancestor's (Blink
//!   SVGSMILElement::InsertedInto, ownerSVGElement()). Golden rule 2: the
//!   spec changed (SVG 1.1 made each svg element a document fragment) and
//!   one browser ships the newer text, so Crane implements it.
//!
//! - A connected animation element is scheduled on that timeline, with its
//!   target element (SVG Animations 2 2.5: its href's element, else its
//!   parent) and its syncbase conditions connected to the timed elements
//!   their ids name.
//!
//! - HTML "update the rendering" step 11 moves every started timeline of the
//!   document to the document's animation time (Blink runs SMIL in the same
//!   frame step, PageAnimator::ServiceScriptedAnimations ->
//!   SVGDocumentExtensions::ServiceSmilOnAnimationFrame), queues the
//!   TimeEvents each element's change raised - a task per element on its
//!   realm's loop, the DOM manipulation task source, as Blink
//!   (EnqueueEvent) and Gecko (FireTimeEventAsync) dispatch them, after the
//!   sample - and asks for the next frame while a timeline has a time to
//!   come.
//!
//! - The animated values: each target attribute's value from the
//!   highest-priority contributing <set> (SMIL Animation 3.5, the animation
//!   sandwich: later begin wins, then later in tree order), read by the SVG
//!   DOM's animVal (SVGAnimatedString). Computed again on read after any
//!   change (`values_dirty`); the DOM attribute itself never changes.
//!
//! Lifetimes. The per-element states are their impls' (SVGAnimationElement
//! owns an `AnimationState`, SVGSVGElement a `Timeline`), reached through
//! the hooks the impls install. Elements are held weakly - a document's
//! list of timelines, an animation's target - by same_object.Link: nothing
//! here keeps a node alive. A queued TimeEvent task holds its element
//! (node_holds.ElementTask) until it runs.
//!
//! lint-impls: hook for SVGAnimationElement, SVGSVGElement
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const Hook = @import("process").hook.Hook;
const element_data = @import("../element_data.zig");
const element_references = @import("../element_references.zig");
const instance_bridge = @import("../instance_bridge.zig");
const NodeBase = @import("../node_base.zig").NodeBase;
const same_object = @import("../same_object.zig");
const node_holds = @import("../node_holds.zig");
const update_the_rendering = @import("../update_the_rendering.zig");
const animations_registry = @import("../animations/registry.zig");
const document_internals = @import("../document_internals.zig");
const document_lifecycle = @import("../document_lifecycle.zig");
const event_construction = @import("../event_construction.zig");
const fire_event = @import("../fire_event.zig");
const reflected_with_fallback = @import("../reflected_with_fallback.zig");
const event_handlers = @import("../event_handlers.zig");
const css = @import("css");
const infra = @import("infra");
const resource_loading = @import("../style/resource_loading.zig");
const style_hooks = @import("../style/hooks.zig");
const csp_violations = @import("../csp_violations.zig");
const time_mod = @import("time.zig");
const parse = @import("parse.zig");
const timed = @import("timed_element.zig");
const TimeContainer = @import("time_container.zig").TimeContainer;

const Time = time_mod.Time;
const TimedElement = timed.TimedElement;
const Link = same_object.Link;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.smil);

pub const svg_namespace = "http://www.w3.org/2000/svg";
const xlink_namespace = "http://www.w3.org/1999/xlink";

// ============================================================================
// The states the impls own
// ============================================================================

/// The animation elements (SVG Animations 2 2.1).
pub const Kind = enum(u2) { set, animate, animate_motion, animate_transform };

pub fn kindOf(local_name: []const u8) ?Kind {
    if (std.mem.eql(u8, local_name, "set")) return .set;
    if (std.mem.eql(u8, local_name, "animate")) return .animate;
    if (std.mem.eql(u8, local_name, "animateMotion")) return .animate_motion;
    if (std.mem.eql(u8, local_name, "animateTransform")) return .animate_transform;
    return null;
}

/// An animation element's state: its timed element, its target, and the
/// timeline it is on. OWNED by the SVGAnimationElement impl, a block of its
/// Browser's arena in a side table (dom.orphan_states.Swept): `detach` then
/// `deinit` in the element's own teardown, `deinit` alone in an orphan's
/// sweep. Never moved once made: the timed element is pointed at.
pub const AnimationState = struct {
    allocator: Allocator,
    timed: TimedElement,
    /// The animation element. Its own state: never a hold.
    element: *runtime.Instance,
    /// SVG Animations 2 2.5: the element this animation modifies, while it
    /// is connected. A weak link.
    target: ?Link = null,
    /// The outermost svg element whose timeline schedules `timed`.
    timeline_svg: ?Link = null,

    pub fn init(allocator: Allocator, element: *runtime.Instance) AnimationState {
        return .{ .allocator = allocator, .timed = TimedElement.init(allocator), .element = element };
    }

    /// Off the timeline and the syncbases (the element's own teardown).
    pub fn detach(self: *AnimationState) void {
        self.timed.detach();
    }

    /// What the state owns (dom.orphan_states: no instance is read).
    pub fn deinit(self: *AnimationState) void {
        self.timed.deinit();
    }

    fn fromTimed(timed_element: *TimedElement) *AnimationState {
        return @fieldParentPtr("timed", timed_element);
    }
};

/// An outermost svg element's timeline. OWNED by the SVGSVGElement impl,
/// made the first time an animation needs it, a block of its Browser's arena
/// in a side table (dom.orphan_states.Swept): `detach` then `deinit` in the
/// svg element's own teardown, `deinit` alone in an orphan's sweep.
pub const Timeline = struct {
    container: TimeContainer,

    pub fn init(allocator: Allocator) Timeline {
        return .{ .container = TimeContainer.init(allocator) };
    }

    /// Leave the animations on no timeline (the svg element's teardown).
    pub fn detach(self: *Timeline) void {
        self.container.detachAll();
    }

    /// What the timeline owns (dom.orphan_states: no instance is read).
    pub fn deinit(self: *Timeline) void {
        self.container.deinit();
    }
};

pub const AnimationElementSteps = struct {
    /// The state of `element`, an animation element; null for any other.
    state_of: *const fn (element: *runtime.Instance) ?*AnimationState,
};

pub const SvgElementSteps = struct {
    /// The timeline of `svg`, an svg element - made when `create` is set;
    /// null for any other element.
    timeline_of: *const fn (svg: *runtime.Instance, create: bool) ?*Timeline,
    /// Whether `element` is an svg element: its brand, no lookup.
    is_svg: *const fn (element: *runtime.Instance) bool,
};

/// Process-wide, written once at start-up (hook.zig).
var animation_steps: Hook(?AnimationElementSteps) = .init(null);
/// Process-wide, written once at start-up (hook.zig).
var svg_steps: Hook(?SvgElementSteps) = .init(null);

/// Called by SVGAnimationElement's installHooks, once, at process start.
pub fn installAnimationElement(steps: AnimationElementSteps) void {
    animation_steps.install(steps);
}

/// Called by SVGSVGElement's installHooks, once, at process start.
pub fn installSvgElement(steps: SvgElementSteps) void {
    svg_steps.install(steps);
}

pub fn stateOf(element: *runtime.Instance) ?*AnimationState {
    const steps = animation_steps.get() orelse return null;
    return steps.state_of(element);
}

fn timelineOf(svg: *runtime.Instance, create: bool) ?*Timeline {
    const steps = svg_steps.get() orelse return null;
    return steps.timeline_of(svg, create);
}

// ============================================================================
// A document's timelines and animated values
// ============================================================================

/// One target attribute's animated value.
pub const AnimatedValue = struct {
    target: Link,
    /// The attribute's namespace and local name, and its value. Owned.
    namespace: ?[]u8,
    local_name: []u8,
    value: []u8,

    fn deinit(self: *AnimatedValue, allocator: Allocator) void {
        if (self.namespace) |ns| allocator.free(ns);
        allocator.free(self.local_name);
        allocator.free(self.value);
    }
};

/// One target element's override style: the CSS properties animations set
/// on it (SVG Animations 2 2.6), as a declaration block. Owned.
pub const AnimatedStyle = struct {
    target: Link,
    block: css.declarations.DeclarationBlock,
};

/// When an outermost svg element's timeline began, for one that has no
/// timeline yet. The link tells a reused address from the element.
pub const LateBegin = struct {
    svg: Link,
    at: Time,
};

/// A document's SVG animation state, in its rare data: the outermost svg
/// elements with a timeline, and the animated values computed last.
pub const DocumentState = struct {
    timelines: std.ArrayListUnmanaged(Link) = .empty,
    values: std.ArrayListUnmanaged(AnimatedValue) = .empty,
    styles: std.ArrayListUnmanaged(AnimatedStyle) = .empty,
    /// A hash of what `styles` declared at the last computation: a change
    /// re-keys the document's cached styles.
    style_signature: u64 = 0,
    values_dirty: bool = false,
    /// The time the document's timelines began at its load: the begin of
    /// every outermost svg element connected then that has no timeline yet.
    loaded_at: ?Time = null,
    /// The outermost svg elements inserted after the load that have no
    /// timeline yet, with the time each was inserted - the time its
    /// timeline began (Blink SVGSVGElement::InsertedInto, Gecko
    /// SVGSVGElement::BindToTree, WebKit SVGSVGElement::insertedIntoAncestor
    /// start the time container then, animations or not). Only the time is
    /// kept until an animation or a timeline method needs the timeline;
    /// an entry goes with its element's removal.
    late_begins: std.AutoHashMapUnmanaged(*runtime.Instance, LateBegin) = .empty,
    /// An svg element moved in and out of a loaded document puts and
    /// removes its entry each time (infra.tombstones).
    late_begins_guard: infra.tombstones.TombstoneGuard = .{},

    pub fn deinit(self: *DocumentState, allocator: Allocator) void {
        self.late_begins.deinit(allocator);
        self.timelines.deinit(allocator);
        for (self.values.items) |*value| value.deinit(allocator);
        self.values.deinit(allocator);
        for (self.styles.items) |*style| style.block.deinit();
        self.styles.deinit(allocator);
    }
};

fn documentState(document: *runtime.Instance, create: bool) ?*DocumentState {
    const internal = document_internals.getInternal(document) orelse return null;
    if (!create) {
        const rare = internal.rareData() orelse return null;
        return &rare.smil;
    }
    const rare = internal.ensureRareData(document) catch return null;
    return &rare.smil;
}

fn documentOf(node: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Node.get_ownerDocument(node) catch null;
}

/// The document timeline's time (Web Animations 4.3: the document's
/// animation time), or null while the document is not fully active.
fn documentNow(document: *runtime.Instance) ?Time {
    const ms = animations_registry.documentTime(document) orelse return null;
    return Time.fromMilliseconds(ms);
}

/// The document timeline's time for `node`'s document, or 0 when it has
/// none (a document that is not fully active: its timelines do not move).
fn nowOf(node: *runtime.Instance) Time {
    const document = documentOf(node) orelse return .zero;
    return documentNow(document) orelse .zero;
}

fn isConnected(node: *runtime.Instance) bool {
    return interfaces.Node.get_isConnected(node) catch false;
}

fn svgName(element: *runtime.Instance) ?[]const u8 {
    const view = element_data.of(element) orelse return null;
    if (view.name.namespace != .svg) return null;
    return view.name.local_name;
}

/// The outermost svg element of the SVG document fragment `element` is in
/// (SVG 2 5.1.1: an svg element "that is not a child of another SVG
/// element"): up through its SVG ancestors, the last svg element met.
pub fn outermostSvgElement(element: *runtime.Instance) ?*runtime.Instance {
    var outermost: ?*runtime.Instance = null;
    var current: ?*runtime.Instance = element;
    while (current) |node| {
        const name = svgName(node) orelse break;
        if (std.mem.eql(u8, name, "svg")) outermost = node;
        current = interfaces.Node.get_parentElement(node) catch null;
    }
    return outermost;
}

fn isOutermost(svg: *runtime.Instance) bool {
    const parent = (interfaces.Node.get_parentElement(svg) catch null) orelse return true;
    return svgName(parent) == null;
}

/// The timeline `svg` (an outermost svg element) defines, listed in its
/// document.
fn registeredTimeline(svg: *runtime.Instance) ?*Timeline {
    const timeline = ensureTimeline(svg) orelse return null;
    const document = documentOf(svg) orelse return timeline;
    const state = documentState(document, true) orelse return timeline;
    for (state.timelines.items) |link| {
        if (link.instance == svg and link.isLive()) return timeline;
    }
    state.timelines.append(document.ctx.allocator, Link.to(svg)) catch return timeline;
    return timeline;
}

/// `svg`'s timeline, made if it has none. A connected outermost svg
/// element's timeline began at the load or at its insertion after it, so
/// one made later starts at that time, not now: an animation added to it
/// is on the timeline the element has had since (Blink
/// SMILTimeContainer::Start from SVGSVGElement::InsertedInto, for every
/// outermost svg element).
fn ensureTimeline(svg: *runtime.Instance) ?*Timeline {
    if (timelineOf(svg, false)) |timeline| return timeline;
    const timeline = timelineOf(svg, true) orelse return null;
    if (!isConnected(svg) or !isOutermost(svg)) return timeline;
    const document = documentOf(svg) orelse return timeline;
    if (!canStart(document)) return timeline; // startAnimations starts it
    const state = documentState(document, false);
    const began = if (state) |s| takeBegin(s, svg) else null;
    timeline.container.start(began orelse documentNow(document).?);
    return timeline;
}

/// When `svg`'s timeline began, for an svg element with none yet: its
/// insertion after the load, else the load. Null when neither is known.
fn beganAt(state: *DocumentState, svg: *runtime.Instance) ?Time {
    if (state.late_begins.get(svg)) |late| {
        if (late.svg.instance == svg and late.svg.isLive()) return late.at;
    }
    return state.loaded_at;
}

/// `beganAt`, and the entry goes: the timeline holds the time from now on.
fn takeBegin(state: *DocumentState, svg: *runtime.Instance) ?Time {
    const began = beganAt(state, svg);
    forgetBegin(state, svg);
    return began;
}

fn forgetBegin(state: *DocumentState, svg: *runtime.Instance) void {
    if (state.late_begins.count() == 0) return;
    if (state.late_begins.remove(svg)) state.late_begins_guard.noteRemoval(&state.late_begins);
}

/// An outermost svg element with no timeline became connected: a loaded
/// document's keeps the time it began, for the timeline an animation or a
/// timeline method makes later; before the load, the document is told to
/// keep the load's time.
fn noteBegin(svg: *runtime.Instance, document: *runtime.Instance) void {
    // A document that is not fully active (DOMParser's, an inert one) has
    // no animation time, and its timelines do not begin.
    const now = documentNow(document) orelse return;
    const state = documentState(document, true) orelse return;
    if (!document_lifecycle.isCompletelyLoaded(document)) return;
    state.late_begins_guard.beforeInsert(&state.late_begins);
    state.late_begins.put(document.ctx.allocator, svg, .{ .svg = Link.to(svg), .at = now }) catch return;
}

fn unregisterTimeline(svg: *runtime.Instance, document: *runtime.Instance) void {
    const state = documentState(document, false) orelse return;
    forgetBegin(state, svg);
    var kept: usize = 0;
    for (state.timelines.items) |link| {
        if (!link.isLive() or link.instance == svg) continue;
        state.timelines.items[kept] = link;
        kept += 1;
    }
    state.timelines.shrinkRetainingCapacity(kept);
}

fn markValuesDirty(node: *runtime.Instance) void {
    const document = documentOf(node) orelse return;
    const state = documentState(document, false) orelse return;
    state.values_dirty = true;
}

/// Whether the document's timelines can start: its load event fired, and
/// it is fully active (the timeline runs on its animation time).
fn canStart(document: *runtime.Instance) bool {
    return document_lifecycle.isCompletelyLoaded(document) and documentNow(document) != null;
}

// ============================================================================
// Insertion, removal, attribute changes
// ============================================================================

/// DOM insertion steps, for every inserted node (dom.mutation).
pub fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1 or !node.is_connected) return;
    const element = instanceOf(node) orelse return;
    // Two brand checks (one ancestry entry each) before any lookup: nearly
    // every inserted element is neither an svg nor an animation element.
    if (isSvgElement(element)) {
        if (isOutermost(element)) svgInserted(element);
        return;
    }
    const state = stateOf(element) orelse return;
    animationInserted(state);
}

/// DOM removing steps (dom.mutation): `node` left a connected tree.
pub fn removingSteps(node: *NodeBase, old_parent: ?*NodeBase) void {
    _ = old_parent;
    if (node.node_type != 1) return;
    const element = instanceOf(node) orelse return;
    if (isSvgElement(element)) {
        if (documentOf(element)) |document| unregisterTimeline(element, document);
        return;
    }
    const state = stateOf(element) orelse return;
    animationRemoved(state);
}

/// Whether `element` is an svg element (SVGSVGElement's brand).
fn isSvgElement(element: *runtime.Instance) bool {
    const steps = svg_steps.get() orelse return false;
    return steps.is_svg(element);
}

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    const ptr = instance_bridge.getInstance(node) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

/// An outermost svg element became connected: its timeline is listed, and
/// begins at once in a document that has loaded.
fn svgInserted(svg: *runtime.Instance) void {
    const document = documentOf(svg) orelse return;
    // Only an svg element an animation or a timeline method gave a timeline
    // has one: most never do, and keep only the time theirs began.
    if (timelineOf(svg, false) == null) return noteBegin(svg, document);
    const timeline = registeredTimeline(svg) orelse return;
    if (!timeline.container.started and canStart(document)) {
        timeline.container.start(documentNow(document).?);
        dispatchQueued(&timeline.container);
        markValuesDirty(svg);
    }
    requestFrameIfNeeded(document);
}

fn animationInserted(state: *AnimationState) void {
    const element = state.element;
    // The timing attributes, as they are now (the parser set them before
    // the element was inserted; script may have set them while it was out).
    readTimingAttributes(state);
    const outermost = outermostSvgElement(element) orelse return;
    const timeline = registeredTimeline(outermost) orelse return;
    const document = documentOf(element) orelse return;
    resolveTarget(state);
    connectSyncBases(state);
    if (state.timed.container == null) {
        const now = documentNow(document) orelse Time.zero;
        timeline.container.schedule(&state.timed, now) catch return;
        state.timeline_svg = Link.to(outermost);
        if (state.timed.addedToTimeContainer()) queueEvents(element, .{ .begin = true }, 0);
        connectPendingSyncBases(&timeline.container);
    }
    markValuesDirty(element);
    requestFrameIfNeeded(document);
}

fn animationRemoved(state: *AnimationState) void {
    if (state.timed.container) |container| {
        // An active element raises its end as it leaves its timeline
        // (Blink SVGSMILElement::RemovedFromTimeContainer).
        if (state.timed.active_state == .active and container.started) queueEvents(state.element, .{ .end = true }, 0);
        container.unschedule(&state.timed);
    }
    state.timeline_svg = null;
    state.timed.disconnectSyncBases();
    state.target = null;
    markValuesDirty(state.element);
}

/// Read every timing attribute of `state`'s element into its timed element.
fn readTimingAttributes(state: *AnimationState) void {
    const view = element_data.of(state.element) orelse return;
    setBeginOrEnd(state, .begin, view.findValue(null, "begin"));
    setBeginOrEnd(state, .end, view.findValue(null, "end"));
    state.timed.setDur(view.findValue(null, "dur"));
    state.timed.setRepeatDur(view.findValue(null, "repeatDur"));
    state.timed.setRepeatCount(view.findValue(null, "repeatCount"));
    state.timed.setMin(view.findValue(null, "min"));
    state.timed.setMax(view.findValue(null, "max"));
    state.timed.setRestart(view.findValue(null, "restart"));
    state.timed.setFill(view.findValue(null, "fill"));
}

fn setBeginOrEnd(state: *AnimationState, which: parse.BeginOrEnd, text: ?[]const u8) void {
    var list = state.timed.setBeginOrEnd(which, text) catch return;
    list.deinit(state.allocator);
}

/// The attribute change steps of an animation element (installed for the
/// SVG animation elements' local names: dom.attribute_change_steps).
pub fn attributeChanged(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = old_value;
    const state = stateOf(element) orelse return;
    if (namespace != null) {
        // xlink:href names the target as href does.
        if (std.mem.eql(u8, namespace.?, xlink_namespace) and std.mem.eql(u8, local_name, "href")) targetChanged(state);
        return;
    }
    if (std.mem.eql(u8, local_name, "begin") or std.mem.eql(u8, local_name, "end")) {
        setBeginOrEnd(state, if (local_name[0] == 'b') .begin else .end, value);
        if (state.timed.container != null) {
            connectSyncBases(state);
            state.timed.instanceListsChanged();
        }
    } else if (std.mem.eql(u8, local_name, "dur")) {
        state.timed.setDur(value);
    } else if (std.mem.eql(u8, local_name, "repeatDur")) {
        state.timed.setRepeatDur(value);
    } else if (std.mem.eql(u8, local_name, "repeatCount")) {
        state.timed.setRepeatCount(value);
    } else if (std.mem.eql(u8, local_name, "min")) {
        state.timed.setMin(value);
    } else if (std.mem.eql(u8, local_name, "max")) {
        state.timed.setMax(value);
    } else if (std.mem.eql(u8, local_name, "restart")) {
        state.timed.setRestart(value);
    } else if (std.mem.eql(u8, local_name, "fill")) {
        state.timed.setFill(value);
        markValuesDirty(element);
    } else if (std.mem.eql(u8, local_name, "href")) {
        targetChanged(state);
        return;
    } else if (std.mem.eql(u8, local_name, "attributeName") or std.mem.eql(u8, local_name, "to") or std.mem.eql(u8, local_name, "attributeType")) {
        markValuesDirty(element);
        return;
    } else if (handlerEventType(local_name)) |event_type| {
        handlerAttributeChanged(element, event_type, value);
        return;
    } else {
        return;
    }
    if (documentOf(element)) |document| requestFrameIfNeeded(document);
}

/// The animation event attributes (SVG 2 15.8: onbegin, onend, onrepeat)
/// and the events their handlers are for.
fn handlerEventType(local_name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, local_name, "onbegin")) return "beginEvent";
    if (std.mem.eql(u8, local_name, "onend")) return "endEvent";
    if (std.mem.eql(u8, local_name, "onrepeat")) return "repeatEvent";
    return null;
}

/// HTML 8.1.8.1's attribute change steps for an event handler content
/// attribute, for the animation event attributes: Element's own steps cover
/// the global event handlers, whose event type is the name less "on"; these
/// three name another (SVG 2 15.8; Blink SVGSMILElement::ParseAttribute).
fn handlerAttributeChanged(element: *runtime.Instance, event_type: []const u8, value: ?[]const u8) void {
    const body = value orelse {
        // The main world's handler (event_handlers.deactivateForContentAttribute).
        event_handlers.deactivateForContentAttribute(element, event_type);
        return;
    };
    // Step 5.1: a CSP-blocked replacement leaves the old handler value.
    if (csp_violations.shouldBlockInline(element, .script_attribute, body, .{})) return;
    const document = documentOf(element) orelse return;
    const url = interfaces.Document.get_URL(document) catch return;
    defer document.ctx.allocator.free(url);
    event_handlers.setRaw(element, event_type, .{ .body = body, .url = url }) catch {};
}

fn targetChanged(state: *AnimationState) void {
    if (state.timed.container == null) return;
    resolveTarget(state);
    markValuesDirty(state.element);
}

/// SVG Animations 2 2.5: the href's element (a same-document reference),
/// else the parent element; an SVG element that is connected, or none.
fn resolveTarget(state: *AnimationState) void {
    state.target = null;
    const element = state.element;
    const href = reflected_with_fallback.value(element, "href", xlink_namespace) catch null;
    const target: ?*runtime.Instance = if (href) |reference| blk: {
        const hash = std.mem.indexOfScalar(u8, reference, '#') orelse break :blk null;
        // Only a reference into this document names a target.
        if (std.mem.trim(u8, reference[0..hash], " \t\r\n").len != 0) break :blk null;
        break :blk element_references.byId(element, reference[hash + 1 ..]);
    } else interfaces.Node.get_parentElement(element) catch null;
    const resolved = target orelse return;
    if (svgName(resolved) == null or !isConnected(resolved)) return;
    state.target = Link.to(resolved);
}

/// Connect each syncbase condition to the animation element its id names
/// in the element's tree scope (Blink SVGSMILElement::Condition::
/// ConnectSyncBase).
fn connectSyncBases(state: *AnimationState) void {
    for (state.timed.sync_conditions.items, 0..) |condition, i| {
        const base_element = element_references.byId(state.element, condition.base_id);
        const base_state: ?*AnimationState = if (base_element) |b| stateOf(b) else null;
        state.timed.connectSyncBase(i, if (base_state) |b| &b.timed else null) catch continue;
    }
}

/// An animation element joined `container`: the syncbase conditions of its
/// other elements that named no element yet look again - the id may be the
/// new element's (Blink observes the ids, IdTargetObserver).
fn connectPendingSyncBases(container: *TimeContainer) void {
    for (container.elements.items) |timed_element| {
        for (timed_element.sync_conditions.items) |condition| {
            if (condition.base != null) continue;
            connectSyncBases(AnimationState.fromTimed(timed_element));
            break;
        }
    }
}

// ============================================================================
// The rendering step and the load
// ============================================================================

/// HTML "update the rendering" step 11, after Web Animations: every started
/// timeline of `document` moves to the document's animation time.
pub fn serviceAnimations(document: *runtime.Instance) void {
    const state = documentState(document, false) orelse return;
    const now = documentNow(document) orelse return;
    var any = false;
    var index: usize = 0;
    while (index < state.timelines.items.len) : (index += 1) {
        const link = state.timelines.items[index];
        if (!link.isLive()) continue;
        const timeline = timelineOf(link.instance, false) orelse continue;
        const container = &timeline.container;
        if (!container.started) continue;
        if (container.paused and !container.needs_update) continue;
        container.update(container.elapsed(now), .normal);
        dispatchQueued(container);
        any = true;
    }
    if (any) recomputeValues(document, state);
    requestFrameIfNeeded(document);
}

/// The document's load event has fired (HTML "the end" step 9 and the
/// completely-loaded time): its timelines begin (Blink
/// Document::DispatchLoadAndPageshowEvents -> SVGDocumentExtensions::
/// StartAnimations).
pub fn startAnimations(document: *runtime.Instance) void {
    const state = documentState(document, false) orelse return;
    const now = documentNow(document) orelse return;
    // Every outermost svg element connected now begins here, those with no
    // timeline yet too (svgInserted made the state for them).
    state.loaded_at = now;
    var index: usize = 0;
    while (index < state.timelines.items.len) : (index += 1) {
        const link = state.timelines.items[index];
        if (!link.isLive()) continue;
        const timeline = timelineOf(link.instance, false) orelse continue;
        if (timeline.container.started) continue;
        timeline.container.start(now);
        dispatchQueued(&timeline.container);
        state.values_dirty = true;
    }
    if (state.values_dirty) recomputeValues(document, state);
    requestFrameIfNeeded(document);
}

/// Ask for the next frame while any timeline of `document` has an update
/// pending or a time to come.
pub fn requestFrameIfNeeded(document: *runtime.Instance) void {
    const state = documentState(document, false) orelse return;
    for (state.timelines.items) |link| {
        if (!link.isLive()) continue;
        const timeline = timelineOf(link.instance, false) orelse continue;
        const container = &timeline.container;
        if (!container.started) continue;
        if (container.needs_update or (!container.paused and container.nextTime().isFinite())) {
            update_the_rendering.requestFrame(document);
            return;
        }
    }
}

// ============================================================================
// TimeEvents
// ============================================================================

fn dispatchQueued(container: *TimeContainer) void {
    const dispatches = container.takeDispatches() catch return;
    defer container.allocator.free(dispatches);
    for (dispatches) |dispatch| {
        const state = AnimationState.fromTimed(dispatch.element);
        queueEvents(state.element, dispatch.events, dispatch.repeat);
    }
}

const EventTaskPayload = struct {
    pub const held_count = 1;
    events: timed.Events,
    repeat: u32,

    pub fn steps(self: *EventTaskPayload, held: []const node_holds.TaskHold) void {
        const element = held[0].get() orelse return;
        // End, then begin (an element that restarts "will raise an end
        // event and another begin event"), then repeat.
        if (self.events.end) fireTimeEvent(element, "endEvent", 0);
        if (self.events.begin) fireTimeEvent(element, "beginEvent", 0);
        if (self.events.repeat) {
            fireTimeEvent(element, "repeatEvent", std.math.cast(i32, self.repeat) orelse std.math.maxInt(i32));
            // Chrome and Safari also fire an Event named "repeatn" after
            // each repeatEvent (Blink SVGSMILElement::DispatchEvents, WebKit
            // SVGSMILElement); Firefox does not. No specification names it;
            // golden rule 2's majority decides.
            fireRepeatN(element);
        }
    }
};

const EventTask = node_holds.ElementTask(EventTaskPayload);

fn queueEvents(element: *runtime.Instance, events: timed.Events, repeat: u32) void {
    if (events.isEmpty()) return;
    if (!EventTask.queue(.{element}, .{ .events = events, .repeat = repeat })) {
        log.debug("SMIL events not queued", .{});
    }
}

/// Fire a TimeEvent `event_type` at `element` (SVG Animations 2 5.1: it
/// neither bubbles nor can be canceled; its view is the element's Window).
fn fireTimeEvent(element: *runtime.Instance, event_type: []const u8, detail: i32) void {
    const realm = element.ctx;
    const document = documentOf(element);
    const view: ?*runtime.Instance = if (document) |d| (interfaces.Document.get_defaultView(d) catch null) else null;
    const event = interfaces.TimeEvent.initWith(realm.allocator, realm, .{ .time_view = view, .time_detail = detail }) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    event_construction.innerEventCreationSteps(event, runtime.DOMString.initInterned(event_type), .{}) catch {
        event.releaseIfUnwrapped(generation);
        return;
    };
    _ = fire_event.dispatchTrusted(element, event) catch {};
    event.releaseIfUnwrapped(generation);
}

fn fireRepeatN(element: *runtime.Instance) void {
    const event = interfaces.Event.call_constructor(element.ctx, runtime.DOMString.initInterned("repeatn"), webidl.Opt(dictionaries.EventInit).passed(.{})) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = fire_event.dispatchTrusted(element, event) catch {};
    event.releaseIfUnwrapped(generation);
}

// ============================================================================
// The IDL members' steps (SVG Animations 2 5.2, 5.8)
// ============================================================================

/// The current time of `state`'s timeline, in seconds (0 off any).
pub fn currentTime(state: *AnimationState) f32 {
    const container = state.timed.container orelse return 0;
    const document = documentOf(state.element) orelse return 0;
    const now = documentNow(document) orelse return @floatCast(container.latest_update_time.seconds());
    return @floatCast(container.elapsed(now).seconds());
}

/// beginElementAt(offset) / endElementAt(offset): an instance time at the
/// current time plus `offset`.
pub fn addScriptInstanceTime(state: *AnimationState, which: parse.BeginOrEnd, offset: f32) void {
    const document = documentOf(state.element);
    const at = state.timed.elapsed(nowOf(state.element)).add(Time.fromSeconds(offset));
    state.timed.addInstanceTimeAndUpdate(which, at, .script) catch return;
    if (document) |d| {
        refreshValues(d);
        requestFrameIfNeeded(d);
    }
}

/// The target element, while it is still the one resolved and connected.
pub fn targetElement(state: *AnimationState) ?*runtime.Instance {
    const link = state.target orelse return null;
    if (!link.isLive() or !isConnected(link.instance)) return null;
    return link.instance;
}

/// The timeline an svg element's methods act on: its own, if it is an
/// outermost svg element (5.8 "If the current svg element is not the
/// outermost svg element, then return").
fn ownTimeline(svg: *runtime.Instance) ?*Timeline {
    if (!isOutermost(svg)) return null;
    if (isConnected(svg)) return registeredTimeline(svg);
    return ensureTimeline(svg);
}

pub fn pauseAnimations(svg: *runtime.Instance) void {
    const timeline = ownTimeline(svg) orelse return;
    timeline.container.pause(nowOf(svg));
}

pub fn unpauseAnimations(svg: *runtime.Instance) void {
    const timeline = ownTimeline(svg) orelse return;
    timeline.container.unpause(nowOf(svg));
    if (documentOf(svg)) |d| requestFrameIfNeeded(d);
}

/// animationsPaused(): whether the timeline of the fragment `svg` is in has
/// been paused.
pub fn animationsPaused(svg: *runtime.Instance) bool {
    const outermost = outermostSvgElement(svg) orelse svg;
    const timeline = timelineOf(outermost, false) orelse return false;
    return timeline.container.paused;
}

/// getCurrentTime(): 0 before the timeline began, else its time in seconds.
pub fn svgCurrentTime(svg: *runtime.Instance) f32 {
    const outermost = outermostSvgElement(svg) orelse svg;
    if (timelineOf(outermost, false)) |timeline| {
        return @floatCast(timeline.container.elapsed(nowOf(svg)).seconds());
    }
    // No timeline made yet: the time since the one it has began.
    if (!isConnected(outermost)) return 0;
    const document = documentOf(outermost) orelse return 0;
    if (!canStart(document)) return 0;
    const state = documentState(document, false) orelse return 0;
    const began = beganAt(state, outermost) orelse return 0;
    const now = documentNow(document).?;
    return @floatCast(Time.max(now.sub(began), .zero).seconds());
}

/// setCurrentTime(seconds): seek a timeline that began; record the time for
/// one that has not.
pub fn setCurrentTime(svg: *runtime.Instance, seconds: f32) void {
    const timeline = ownTimeline(svg) orelse return;
    const document = documentOf(svg);
    timeline.container.setElapsed(nowOf(svg), Time.fromSeconds(@max(seconds, 0)));
    dispatchQueued(&timeline.container);
    if (document) |d| {
        refreshValues(d);
        requestFrameIfNeeded(d);
    }
}

// ============================================================================
// Animated values (SMIL Animation 3.5, the animation sandwich)
// ============================================================================

/// The animated value of `target`'s attribute (`namespace`, `local_name`):
/// the highest-priority <set> contributing to it, or null when no
/// animation does. BORROWED until the document's animations next change.
pub fn animatedAttributeValue(target: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) ?[]const u8 {
    const document = documentOf(target) orelse return null;
    const state = documentState(document, false) orelse return null;
    if (state.values_dirty) recomputeValues(document, state);
    for (state.values.items) |value| {
        if (value.target.instance != target or !value.target.isLive()) continue;
        if (!optionalEql(value.namespace, namespace) or !std.mem.eql(u8, value.local_name, local_name)) continue;
        return value.value;
    }
    return null;
}

fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

/// The attribute an animation element's attributeName names (SVG Animations
/// 2 2.6): a prefix resolves in the animation element's scope; a name that
/// is no QName, or whose prefix resolves to nothing, names none.
const AttributeName = struct { namespace: ?[]u8, local_name: []const u8 };

fn resolveAttributeName(allocator: Allocator, element: *runtime.Instance, attribute_name: []const u8) ?AttributeName {
    if (attribute_name.len == 0) return null;
    const colon = std.mem.indexOfScalar(u8, attribute_name, ':') orelse return .{ .namespace = null, .local_name = attribute_name };
    const prefix = attribute_name[0..colon];
    const local = attribute_name[colon + 1 ..];
    if (prefix.len == 0 or local.len == 0 or std.mem.indexOfScalar(u8, local, ':') != null) return null;
    var namespace = (interfaces.Node.call_lookupNamespaceURI(element, runtime.DOMString.initInterned(prefix)) catch return null) orelse return null;
    defer namespace.deinit(element.ctx.allocator);
    if (namespace.asSlice().len == 0) return null;
    const owned = allocator.dupe(u8, namespace.asSlice()) catch return null;
    return .{ .namespace = owned, .local_name = local };
}

/// One CSS property an animation sets, before the blocks are built:
/// borrowed from the animation element's attributes for the computation.
const CssCandidate = struct {
    target: *runtime.Instance,
    property: []const u8,
    value: []const u8,
    source: *TimedElement,
    time: Time,
};

fn recomputeValues(document: *runtime.Instance, state: *DocumentState) void {
    const allocator = document.ctx.allocator;
    for (state.values.items) |*value| value.deinit(allocator);
    state.values.clearRetainingCapacity();
    for (state.styles.items) |*style| style.block.deinit();
    state.styles.clearRetainingCapacity();
    state.values_dirty = false;
    // The animation each entry of `state.values` took its value from.
    var sources: std.ArrayListUnmanaged(*TimedElement) = .empty;
    defer sources.deinit(allocator);
    var css_candidates: std.ArrayListUnmanaged(CssCandidate) = .empty;
    defer css_candidates.deinit(allocator);
    for (state.timelines.items) |link| {
        if (!link.isLive()) continue;
        const timeline = timelineOf(link.instance, false) orelse continue;
        const container = &timeline.container;
        if (container.document_order_dirty) numberInTreeOrder(link.instance, container);
        const time = container.latest_update_time;
        for (container.elements.items) |timed_element| {
            if (!timed_element.isContributing(time)) continue;
            const animation = AnimationState.fromTimed(timed_element);
            const target = targetElement(animation) orelse continue;
            const view = element_data.of(animation.element) orelse continue;
            // <set>: the value is its 'to' attribute (SVG Animations 2 2.14).
            if (kindOf(view.name.local_name) != .set) continue;
            const to = view.findValue(null, "to") orelse continue;
            const attribute_name = view.findValue(null, "attributeName") orelse continue;
            // SVG Animations 2 2.6: "the implementation must first search
            // through the list of CSS properties for a matching property
            // name" - the properties an SVG element's presentation
            // attributes name (Blink SVGElement::CssPropertyIdForSVGAttributeName;
            // Gecko SMILCSSProperty::IsPropertyAnimatable).
            const target_name = svgName(target) orelse continue;
            if (std.mem.indexOfScalar(u8, attribute_name, ':') == null and
                css.svg_presentation.lookup(svg_namespace, target_name, attribute_name) != null)
            {
                addCssCandidate(allocator, &css_candidates, .{ .target = target, .property = attribute_name, .value = to, .source = timed_element, .time = time });
                continue;
            }
            const name = resolveAttributeName(allocator, animation.element, attribute_name) orelse continue;
            var namespace = name.namespace;
            defer if (namespace) |ns| allocator.free(ns);
            const existing: ?usize = for (state.values.items, 0..) |entry, i| {
                if (entry.target.instance == target and optionalEql(entry.namespace, namespace) and std.mem.eql(u8, entry.local_name, name.local_name)) break i;
            } else null;
            if (existing) |i| {
                // The sandwich: the higher-priority animation's value wins.
                if (!timed_element.isHigherPriorityThan(sources.items[i], time)) continue;
                const copy = allocator.dupe(u8, to) catch continue;
                allocator.free(state.values.items[i].value);
                state.values.items[i].value = copy;
                sources.items[i] = timed_element;
                continue;
            }
            const local_copy = allocator.dupe(u8, name.local_name) catch continue;
            const value_copy = allocator.dupe(u8, to) catch {
                allocator.free(local_copy);
                continue;
            };
            sources.append(allocator, timed_element) catch {
                allocator.free(local_copy);
                allocator.free(value_copy);
                continue;
            };
            state.values.append(allocator, .{ .target = Link.to(target), .namespace = namespace, .local_name = local_copy, .value = value_copy }) catch {
                _ = sources.pop();
                allocator.free(local_copy);
                allocator.free(value_copy);
                continue;
            };
            namespace = null;
        }
    }
    buildStyles(document, state, css_candidates.items);
}

/// Keep the highest-priority candidate per target property.
fn addCssCandidate(allocator: Allocator, candidates: *std.ArrayListUnmanaged(CssCandidate), candidate: CssCandidate) void {
    for (candidates.items) |*existing| {
        if (existing.target != candidate.target or !std.mem.eql(u8, existing.property, candidate.property)) continue;
        if (candidate.source.isHigherPriorityThan(existing.source, candidate.time)) existing.* = candidate;
        return;
    }
    candidates.append(allocator, candidate) catch {};
}

/// Each target's override style block, from its winning candidates; a
/// changed set re-keys the document's cached styles.
fn buildStyles(document: *runtime.Instance, state: *DocumentState, candidates: []const CssCandidate) void {
    const allocator = document.ctx.allocator;
    var hasher = std.hash.Wyhash.init(0x534d_494c);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer assignments.deinit(allocator);
    var hashed = false;
    for (candidates) |candidate| {
        const target_name = svgName(candidate.target) orelse continue;
        const property = css.svg_presentation.lookup(svg_namespace, target_name, candidate.property) orelse continue;
        hashed = true;
        const address: usize = @intFromPtr(candidate.target);
        hasher.update(std.mem.asBytes(&address));
        hasher.update(candidate.property);
        hasher.update(&.{0});
        hasher.update(candidate.value);
        hasher.update(&.{0});
        var found: ?usize = null;
        for (state.styles.items, 0..) |style, i| {
            if (style.target.instance == candidate.target) {
                found = i;
                break;
            }
        }
        if (found == null) {
            state.styles.append(allocator, .{ .target = Link.to(candidate.target), .block = css.declarations.DeclarationBlock.init(allocator) }) catch continue;
            found = state.styles.items.len - 1;
        }
        const index = found.?;
        // The value parses as the presentation attribute's would (SVG 2
        // 6.6: a property value, attribute syntax).
        var context = resource_loading.inlineParseContext(candidate.target, allocator, false, candidate.value) catch continue;
        defer context.deinit();
        assignments.clearRetainingCapacity();
        const parsed = css.svg_presentation.parse(context.options(), svg_namespace, target_name, candidate.property, candidate.value, &assignments) catch continue;
        defer for (assignments.items) |a| a.value.release();
        if (!parsed) continue;
        _ = state.styles.items[index].block.setValidatedProperty(property, assignments.items) catch {};
    }
    // No override style is 0, the signature a document starts with: a
    // timeline that sets no CSS property never re-keys the cached styles.
    const signature: u64 = if (hashed) hasher.final() else 0;
    if (signature == state.style_signature) return;
    state.style_signature = signature;
    if (style_hooks.engineOf(document)) |engine| engine.animatedOverrideStyleChanged();
}

/// The override style of `element` (an SVG element of `document`) from
/// its SVG animations, or null. BORROWED until the animations next change.
pub fn animatedStyleBlock(document: *runtime.Instance, element: *runtime.Instance) ?*const css.declarations.DeclarationBlock {
    const state = documentState(document, false) orelse return null;
    if (state.values_dirty) recomputeValues(document, state);
    for (state.styles.items) |*style| {
        if (style.target.instance != element or !style.target.isLive()) continue;
        if (style.block.length() == 0) return null;
        return &style.block;
    }
    return null;
}

/// Compute the animated values now, after a change that moved no tree
/// version (a timeline's update, a seek, a script instance time): a changed
/// override style must re-key the cached styles before the next read.
fn refreshValues(document: *runtime.Instance) void {
    const state = documentState(document, false) orelse return;
    recomputeValues(document, state);
}

/// Number `container`'s elements in tree order (the sandwich's tie-break).
fn numberInTreeOrder(svg: *runtime.Instance, container: *TimeContainer) void {
    container.document_order_dirty = false;
    const root = instance_bridge.getNodeBase(svg) orelse return;
    var index: u32 = 0;
    var at: ?*NodeBase = root.firstChild();
    while (at) |node| : (at = nextInTree(node, root)) {
        if (node.node_type != 1) continue;
        const element = instanceOf(node) orelse continue;
        const state = stateOf(element) orelse continue;
        state.timed.document_order_index = index;
        index += 1;
    }
}

fn nextInTree(node: *NodeBase, boundary: *NodeBase) ?*NodeBase {
    if (node.firstChild()) |child| return child;
    var current = node;
    while (current != boundary) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}
