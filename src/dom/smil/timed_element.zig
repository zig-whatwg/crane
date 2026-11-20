//! The timing model of one SVG animation element (SMIL Animation 3.2-3.6,
//! normative for SVG through SVG Animations 2 section 2.3): its begin and end
//! instance time lists, its current and previous interval, its active state,
//! and the events and dependents' notices its life cycle raises.
//!
//! The algorithms are SMIL Animation 3.6.8's (getFirstInterval,
//! getNextInterval, "Interaction with restart semantics") and 3.3.4's
//! active duration table, in the shape Blink gives them - one interval
//! resolver for the first and every next interval, re-evaluated when an
//! instance list changes (Blink SVGSMILElement: ResolveInterval,
//! ResolveActiveEnd, RepeatingDuration, UpdateInterval,
//! HandleIntervalRestart, DiscardOrRevalidateCurrentInterval,
//! UpdateActiveState, ComputeSeekEvents, CalculateProgressState,
//! core/svg/animation/svg_smil_element.cc, read 2026-11-20; BSD-2, Apple
//! 2008). The algorithm is reproduced, not the code.
//!
//! Plain data, engine-free: nothing here touches a node. The element's
//! owner (dom.smil.document_animations, for the SVGAnimationElement impl)
//! feeds it the timing attributes' values, connects its syncbase conditions
//! to other timed elements, and turns the events it reports into TimeEvents.
//!
//! Ownership: a timed element and its time container point at each other
//! while it is scheduled, and each detaches the other before it goes
//! (`TimeContainer.unschedule`, `TimeContainer.deinit`); a syncbase
//! condition and its syncbase element likewise (`disconnectSyncBases`,
//! `deinit`). Whichever is freed first, the other is left pointing at
//! nothing.
const std = @import("std");
const time_mod = @import("time.zig");
const parse = @import("parse.zig");
const TimeContainer = @import("time_container.zig").TimeContainer;

const Time = time_mod.Time;
const Interval = time_mod.Interval;
const RepeatCount = time_mod.RepeatCount;
const Allocator = std.mem.Allocator;
pub const BeginOrEnd = parse.BeginOrEnd;

/// Where an instance time came from (SMIL Animation 3.6.8: event values,
/// DOM method calls and syncbase values are cleared or kept by different
/// rules).
pub const Origin = enum(u3) { attribute, script, event, syncbase, repeat, link_activation };

pub const InstanceTime = struct {
    time: Time,
    origin: Origin,
};

/// A begin or end instance time list, kept sorted ("The lists are maintained
/// in sorted order, with "indefinite" sorting after all other resolved
/// times, and unresolved times sorting to the end").
pub const InstanceTimeList = struct {
    items: std.ArrayListUnmanaged(InstanceTime) = .empty,

    pub fn deinit(self: *InstanceTimeList, allocator: Allocator) void {
        self.items.deinit(allocator);
    }

    pub fn append(self: *InstanceTimeList, allocator: Allocator, time: Time, origin: Origin) Allocator.Error!void {
        try self.items.append(allocator, .{ .time = time, .origin = origin });
    }

    /// Insert in order, unless the same time from the same origin is there.
    pub fn insertSortedAndUnique(self: *InstanceTimeList, allocator: Allocator, time: Time, origin: Origin) Allocator.Error!void {
        var position: usize = 0;
        while (position < self.items.items.len and self.items.items[position].time.lessThan(time)) position += 1;
        var i = position;
        while (i < self.items.items.len and self.items.items[i].time.eql(time)) : (i += 1) {
            if (self.items.items[i].origin == origin) return;
        }
        try self.items.insert(allocator, position, .{ .time = time, .origin = origin });
    }

    pub fn removeWithOrigin(self: *InstanceTimeList, origin: Origin) void {
        var kept: usize = 0;
        for (self.items.items) |item| {
            if (item.origin == origin) continue;
            self.items.items[kept] = item;
            kept += 1;
        }
        self.items.shrinkRetainingCapacity(kept);
    }

    pub fn removeBeforeWithOrigin(self: *InstanceTimeList, before: Time, origin: Origin) void {
        var kept: usize = 0;
        for (self.items.items) |item| {
            if (item.origin == origin and item.time.lessThan(before)) continue;
            self.items.items[kept] = item;
            kept += 1;
        }
        self.items.shrinkRetainingCapacity(kept);
    }

    pub fn sort(self: *InstanceTimeList) void {
        std.mem.sort(InstanceTime, self.items.items, {}, struct {
            fn lessThan(_: void, a: InstanceTime, b: InstanceTime) bool {
                return a.time.lessThan(b.time);
            }
        }.lessThan);
    }

    /// The first instance time strictly greater than `time`, or unresolved.
    pub fn nextAfter(self: *const InstanceTimeList, time: Time) Time {
        for (self.items.items) |item| {
            if (time.lessThan(item.time)) return item.time;
        }
        return .unresolved;
    }

    pub fn isEmpty(self: *const InstanceTimeList) bool {
        return self.items.items.len == 0;
    }
};

