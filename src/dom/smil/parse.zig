//! The timing attributes' value grammars (SMIL Animation 3.6.7, which SVG
//! Animations 2 section 2.9 makes normative for SVG): clock values, offset
//! values, and the begin and end value lists.
//!
//! Where the grammar leaves a choice open - what a syntax error in one value
//! of a list does ("the host language must specify how the user agent deals
//! with this"; SVG 2 names no rule) - Crane does what Chrome and Safari do
//! (one engine lineage, WebKit's SVGSMILElement): an invalid value is
//! skipped and the rest of the list still counts (Blink
//! SVGSMILElement::ParseBeginOrEnd / ParseCondition / ParseClockValue /
//! ParseOffsetValue, core/svg/animation/svg_smil_element.cc, read
//! 2026-11-20). Firefox drops the whole list instead (dom/smil/SMILParserUtils
//! .cpp). Golden rule 2: the browsers differ, no newer spec is involved, and
//! two of the three agree.
//!
//! Spec: https://www.w3.org/TR/2001/REC-smil-animation-20010904/#TimingAttrValGrammars
const std = @import("std");
const Time = @import("time.zig").Time;

/// Whether a value list is a begin or an end list.
pub const BeginOrEnd = enum(u1) { begin, end };

/// A begin or end condition that yields instance times only when something
/// happens (SMIL Animation 3.6.8 "Building the instance times lists"): an
/// event, a syncbase element's new interval or repeat, an access key.
pub const Condition = struct {
    kind: Kind,
    /// The eventbase or syncbase element's id, unescaped; empty when none
    /// was given (an event value then listens at the target element). Owned.
    base_id: []u8,
    /// The event type, or "begin", "end" or "repeat" for a syncbase
    /// condition. Owned.
    name: []u8,
    /// The offset from the event or syncbase time.
    offset: Time,
    /// repeat(n)'s n; null for every other condition.
    repeat: ?u32 = null,

    pub const Kind = enum(u2) {
        /// An event value: an instance time each time the event is
        /// observed on the eventbase element.
        event,
        /// A syncbase value (`id.begin`, `id.end`) or a repeat value
        /// (`id.repeat(n)`): an instance time each time the syncbase
        /// element gets a new interval, or repeats the n-th time.
        syncbase,
        /// accessKey(c) and wallclock(...): never resolved. Chrome and
        /// Safari do not implement accessKey values (Blink ParseCondition:
        /// "FIXME: accesskey() support"), and no browser implements
        /// wallclock values (Blink and WebKit parse them as an event no
        /// target fires; Gecko rejects them).
        never,
    };

    pub fn deinit(self: *Condition, allocator: std.mem.Allocator) void {
        allocator.free(self.base_id);
        allocator.free(self.name);
    }

    pub fn hasExplicitBase(self: Condition) bool {
        return self.base_id.len != 0;
    }
};

/// What a begin or end attribute's value list yields: the instance times its
/// offset values (and, in an end list, "indefinite") give at once, sorted,
/// and the conditions that give theirs later.
pub const ValueList = struct {
    times: std.ArrayListUnmanaged(Time) = .empty,
    conditions: std.ArrayListUnmanaged(Condition) = .empty,
    /// An end list with any value at all (SMIL Animation 3.6.8: "If there
    /// was no end attribute specified").
    has_values: bool = false,
    /// An end list with event, repeat or access key values: "Events leave
    /// the end open-ended" (3.6.8 getFirstInterval).
    has_event_conditions: bool = false,

    pub fn deinit(self: *ValueList, allocator: std.mem.Allocator) void {
        self.times.deinit(allocator);
        for (self.conditions.items) |*condition| condition.deinit(allocator);
        self.conditions.deinit(allocator);
        self.* = .{};
    }
};

/// The XML white space characters (SMIL Animation 3.6.7, "S").
const whitespace = " \t\r\n";

fn strip(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, whitespace);
}

