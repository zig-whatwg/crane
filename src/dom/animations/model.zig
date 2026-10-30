//! Web Animations 1 4.3-4.5: timelines, animation effects and animations,
//! and every procedure that changes an animation's timing.
//!
//! The models are OWNED by their interfaces' impls (made in initOwn, freed in
//! deinitOwn; hooks.zig reaches them). What one model keeps of another:
//!   - an animation's timeline and effect, a keyframe effect's target: what
//!     script can read back, so each is a TRACED edge from the owner's
//!     wrapper (engine.traceChild) plus a generation-checked Link to read it
//!     by - never a root;
//!   - an effect's animation, a timeline's document: back links, BORROWED and
//!     generation-checked.
//! An animation keeps itself alive (engine.keepPlatformObjectAlive, counted
//! once by `kept`) while it has work the engine cannot see: a pending task,
//! a queued finish notification or event, a running timeline it advances
//! on, or a target it is relevant to (Blink: Animation::HasPendingActivity
//! and DocumentTimeline's animations_needing_update_, the element's effect
//! stack keeping in-effect animations).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#animations
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const timing_mod = @import("timing.zig");
const promise_mod = @import("promise.zig");
const hooks = @import("hooks.zig");
const registry = @import("registry.zig");
const keyframes_mod = @import("keyframes.zig");

const Allocator = std.mem.Allocator;
pub const Timing = timing_mod.Timing;

/// A link to an Instance that may be freed without telling the holder: the
/// slab generation names the object it was taken on.
pub const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn to(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    /// The instance, while it is still the object this link was taken on.
    pub fn get(self: Link) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.instance) != self.generation) return null;
        return self.instance;
    }
};

/// 5.4.1 animation classes, in inter-class composite order.
pub const Class = enum(u2) { css_transition, css_animation, script };

pub const PlayState = enum { idle, running, paused, finished };
pub const ReplaceState = enum { active, removed, persisted };
pub const Composite = enum { replace, add, accumulate };

// ============================================================================
// Timelines (4.3)
// ============================================================================

pub const Timeline = struct {
    allocator: Allocator,
    /// Back link to its own instance.
    instance: *runtime.Instance,
    /// A document timeline's document (4.3.1); null for a timeline Crane
    /// cannot run (a scroll or view timeline: inactive).
    document: ?Link = null,
    /// 4.3.1 the origin time, ms relative to the document's time origin.
    origin_time: f64 = 0,

    /// 4.3 the timeline's current time: for a document timeline, the
    /// document's animation time less the origin time; unresolved while
    /// the document is not an active document (4.3.1).
    pub fn currentTime(self: *const Timeline) ?f64 {
        const link = self.document orelse return null;
        const document = link.get() orelse return null;
        const time = registry.documentTime(document) orelse return null;
        return time - self.origin_time;
    }

    /// 4.3.1 "convert a timeline time to an origin-relative time".
    pub fn toOriginRelative(self: *const Timeline, time: ?f64) ?f64 {
        const t = time orelse return null;
        if (self.currentTime() == null) return null;
        return t + self.origin_time;
    }

    /// The document the timeline is associated with, while it lives.
    pub fn documentInstance(self: *const Timeline) ?*runtime.Instance {
        const link = self.document orelse return null;
        return link.get();
    }
};

// ============================================================================
// Animation effects (4.6) and keyframe effects (5.3)
// ============================================================================

