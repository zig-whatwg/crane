//! CSS animation and transition events on the timing model: the events a
//! CSSAnimation (CSS Animations 2, 5.1) and a CSSTransition (CSS Transitions
//! 2, 5.1) queue at their owning element as their phase changes from one
//! animation frame to the next.
//!
//! Who makes CSS animations and transitions - the style engine, from
//! computed animation-* and transition-* values at style change events - is
//! a later batch (rendering2's design delta, section 6). This file is what
//! that maker will call: `attach` gives a CSSAnimation or CSSTransition its
//! owning element and name; `update` runs at each "update animations and
//! send events" for it, and `canceled` when it is canceled.
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
};

pub fn destroy(allocator: Allocator, state: *State) void {
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
    if (animation.css) |old| destroy(allocator, old);
    animation.css = state;
    animation.class = if (kind == .animation) .css_animation else .css_transition;
}

/// The style engine ends the association (CSS Animations 2 2.1).
pub fn detach(animation: *model.Animation) void {
    const state = animation.css orelse return;
    state.owning_element = null;
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
                queue(animation, state, target, "animationcancel", state.canceled_active_time orelse 0);
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
                queue(animation, state, target, "transitioncancel", state.canceled_active_time orelse 0);
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

/// Queue the event named `event_type`, its elapsed time `elapsed_ms`, at
/// `target`.
fn queue(animation: *model.Animation, state: *const State, target: *runtime.Instance, event_type: []const u8, elapsed_ms: f64) void {
    const realm = animation.instance.ctx;
    if (!realm.hasEngine()) return;
    const type_string = runtime.DOMString.initInterned(event_type);
    const elapsed = elapsed_ms / 1000;
    const event = switch (state.kind) {
        .animation => interfaces.AnimationEvent.call_constructor(realm, type_string, webidl.Opt(dictionaries.AnimationEventInit).passed(.{
            .base = .{},
            .animationName = runtime.DOMString.initInterned(state.name),
            .elapsedTime = elapsed,
            .pseudoElement = runtime.DOMString.initInterned(state.pseudo),
            .animation = animation.instance,
        })),
        .transition => interfaces.TransitionEvent.call_constructor(realm, type_string, webidl.Opt(dictionaries.TransitionEventInit).passed(.{
            .base = .{},
            .propertyName = runtime.DOMString.initInterned(state.name),
            .elapsedTime = elapsed,
            .pseudoElement = runtime.DOMString.initInterned(state.pseudo),
            .animation = animation.instance,
        })),
    } catch return;
    // The scheduled event time: when the event's moment - its elapsed time
    // into the active interval - falls on the timeline, origin-relative.
    const delay = if (animation.effectModel()) |effect| effect.timing.delay else 0;
    const scheduled = animation.animationTimeToOriginRelative(delay + elapsed_ms);
    registry.queueEvent(animation, event, target, scheduled);
}