/// A decimal number as the browsers read one in a timing value: an optional
/// sign, digits with an optional fraction (either part may be empty, not
/// both) and an optional exponent, and nothing else.
fn parseNumber(text: []const u8) ?f64 {
    var i: usize = 0;
    if (i < text.len and (text[i] == '+' or text[i] == '-')) i += 1;
    var digits: usize = 0;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) digits += 1;
    if (i < text.len and text[i] == '.') {
        i += 1;
        while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) digits += 1;
    }
    if (digits == 0) return null;
    if (i < text.len and (text[i] == 'e' or text[i] == 'E')) {
        i += 1;
        if (i < text.len and (text[i] == '+' or text[i] == '-')) i += 1;
        const exponent_start = i;
        while (i < text.len and std.ascii.isDigit(text[i])) i += 1;
        if (i == exponent_start) return null;
    }
    if (i != text.len) return null;
    const value = std.fmt.parseFloat(f64, text) catch return null;
    if (!std.math.isFinite(value)) return null;
    return value;
}

/// An offset value or Timecount value: a number with an optional metric
/// ("h", "min", "s", "ms"; seconds by default) - SMIL Animation 3.6.7
/// "Clock values" and "Offset values". Unresolved when it is not one.
pub fn parseOffsetValue(text: []const u8) Time {
    const view = strip(text);
    const Metric = struct { suffix: []const u8, scale: f64 };
    // "min" and "ms" before "s", "h" alone: the longest suffix that matches.
    const metrics = [_]Metric{
        .{ .suffix = "min", .scale = 60 },
        .{ .suffix = "ms", .scale = 0.001 },
        .{ .suffix = "h", .scale = 3600 },
        .{ .suffix = "s", .scale = 1 },
    };
    for (metrics) |metric| {
        if (std.mem.endsWith(u8, view, metric.suffix)) {
            const number = parseNumber(view[0 .. view.len - metric.suffix.len]) orelse return .unresolved;
            return Time.fromSeconds(number * metric.scale);
        }
    }
    const number = parseNumber(view) orelse return .unresolved;
    return Time.fromSeconds(number);
}

fn parseUnsigned(text: []const u8) ?u64 {
    if (text.len == 0) return null;
    for (text) |c| if (!std.ascii.isDigit(c)) return null;
    return std.fmt.parseInt(u64, text, 10) catch null;
}

/// A clock value (SMIL Animation 3.6.7): "indefinite", a Full-clock-value
/// (hh:mm:ss[.f]), a Partial-clock-value (mm:ss[.f]) or a Timecount-value.
/// Unresolved when it is none of them.
pub fn parseClockValue(text: []const u8) Time {
    const view = strip(text);
    if (std.mem.eql(u8, view, "indefinite")) return .indefinite;
    const colon_one = std.mem.indexOfScalar(u8, view, ':') orelse return parseOffsetValue(view);
    var hours: ?[]const u8 = null;
    var minutes = view[0..colon_one];
    var seconds_part = view[colon_one + 1 ..];
    if (std.mem.indexOfScalar(u8, seconds_part, ':')) |colon_two| {
        // hh:mm:ss: the minutes are the two digits between the colons.
        if (colon_two != 2) return .unresolved;
        hours = minutes;
        minutes = seconds_part[0..2];
        seconds_part = seconds_part[3..];
    }
    // Minutes ::= 2DIGIT; range from 00 to 59.
    if (minutes.len != 2) return .unresolved;
    // Seconds ::= 2DIGIT ("." Fraction)?, Fraction ::= DIGIT+.
    if (std.mem.indexOfScalar(u8, seconds_part, '.')) |dot| {
        if (dot != 2 or seconds_part.len < 4) return .unresolved;
    } else if (seconds_part.len != 2) return .unresolved;
    if (!std.ascii.isDigit(seconds_part[0]) or !std.ascii.isDigit(seconds_part[1])) return .unresolved;
    const secs = parseNumber(seconds_part) orelse return .unresolved;
    if (secs >= 60) return .unresolved;
    const mins = parseUnsigned(minutes) orelse return .unresolved;
    if (mins >= 60) return .unresolved;
    var total = secs + @as(f64, @floatFromInt(mins)) * 60;
    if (hours) |h| {
        const hrs = parseUnsigned(h) orelse return .unresolved;
        total += @as(f64, @floatFromInt(hrs)) * 3600;
    }
    return Time.fromSeconds(total);
}

