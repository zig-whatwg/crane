//! CSS animation and transition events on the timing model: the events a
//! CSSAnimation (CSS Animations 2, 5.1) and a CSSTransition (CSS Transitions
//! 2, 5.1) queue at their owning element as their phase changes from one
//! animation frame to the next.
//!
//! The style engine makes them from computed animation-* and transition-*
//! values at style change events (css_animations.zig, css_transitions.zig):
//! `attach` gives a CSSAnimation or CSSTransition its owning element and
//! name; `update` runs at each "update animations and send events" for it
//! (and where a pending task completes), and `canceled` when it is
//! canceled.
//!
//! Spec: https://drafts.csswg.org/css-animations-2/#event-dispatch
//! Spec: https://drafts.csswg.org/css-transitions-2/#event-dispatch
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const model = @import("model.zig");
const registry = @import("registry.zig");
const timing_mod = @import("timing.zig");

const Allocator = std.mem.Allocator;

pub const Kind = enum { animation, transition };

/// The phase the events compare, frame to frame: the effect's phase, plus a
/// transition's 'pending'.
const Phase = enum { idle, pending, before, active, after };

pub const State = struct {
    kind: Kind,
    /// The owning element (CSS Animations 2 2.1, CSS Transitions 2): the
    /// element whose style generated the animation. BORROWED: the style
    /// engine owns the association, and ends it by `detach`.
    owning_element: ?model.Link = null,
    /// The owning pseudo-element's selector ("::before"), "" for none.
    pseudo: []u8 = &.{},
    /// animationName / transitionProperty. OWNED.
    name: []u8 = &.{},
    previous_phase: Phase = .idle,
    previous_iteration: ?f64 = null,
    /// The active time, with a fill of both, when the animation was canceled
    /// - the animationcancel / transitioncancel elapsed time.
    canceled_active_time: ?f64 = null,
    /// A CSS transition's own values (css_transitions.Transition): its
    /// property, start, end and reversing values, transition generation and
    /// running-set membership. OWNED; null for a CSS animation.
    transition: ?*@import("css_transitions.zig").Transition = null,
    /// A CSS animation's own state (css_animations.CssAnimation): its
    /// pseudo-element, animation-name position, keyframes' origin, last
    /// play state, script overrides and list membership. OWNED; null for a
    /// CSS transition.
    css_animation: ?*@import("css_animations.zig").CssAnimation = null,
};

pub fn destroy(allocator: Allocator, state: *State) void {
    if (state.transition) |transition| transition.destroy(allocator);
    if (state.css_animation) |css_animation| css_animation.destroy(allocator);
    if (state.name.len != 0) allocator.free(state.name);
    if (state.pseudo.len != 0) allocator.free(state.pseudo);
    allocator.destroy(state);
}

/// Make `animation` - a CSSAnimation or CSSTransition - one of `kind`,
/// owned by `element` (and `pseudo`), named `name`.
pub fn attach(animation: *model.Animation, kind: Kind, element: ?*runtime.Instance, pseudo: []const u8, name: []const u8) !void {
    const allocator = animation.allocator;
    const state = try allocator.create(State);
    errdefer allocator.destroy(state);
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const owned_pseudo = try allocator.dupe(u8, pseudo);
    state.* = .{
        .kind = kind,
        .owning_element = if (element) |e| model.Link.to(e) else null,
        .pseudo = owned_pseudo,
        .name = owned_name,
    };
    if (animation.css) |old| {
        // A second attach keeps the transition's or animation's own values.
        state.transition = old.transition;
        old.transition = null;
        state.css_animation = old.css_animation;
        old.css_animation = null;
        destroy(allocator, old);
    }
    animation.css = state;
    animation.class = if (kind == .animation) .css_animation else .css_transition;
}

/// The style engine ends the association (CSS Animations 2 2.1).
pub fn detach(animation: *model.Animation) void {
    const state = animation.css orelse return;
    state.owning_element = null;
}

/// An event's composite-order key, captured when it is queued (Web
/// Animations 1 4.4 step 6 sorts equal scheduled event times by composite
/// order): the owning element, the pseudo-element's rank and the position
/// among that element's animations - a CSS animation's animation-name
/// index (CSS Animations 2 2.2), a CSS transition's generation (CSS
/// Transitions 2 4.1). For a cancel these are the ones "in use at the
/// moment when the CSS Animation was cancelled", and "positions of
/// cancelled animations sort before positions of animations that have not
/// been cancelled".
pub const OrderKey = struct {
    owner: ?model.Link = null,
    pseudo_rank: u8 = 0,
    position: u64 = 0,
    canceled: bool = false,

    /// Null when the keys do not decide (no owner, or the same owner,
    /// pseudo-element and position): the caller falls back to the global
    /// list position, then queue order. Pseudo-elements other than
    /// ::marker, ::before and ::after share a rank (their code-point order
    /// is not kept, stated).
    pub fn lessThan(a: OrderKey, b: OrderKey) ?bool {
        const oa = (a.owner orelse return null).get() orelse return null;
        const ob = (b.owner orelse return null).get() orelse return null;
        if (oa != ob) return @import("css_animations.zig").treeOrderLessThan(oa, ob);
        if (a.pseudo_rank != b.pseudo_rank) return a.pseudo_rank < b.pseudo_rank;
        if (a.canceled != b.canceled) return a.canceled;
        if (a.position != b.position) return a.position < b.position;
        return null;
    }
};

