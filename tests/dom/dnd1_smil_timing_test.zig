//! Lane dnd1: the SMIL timing model for SVG animation elements
//! (dom.smil): clock values and begin/end lists (SMIL Animation 3.6.7),
//! intervals, active states and TimeEvents (3.6.8), repeats (3.3.1),
//! min/max (3.3.3), freezing (3.3.5), restart (3.3.7), syncbases (3.6.6),
//! DOM begin/end methods (SVG Animations 2 5.2) and seeking (5.8).
const std = @import("std");
const dom = @import("dom");
const testing = std.testing;
const smil = dom.smil;
const Time = smil.Time;
const TimedElement = smil.TimedElement;
const TimeContainer = smil.TimeContainer;

fn secs(s: f64) Time {
    return Time.fromSeconds(s);
}

test "clock values: full, partial and timecount forms (SMIL Animation 3.6.7)" {
    const parse = smil.parse.parseClockValue;
    try testing.expectEqual(secs(9003).us, parse("02:30:03").us);
    try testing.expectEqual(secs(50 * 3600 + 10.25).us, parse("50:00:10.25").us);
    try testing.expectEqual(secs(153).us, parse("02:33").us);
    try testing.expectEqual(secs(10.5).us, parse("00:10.5").us);
    try testing.expectEqual(secs(3.2 * 3600).us, parse("3.2h").us);
    try testing.expectEqual(secs(45 * 60).us, parse("45min").us);
    try testing.expectEqual(secs(30).us, parse("30s").us);
    try testing.expectEqual(secs(0.005).us, parse("5ms").us);
    try testing.expectEqual(secs(12.467).us, parse(" 12.467 ").us);
    try testing.expectEqual(secs(0.5).us, parse("00.5s").us);
    try testing.expectEqual(secs(0.005).us, parse("00:00.005").us);
    try testing.expect(parse("indefinite").isIndefinite());
    for ([_][]const u8{ "", "abc", "1:2", "00:60", "60:00", "00:5", "00:05.", "1 s", "s", "1.2.3", "02:30:3" }) |bad| {
        if (!parse(bad).isUnresolved()) {
            std.debug.print("expected unresolved for '{s}'\n", .{bad});
            return error.TestUnexpectedResult;
        }
    }
}

test "begin and end lists: offsets, default begin, conditions" {
    const allocator = testing.allocator;
    {
        var list = try smil.parse.parseValueList(allocator, null, .begin);
        defer list.deinit(allocator);
        try testing.expectEqual(@as(usize, 1), list.times.items.len);
        try testing.expect(list.times.items[0].eql(.zero));
    }
    {
        // An empty begin attribute is not the default: no instance time.
        var list = try smil.parse.parseValueList(allocator, "", .begin);
        defer list.deinit(allocator);
        try testing.expectEqual(@as(usize, 0), list.times.items.len);
    }
    {
        var list = try smil.parse.parseValueList(allocator, "2s; 1s ;-1s; foo.click+1.5s; bar.end - 2s; baz.repeat(3); click; accessKey(a); wallclock(08:00); bogus.begin+x", .begin);
        defer list.deinit(allocator);
        try testing.expectEqual(@as(usize, 3), list.times.items.len);
        try testing.expectEqual(secs(-1).us, list.times.items[0].us);
        try testing.expectEqual(secs(1).us, list.times.items[1].us);
        try testing.expectEqual(secs(2).us, list.times.items[2].us);
        const conditions = list.conditions.items;
        try testing.expectEqual(@as(usize, 6), conditions.len);
        try testing.expectEqual(smil.parse.Condition.Kind.event, conditions[0].kind);
        try testing.expectEqualStrings("foo", conditions[0].base_id);
        try testing.expectEqualStrings("click", conditions[0].name);
        try testing.expectEqual(secs(1.5).us, conditions[0].offset.us);
        try testing.expectEqual(smil.parse.Condition.Kind.syncbase, conditions[1].kind);
        try testing.expectEqualStrings("bar", conditions[1].base_id);
        try testing.expectEqualStrings("end", conditions[1].name);
        try testing.expectEqual(secs(-2).us, conditions[1].offset.us);
        try testing.expectEqual(smil.parse.Condition.Kind.syncbase, conditions[2].kind);
        try testing.expectEqual(@as(?u32, 3), conditions[2].repeat);
        try testing.expectEqual(smil.parse.Condition.Kind.event, conditions[3].kind);
        try testing.expectEqualStrings("", conditions[3].base_id);
        try testing.expectEqual(smil.parse.Condition.Kind.never, conditions[4].kind);
        try testing.expectEqual(smil.parse.Condition.Kind.never, conditions[5].kind);
    }
    {
        // An escaped dot is part of the id.
        var list = try smil.parse.parseValueList(allocator, "a\\.b.begin", .end);
        defer list.deinit(allocator);
        try testing.expectEqualStrings("a.b", list.conditions.items[0].base_id);
        try testing.expect(list.has_values);
        try testing.expect(!list.has_event_conditions);
    }
    {
        var list = try smil.parse.parseValueList(allocator, "indefinite", .end);
        defer list.deinit(allocator);
        try testing.expect(list.times.items[0].isIndefinite());
    }
}