pub const Restart = enum(u2) { always, when_not_active, never };
pub const Fill = enum(u1) { remove, freeze };
pub const ActiveState = enum(u2) { inactive, active, frozen };

/// The TimeEvents one update owes an element, in dispatch order: end, then
/// begin, then repeat (an element that restarts raises "an end event and
/// another begin event", SVG Animations 2 5.1).
pub const Events = packed struct(u8) {
    end: bool = false,
    begin: bool = false,
    repeat: bool = false,
    _: u5 = 0,

    pub fn isEmpty(self: Events) bool {
        return !self.end and !self.begin and !self.repeat;
    }
};

/// Where the simple time is: the fraction of the simple duration played, and
/// the (0-based) iteration.
pub const Progress = struct {
    fraction: f32 = 0,
    repeat: u32 = 0,
};

/// Whether next-interval times count repeat boundaries (a seek skips them).
pub const IncludeRepeats = enum { include, exclude };

/// A syncbase condition, live: its parse and the timed element it is
/// connected to.
pub const SyncBaseCondition = struct {
    which: BeginOrEnd,
    /// "begin", "end" or "repeat".
    symbol: Symbol,
    offset: Time,
    repeat: u32 = 0,
    /// The syncbase element's id. Owned.
    base_id: []u8,
    base: ?*TimedElement = null,

    pub const Symbol = enum(u2) { begin, end, repeat };
};

const max_instance_times = 100;

