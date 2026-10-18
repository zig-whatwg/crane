//! An event's dispatch state: what DOM's dispatch algorithm reads and writes
//! on an Event, most of which no IDL member sets.
//!
//! `EventState` is Event's internal state - its flags, path, target, related
//! target, current target, phase, isTrusted and touch target list (DOM 2.2)
//! - defined here so that the dispatcher (EventTarget) works on it directly:
//! Event's impl keeps it (`InternalState = EventState`), creates it with the
//! event and frees it with the event, and installs `of()` once, at process
//! start (its installHooks). The dispatcher takes `of(event)` once per
//! dispatch and works on the fields; Event's IDL getters read the same
//! fields. WebKit's split: dom/EventDispatcher.cpp's `dispatchEventInDOM`
//! calls Event's non-IDL members (`setEventPhase`, `setTarget`,
//! `setEventPath`) from outside Event.
//!
//! Also here: "invoke" step 9, which renames a trusted animation or
//! transition event to its legacy WebKit type while the legacy listeners run,
//! and back again.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-event,
//! https://dom.spec.whatwg.org/#concept-event-dispatch
//!
//! lint-impls: hook for Event

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const infra = @import("infra");
const KeptInstance = @import("custom_elements.zig").KeptInstance;

/// One struct of an event's path (DOM 2.9 "append to an event path"), built
/// by dom.event_path.
pub const PathItem = struct {
    invocation_target: *runtime.Instance,
    invocation_target_in_shadow_tree: bool,
    shadow_adjusted_target: ?*runtime.Instance,
    related_target: ?*runtime.Instance,
    touch_target_list: infra.List(*runtime.Instance),
    root_of_closed_tree: bool,
    slot_in_closed_tree: bool,
    /// Not a field of the standard's struct: what "invoke" steps 1-3 set the
    /// event's target to for this item - the shadow-adjusted target of the
    /// last item at or before it whose shadow-adjusted target is non-null.
    /// That item is the last one dispatch appended through step 6.3 or
    /// 6.9.8, so this is dispatch's `target` when the item was appended;
    /// recorded then, invoke finds it without walking back along the path
    /// (Blink keeps it per tree scope: TreeScopeEventContext::Target).
    target: *runtime.Instance,
};

/// Event's eventPhase values (DOM 2.2).
pub const Phase = struct {
    pub const none: u16 = 0;
    pub const capturing: u16 = 1;
    pub const at_target: u16 = 2;
    pub const bubbling: u16 = 3;
};

/// The member an event keeps its target in (engine.traceChild): the target
/// dispatch left it with, which script reads after dispatch (`event.target`,
/// `srcElement`). Blink: Event::Trace visits target_ (core/dom/events/
/// event.cc); it was a bare pointer here, and a held event read a freed node
/// once the target's tree was collected (lane ownerdoc,
/// crane/od-event-keeps-its-targets.html).
pub const target_slot: engine.TracedSlot = .{ .name = "target" };

/// The member an event keeps its relatedTarget in (engine.traceChild). The
/// relatedTarget is DOM's (2.2), one per event, which the relatedTarget
/// attributes of MouseEvent, FocusEvent and their subclasses return
/// (UI Events): dispatch retargets it item by item and can leave it on a
/// different object than the one it was initialized to - a shadow host
/// instead of a node in its shadow tree - so the event keeps the one it
/// holds. Blink: Event::Trace visits the related target (MouseEvent::Trace
/// related_target_, FocusEvent's); WebKit: RefPtr<EventTarget>.
pub const related_target_slot: engine.TracedSlot = .{ .name = "relatedTarget" };