/// One animation element on one timeline, driven by hand.
const Fixture = struct {
    container: TimeContainer,
    element: TimedElement,

    fn init(self: *Fixture, begin: ?[]const u8, end: ?[]const u8) !void {
        self.container = TimeContainer.init(testing.allocator);
        self.element = TimedElement.init(testing.allocator);
        var b = try self.element.setBeginOrEnd(.begin, begin);
        b.deinit(testing.allocator);
        var e = try self.element.setBeginOrEnd(.end, end);
        e.deinit(testing.allocator);
    }

    fn deinit(self: *Fixture) void {
        self.element.deinit();
        self.container.deinit();
    }

    fn start(self: *Fixture) !void {
        try self.container.schedule(&self.element, .zero);
        _ = self.element.addedToTimeContainer();
        self.container.start(.zero);
    }

    /// Run the timeline to `at` seconds; the events it raised, in order.
    fn runTo(self: *Fixture, at: f64) ![]smil.time_container.Dispatch {
        self.container.update(self.container.elapsed(secs(at)), .normal);
        return self.container.takeDispatches();
    }
};

fn expectEvents(dispatches: []const smil.time_container.Dispatch, begin: bool, end: bool, repeat: bool) !void {
    var b = false;
    var e = false;
    var r = false;
    for (dispatches) |d| {
        b = b or d.events.begin;
        e = e or d.events.end;
        r = r or d.events.repeat;
    }
    try testing.expectEqual(begin, b);
    try testing.expectEqual(end, e);
    try testing.expectEqual(repeat, r);
}

test "begin=0 with no dur: active from the timeline's start, never ending (a <set>)" {
    var f: Fixture = undefined;
    try f.init(null, null);
    defer f.deinit();
    try f.start();
    // Starting the timeline is a seek to 0: the begin event, no other.
    const at_start = try f.container.takeDispatches();
    defer testing.allocator.free(at_start);
    try expectEvents(at_start, true, false, false);
    try testing.expectEqual(smil.timed_element.ActiveState.active, f.element.active_state);
    try testing.expect(f.element.simpleDuration().isIndefinite());
    const later = try f.runTo(100);
    defer testing.allocator.free(later);
    try expectEvents(later, false, false, false);
    try testing.expect(f.element.isContributing(secs(100)));
}

test "an element inserted into a running timeline begins at the next update" {
    var f: Fixture = undefined;
    f.container = TimeContainer.init(testing.allocator);
    f.element = TimedElement.init(testing.allocator);
    defer f.deinit();
    var b = try f.element.setBeginOrEnd(.begin, "0s");
    b.deinit(testing.allocator);
    var e = try f.element.setBeginOrEnd(.end, null);
    e.deinit(testing.allocator);
    f.container.start(secs(5));
    try f.container.schedule(&f.element, secs(5));
    // Not active "just before" the latest update: the next update raises
    // the begin.
    try testing.expect(!f.element.addedToTimeContainer());
    try testing.expect(f.container.needs_update);
    const events = try f.runTo(5.01);
    defer testing.allocator.free(events);
    try expectEvents(events, true, false, false);
}

