//! The timeline of an SVG document fragment: SVG Animations 2 4.1 ("The
//! outermost svg element of an SVG document fragment defines a timeline")
//! and 5.8 (pauseAnimations, unpauseAnimations, animationsPaused,
//! getCurrentTime, setCurrentTime), and the update that moves every timed
//! element of the fragment along it (SMIL Animation 3.6.8).
//!
//! The update is Blink's SMILTimeContainer (UpdateIntervals,
//! UpdateTimedElements, PrepareSeek, Elapsed, SetElapsed, Pause, Unpause;
//! core/svg/animation/smil_time_container.cc, read 2026-11-20; BSD-2, Apple
//! 2008), reproduced: elements are visited in the order their next interval
//! times come due, time advancing to each in turn, so that a syncbase's new
//! interval reaches its dependents before they are visited at that time. A
//! seek moves time without repeats and reports, at the end, how each element
//! changed (begin and end events, no repeat events).
//!
//! The fragment's time runs on its document's timeline (Web Animations 4.3:
//! the document's animation time, `now` in every call): a started, unpaused
//! timeline's time is `presentation_time + (now - reference_time)`.
//!
//! Plain data: the elements are borrowed, each detaching itself before it
//! goes (TimedElement.deinit), and `deinit` detaches the ones still here.
const std = @import("std");
const time_mod = @import("time.zig");
const timed = @import("timed_element.zig");

const Time = time_mod.Time;
const Interval = time_mod.Interval;
const TimedElement = timed.TimedElement;
const Events = timed.Events;
const Allocator = std.mem.Allocator;

/// The events an update owes one element.
pub const Dispatch = struct {
    element: *TimedElement,
    events: Events,
    /// The iteration a repeat event reports.
    repeat: u32,
};