/// An Event's internal state (DOM 2.2): every flag, the path, the targets,
/// the phase and isTrusted. Owned by the event (Event's impl creates and
/// frees it); the dispatcher writes it through `of()`.
pub const EventState = struct {
    allocator: std.mem.Allocator,

    // DOM 2.2 - the event's flags, initially unset.
    stop_propagation_flag: bool = false,
    stop_immediate_propagation_flag: bool = false,
    canceled_flag: bool = false,
    in_passive_listener_flag: bool = false,
    initialized_flag: bool = false,
    dispatch_flag: bool = false,

    /// DOM 2.2 "path", initially the empty list.
    path: infra.List(PathItem),

    /// The target attribute's value, initially null (srcElement returns it
    /// too). Set with `setTarget`, which keeps it for script.
    target: ?*runtime.Instance = null,
    /// DOM 2.2 "relatedTarget", initially null. Set with `setRelatedTarget`,
    /// which keeps it; dispatch writes it per path item ("invoke" step 4)
    /// and keeps the value it ends with (`endDispatch`).
    related_target: ?*runtime.Instance = null,
    /// The currentTarget attribute's value, initially null.
    current_target: ?*runtime.Instance = null,
    /// The eventPhase attribute's value, initially NONE.
    phase: u16 = Phase.none,
    /// The isTrusted attribute's value, initially false.
    is_trusted: bool = false,

    /// DOM 2.2 "touch target list", initially the empty list.
    touch_target_list: infra.List(*runtime.Instance),

    /// The target `target_slot`'s edge holds, or null for none (`keepTarget`).
    traced_target: ?*runtime.Instance = null,

    /// The related target `related_target_slot`'s edge holds, or null for
    /// none (`keepRelatedTarget`), with its slab generation and realm: the
    /// teardown net - a realm's teardown frees its Instances whatever points
    /// at them, and the getter then reads null, never a freed object.
    kept_related_target: ?KeptInstance = null,

    pub fn init(allocator: std.mem.Allocator) EventState {
        return .{
            .allocator = allocator,
            .path = infra.List(PathItem).init(allocator),
            .touch_target_list = infra.List(*runtime.Instance).init(allocator),
        };
    }

    /// Release what the state owns: each path struct's touch target list,
    /// the path and the touch target list. `event`'s edge to its target is
    /// the event's teardown to end (`forgetTarget`).
    pub fn deinit(self: *EventState) void {
        for (self.path.toSliceMut()) |*item| item.touch_target_list.deinit();
        self.path.deinit();
        self.touch_target_list.deinit();
    }

    /// Set `event`'s target (and so its srcElement) to `target`, and keep it
    /// while script can reach the event (`keepTarget`).
    pub fn setTarget(self: *EventState, event: *runtime.Instance, target: ?*runtime.Instance) void {
        self.target = target;
        self.keepTarget(event);
    }

    /// Keep the event's current target (`target_slot`) while script can
    /// reach the event, and let a target it no longer has go.
    ///
    /// Only an event script can reach keeps it: one with a wrapper. An event
    /// script has not seen - the engine fires most of them, and nobody hears
    /// most of those - keeps nothing: tracing would wrap every target the
    /// engine fires at (docs/lessons/architecture-tracing-a-holders-nodes-
    /// makes-a-wrapper-per-node.md) and hold it strongly until the event is
    /// freed. The dispatcher holds the target while it runs; a listener that
    /// sees the event wraps it, and the end of dispatch (`endDispatch`) draws
    /// the edge then.
    pub fn keepTarget(self: *EventState, event: *runtime.Instance) void {
        const target = self.target;
        if (target == self.traced_target) return;
        if (target) |t| {
            if (!engine.hasWrapper(event)) return;
            self.traced_target = t;
            engine.traceChild(event, t, target_slot);
        } else {
            self.traced_target = null;
            engine.forgetTracedChild(event, target_slot);
        }
    }

    /// End `event`'s edge to its target, at the event's teardown. An event
    /// its wrapper's collection frees has no edge left to end.
    pub fn forgetTarget(self: *EventState, event: *runtime.Instance) void {
        if (self.traced_target != null) engine.forgetTracedChild(event, target_slot);
        self.traced_target = null;
    }

    /// Set `event`'s relatedTarget to `related` and keep it: what the
    /// constructors and the legacy init*Event() methods of MouseEvent,
    /// FocusEvent and their subclasses initialize.
    pub fn setRelatedTarget(self: *EventState, event: *runtime.Instance, related: ?*runtime.Instance) void {
        self.related_target = related;
        self.keepRelatedTarget(event);
    }

    /// The relatedTarget attribute's value: `related_target`, or null once
    /// the realm of the one the event keeps has been torn down (the net).
    /// Mid-dispatch it is the current path item's, which the path holds.
    pub fn relatedTarget(self: *const EventState) ?*runtime.Instance {
        const related = self.related_target orelse return null;
        if (self.kept_related_target) |kept| {
            if (kept.instance == related) return kept.get();
        }
        return related;
    }

    /// Keep `related_target`, and let go of one the event no longer holds.
    ///
    /// Unlike the target's edge, this one is drawn whether or not script has
    /// wrapped the event (an owner script has not seen holds it until its
    /// wrapper is made): the constructors set it before the binding wraps
    /// the event, and the events that carry one - focus, mouse and drag
    /// events - are few, so nothing wraps a node per fired event.
    pub fn keepRelatedTarget(self: *EventState, event: *runtime.Instance) void {
        const related = self.related_target;
        const kept: ?*runtime.Instance = if (self.kept_related_target) |k| k.instance else null;
        if (related == kept) return;
        if (related) |r| {
            self.kept_related_target = KeptInstance.of(r);
            engine.traceChild(event, r, related_target_slot);
        } else {
            self.kept_related_target = null;
            engine.forgetTracedChild(event, related_target_slot);
        }
    }

    /// End `event`'s edge to its relatedTarget, at the event's teardown.
    pub fn forgetRelatedTarget(self: *EventState, event: *runtime.Instance) void {
        if (self.kept_related_target != null) engine.forgetTracedChild(event, related_target_slot);
        self.kept_related_target = null;
    }

    /// DOM 2.2 "set the canceled flag" given the event, whose cancelable
    /// attribute value is `cancelable`: set the canceled flag if cancelable
    /// is true and the in passive listener flag is unset, and do nothing
    /// otherwise.
    pub fn setCanceledFlag(self: *EventState, cancelable: bool) void {
        if (cancelable and !self.in_passive_listener_flag) self.canceled_flag = true;
    }

    /// Dispatch step 9: "Set event's path to the empty list." Each struct
    /// owns a touch target list, so clearing without releasing them leaks one
    /// list per path entry per dispatch.
    pub fn clearPath(self: *EventState) void {
        for (self.path.toSliceMut()) |*item| item.touch_target_list.deinit();
        self.path.clear();
    }

    /// Dispatch steps 7-11: leave `event` in a state in which it can be
    /// dispatched again. Step 7: eventPhase NONE. Step 8: currentTarget
    /// null. Step 9: the path empty. Step 10: the dispatch, stop propagation
    /// and stop immediate propagation flags unset - leaving them set made the
    /// next dispatch of the same event object a no-op, which is how a
    /// `stopPropagation()` in one dispatch silently swallowed every later
    /// one. Step 11: with `clear_targets`, the target, relatedTarget and
    /// touch target list cleared.
    ///
    /// Dispatch is over: invoke wrote the target and relatedTarget raw, item
    /// by item, while the path held them, and a listener may have wrapped
    /// the event meanwhile - so the values the event ends with are kept
    /// now, after step 11, never an edge to a value step 11 then drops.
    pub fn finishDispatch(self: *EventState, event: *runtime.Instance, clear_targets: bool) void {
        self.phase = Phase.none;
        self.current_target = null;
        self.clearPath();
        self.dispatch_flag = false;
        self.stop_propagation_flag = false;
        self.stop_immediate_propagation_flag = false;
        if (clear_targets) {
            self.target = null;
            self.related_target = null;
            self.touch_target_list.clear();
        }
        self.keepTarget(event);
        self.keepRelatedTarget(event);
    }

    /// Dispatch steps 7-10, for a dispatch whose clearTargets is false.
    pub fn endDispatch(self: *EventState, event: *runtime.Instance) void {
        self.finishDispatch(event, false);
    }
};