test "dur ends the interval; fill=freeze keeps contributing, fill=remove stops" {
    for ([_]bool{ true, false }) |freeze| {
        var f: Fixture = undefined;
        try f.init("1s", null);
        defer f.deinit();
        f.element.setDur("2s");
        if (freeze) f.element.setFill("freeze");
        try f.start();
        testing.allocator.free(try f.container.takeDispatches());
        const before = try f.runTo(0.5);
        defer testing.allocator.free(before);
        try expectEvents(before, false, false, false);
        const began = try f.runTo(1.5);
        defer testing.allocator.free(began);
        try expectEvents(began, true, false, false);
        try testing.expectEqual(@as(f32, 0.25), f.element.calculateProgress(secs(1.5)).fraction);
        const ended = try f.runTo(3.5);
        defer testing.allocator.free(ended);
        try expectEvents(ended, false, true, false);
        try testing.expectEqual(freeze, f.element.isContributing(secs(3.5)));
        try testing.expectEqual(if (freeze) smil.timed_element.ActiveState.frozen else .inactive, f.element.active_state);
    }
}

test "repeatCount: a repeat event per new iteration, numbered from 1" {
    var f: Fixture = undefined;
    try f.init(null, null);
    defer f.deinit();
    f.element.setDur("1s");
    f.element.setRepeatCount("3");
    try f.start();
    testing.allocator.free(try f.container.takeDispatches());
    try testing.expectEqual(secs(3).us, f.element.interval.end.us);
    const first = try f.runTo(1.2);
    defer testing.allocator.free(first);
    try expectEvents(first, false, false, true);
    try testing.expectEqual(@as(u32, 1), first[first.len - 1].repeat);
    const second = try f.runTo(2.2);
    defer testing.allocator.free(second);
    try testing.expectEqual(@as(u32, 2), second[second.len - 1].repeat);
    const ended = try f.runTo(3.1);
    defer testing.allocator.free(ended);
    try expectEvents(ended, false, true, false);
}

test "min and max bound the active duration (SMIL Animation 3.3.3)" {
    var f: Fixture = undefined;
    try f.init(null, null);
    defer f.deinit();
    f.element.setDur("1s");
    f.element.setMax("0.5s");
    try testing.expectEqual(secs(0.5).us, f.element.resolveActiveEnd(.zero).us);
    f.element.setMax(null);
    f.element.setMin("3s");
    try testing.expectEqual(secs(3).us, f.element.resolveActiveEnd(.zero).us);
    // max < min: both ignored.
    f.element.setMax("2s");
    try testing.expectEqual(secs(1).us, f.element.resolveActiveEnd(.zero).us);
}

test "end list: the first end after the begin; all ends before it: no interval" {
    var f: Fixture = undefined;
    try f.init("2s", "1s; 4s");
    defer f.deinit();
    try testing.expectEqual(secs(4).us, f.element.resolveActiveEnd(secs(2)).us);
    var e = try f.element.setBeginOrEnd(.end, "1s");
    e.deinit(testing.allocator);
    try testing.expect(f.element.resolveActiveEnd(secs(2)).isUnresolved());
    // An event condition leaves the end open.
    var e2 = try f.element.setBeginOrEnd(.end, "1s; click");
    e2.deinit(testing.allocator);
    try testing.expect(f.element.resolveActiveEnd(secs(2)).isIndefinite());
}

test "restart=always: a later begin ends the interval there and begins again" {
    var f: Fixture = undefined;
    try f.init("0s; 1s", null);
    defer f.deinit();
    f.element.setDur("2s");
    try f.start();
    testing.allocator.free(try f.container.takeDispatches());
    try testing.expectEqual(secs(1).us, f.element.interval.end.us);
    const restarted = try f.runTo(1.5);
    defer testing.allocator.free(restarted);
    try expectEvents(restarted, true, true, false);
    try testing.expectEqual(secs(1).us, f.element.interval.begin.us);
    try testing.expectEqual(secs(3).us, f.element.interval.end.us);
}

test "restart=never: the element plays once" {
    var f: Fixture = undefined;
    try f.init("0s; 1s", null);
    defer f.deinit();
    f.element.setDur("0.5s");
    f.element.setRestart("never");
    try f.start();
    testing.allocator.free(try f.container.takeDispatches());
    const later = try f.runTo(2);
    defer testing.allocator.free(later);
    try expectEvents(later, false, true, false);
    try testing.expectEqual(smil.timed_element.ActiveState.inactive, f.element.active_state);
}