pub const TimeContainer = struct {
    allocator: Allocator,
    elements: std.ArrayListUnmanaged(*TimedElement) = .empty,
    /// The time at the latest restart of the timeline (a start, seek or
    /// unpause); 0 until one.
    presentation_time: Time = .zero,
    /// The document timeline time `presentation_time` was taken at.
    reference_time: Time = .zero,
    /// The time every element was last updated to.
    latest_update_time: Time = .zero,
    started: bool = false,
    paused: bool = false,
    is_updating_intervals: bool = false,
    /// An element's schedule changed outside an update: the next frame
    /// must update the container.
    needs_update: bool = false,
    /// Tree order needs re-numbering before the sandwich next reads it.
    document_order_dirty: bool = true,
    /// The events the updates since the last `takeDispatches` owe.
    dispatches: std.ArrayListUnmanaged(Dispatch) = .empty,

    /// "We can't seek beyond this time".
    pub const max_presentation_time: Time = .{ .us = Time.latest.us - 1 };

    pub fn init(allocator: Allocator) TimeContainer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TimeContainer) void {
        for (self.elements.items) |element| element.container = null;
        self.elements.deinit(self.allocator);
        self.dispatches.deinit(self.allocator);
        self.* = undefined;
    }

    // ------------------------------------------------------------------
    // The timeline (SVG Animations 2 5.8)
    // ------------------------------------------------------------------

    /// The fragment's current time, given the document timeline's `now`:
    /// 0 before the timeline began, the paused time while paused.
    pub fn elapsed(self: *const TimeContainer, now: Time) Time {
        if (!self.started) return .zero;
        if (self.paused) return self.presentation_time;
        const offset = Time.max(now.sub(self.reference_time), .zero);
        return Time.min(self.presentation_time.add(offset), max_presentation_time);
    }

    /// The timeline begins (the document's load, or the fragment's
    /// insertion into a loaded document): elements are brought to the
    /// presentation time - 0, or what setCurrentTime() recorded before.
    pub fn start(self: *TimeContainer, now: Time) void {
        if (self.started) return;
        self.reference_time = now;
        self.started = true;
        // A seek from nothing: no element was playing before (Blink's
        // Start runs the seek update without PrepareSeek).
        self.update(self.presentation_time, .start);
    }

    pub fn pause(self: *TimeContainer, now: Time) void {
        if (self.paused) return;
        if (self.started) self.presentation_time = self.elapsed(now);
        self.paused = true;
    }

    pub fn unpause(self: *TimeContainer, now: Time) void {
        if (!self.paused) return;
        self.paused = false;
        if (!self.started) return;
        self.reference_time = now;
        self.needs_update = true;
    }

    /// setCurrentTime(seconds) steps 2-3: seek a timeline that began; record
    /// the time to seek to for one that has not.
    pub fn setElapsed(self: *TimeContainer, now: Time, time: Time) void {
        self.presentation_time = Time.min(time, max_presentation_time);
        if (!self.started) return;
        if (!self.paused) self.reference_time = now;
        self.update(self.presentation_time, .seek);
    }

    // ------------------------------------------------------------------
    // Scheduling
    // ------------------------------------------------------------------

    /// Schedule `element` (`now`: the document timeline's time).
    pub fn schedule(self: *TimeContainer, element: *TimedElement, now: Time) Allocator.Error!void {
        std.debug.assert(element.container == null);
        // The first element of a running timeline need not catch up on the
        // time before it came.
        if (self.elements.items.len == 0 and self.started) self.latest_update_time = self.elapsed(now);
        try self.elements.append(self.allocator, element);
        element.container = self;
        element.queue_key = .unresolved;
        self.document_order_dirty = true;
    }

    pub fn unschedule(self: *TimeContainer, element: *TimedElement) void {
        if (std.mem.indexOfScalar(*TimedElement, self.elements.items, element)) |i| _ = self.elements.orderedRemove(i);
        var kept: usize = 0;
        for (self.dispatches.items) |dispatch| {
            if (dispatch.element == element) continue;
            self.dispatches.items[kept] = dispatch;
            kept += 1;
        }
        self.dispatches.shrinkRetainingCapacity(kept);
        element.container = null;
    }

    /// `element`'s next interval time is now `key`. Outside an update, the
    /// next frame updates the container.
    pub fn reschedule(self: *TimeContainer, element: *TimedElement, key: Time) void {
        element.queue_key = key;
        if (self.is_updating_intervals or !self.started) return;
        self.needs_update = true;
    }

    /// The earliest next interval time of any element.
    pub fn nextTime(self: *const TimeContainer) Time {
        var next: Time = .unresolved;
        for (self.elements.items) |element| next = Time.min(next, element.queue_key);
        return next;
    }

    fn minElement(self: *const TimeContainer) ?*TimedElement {
        var best: ?*TimedElement = null;
        for (self.elements.items) |element| {
            if (best == null or element.queue_key.lessThan(best.?.queue_key)) best = element;
        }
        return best;
    }

    // ------------------------------------------------------------------
    // The update
    // ------------------------------------------------------------------

    pub const Policy = enum {
        normal,
        seek,
        /// The timeline's start: a seek from a timeline nothing played on.
        start,
    };

    /// Bring every element to `target` (`.normal`: time runs, every event
    /// raised; `.seek`: time jumps, no repeats, and only the net change of
    /// each element raises events; `.start`: a seek with nothing playing
    /// before it).
    pub fn update(self: *TimeContainer, target_in: Time, requested: Policy) void {
        const target = Time.min(target_in, max_presentation_time);
        const prepare = requested == .seek;
        const policy: Policy = if (requested == .start) .seek else requested;
        self.needs_update = false;
        if (self.elements.items.len == 0) {
            self.latest_update_time = target;
            return;
        }
        // A seek: which elements are active now, to compare with after.
        var seek_starts: std.ArrayListUnmanaged(struct { element: *TimedElement, interval: Interval }) = .empty;
        defer seek_starts.deinit(self.allocator);
        if (prepare) {
            for (self.elements.items) |element| {
                const interval = element.activeInterval(self.latest_update_time);
                if (!interval.contains(self.latest_update_time)) continue;
                seek_starts.append(self.allocator, .{ .element = element, .interval = interval }) catch {};
            }
            // Rewinding: start again from 0 and move forward.
            if (target.lessThan(self.latest_update_time)) {
                for (self.elements.items) |element| {
                    element.reset();
                    element.queue_key = .earliest;
                }
                self.latest_update_time = .zero;
            }
        }
        var updated: std.ArrayListUnmanaged(*TimedElement) = .empty;
        defer updated.deinit(self.allocator);
        // "Flush any late interval updates", then advance to each next
        // interval time in turn.
        self.updateIntervals(policy, &updated);
        while (true) {
            const next = self.nextTime();
            if (!self.latest_update_time.lessThan(target)) break;
            if (target.lessThan(next)) {
                self.latest_update_time = target;
                break;
            }
            self.latest_update_time = next;
            self.updateIntervals(policy, &updated);
        }
        self.updateIntervals(policy, &updated);
        if (policy == .seek) {
            // Every element the seek touched - active before it, or visited
            // during it - gets its next interval time again, repeats
            // included this time, and the events of its net change.
            for (seek_starts.items) |entry| {
                if (std.mem.indexOfScalar(*TimedElement, updated.items, entry.element) == null) updated.append(self.allocator, entry.element) catch {};
            }
            for (updated.items) |element| {
                element.queue_key = element.computeNextIntervalTime(target, .include);
                var starting: Interval = .unresolved;
                for (seek_starts.items) |entry| if (entry.element == element) {
                    starting = entry.interval;
                };
                const events = element.computeSeekEvents(starting);
                if (!events.isEmpty()) self.dispatches.append(self.allocator, .{ .element = element, .events = events, .repeat = 0 }) catch {};
            }
        }
    }

    /// Update every element whose next interval time has come, at the
    /// latest update time, until none is left.
    fn updateIntervals(self: *TimeContainer, policy: Policy, updated: *std.ArrayListUnmanaged(*TimedElement)) void {
        const time = self.latest_update_time;
        self.is_updating_intervals = true;
        defer self.is_updating_intervals = false;
        const repeats: timed.IncludeRepeats = if (policy == .seek) .exclude else .include;
        var guard: usize = 0;
        const limit = @max(self.elements.items.len * 16, 1_000_000);
        while (self.minElement()) |element| {
            if (time.lessThan(element.queue_key)) break;
            element.updateInterval(time);
            const events = element.updateActiveState(time, policy == .seek);
            if (policy == .seek) {
                if (std.mem.indexOfScalar(*TimedElement, updated.items, element) == null) updated.append(self.allocator, element) catch {};
            } else if (!events.isEmpty()) {
                self.dispatches.append(self.allocator, .{ .element = element, .events = events, .repeat = element.last_progress.repeat }) catch {};
            }
            element.queue_key = element.computeNextIntervalTime(time, repeats);
            guard += 1;
            // A timegraph that never settles (a closed cycle the propagation
            // did not break) stops here rather than spinning.
            if (guard >= limit) break;
        }
    }

    /// The events owed since the last call, OWNED by the caller.
    pub fn takeDispatches(self: *TimeContainer) Allocator.Error![]Dispatch {
        return self.dispatches.toOwnedSlice(self.allocator);
    }
};