/// What the Event impl supplies.
pub const Implementation = struct {
    /// `event`'s state, or null when `event` is not an Event or has none
    /// (one never constructed through Event's steps: its initialized flag is
    /// unset). BORROWED: it lives as long as the event.
    state: *const fn (event: *runtime.Instance) ?*EventState,
    /// Set `event`'s type attribute value to `event_type`, which the event
    /// then holds, and hand back the value it held (its owner is the caller).
    /// No copy, no free: the swap is undone with the value it returned.
    swap_type: *const fn (event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Event's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `event`'s dispatch state, or null when it has none (see
/// `Implementation.state`). Taken once per dispatch: the pointer is good for
/// as long as the event is.
pub fn of(event: *runtime.Instance) ?*EventState {
    const impl = implementation orelse return null;
    return impl.state(event);
}

/// `event`'s type attribute value becomes `event_type`; the previous value is
/// returned, to be swapped back. Null when `event` is not an Event.
pub fn swapType(event: *runtime.Instance, event_type: runtime.DOMString) ?runtime.DOMString {
    const impl = implementation orelse return null;
    return impl.swap_type(event, event_type);
}

/// "Invoke" step 9.2: the legacy type an event type is renamed to for
/// listeners registered only under that name - the table's second column for
/// the first - or null.
pub fn legacyEventType(event_type: []const u8) ?[]const u8 {
    const table = [_][2][]const u8{
        .{ "animationend", "webkitAnimationEnd" },
        .{ "animationiteration", "webkitAnimationIteration" },
        .{ "animationstart", "webkitAnimationStart" },
        .{ "transitionend", "webkitTransitionEnd" },
    };
    for (table) |row| {
        if (std.mem.eql(u8, event_type, row[0])) return row[1];
    }
    return null;
}

test "invoke step 9.2 maps the four unprefixed types, exactly, and nothing else" {
    try std.testing.expectEqualStrings("webkitAnimationEnd", legacyEventType("animationend").?);
    try std.testing.expectEqualStrings("webkitAnimationIteration", legacyEventType("animationiteration").?);
    try std.testing.expectEqualStrings("webkitAnimationStart", legacyEventType("animationstart").?);
    try std.testing.expectEqualStrings("webkitTransitionEnd", legacyEventType("transitionend").?);
    try std.testing.expect(legacyEventType("AnimationEnd") == null);
    try std.testing.expect(legacyEventType("webkitAnimationEnd") == null);
    try std.testing.expect(legacyEventType("transitionrun") == null);
}

test "an event's state starts with every flag unset, no targets and phase NONE" {
    var state = EventState.init(std.testing.allocator);
    defer state.deinit();
    try std.testing.expect(!state.initialized_flag and !state.dispatch_flag and !state.canceled_flag);
    try std.testing.expect(state.target == null and state.current_target == null and state.related_target == null);
    try std.testing.expectEqual(Phase.none, state.phase);
    try std.testing.expect(!state.is_trusted);
    try std.testing.expectEqual(@as(usize, 0), state.path.len);
}

test "set the canceled flag honours cancelable and the in passive listener flag" {
    var state = EventState.init(std.testing.allocator);
    defer state.deinit();
    state.setCanceledFlag(false);
    try std.testing.expect(!state.canceled_flag);
    state.in_passive_listener_flag = true;
    state.setCanceledFlag(true);
    try std.testing.expect(!state.canceled_flag);
    state.in_passive_listener_flag = false;
    state.setCanceledFlag(true);
    try std.testing.expect(state.canceled_flag);
}

test "without an installed implementation an event has no state" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with nothing installed nothing reads it.
    var event: runtime.Instance = undefined;
    try std.testing.expect(of(&event) == null);
}