pub const TimedElement = struct {
    allocator: Allocator,
    begin_times: InstanceTimeList = .{},
    end_times: InstanceTimeList = .{},
    /// The syncbase and repeat conditions of the begin and end lists.
    sync_conditions: std.ArrayListUnmanaged(SyncBaseCondition) = .empty,
    /// The timed elements whose conditions name this one as syncbase.
    dependents: std.ArrayListUnmanaged(*TimedElement) = .empty,
    has_end_event_conditions: bool = false,
    has_end_attribute_specified: bool = false,

    interval: Interval = .unresolved,
    previous_interval: Interval = .unresolved,
    active_state: ActiveState = .inactive,
    is_waiting_for_first_interval: bool = true,
    restart: Restart = .always,
    fill: Fill = .remove,
    last_progress: Progress = .{},

    /// The timing attributes' parsed values (SMIL Animation 3.2.1, 3.3.1,
    /// 3.3.3): dur, repeatDur and the min/max bounds. Unresolved: absent or
    /// invalid.
    dur: Time = .unresolved,
    repeat_dur: Time = .unresolved,
    repeat_count: RepeatCount = .unspecified,
    min: Time = .zero,
    max: Time = .indefinite,

    interval_has_changed: bool = false,
    instance_lists_have_changed: bool = false,
    interval_needs_revalidation: bool = false,
    is_notifying_dependents: bool = false,

    /// The time container this element is scheduled in, and its place there.
    container: ?*TimeContainer = null,
    /// The next time this element needs an update (its key in the
    /// container's queue).
    queue_key: Time = .unresolved,
    /// Tree order among its container's timed elements: the tie-break of
    /// the animation sandwich (SMIL Animation 3.5).
    document_order_index: u32 = 0,

    pub fn init(allocator: Allocator) TimedElement {
        return .{ .allocator = allocator };
    }

    /// Detach from everything that points here, then free the lists.
    pub fn deinit(self: *TimedElement) void {
        if (self.container) |container| container.unschedule(self);
        self.disconnectSyncBases();
        for (self.dependents.items) |dependent| {
            for (dependent.sync_conditions.items) |*condition| {
                if (condition.base == self) condition.base = null;
            }
        }
        self.dependents.deinit(self.allocator);
        for (self.sync_conditions.items) |condition| self.allocator.free(condition.base_id);
        self.sync_conditions.deinit(self.allocator);
        self.begin_times.deinit(self.allocator);
        self.end_times.deinit(self.allocator);
        self.* = undefined;
    }

    // ------------------------------------------------------------------
    // The timing attributes
    // ------------------------------------------------------------------

    /// The begin or end attribute changed (`text` null: removed). Its offset
    /// values replace the previous ones; its syncbase conditions are
    /// returned to the caller to connect (`sync_conditions` gets them,
    /// unconnected); its event conditions are the caller's (`list.conditions`
    /// kept by the caller). Returns the parsed list, OWNED by the caller.
    pub fn setBeginOrEnd(self: *TimedElement, which: BeginOrEnd, text: ?[]const u8) Allocator.Error!parse.ValueList {
        var list = try parse.parseValueList(self.allocator, text, which);
        errdefer list.deinit(self.allocator);
        const times = if (which == .begin) &self.begin_times else &self.end_times;
        // Remove any previously added offset values.
        times.removeWithOrigin(.attribute);
        for (list.times.items) |time| try times.append(self.allocator, time, .attribute);
        times.sort();
        if (which == .end) {
            self.has_end_attribute_specified = list.has_values;
            self.has_end_event_conditions = list.has_event_conditions;
        }
        // The syncbase conditions of this list are replaced.
        self.disconnectSyncBasesOf(which);
        var kept: usize = 0;
        for (self.sync_conditions.items) |condition| {
            if (condition.which == which) {
                self.allocator.free(condition.base_id);
                continue;
            }
            self.sync_conditions.items[kept] = condition;
            kept += 1;
        }
        self.sync_conditions.shrinkRetainingCapacity(kept);
        for (list.conditions.items) |condition| {
            if (condition.kind != .syncbase) continue;
            const symbol: SyncBaseCondition.Symbol = if (condition.repeat != null) .repeat else if (std.mem.eql(u8, condition.name, "begin")) .begin else .end;
            const base_id = try self.allocator.dupe(u8, condition.base_id);
            errdefer self.allocator.free(base_id);
            try self.sync_conditions.append(self.allocator, .{ .which = which, .symbol = symbol, .offset = condition.offset, .repeat = condition.repeat orelse 0, .base_id = base_id });
        }
        self.instance_lists_have_changed = true;
        return list;
    }

    /// dur (SMIL Animation 3.2.1): a clock value greater than 0, or
    /// "indefinite"; anything else is ignored, which leaves the simple
    /// duration indefinite.
    pub fn setDur(self: *TimedElement, text: ?[]const u8) void {
        const value = if (text) |t| parse.parseClockValue(t) else Time.unresolved;
        self.dur = if (!value.isUnresolved() and !Time.zero.lessThan(value)) .unresolved else value;
        self.intervalStateChanged();
    }

    /// repeatDur (3.3.1): a clock value or "indefinite".
    pub fn setRepeatDur(self: *TimedElement, text: ?[]const u8) void {
        const value = if (text) |t| parse.parseClockValue(t) else Time.unresolved;
        self.repeat_dur = if (!value.isUnresolved() and !Time.zero.lessThan(value)) .unresolved else value;
        self.intervalStateChanged();
    }

    /// repeatCount (3.3.1): a number greater than 0, or "indefinite".
    pub fn setRepeatCount(self: *TimedElement, text: ?[]const u8) void {
        self.repeat_count = parseRepeatCount(text);
        self.intervalStateChanged();
    }

    /// min (3.3.3): a clock value of 0 or more; otherwise 0.
    pub fn setMin(self: *TimedElement, text: ?[]const u8) void {
        const value = if (text) |t| parse.parseClockValue(t) else Time.unresolved;
        self.min = if (value.isUnresolved() or value.lessThan(.zero)) .zero else value;
        self.intervalStateChanged();
    }

    /// max (3.3.3): a clock value greater than 0, or "indefinite";
    /// otherwise indefinite.
    pub fn setMax(self: *TimedElement, text: ?[]const u8) void {
        const value = if (text) |t| parse.parseClockValue(t) else Time.unresolved;
        self.max = if (value.isUnresolved() or !Time.zero.lessThan(value)) .indefinite else value;
        self.intervalStateChanged();
    }

    /// restart (3.3.7): "always" (the default), "whenNotActive", "never".
    pub fn setRestart(self: *TimedElement, text: ?[]const u8) void {
        const value = text orelse "";
        self.restart = if (std.mem.eql(u8, value, "never")) .never else if (std.mem.eql(u8, value, "whenNotActive")) .when_not_active else .always;
    }

    /// fill (3.3.5): "freeze", or "remove" (the default).
    pub fn setFill(self: *TimedElement, text: ?[]const u8) void {
        self.fill = if (text != null and std.mem.eql(u8, text.?, "freeze")) .freeze else .remove;
    }

    fn parseRepeatCount(text: ?[]const u8) RepeatCount {
        const value = text orelse return .unspecified;
        const trimmed = std.mem.trim(u8, value, " \t\r\n");
        if (std.mem.eql(u8, trimmed, "indefinite")) return .indefinite;
        const number = std.fmt.parseFloat(f64, trimmed) catch return .unspecified;
        if (!std.math.isFinite(number) or number <= 0) return .unspecified;
        return .{ .numeric = number };
    }

    // ------------------------------------------------------------------
    // Durations (SMIL Animation 3.3.4)
    // ------------------------------------------------------------------

    /// The simple duration: dur, or indefinite when dur is absent.
    pub fn simpleDuration(self: *const TimedElement) Time {
        return Time.min(self.dur, .indefinite);
    }

    /// The repeating duration: the simple duration as repeatCount and
    /// repeatDur extend it ("MIN(repeatCount*d, repeatDur)").
    pub fn repeatingDuration(self: *const TimedElement) Time {
        const simple = self.simpleDuration();
        if (simple.eql(.zero) or (self.repeat_dur.isUnresolved() and self.repeat_count == .unspecified)) return simple;
        const repeat_dur = Time.min(self.repeat_dur, .indefinite);
        const repeat_count_duration = simple.repeat(self.repeat_count);
        if (!repeat_count_duration.isUnresolved()) return Time.min(repeat_dur, repeat_count_duration);
        return repeat_dur;
    }

    /// The active end of an interval that begins at `begin`: the end list's
    /// next time after it and the repeating duration, bounded by min and
    /// max (3.3.3, 3.3.4). Unresolved when no end can be found ("if all
    /// ends are before the begin, bad interval").
    pub fn resolveActiveEnd(self: *const TimedElement, begin: Time) Time {
        var end: Time = .indefinite;
        if (!self.end_times.isEmpty()) {
            const next_end = self.end_times.nextAfter(begin);
            if (next_end.isUnresolved()) {
                // "Events leave the end open-ended", as does an end list
                // that only names conditions that have not happened.
                if (!(self.has_end_event_conditions or !self.has_end_attribute_specified)) return .unresolved;
            } else {
                end = next_end;
            }
        }
        var preliminary: Time = undefined;
        if (!end.isUnresolved() and self.dur.isUnresolved() and self.repeat_dur.isUnresolved() and self.repeat_count == .unspecified) {
            preliminary = end.sub(begin);
        } else if (!end.isFinite()) {
            preliminary = self.repeatingDuration();
        } else {
            preliminary = Time.min(self.repeatingDuration(), end.sub(begin));
        }
        var min_value = self.min;
        var max_value = self.max;
        // "If both min and max attributes are specified then the max value
        // must be greater than or equal to the min value. If this
        // requirement is not fulfilled then both attributes are ignored."
        if (max_value.lessThan(min_value)) {
            min_value = .zero;
            max_value = .indefinite;
        }
        return begin.add(Time.min(max_value, Time.max(min_value, preliminary)));
    }

    // ------------------------------------------------------------------
    // Intervals (SMIL Animation 3.6.8)
    // ------------------------------------------------------------------

    /// The first acceptable interval that begins at or after `begin_after`
    /// and ends after `end_after` (getFirstInterval / getNextInterval).
    /// While waiting for the first interval, an interval that already ended
    /// (but ended after the timeline's start) becomes the current one, so
    /// that it can be frozen.
    fn resolveInterval(self: *TimedElement, begin_after_in: Time, end_after: Time) Interval {
        const first = self.is_waiting_for_first_interval;
        var begin_after = begin_after_in;
        var search_start: usize = 0;
        const begins = self.begin_times.items.items;
        while (search_start < begins.len) {
            var index = search_start;
            while (index < begins.len and begins[index].time.lessThan(begin_after)) index += 1;
            // "If there is no such value", or "indefinite", which yields no
            // begin instance time.
            if (index == begins.len or begins[index].time.isIndefinite()) break;
            const begin = begins[index].time;
            const end = self.resolveActiveEnd(begin);
            if (end.isUnresolved()) break;
            const interval: Interval = .{ .begin = begin, .end = end };
            // "We have an end - is it after the parent simple begin?"
            if (end_after.lessThan(end)) return interval;
            if (first and Time.zero.lessThan(end)) {
                self.interval = interval;
                self.is_waiting_for_first_interval = false;
            }
            // Forward progress: only the rest of the begin list next time.
            search_start = index + 1;
            begin_after = end;
        }
        return .unresolved;
    }

    fn setNewInterval(self: *TimedElement, interval: Interval) void {
        self.interval = interval;
        self.notifyDependents(.{ .origin = .syncbase, .begin = interval.begin, .end = interval.end });
    }

    fn setNewIntervalEnd(self: *TimedElement, end: Time) void {
        self.interval.end = end;
        self.notifyDependents(.{ .origin = .syncbase, .begin = self.interval.begin, .end = end });
    }

    /// The end of the interval this element played last, to find the next
    /// one after it; earliest while waiting for the first.
    fn lastIntervalEndTime(self: *const TimedElement) Time {
        if (!self.is_waiting_for_first_interval) {
            if (self.interval.isResolved()) return self.interval.end;
            if (self.previous_interval.isResolved()) return self.previous_interval.end;
        }
        return .earliest;
    }

    /// An instance list changed or a duration attribute did: a current
    /// interval that has not begun is resolved again; one that is playing
    /// gets its end re-evaluated (3.6.8 "Waiting to begin the interval",
    /// "Active time - playing an interval").
    fn discardOrRevalidateCurrentInterval(self: *TimedElement, presentation_time: Time) void {
        if (!self.interval.isResolved()) return;
        if (self.interval.beginsAfter(presentation_time)) {
            self.interval = .unresolved;
            return;
        }
        if (self.interval.endsAfter(presentation_time)) {
            const new_end = self.resolveActiveEnd(self.interval.begin);
            if (new_end.isUnresolved()) {
                self.interval = .unresolved;
                if (!self.previous_interval.isResolved()) self.is_waiting_for_first_interval = true;
                return;
            }
            if (!new_end.eql(self.interval.end)) self.setNewIntervalEnd(new_end);
        }
    }

    /// "Interaction with restart semantics" case 1: while playing with
    /// restart="always", a later begin instance time before the current end
    /// ends the interval there. Whether a next interval may be looked for.
    fn handleIntervalRestart(self: *TimedElement, presentation_time: Time) bool {
        if (!self.is_waiting_for_first_interval and self.restart == .never) return false;
        if (!self.interval.isResolved() or self.interval.endsBefore(presentation_time)) return true;
        if (self.restart == .always) {
            const next_begin = self.begin_times.nextAfter(self.interval.begin);
            if (self.interval.endsAfter(next_begin)) {
                self.setNewIntervalEnd(next_begin);
                return self.interval.endsBefore(presentation_time);
            }
        }
        return false;
    }

    /// Bring the current interval up to `presentation_time`: re-evaluate it
    /// after a change, end it for a restart, and find the next one when it
    /// ended (3.6.8 "End of an interval").
    pub fn updateInterval(self: *TimedElement, presentation_time: Time) void {
        if (self.instance_lists_have_changed or self.interval_needs_revalidation) {
            self.instance_lists_have_changed = false;
            self.interval_needs_revalidation = false;
            self.discardOrRevalidateCurrentInterval(presentation_time);
        }
        if (!self.handleIntervalRestart(presentation_time)) return;
        const begin_after = self.lastIntervalEndTime();
        const next = self.resolveInterval(begin_after, presentation_time);
        if (next.eql(self.interval)) return;
        self.interval_has_changed = true;
        if (self.interval.isResolved()) self.previous_interval = self.interval;
        // No more intervals: wait for an event to give a new instance time.
        if (!next.isResolved()) {
            self.interval = next;
            return;
        }
        self.setNewInterval(next);
        self.pruneOldInstanceTimes(&self.begin_times);
        self.pruneOldInstanceTimes(&self.end_times);
    }

    /// Script-made instance times before the last interval's end can no
    /// longer begin or end anything; the lists keep at most 100 of them.
    fn pruneOldInstanceTimes(self: *TimedElement, times: *InstanceTimeList) void {
        if (self.previous_interval.isResolved()) times.removeBeforeWithOrigin(self.previous_interval.end, .script);
        while (times.items.items.len > max_instance_times) {
            var removed = false;
            for (times.items.items, 0..) |item, i| {
                if (item.origin != .script) continue;
                if (item.time.eql(self.interval.begin) or item.time.eql(self.previous_interval.begin) or item.time.eql(self.previous_interval.end)) continue;
                _ = times.items.orderedRemove(i);
                removed = true;
                break;
            }
            if (!removed) break;
        }
    }

    /// The interval whose state applies at `time`: the previous one while
    /// the current one has not begun.
    pub fn activeInterval(self: *const TimedElement, time: Time) Interval {
        if (!self.interval.isResolved()) return self.previous_interval;
        if (self.previous_interval.isResolved() and self.interval.beginsAfter(time)) return self.previous_interval;
        return self.interval;
    }

    fn determineActiveState(self: *const TimedElement, interval: Interval, time: Time) ActiveState {
        if (interval.contains(time)) return .active;
        if (self.is_waiting_for_first_interval) return .inactive;
        return if (self.fill == .freeze) .frozen else .inactive;
    }

    /// Whether the animation applies its effect at `time` (SMIL Animation
    /// 3.3.5): while active - past the repeating duration only when frozen
    /// - and while frozen.
    pub fn isContributing(self: *const TimedElement, time: Time) bool {
        return (self.active_state == .active and
            (self.fill == .freeze or !self.interval.begin.add(self.repeatingDuration()).lessThan(time))) or
            self.active_state == .frozen;
    }

    /// The active state at `time`, and the events the change owes.
    pub fn updateActiveState(self: *TimedElement, time: Time, skip_repeat: bool) Events {
        const was_active = self.active_state == .active;
        self.active_state = self.determineActiveState(self.interval, time);
        const is_active = self.active_state == .active;
        const interval_restart = self.interval_has_changed and self.previous_interval.end.eql(self.interval.begin);
        self.interval_has_changed = false;
        var events: Events = .{};
        if ((was_active and !is_active) or interval_restart) events.end = true;
        if (self.isContributing(time)) {
            if ((!was_active and is_active) or interval_restart) {
                events.begin = true;
                self.is_waiting_for_first_interval = false;
            }
            if (!skip_repeat) {
                const progress = self.calculateProgress(time);
                if (progress.repeat != 0 and progress.repeat != self.last_progress.repeat) {
                    self.notifyDependents(.{ .origin = .repeat, .repeat = progress.repeat, .begin = time, .end = .unresolved });
                    events.repeat = true;
                }
                self.last_progress = progress;
            }
        }
        return events;
    }

    /// After a seek: the events that say how the element's state at the new
    /// time differs from `starting` (the interval active before it).
    pub fn computeSeekEvents(self: *const TimedElement, starting: Interval) Events {
        if (self.active_state != .active) {
            if (!starting.isResolved()) return .{};
            return .{ .end = true };
        }
        if (starting.isResolved()) {
            if (self.interval.eql(starting)) return .{};
            return .{ .end = true, .begin = true };
        }
        return .{ .begin = true };
    }

    /// The simple time at `time`: the fraction of the simple duration and
    /// the iteration - frozen at the active end's value past it (3.3.5).
    pub fn calculateProgress(self: *const TimedElement, time: Time) Progress {
        const simple = self.simpleDuration();
        if (simple.isIndefinite()) return .{ .fraction = 0, .repeat = 0 };
        if (simple.eql(.zero)) return .{ .fraction = 1, .repeat = 0 };
        const interval = self.activeInterval(time);
        const active_time = time.sub(interval.begin);
        const repeating = self.repeatingDuration();
        var repeat: i64 = undefined;
        var simple_time: Time = undefined;
        if (!time.lessThan(interval.end) or repeating.lessThan(active_time)) {
            const last_active = if (!time.lessThan(interval.end)) interval.end.sub(interval.begin) else repeating;
            if (!last_active.isFinite()) return .{ .fraction = 0, .repeat = 0 };
            repeat = last_active.intDiv(simple);
            simple_time = last_active.rem(simple);
            if (!simple_time.eql(.zero)) {
                simple_time = simple_time.sub(.epsilon);
            } else {
                simple_time = simple;
                repeat -= 1;
            }
        } else {
            repeat = active_time.intDiv(simple);
            simple_time = active_time.rem(simple);
        }
        const fraction: f32 = @floatCast(@as(f64, @floatFromInt(simple_time.us)) / @as(f64, @floatFromInt(simple.us)));
        return .{ .fraction = std.math.clamp(fraction, 0, 1), .repeat = std.math.cast(u32, @max(repeat, 0)) orelse std.math.maxInt(u32) };
    }

    /// The next time this element's state can change after `time`: its
    /// interval's begin or end, a repeat boundary, or a later begin
    /// instance time.
    pub fn computeNextIntervalTime(self: *const TimedElement, time: Time, repeats: IncludeRepeats) Time {
        var next: Time = .unresolved;
        if (self.interval.beginsAfter(time)) {
            next = self.interval.begin;
        } else if (self.interval.endsAfter(time)) {
            const simple = self.simpleDuration();
            if (repeats == .include and simple.isFinite() and !simple.eql(.zero)) {
                const into = time.sub(self.interval.begin);
                const next_repeat = time.add(simple.sub(into.rem(simple)));
                next = Time.min(next_repeat, self.interval.end);
            } else {
                next = self.interval.end;
            }
        }
        const next_begin = self.begin_times.nextAfter(time);
        if (next_begin.isFinite()) next = Time.min(next, next_begin);
        return next;
    }

    /// The animation's begin for the sandwich's priority (3.5: "animations
    /// that begin later have higher priority"): a frozen animation whose
    /// next interval has not begun still ranks by the one it froze.
    pub fn beginTimeForPrioritization(self: *const TimedElement, time: Time) Time {
        if (self.active_state == .frozen and self.interval.beginsAfter(time)) return self.previous_interval.begin;
        return self.interval.begin;
    }

    pub fn isHigherPriorityThan(self: *const TimedElement, other: *const TimedElement, time: Time) bool {
        const a = self.beginTimeForPrioritization(time);
        const b = other.beginTimeForPrioritization(time);
        if (a.eql(b)) return self.document_order_index > other.document_order_index;
        return b.lessThan(a);
    }

    /// Back to the state before the timeline began (a seek backwards).
    pub fn reset(self: *TimedElement) void {
        self.active_state = .inactive;
        self.is_waiting_for_first_interval = true;
        self.interval = .unresolved;
        self.previous_interval = .unresolved;
        self.last_progress = .{};
    }

    // ------------------------------------------------------------------
    // Instance times from outside: DOM methods, events, syncbases
    // ------------------------------------------------------------------

    fn addInstanceTime(self: *TimedElement, which: BeginOrEnd, time: Time, origin: Origin) Allocator.Error!void {
        const list = if (which == .begin) &self.begin_times else &self.end_times;
        try list.insertSortedAndUnique(self.allocator, time, origin);
        self.instance_lists_have_changed = true;
    }

    /// A new instance time from a DOM method call (beginElementAt,
    /// endElementAt) or an event: added, and the element updated at once.
    /// An end time from script while the element is inactive is ignored
    /// (Blink AddInstanceTimeAndUpdate: endElement() on an element that has
    /// not begun ends nothing).
    pub fn addInstanceTimeAndUpdate(self: *TimedElement, which: BeginOrEnd, time: Time, origin: Origin) Allocator.Error!void {
        if (which == .end and self.active_state == .inactive and origin == .script) return;
        try self.addInstanceTime(which, time, origin);
        self.instanceListChanged();
    }

    /// The instance lists changed: update the interval now, and have the
    /// container's next update raise the events.
    fn instanceListChanged(self: *TimedElement) void {
        const current = if (self.container) |container| container.latest_update_time else Time.zero;
        const was_active = self.active_state == .active;
        self.updateInterval(current);
        // The state just before the current time, so that the next update
        // sees the transition and raises its events.
        const previous_time = current.sub(.epsilon);
        if (was_active) {
            const interval = self.activeInterval(previous_time);
            self.active_state = self.determineActiveState(interval, previous_time);
        }
        if (self.container) |container| {
            const next = if (self.previous_interval.isResolved() and self.previous_interval.endsAfter(previous_time))
                self.previous_interval.end
            else
                self.computeNextIntervalTime(previous_time, .include);
            container.reschedule(self, next);
        }
    }

    /// The begin or end attribute changed (`setBeginOrEnd`): the interval is
    /// re-evaluated now, on a timeline (Blink ParseAttribute's
    /// InstanceListChanged).
    pub fn instanceListsChanged(self: *TimedElement) void {
        if (self.container == null) return;
        self.instance_lists_have_changed = true;
        self.instanceListChanged();
    }

    /// A duration attribute changed: the container re-evaluates the interval
    /// at its next update.
    fn intervalStateChanged(self: *TimedElement) void {
        const container = self.container orelse return;
        container.reschedule(self, .earliest);
        self.interval_needs_revalidation = true;
    }

    /// The element was scheduled in a time container: bring it up to the
    /// container's latest update. Whether it is active then (a begin event
    /// is owed once the timeline has started).
    pub fn addedToTimeContainer(self: *TimedElement) bool {
        const container = self.container orelse return false;
        const current = container.latest_update_time;
        self.updateInterval(current);
        const previous_time = current.sub(.epsilon);
        self.active_state = self.determineActiveState(self.interval, previous_time);
        container.reschedule(self, self.computeNextIntervalTime(previous_time, .include));
        if (self.active_state != .inactive) self.is_waiting_for_first_interval = false;
        return self.active_state == .active and container.started;
    }

    /// What a notice to dependents carries (3.6.8: a new interval, or a
    /// repeat).
    pub const Notice = struct {
        origin: Origin,
        repeat: u32 = 0,
        /// The interval's begin, or the repeat's time.
        begin: Time,
        end: Time,
    };

    fn notifyDependents(self: *TimedElement, notice: Notice) void {
        // Notices that come round to this element again are dropped ("When
        // a cycle is detected, the change propagation is ignored").
        if (self.is_notifying_dependents) return;
        self.is_notifying_dependents = true;
        defer self.is_notifying_dependents = false;
        for (self.dependents.items) |dependent| dependent.createInstanceTimesFromSyncBase(self, notice);
    }

    /// A syncbase this element depends on got a new interval or repeated:
    /// an instance time for each condition that names it.
    fn createInstanceTimesFromSyncBase(self: *TimedElement, base: *TimedElement, notice: Notice) void {
        var added = false;
        for (self.sync_conditions.items) |condition| {
            if (condition.base != base) continue;
            var time: Time = .unresolved;
            if (notice.origin == .syncbase) {
                time = switch (condition.symbol) {
                    .begin => notice.begin.add(condition.offset),
                    .end => notice.end.add(condition.offset),
                    .repeat => .unresolved,
                };
            } else {
                if (condition.symbol != .repeat or notice.repeat != condition.repeat) continue;
                time = notice.begin.add(condition.offset);
            }
            if (!time.isFinite()) continue;
            self.addInstanceTime(condition.which, time, notice.origin) catch continue;
            added = true;
        }
        if (!added or self.is_notifying_dependents) return;
        self.instanceListChanged();
    }

    /// Connect the syncbase condition at `index` to `base`, the timed
    /// element its id names (null: none), as it changed.
    pub fn connectSyncBase(self: *TimedElement, index: usize, base: ?*TimedElement) Allocator.Error!void {
        const condition = &self.sync_conditions.items[index];
        if (condition.base == base) return;
        if (condition.base != null) self.disconnectSyncBaseAt(index);
        const target = base orelse return;
        if (target == self) return;
        condition.base = target;
        if (std.mem.indexOfScalar(*TimedElement, target.dependents.items, self) == null) try target.dependents.append(target.allocator, self);
        // A syncbase with a current interval gives its time at once.
        if (target.interval.isResolved()) self.createInstanceTimesFromSyncBase(target, .{ .origin = .syncbase, .begin = target.interval.begin, .end = target.interval.end });
    }

    fn disconnectSyncBaseAt(self: *TimedElement, index: usize) void {
        const base = self.sync_conditions.items[index].base orelse return;
        self.sync_conditions.items[index].base = null;
        // Still a dependent through another condition?
        for (self.sync_conditions.items) |condition| if (condition.base == base) return;
        if (std.mem.indexOfScalar(*TimedElement, base.dependents.items, self)) |i| _ = base.dependents.swapRemove(i);
    }

    fn disconnectSyncBasesOf(self: *TimedElement, which: BeginOrEnd) void {
        for (self.sync_conditions.items, 0..) |condition, i| {
            if (condition.which == which) self.disconnectSyncBaseAt(i);
        }
    }

    pub fn disconnectSyncBases(self: *TimedElement) void {
        for (0..self.sync_conditions.items.len) |i| self.disconnectSyncBaseAt(i);
    }

    /// The current presentation time of this element's timeline (0 when it
    /// is in none, or its timeline has not begun).
    pub fn elapsed(self: *const TimedElement, now: Time) Time {
        const container = self.container orelse return .zero;
        return container.elapsed(now);
    }
};