pub const Effect = struct {
    allocator: Allocator,
    /// Back link to its own instance.
    instance: *runtime.Instance,
    timing: Timing = .{},
    /// 4.6.2 the associated animation: BORROWED back link.
    animation: ?Link = null,
    /// A KeyframeEffect (5.3); a bare AnimationEffect has no target.
    keyframe_effect: bool = false,
    /// 5.3 the target element, kept by a traced edge (`target_slot`).
    target: ?Link = null,
    /// The target pseudo-selector, OWNED; null for the element itself.
    pseudo: ?[]u8 = null,
    composite: Composite = .replace,
    /// Web Animations 2 the iteration composite operation (kept; applied
    /// with the animated values).
    iteration_accumulate: bool = false,
    keyframes: keyframes_mod.List = .{},

    pub const target_slot: engine.TracedSlot = .{ .name = "KeyframeEffect:target" };

    pub fn deinit(self: *Effect) void {
        self.timing.deinit(self.allocator);
        if (self.pseudo) |pseudo| self.allocator.free(pseudo);
        self.keyframes.deinit(self.allocator);
    }

    /// The associated animation's model, while it lives.
    pub fn animationModel(self: *const Effect) ?*Animation {
        const link = self.animation orelse return null;
        const instance = link.get() orelse return null;
        return hooks.animationOf(instance);
    }

    /// The target element, while it lives.
    pub fn targetElement(self: *const Effect) ?*runtime.Instance {
        const link = self.target orelse return null;
        return link.get();
    }

    /// 5.3 "set the target element": the traced edge follows it.
    pub fn setTarget(self: *Effect, element: ?*runtime.Instance) void {
        if (element) |e| {
            engine.traceChild(self.instance, e, target_slot);
            self.target = Link.to(e);
        } else {
            if (self.target != null) engine.forgetTracedChild(self.instance, target_slot);
            self.target = null;
        }
    }

    /// 4.6.3 the local time: the associated animation's current time.
    pub fn localTime(self: *const Effect) ?f64 {
        const animation = self.animationModel() orelse return null;
        return animation.currentTime();
    }

    /// 4.6.6-4.7 for the effect's local time now.
    pub fn computed(self: *const Effect) timing_mod.Computed {
        return self.computedWith(false);
    }

    pub fn computedWith(self: *const Effect, inclusive: bool) timing_mod.Computed {
        const animation = self.animationModel();
        // 4.6.6 "animation direction": backwards when the associated
        // animation's playback rate is less than zero.
        const backwards = if (animation) |a| a.playback_rate < 0 else false;
        const local = if (animation) |a| a.currentTime() else null;
        return timing_mod.compute(&self.timing, local, backwards, inclusive);
    }

    /// 4.6.6 "in play": in the active phase, and its animation not finished.
    pub fn inPlay(self: *const Effect) bool {
        const animation = self.animationModel() orelse return false;
        return self.computed().phase == .active and animation.playState() != .finished;
    }

    /// 4.6.6 "current".
    pub fn isCurrent(self: *const Effect) bool {
        const animation = self.animationModel() orelse return false;
        const the_phase = self.computed().phase;
        if (the_phase == .active and animation.playState() != .finished) return true;
        if (the_phase == .before and animation.playback_rate > 0) return true;
        if (the_phase == .after and animation.playback_rate < 0) return true;
        // (A timeline that is not monotonically increasing: none in Crane.)
        return false;
    }

    /// 4.6.6 "in effect": a resolved active time.
    pub fn isInEffect(self: *const Effect) bool {
        return self.computed().active_time != null;
    }
};

// ============================================================================
// Animations (4.5)
// ============================================================================