test "beginElementAt and endElementAt: script instance times" {
    var f: Fixture = undefined;
    try f.init("indefinite", null);
    defer f.deinit();
    try f.start();
    testing.allocator.free(try f.container.takeDispatches());
    try testing.expect(!f.element.interval.isResolved());
    // endElement() on an element that has not begun does nothing.
    try f.element.addInstanceTimeAndUpdate(.end, secs(0.5), .script);
    try testing.expect(f.element.end_times.isEmpty());
    // beginElementAt(1) at 0.5.
    const now_before = try f.runTo(0.5);
    testing.allocator.free(now_before);
    try f.element.addInstanceTimeAndUpdate(.begin, f.element.elapsed(secs(0.5)).add(secs(1)), .script);
    try testing.expectEqual(secs(1.5).us, f.element.interval.begin.us);
    const began = try f.runTo(1.6);
    defer testing.allocator.free(began);
    try expectEvents(began, true, false, false);
    try f.element.addInstanceTimeAndUpdate(.end, f.element.elapsed(secs(1.6)), .script);
    const ended = try f.runTo(1.7);
    defer testing.allocator.free(ended);
    try expectEvents(ended, false, true, false);
}

test "syncbase: B begins when A's interval ends, and moves with it" {
    var container = TimeContainer.init(testing.allocator);
    defer container.deinit();
    var a = TimedElement.init(testing.allocator);
    defer a.deinit();
    var b = TimedElement.init(testing.allocator);
    defer b.deinit();
    var la = try a.setBeginOrEnd(.begin, "1s");
    la.deinit(testing.allocator);
    a.setDur("2s");
    var lb = try b.setBeginOrEnd(.begin, "a.end+0.5s");
    lb.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), b.sync_conditions.items.len);
    try container.schedule(&a, .zero);
    try container.schedule(&b, .zero);
    try b.connectSyncBase(0, &a);
    _ = a.addedToTimeContainer();
    _ = b.addedToTimeContainer();
    container.start(.zero);
    testing.allocator.free(try container.takeDispatches());
    try testing.expectEqual(secs(3.5).us, b.interval.begin.us);
    container.update(container.elapsed(secs(3.6)), .normal);
    const events = try container.takeDispatches();
    defer testing.allocator.free(events);
    var b_began = false;
    for (events) |d| if (d.element == &b and d.events.begin) {
        b_began = true;
    };
    try testing.expect(b_began);
}

test "a seek raises the net change only, and rewinding starts again from 0" {
    var f: Fixture = undefined;
    try f.init("1s", null);
    defer f.deinit();
    f.element.setDur("1s");
    f.element.setRepeatCount("5");
    try f.start();
    testing.allocator.free(try f.container.takeDispatches());
    // Forward past three repeats: a begin, no repeat events.
    f.container.setElapsed(.zero, secs(4.5));
    const forward = try f.container.takeDispatches();
    defer testing.allocator.free(forward);
    try expectEvents(forward, true, false, false);
    // Back to before the begin: an end.
    f.container.setElapsed(.zero, secs(0.5));
    const back = try f.container.takeDispatches();
    defer testing.allocator.free(back);
    try expectEvents(back, false, true, false);
    try testing.expectEqual(smil.timed_element.ActiveState.inactive, f.element.active_state);
}

test "pause and unpause hold the timeline's time" {
    var container = TimeContainer.init(testing.allocator);
    defer container.deinit();
    container.start(secs(10));
    try testing.expectEqual(secs(2).us, container.elapsed(secs(12)).us);
    container.pause(secs(12));
    try testing.expectEqual(secs(2).us, container.elapsed(secs(20)).us);
    container.unpause(secs(20));
    try testing.expectEqual(secs(3).us, container.elapsed(secs(21)).us);
    // setCurrentTime before the timeline begins is kept for its start.
    var later = TimeContainer.init(testing.allocator);
    defer later.deinit();
    later.setElapsed(.zero, secs(7));
    try testing.expectEqual(@as(i64, 0), later.elapsed(secs(1)).us);
    later.start(secs(1));
    try testing.expectEqual(secs(8).us, later.elapsed(secs(2)).us);
}

test "freed in either order: element and container detach each other" {
    {
        var container = TimeContainer.init(testing.allocator);
        var element = TimedElement.init(testing.allocator);
        try container.schedule(&element, .zero);
        element.deinit();
        try testing.expectEqual(@as(usize, 0), container.elements.items.len);
        container.deinit();
    }
    {
        var container = TimeContainer.init(testing.allocator);
        var element = TimedElement.init(testing.allocator);
        try container.schedule(&element, .zero);
        container.deinit();
        try testing.expect(element.container == null);
        element.deinit();
    }
}