/// The index of the first '.' not escaped by a backslash (SMIL Animation
/// 3.6.7: "ignore any '.' separator characters preceded by a backslash").
fn findUnescapedDot(text: []const u8) ?usize {
    var escaped = false;
    for (text, 0..) |c, i| {
        if (escaped) {
            escaped = false;
        } else if (c == '\\') {
            escaped = true;
        } else if (c == '.') {
            return i;
        }
    }
    return null;
}

/// `text` without its escaping backslashes. OWNED.
fn unescape(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var escaped = false;
    for (text) |c| {
        if (escaped) {
            try out.append(allocator, c);
            escaped = false;
        } else if (c == '\\') {
            escaped = true;
        } else {
            try out.append(allocator, c);
        }
    }
    return out.toOwnedSlice(allocator);
}

/// One value of a list that is not a clock value: an event, syncbase,
/// repeat, access key or wallclock value (SMIL Animation 3.6.7 "Parsing
/// timing specifiers" step 5, as Blink's ParseCondition reads it). Null
/// when it is no valid condition.
pub fn parseCondition(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}!?Condition {
    const value = strip(text);
    // The offset: everything from the first sign on ("Build a token
    // substring up to but not including any sign indicator").
    var condition_text = value;
    var offset: Time = .zero;
    const plus = std.mem.indexOfScalar(u8, value, '+');
    const minus = if (plus == null) std.mem.indexOfScalar(u8, value, '-') else null;
    if (plus orelse minus) |pos| {
        condition_text = strip(value[0..pos]);
        offset = parseOffsetValue(value[pos + 1 ..]);
        if (offset.isUnresolved()) return null;
        if (minus != null) offset = offset.negate();
    }
    if (condition_text.len == 0) return null;
    var base_text: []const u8 = "";
    var name = condition_text;
    if (findUnescapedDot(condition_text)) |dot| {
        base_text = condition_text[0..dot];
        name = condition_text[dot + 1 ..];
    }
    if (name.len == 0) return null;
    var kind: Condition.Kind = .event;
    var repeat: ?u32 = null;
    if (std.mem.startsWith(u8, name, "repeat(") and std.mem.endsWith(u8, name, ")")) {
        const count = parseUnsigned(name[7 .. name.len - 1]) orelse return null;
        repeat = std.math.cast(u32, count) orelse return null;
        name = "repeat";
        kind = .syncbase;
    } else if (std.mem.eql(u8, name, "begin") or std.mem.eql(u8, name, "end")) {
        // A syncbase value names its syncbase element.
        if (base_text.len == 0) return null;
        kind = .syncbase;
    } else if (std.mem.startsWith(u8, name, "accessKey(") or std.mem.startsWith(u8, name, "accesskey(") or
        std.mem.startsWith(u8, name, "wallclock("))
    {
        kind = .never;
    }
    if (kind == .syncbase and base_text.len == 0) {
        // repeat(n) with no syncbase element: the eventbase is the target
        // element, which raises no repeat events of its own; Blink connects
        // no syncbase for it either.
        kind = .never;
    }
    const base_id = try unescape(allocator, base_text);
    errdefer allocator.free(base_id);
    const owned_name = try unescape(allocator, name);
    return .{ .kind = kind, .base_id = base_id, .name = owned_name, .offset = offset, .repeat = repeat };
}

/// Parse a begin or end attribute's value list (`text` null: no attribute).
/// SMIL Animation 3.2.1: "If no begin is specified, the default timing is
/// equivalent to an offset value of "0"."
pub fn parseValueList(allocator: std.mem.Allocator, text: ?[]const u8, which: BeginOrEnd) error{OutOfMemory}!ValueList {
    var list: ValueList = .{};
    errdefer list.deinit(allocator);
    const value = text orelse {
        if (which == .begin) try list.times.append(allocator, .zero);
        return list;
    };
    var items = std.mem.splitScalar(u8, value, ';');
    while (items.next()) |item| {
        if (strip(item).len == 0) continue;
        const time = parseClockValue(item);
        if (!time.isUnresolved()) {
            try list.times.append(allocator, time);
            list.has_values = true;
            continue;
        }
        const condition = (try parseCondition(allocator, item)) orelse continue;
        try list.conditions.append(allocator, condition);
        list.has_values = true;
        if (condition.kind == .event or condition.kind == .never or condition.repeat != null) list.has_event_conditions = true;
    }
    std.mem.sort(Time, list.times.items, {}, Time.sortLessThan);
    return list;
}