/// `animation`'s OrderKey now.
pub fn orderKey(animation: *const model.Animation) OrderKey {
    const state = animation.css orelse return .{};
    const owner = state.owning_element orelse return .{};
    if (owner.get() == null) return .{};
    const css_animations = @import("css_animations.zig");
    var key: OrderKey = .{ .owner = owner, .canceled = animation.playState() == .idle };
    if (state.css_animation) |own| {
        key.pseudo_rank = css_animations.pseudoRank(own.pseudo);
        key.position = own.index;
    } else if (state.transition) |own| {
        key.pseudo_rank = css_animations.pseudoRank(own.pseudo);
        key.position = own.generation;
    }
    return key;
}

pub fn hasOwningElement(animation: *const model.Animation) bool {
    const state = animation.css orelse return false;
    const link = state.owning_element orelse return false;
    return link.get() != null;
}

/// The animationName or transitionProperty, "" for an animation that is
/// none of them.
pub fn nameOf(animation: *const model.Animation) []const u8 {
    const state = animation.css orelse return "";
    return state.name;
}

/// Cancel an animation (Web Animations 4.5.14) records the elapsed time of
/// its cancel event: its active time now, with a fill of both.
pub fn canceled(animation: *model.Animation) void {
    const state = animation.css orelse return;
    const effect = animation.effectModel() orelse {
        state.canceled_active_time = 0;
        return;
    };
    var both = effect.timing;
    both.fill = .both;
    const local = animation.currentTime();
    const backwards = animation.playback_rate < 0;
    const the_phase = timing_mod.phase(&both, local, backwards, false);
    state.canceled_active_time = timing_mod.activeTime(&both, local, the_phase) orelse 0;
}

/// The phase now (CSS Animations 2 5.1; CSS Transitions 2 5.1 "the
/// transition phase").
fn currentPhase(animation: *const model.Animation, state: *const State) Phase {
    const effect = animation.effectModel() orelse {
        const current = animation.currentTime() orelse return .idle;
        return if (current < 0) .before else .after;
    };
    if (state.kind == .transition and animation.hasPendingTask() and
        (state.previous_phase == .idle or state.previous_phase == .pending)) return .pending;
    return switch (effect.computed().phase) {
        .idle => .idle,
        .before => .before,
        .active => .active,
        .after => .after,
    };
}

/// At each new animation frame for `animation`: compare its phase with the
/// previous frame's and queue the events the tables give.
pub fn update(animation: *model.Animation) void {
    const state = animation.css orelse return;
    // CSS Animations 2: only when the animation has no pending task.
    if (state.kind == .animation and animation.hasPendingTask()) return;
    const previous = state.previous_phase;
    const now = currentPhase(animation, state);
    const iteration = if (animation.effectModel()) |effect| effect.computed().current_iteration else null;
    defer {
        state.previous_phase = now;
        state.previous_iteration = iteration;
    }
    const element = if (state.owning_element) |link| link.get() else null;
    // No owning element: no CSS events (the playback events still fire).
    const target = element orelse return;
    const times = intervals(animation);
    switch (state.kind) {
        .animation => {
            const was_idle_or_before = previous == .idle or previous == .before or previous == .pending;
            if (was_idle_or_before and now == .active) {
                queue(animation, state, target, "animationstart", times.start);
            } else if (was_idle_or_before and now == .after) {
                queue(animation, state, target, "animationstart", times.start);
                queue(animation, state, target, "animationend", times.end);
            } else if (previous == .active and now == .before) {
                queue(animation, state, target, "animationend", times.start);
            } else if (previous == .active and now == .active) {
                if (iteration != null and state.previous_iteration != null and iteration.? != state.previous_iteration.?) {
                    // † the iteration boundary.
                    const boundary = if (state.previous_iteration.? > iteration.?) iteration.? + 1 else iteration.?;
                    const effect = animation.effectModel().?;
                    const elapsed = (boundary - effect.timing.iteration_start) * effect.timing.iterationDuration();
                    queue(animation, state, target, "animationiteration", elapsed);
                }
            } else if (previous == .active and now == .after) {
                queue(animation, state, target, "animationend", times.end);
            } else if (previous == .after and now == .active) {
                queue(animation, state, target, "animationstart", times.end);
            } else if (previous == .after and now == .before) {
                queue(animation, state, target, "animationstart", times.end);
                queue(animation, state, target, "animationend", times.start);
            } else if (previous != .idle and previous != .after and now == .idle) {
                queueCancel(animation, state, target, "animationcancel");
            }
        },
        .transition => {
            if (previous == .idle and (now == .pending or now == .before)) {
                queue(animation, state, target, "transitionrun", times.start);
            } else if (previous == .idle and now == .active) {
                queue(animation, state, target, "transitionrun", times.start);
                queue(animation, state, target, "transitionstart", times.start);
            } else if (previous == .idle and now == .after) {
                queue(animation, state, target, "transitionrun", times.start);
                queue(animation, state, target, "transitionstart", times.start);
                queue(animation, state, target, "transitionend", times.end);
            } else if ((previous == .pending or previous == .before) and now == .active) {
                queue(animation, state, target, "transitionstart", times.start);
            } else if ((previous == .pending or previous == .before) and now == .after) {
                queue(animation, state, target, "transitionstart", times.start);
                queue(animation, state, target, "transitionend", times.end);
            } else if (previous == .active and now == .after) {
                queue(animation, state, target, "transitionend", times.end);
            } else if (previous == .active and now == .before) {
                queue(animation, state, target, "transitionend", times.start);
            } else if (previous == .after and now == .active) {
                queue(animation, state, target, "transitionstart", times.end);
            } else if (previous == .after and now == .before) {
                queue(animation, state, target, "transitionstart", times.end);
                queue(animation, state, target, "transitionend", times.start);
            } else if (previous != .idle and previous != .after and now == .idle) {
                queueCancel(animation, state, target, "transitioncancel");
            }
        },
    }
    if (now == .idle) state.canceled_active_time = null;
}