pub const Animation = struct {
    allocator: Allocator,
    /// Back link to its own instance.
    instance: *runtime.Instance,
    class: Class = .script,
    /// The position in the global animation list (4.5): creation order.
    sequence: u64 = 0,
    id: []u8 = &.{},
    timeline: ?Link = null,
    effect: ?Link = null,
    start_time: ?f64 = null,
    hold_time: ?f64 = null,
    /// 4.5.12 the previous current time.
    previous_current_time: ?f64 = null,
    playback_rate: f64 = 1,
    /// 4.5.15.2 the pending playback rate.
    pending_playback_rate: ?f64 = null,
    pending_play: bool = false,
    pending_pause: bool = false,
    replace_state: ReplaceState = .active,
    ready: promise_mod.Slot = .{ .slot = .{ .name = "Animation:ready" }, .status = .fulfilled },
    finished: promise_mod.Slot = .{ .slot = .{ .name = "Animation:finished" }, .status = .pending },
    /// 4.5.12 step 5.2: a microtask to run the finish notification steps is
    /// queued; `finish_serial` cancels it ("cancel any queued microtask").
    finish_queued: bool = false,
    finish_serial: u32 = 0,
    /// Events queued for this animation and not dispatched yet.
    queued_events: u32 = 0,
    /// One keepPlatformObjectAlive of this model's own.
    kept: bool = false,
    /// A CSS animation's or transition's own state (css_events.zig).
    css: ?*@import("css_events.zig").State = null,

    pub const timeline_slot: engine.TracedSlot = .{ .name = "Animation:timeline" };
    pub const effect_slot: engine.TracedSlot = .{ .name = "Animation:effect" };

    /// The owner frees its instance: what the model owns goes. A collected
    /// owner's edges went with its wrapper (`owner_live` false).
    pub fn deinit(self: *Animation, owner_live: bool) void {
        self.ready.deinit(self.instance, owner_live);
        self.finished.deinit(self.instance, owner_live);
        if (self.id.len != 0) self.allocator.free(self.id);
        self.id = &.{};
        if (self.css) |css| @import("css_events.zig").destroy(self.allocator, css);
        self.css = null;
    }

    pub fn timelineModel(self: *const Animation) ?*Timeline {
        const link = self.timeline orelse return null;
        const instance = link.get() orelse return null;
        return hooks.timelineOf(instance);
    }

    pub fn effectModel(self: *const Animation) ?*Effect {
        const link = self.effect orelse return null;
        const instance = link.get() orelse return null;
        return hooks.effectOf(instance);
    }

    /// The timeline's current time: unresolved without an active timeline.
    pub fn timelineTime(self: *const Animation) ?f64 {
        const timeline = self.timelineModel() orelse return null;
        return timeline.currentTime();
    }

    /// 4.5 the document for timing: the timeline's document.
    pub fn documentForTiming(self: *const Animation) ?*runtime.Instance {
        const timeline = self.timelineModel() orelse return null;
        return timeline.documentInstance();
    }

    /// 4.5.1 the current time.
    pub fn currentTime(self: *const Animation) ?f64 {
        if (self.hold_time) |hold| return hold;
        return self.currentTimeIgnoringHold();
    }

    /// 4.5.1 with an unresolved hold time (4.5.12 step 1's "unconstrained").
    fn currentTimeIgnoringHold(self: *const Animation) ?f64 {
        const timeline_time = self.timelineTime() orelse return null;
        const start = self.start_time orelse return null;
        return (timeline_time - start) * self.playback_rate;
    }

    /// 4.5.15.2 the effective playback rate.
    pub fn effectivePlaybackRate(self: *const Animation) f64 {
        return self.pending_playback_rate orelse self.playback_rate;
    }

    /// 4.5.12 the associated effect end: the effect's end time, or zero.
    pub fn effectEnd(self: *const Animation) f64 {
        const effect = self.effectModel() orelse return 0;
        return effect.timing.endTime();
    }

    pub fn hasPendingTask(self: *const Animation) bool {
        return self.pending_play or self.pending_pause;
    }

    /// 4.5.17 the play state.
    pub fn playState(self: *const Animation) PlayState {
        const current = self.currentTime();
        if (current == null and self.start_time == null and !self.hasPendingTask()) return .idle;
        if (self.pending_pause or (self.start_time == null and !self.pending_play)) return .paused;
        if (current) |time| {
            const rate = self.effectivePlaybackRate();
            if ((rate > 0 and time >= self.effectEnd()) or (rate < 0 and time <= 0)) return .finished;
        }
        return .running;
    }

    /// 4.5.15.2 "apply any pending playback rate".
    fn applyPendingPlaybackRate(self: *Animation) void {
        const pending = self.pending_playback_rate orelse return;
        self.playback_rate = pending;
        self.pending_playback_rate = null;
    }

    /// 4.6.7 relevant: its effect current or in effect, and not removed.
    pub fn isRelevant(self: *const Animation) bool {
        if (self.replace_state == .removed) return false;
        const effect = self.effectModel() orelse return false;
        return effect.isCurrent() or effect.isInEffect();
    }

    // ------------------------------------------------------------------
    // 4.5.2 Setting the timeline
    // ------------------------------------------------------------------

    pub fn setTimeline(self: *Animation, new_timeline: ?*runtime.Instance) void {
        // 1-2.
        const old = if (self.timeline) |link| link.get() else null;
        if (old == new_timeline and (self.timeline == null) == (new_timeline == null)) return;
        const old_document = self.documentForTiming();
        // 3. The traced edge follows the member script reads.
        if (new_timeline) |timeline| {
            engine.traceChild(self.instance, timeline, timeline_slot);
            self.timeline = Link.to(timeline);
        } else {
            if (self.timeline != null) engine.forgetTracedChild(self.instance, timeline_slot);
            self.timeline = null;
        }
        // 4.
        if (self.start_time != null) self.hold_time = null;
        // 5.
        self.updateFinishedState(false, false);
        // Events queued for the old document for timing stay in its queue.
        _ = old_document;
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.3 Setting the associated effect
    // ------------------------------------------------------------------

    pub fn setEffect(self: *Animation, new_effect: ?*runtime.Instance) void {
        // 1-2.
        const old = if (self.effect) |link| link.get() else null;
        if (old == new_effect and (self.effect == null) == (new_effect == null)) return;
        // 3-4. "Reschedule" a pending task: it runs when the animation is
        // ready, which does not depend on the effect here.
        // 5. A new effect leaves its previous animation first.
        if (new_effect) |instance| if (hooks.effectOf(instance)) |effect| {
            if (effect.animationModel()) |previous| if (previous != self) previous.setEffect(null);
        };
        // The old effect no longer has an associated animation.
        if (self.effectModel()) |effect| effect.animation = null;
        // 6.
        if (new_effect) |instance| {
            engine.traceChild(self.instance, instance, effect_slot);
            self.effect = Link.to(instance);
            if (hooks.effectOf(instance)) |effect| effect.animation = Link.to(self.instance);
        } else {
            if (self.effect != null) engine.forgetTracedChild(self.instance, effect_slot);
            self.effect = null;
        }
        // 7.
        self.updateFinishedState(false, false);
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.4 Setting the current time
    // ------------------------------------------------------------------

    /// "Silently set the current time".
    fn silentlySetCurrentTime(self: *Animation, seek_time: ?f64) error{TypeError}!void {
        // 1.
        const seek = seek_time orelse {
            if (self.currentTime() != null) return error.TypeError;
            return;
        };
        // 2.
        const timeline_time = self.timelineTime();
        if (self.hold_time != null or self.start_time == null or timeline_time == null or self.playback_rate == 0) {
            self.hold_time = seek;
        } else {
            self.start_time = timeline_time.? - (seek / self.playback_rate);
        }
        // 3.
        if (timeline_time == null) self.start_time = null;
        // 4.
        self.previous_current_time = null;
    }

    /// "Set the current time" (the currentTime setter).
    pub fn setCurrentTime(self: *Animation, seek_time: ?f64) error{TypeError}!void {
        // 1.
        try self.silentlySetCurrentTime(seek_time);
        // 2. A pending pause completes now.
        if (self.pending_pause) {
            self.hold_time = seek_time;
            self.applyPendingPlaybackRate();
            self.start_time = null;
            self.pending_pause = false;
            self.ready.resolve(self.instance);
        }
        // 3.
        self.updateFinishedState(true, false);
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.5 Setting the start time
    // ------------------------------------------------------------------

    pub fn setStartTime(self: *Animation, new_start_time: ?f64) void {
        // 1.
        const timeline_time = self.timelineTime();
        // 2.
        if (timeline_time == null and new_start_time != null) self.hold_time = null;
        // 3.
        const previous_current_time = self.currentTime();
        // 4.
        self.applyPendingPlaybackRate();
        // 5.
        self.start_time = new_start_time;
        // 6.
        if (new_start_time != null) {
            if (self.playback_rate != 0) self.hold_time = null;
        } else self.hold_time = previous_current_time;
        // 7.
        if (self.hasPendingTask()) {
            self.pending_play = false;
            self.pending_pause = false;
            self.ready.resolve(self.instance);
        }
        // 8.
        self.updateFinishedState(true, false);
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.8 Playing
    // ------------------------------------------------------------------

    pub fn play(self: *Animation, auto_rewind: bool) error{InvalidStateError}!void {
        try self.playSteps(auto_rewind);
        self.settle();
    }

    fn playSteps(self: *Animation, auto_rewind: bool) error{InvalidStateError}!void {
        // 1-3.
        const aborted_pause = self.pending_pause;
        var has_pending_ready_promise = false;
        var seek_time: ?f64 = null;
        const current = self.currentTime();
        const rate = self.effectivePlaybackRate();
        const effect_end = self.effectEnd();
        // 4.
        if (auto_rewind) {
            if (rate >= 0 and (current == null or current.? < 0 or current.? >= effect_end)) {
                seek_time = 0;
            } else if (rate < 0 and (current == null or current.? <= 0 or current.? > effect_end)) {
                if (std.math.isPositiveInf(effect_end)) return error.InvalidStateError;
                seek_time = effect_end;
            }
        }
        // 5.
        if (seek_time == null and self.start_time == null and current == null) seek_time = 0;
        // 6-7. Document timelines are monotonically increasing: no finite
        // timeline here.
        if (seek_time) |seek| self.hold_time = seek;
        // 8.
        if (self.hold_time != null) self.start_time = null;
        // 9.
        if (self.hasPendingTask()) {
            self.pending_play = false;
            self.pending_pause = false;
            has_pending_ready_promise = true;
        }
        // 10.
        if (self.hold_time == null and seek_time == null and !aborted_pause and self.pending_playback_rate == null) return;
        // 11.
        if (!has_pending_ready_promise) self.ready.replace(self.instance, .pending);
        // 12. The pending play task runs when the animation is ready: at its
        // document for timing's next "update animations and send events".
        self.pending_play = true;
        // 13.
        self.updateFinishedState(false, false);
    }

    // ------------------------------------------------------------------
    // 4.5.9 Pausing
    // ------------------------------------------------------------------

    pub fn pause(self: *Animation) error{InvalidStateError}!void {
        // 1-2.
        if (self.pending_pause) return;
        if (self.playState() == .paused) return;
        // 3-6.
        if (self.currentTime() == null) {
            if (self.playback_rate >= 0) {
                self.hold_time = 0;
            } else {
                const effect_end = self.effectEnd();
                if (std.math.isPositiveInf(effect_end)) return error.InvalidStateError;
                self.hold_time = effect_end;
            }
        }
        // 7-8.
        var has_pending_ready_promise = false;
        if (self.pending_play) {
            self.pending_play = false;
            has_pending_ready_promise = true;
        }
        // 9.
        if (!has_pending_ready_promise) self.ready.replace(self.instance, .pending);
        // 10.
        self.pending_pause = true;
        // 11.
        self.updateFinishedState(false, false);
        self.settle();
    }

    // ------------------------------------------------------------------
    // The pending tasks, run when the animation is ready (4.5.6)
    // ------------------------------------------------------------------

    /// The animation is ready (4.5.6): its pending play or pause task runs,
    /// with `ready_time` the timeline's time now. Crane has no compositor to
    /// set up, so an animation is ready at its document for timing's next
    /// "update animations and send events" with an active timeline (WebKit
    /// runs the pending tasks there too: AnimationTimelinesController::
    /// updateAnimationsAndSendEvents).
    pub fn runPendingTasks(self: *Animation) void {
        if (!self.hasPendingTask()) return;
        const ready_time = self.timelineTime() orelse return;
        if (self.pending_play) {
            self.pending_play = false;
            // 12.3.
            if (self.hold_time) |hold| {
                self.applyPendingPlaybackRate();
                self.start_time = if (self.playback_rate == 0) ready_time else ready_time - hold / self.playback_rate;
                if (self.playback_rate != 0) self.hold_time = null;
            } else if (self.start_time != null and self.pending_playback_rate != null) {
                const current_time_to_match = (ready_time - self.start_time.?) * self.playback_rate;
                self.applyPendingPlaybackRate();
                if (self.playback_rate == 0) self.hold_time = current_time_to_match;
                self.start_time = if (self.playback_rate == 0) ready_time else ready_time - current_time_to_match / self.playback_rate;
            }
            // 12.4-12.5.
            self.ready.resolve(self.instance);
            self.updateFinishedState(false, false);
        } else if (self.pending_pause) {
            self.pending_pause = false;
            // 10.2.
            if (self.start_time != null and self.hold_time == null) self.hold_time = (ready_time - self.start_time.?) * self.playback_rate;
            // 10.3-10.6.
            self.applyPendingPlaybackRate();
            self.start_time = null;
            self.ready.resolve(self.instance);
            self.updateFinishedState(false, false);
        }
    }

    // ------------------------------------------------------------------
    // 4.5.12 Updating the finished state
    // ------------------------------------------------------------------

    pub fn updateFinishedState(self: *Animation, did_seek: bool, synchronously_notify: bool) void {
        // 1.
        const unconstrained = if (did_seek) self.currentTime() else self.currentTimeIgnoringHold();
        // 2.
        if (unconstrained != null and self.start_time != null and !self.hasPendingTask()) {
            const time = unconstrained.?;
            const effect_end = self.effectEnd();
            if (self.playback_rate > 0 and time >= effect_end) {
                self.hold_time = if (did_seek) time else if (self.previous_current_time) |previous| @max(previous, effect_end) else effect_end;
            } else if (self.playback_rate < 0 and time <= 0) {
                self.hold_time = if (did_seek) time else if (self.previous_current_time) |previous| @min(previous, 0) else 0;
            } else if (self.playback_rate != 0 and self.timelineTime() != null) {
                if (did_seek) if (self.hold_time) |hold| {
                    self.start_time = self.timelineTime().? - (hold / self.playback_rate);
                };
                self.hold_time = null;
            }
        }
        // 3.
        self.previous_current_time = self.currentTime();
        // 4.
        const current_finished_state = self.playState() == .finished;
        // 5.
        if (current_finished_state and !self.finished.isResolved()) {
            if (synchronously_notify) {
                // 5.2: cancel a queued microtask and notify now.
                self.finish_serial +%= 1;
                self.finish_queued = false;
                self.finishNotificationSteps();
            } else if (!self.finish_queued) {
                self.queueFinishNotification();
            }
        }
        // 6.
        if (!current_finished_state and self.finished.isResolved()) self.finished.replace(self.instance, .pending);
    }

    fn queueFinishNotification(self: *Animation) void {
        const record = self.allocator.create(FinishMicrotask) catch return;
        record.* = .{ .allocator = self.allocator, .animation = Link.to(self.instance), .serial = self.finish_serial };
        engine.queueRealmMicrotask(self.instance.ctx, &FinishMicrotask.steps, record) catch {
            self.allocator.destroy(record);
            return;
        };
        self.finish_queued = true;
    }

    /// 4.5.12 step 5.1 "the finish notification steps".
    fn finishNotificationSteps(self: *Animation) void {
        // 1.
        if (self.playState() != .finished) return;
        // 2.
        self.finished.resolve(self.instance);
        // 3-6.
        const timeline_time = self.timelineTime();
        // 7. The scheduled event time: the associated effect end, as an
        // origin-relative time.
        const scheduled = self.animationTimeToOriginRelative(self.effectEnd());
        registry.queuePlaybackEvent(self, "finish", self.currentTime(), timeline_time, scheduled);
    }

    // ------------------------------------------------------------------
    // 4.5.13 Finishing
    // ------------------------------------------------------------------

    pub fn finish(self: *Animation) error{InvalidStateError}!void {
        // 1.
        const rate = self.effectivePlaybackRate();
        if (rate == 0 or (rate > 0 and std.math.isPositiveInf(self.effectEnd()))) return error.InvalidStateError;
        // 2.
        self.applyPendingPlaybackRate();
        // 3.
        const limit: f64 = if (self.playback_rate > 0) self.effectEnd() else 0;
        // 4.
        self.silentlySetCurrentTime(limit) catch unreachable;
        // 5.
        if (self.start_time == null) if (self.timelineTime()) |timeline_time| {
            self.start_time = timeline_time - (limit / self.playback_rate);
        };
        // 6.
        if (self.pending_pause and self.start_time != null) {
            self.hold_time = null;
            self.pending_pause = false;
            self.ready.resolve(self.instance);
        }
        // 7.
        if (self.pending_play and self.start_time != null) {
            self.pending_play = false;
            self.ready.resolve(self.instance);
        }
        // 8.
        self.updateFinishedState(true, true);
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.14 Canceling
    // ------------------------------------------------------------------

    pub fn cancel(self: *Animation) void {
        self.cancelSteps();
        self.settle();
    }

    fn cancelSteps(self: *Animation) void {
        // 1.
        if (self.playState() != .idle) {
            self.resetPendingTasks();
            self.finished.rejectAbort(self.instance);
            self.finished.replace(self.instance, .pending);
            const timeline_time = self.timelineTime();
            const scheduled = if (self.timelineModel()) |timeline| timeline.toOriginRelative(timeline_time) else null;
            registry.queuePlaybackEvent(self, "cancel", null, timeline_time, scheduled);
            if (self.css != null) @import("css_events.zig").canceled(self);
        }
        // 2-3.
        self.hold_time = null;
        self.start_time = null;
    }

    /// 4.5.14 "reset an animation's pending tasks".
    fn resetPendingTasks(self: *Animation) void {
        // 1-3.
        if (!self.hasPendingTask()) return;
        self.pending_play = false;
        self.pending_pause = false;
        // 4.
        self.applyPendingPlaybackRate();
        // 5-7.
        self.ready.rejectAbort(self.instance);
        self.ready.replace(self.instance, .fulfilled);
    }

    // ------------------------------------------------------------------
    // 4.5.15 Speed control
    // ------------------------------------------------------------------

    /// 4.5.15.1 "set the playback rate" (the playbackRate setter).
    pub fn setPlaybackRate(self: *Animation, new_playback_rate: f64) void {
        // 1.
        self.pending_playback_rate = null;
        // 2-3.
        const previous_time = self.currentTime();
        // 4.
        self.playback_rate = new_playback_rate;
        // 5. Document timelines are monotonically increasing.
        if (self.timeline != null and previous_time != null) self.setCurrentTime(previous_time) catch {};
        // 6.
        self.updateFinishedState(true, false);
        self.settle();
    }

    /// 4.5.15.2 "seamlessly update the playback rate" (updatePlaybackRate).
    pub fn updatePlaybackRate(self: *Animation, new_playback_rate: f64) void {
        // 1.
        const previous_play_state = self.playState();
        // 2.
        self.pending_playback_rate = new_playback_rate;
        // 3.
        if (self.hasPendingTask()) {
            // The pending tasks apply it.
        } else if (previous_play_state == .idle or previous_play_state == .paused or self.currentTime() == null) {
            self.applyPendingPlaybackRate();
        } else if (previous_play_state == .finished) {
            const unconstrained = self.currentTimeIgnoringHold();
            const timeline_time = self.timelineTime();
            if (timeline_time) |time| {
                self.start_time = if (new_playback_rate == 0) time else time - ((unconstrained orelse 0) / new_playback_rate);
            }
            self.applyPendingPlaybackRate();
            self.updateFinishedState(false, false);
        } else {
            self.playSteps(false) catch {};
        }
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.16 Reversing
    // ------------------------------------------------------------------

    pub fn reverse(self: *Animation) error{InvalidStateError}!void {
        // 1.
        if (self.timelineTime() == null) return error.InvalidStateError;
        // 2-3.
        const original_pending_playback_rate = self.pending_playback_rate;
        self.pending_playback_rate = -self.effectivePlaybackRate();
        // 4.
        self.playSteps(true) catch |err| {
            self.pending_playback_rate = original_pending_playback_rate;
            return err;
        };
        self.settle();
    }

    /// persist(): the replace state becomes persisted.
    pub fn persist(self: *Animation) void {
        self.replace_state = .persisted;
        self.settle();
    }

    // ------------------------------------------------------------------
    // 4.5.18.1 Time conversions for scheduled event times
    // ------------------------------------------------------------------

    /// "Convert an animation time to timeline time".
    pub fn animationTimeToTimelineTime(self: *const Animation, time: ?f64) ?f64 {
        const t = time orelse return null;
        if (std.math.isInf(t)) return null;
        if (self.playback_rate == 0) return null;
        const start = self.start_time orelse return null;
        return t * (1 / self.playback_rate) + start;
    }

    /// "Convert a timeline time to an origin-relative time", from a time
    /// relative to the animation's start time.
    pub fn animationTimeToOriginRelative(self: *const Animation, time: ?f64) ?f64 {
        // 1-2.
        const timeline_time = self.animationTimeToTimelineTime(time) orelse return time;
        // 3-6.
        const timeline = self.timelineModel() orelse return null;
        return timeline.toOriginRelative(timeline_time);
    }

    // ------------------------------------------------------------------
    // Keep-alive and frames
    // ------------------------------------------------------------------

    /// After any change: keep the animation alive while it has work the
    /// engine cannot see, and ask for a frame while its timing needs one
    /// (lesson: frames on demand need every owner to ask).
    pub fn settle(self: *Animation) void {
        // Every change to an animation ends here: the effect values may
        // have moved (effect_stack.component).
        registry.valuesChanged(self.instance.ctx);
        const needs_frame = self.hasPendingTask() or self.queued_events > 0 or self.playState() == .running;
        const document = self.documentForTiming();
        if (needs_frame) if (document) |d| registry.requestFrameFor(d);
        const keep = self.hasPendingTask() or self.queued_events > 0 or self.finish_queued or
            (self.playState() == .running and document != null) or
            (self.isRelevant() and self.targetConnected());
        if (keep == self.kept) return;
        if (!self.instance.ctx.hasEngine()) return;
        if (keep) engine.keepPlatformObjectAlive(self.instance) else engine.releasePlatformObject(self.instance);
        self.kept = keep;
    }

    /// The realm's window goes: no step of it will run again here.
    pub fn letGo(self: *Animation) void {
        if (!self.kept) return;
        self.kept = false;
        if (self.instance.ctx.hasEngine()) engine.releasePlatformObject(self.instance);
    }

    fn targetConnected(self: *const Animation) bool {
        const effect = self.effectModel() orelse return false;
        const target = effect.targetElement() orelse return false;
        return interfaces.Node.get_isConnected(target) catch false;
    }
};

/// The queued "finish notification steps" (4.5.12 step 5.2).
const FinishMicrotask = struct {
    allocator: Allocator,
    animation: Link,
    serial: u32,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = run, .dropped = dropped };

    fn run(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *FinishMicrotask = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        const instance = self.animation.get() orelse return;
        const animation = hooks.animationOf(instance) orelse return;
        if (animation.finish_serial != self.serial or !animation.finish_queued) return;
        animation.finish_queued = false;
        animation.finishNotificationSteps();
        animation.settle();
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *FinishMicrotask = @ptrCast(@alignCast(data.?));
        defer self.allocator.destroy(self);
        // The realm ended or the queue was discarded: the animation's
        // engine side is gone or going; only the flag is ours to reset.
        const instance = self.animation.get() orelse return;
        const animation = hooks.animationOf(instance) orelse return;
        if (animation.finish_serial == self.serial) animation.finish_queued = false;
    }
};