const Intervals = struct { start: f64, end: f64 };

/// "interval start = max(min(-start delay, active duration), 0)";
/// "interval end = max(min(associated effect end - start delay, active
/// duration), 0)".
fn intervals(animation: *const model.Animation) Intervals {
    const effect = animation.effectModel() orelse return .{ .start = 0, .end = 0 };
    const t = &effect.timing;
    const active = t.activeDuration();
    return .{
        .start = @max(@min(-t.delay, active), 0),
        .end = @max(@min(animation.effectEnd() - t.delay, active), 0),
    };
}

/// Queue a cancel event. A canceled animation has no start time to place the
/// moment on: its scheduled event time is the timeline's time now (as the
/// "cancel" playback event's, Web Animations 1 4.5.14 step 1.10), so it sorts
/// after the playback event it follows and before later frames' events
/// (web-animations/timing-model/timelines/update-and-send-events.html "Sorts
/// events for the same transition"; Chrome, Firefox and Safari pass it).
fn queueCancel(animation: *model.Animation, state: *const State, target: *runtime.Instance, event_type: []const u8) void {
    const timeline_time = animation.timelineTime();
    const scheduled = if (animation.timelineModel()) |timeline| timeline.toOriginRelative(timeline_time) else null;
    queueAt(animation, state, target, event_type, state.canceled_active_time orelse 0, scheduled);
}

/// Queue the event named `event_type`, its elapsed time `elapsed_ms`, at
/// `target`.
fn queue(animation: *model.Animation, state: *const State, target: *runtime.Instance, event_type: []const u8, elapsed_ms: f64) void {
    // The scheduled event time: when the event's moment - its elapsed time
    // into the active interval - falls on the timeline, origin-relative.
    const delay = if (animation.effectModel()) |effect| effect.timing.delay else 0;
    queueAt(animation, state, target, event_type, elapsed_ms, animation.animationTimeToOriginRelative(delay + elapsed_ms));
}

fn queueAt(animation: *model.Animation, state: *const State, target: *runtime.Instance, event_type: []const u8, elapsed_ms: f64, scheduled: ?f64) void {
    const realm = animation.instance.ctx;
    if (!realm.hasEngine()) return;
    const type_string = runtime.DOMString.initInterned(event_type);
    const elapsed = elapsed_ms / 1000;
    // CSS Animations 1 4.2 and CSS Transitions 1 6.2: every animation and
    // transition event "Bubbles: Yes", "Cancelable: No".
    const event = switch (state.kind) {
        .animation => interfaces.AnimationEvent.call_constructor(realm, type_string, webidl.Opt(dictionaries.AnimationEventInit).passed(.{
            .base = .{ .bubbles = true },
            .animationName = runtime.DOMString.initInterned(state.name),
            .elapsedTime = elapsed,
            .pseudoElement = runtime.DOMString.initInterned(state.pseudo),
            .animation = animation.instance,
        })),
        .transition => interfaces.TransitionEvent.call_constructor(realm, type_string, webidl.Opt(dictionaries.TransitionEventInit).passed(.{
            .base = .{ .bubbles = true },
            .propertyName = runtime.DOMString.initInterned(state.name),
            .elapsedTime = elapsed,
            .pseudoElement = runtime.DOMString.initInterned(state.pseudo),
            .animation = animation.instance,
        })),
    } catch return;
    registry.queueEvent(animation, event, target, scheduled);
}
