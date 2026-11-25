//! The timing dictionaries of the Web Animations API (6.5.1, 6.6.4, 6.8):
//! "update the timing properties of an animation effect" (6.5.4), and the
//! (unrestricted double or KeyframeEffectOptions / KeyframeAnimationOptions)
//! argument of the KeyframeEffect constructor and animate(), as the binding
//! converted it (lane bind1 batch B, B5 group 3b: they were read from the
//! object by hand until then).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-effecttiming-dictionaries
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const enums = @import("enums");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const typedefs = @import("typedefs");
const timing_mod = @import("timing.zig");
const easing_mod = @import("easing.zig");
const model = @import("model.zig");

const Allocator = std.mem.Allocator;

/// An OptionalEffectTiming: each member present or not. `easing` is
/// BORROWED for the call.
pub const OptionalTiming = struct {
    delay: ?f64 = null,
    end_delay: ?f64 = null,
    fill: ?timing_mod.FillMode = null,
    iteration_start: ?f64 = null,
    iterations: ?f64 = null,
    duration: ?Duration = null,
    direction: ?timing_mod.Direction = null,
    easing: ?[]const u8 = null,
};

/// The `duration` member: a number, or a string that must be "auto".
pub const Duration = union(enum) { number: f64, auto, invalid };

/// 6.5.4 "update the timing properties of an animation effect" from
/// `input`.
pub fn updateTiming(effect: *model.Effect, input: OptionalTiming) error{ TypeError, OutOfMemory }!void {
    // 1. "If the iterationStart member of input exists and is less than
    // zero, throw a TypeError."
    if (input.iteration_start) |value| if (value < 0) return error.TypeError;
    // 2.
    if (input.iterations) |value| if (value < 0 or std.math.isNan(value)) return error.TypeError;
    // 3.
    if (input.duration) |duration| switch (duration) {
        .number => |value| if (value < 0 or std.math.isNan(value)) return error.TypeError,
        .auto => {},
        .invalid => return error.TypeError,
    };
    // 4.
    var parsed: ?easing_mod.Easing = null;
    if (input.easing) |text| parsed = (try easing_mod.parse(effect.allocator, text)) orelse return error.TypeError;
    // 5.
    const t = &effect.timing;
    if (input.delay) |value| t.delay = value;
    if (input.end_delay) |value| t.end_delay = value;
    if (input.fill) |value| t.fill = value;
    if (input.iteration_start) |value| t.iteration_start = value;
    if (input.iterations) |value| t.iterations = value;
    if (input.duration) |duration| t.duration = switch (duration) {
        .number => |value| value,
        else => null,
    };
    if (input.direction) |value| t.direction = value;
    if (parsed) |easing| {
        t.easing.deinit(effect.allocator);
        t.easing = easing;
    }
    // 6.
    if (effect.animationModel()) |animation| {
        animation.updateFinishedState(false, false);
        animation.settle();
    }
}

/// The OptionalEffectTiming the binding converted (updateTiming).
pub fn fromOptionalEffectTiming(dict: dictionaries.OptionalEffectTiming, easing_buffer: *std.ArrayList(u8), allocator: Allocator) !OptionalTiming {
    var input: OptionalTiming = .{
        .delay = dict.delay,
        .end_delay = dict.endDelay,
        .fill = if (dict.fill) |f| @fromBackingInt(@intCast(@backingInt(f))) else null,
        .iteration_start = dict.iterationStart,
        .iterations = dict.iterations,
        .direction = if (dict.direction) |d| @fromBackingInt(@intCast(@backingInt(d))) else null,
    };
    if (dict.duration) |value| input.duration = durationOf(value);
    if (dict.easing) |text| {
        try easing_buffer.appendSlice(allocator, text.asSlice());
        input.easing = easing_buffer.items;
    }
    return input;
}

/// The `duration` member as the binding converted it: EffectTiming's
/// (unrestricted double or CSSNumericValue or DOMString) or
/// OptionalEffectTiming's (unrestricted double or DOMString). A string is
/// "auto" or invalid (a TypeError in "update the timing properties", 6.5.4
/// step 3); so is ToString of any other value, an object's included
/// (WebIDL 3.2.25 puts the string arm before the numeric one: Chrome 157,
/// Firefox 159 and Safari 27 call an object's toString and throw for
/// 'bogus', '5' and true - probe tmp/probes/bind1-nullmember/report-g3.txt).
fn durationOf(value: anytype) Duration {
    switch (value) {
        inline else => |arm, tag| {
            const name = @tagName(tag);
            if (comptime std.mem.eql(u8, name, "double")) {
                return .{ .number = arm };
            } else if (comptime std.mem.eql(u8, name, "domstring")) {
                return if (std.mem.eql(u8, arm.asSlice(), "auto")) .auto else .invalid;
            } else if (comptime std.mem.eql(u8, name, "cssnumeric_value")) {
                // A CSSNumericValue: Crane's document timelines take a time
                // in milliseconds as a number only (Web Animations 2 6.5.1
                // converts a time-typed value; Typed OM values are not
                // supported here).
                return .invalid;
            } else @compileError("duration arm " ++ name ++ " has no meaning here");
        },
    }
}

/// What the KeyframeEffect constructor and animate() read from their
/// options argument.
pub const EffectOptions = struct {
    timing: OptionalTiming = .{},
    /// OWNED: the easing string `timing.easing` borrows.
    easing_text: ?[]u8 = null,
    composite: model.Composite = .replace,
    /// Web Animations 2's iterationComposite member: whether the effect's
    /// iteration composite operation is accumulate ("replace" by default).
    iteration_accumulate: bool = false,
    /// The pseudoElement member as given (null: none). OWNED.
    pseudo_element: ?[]u8 = null,
    /// KeyframeAnimationOptions only.
    id: ?[]u8 = null,
    timeline: TimelineMember = .missing,
    /// HELD: the timeline member's object, from conversion until deinit.
    /// The binding's dictionary member is a bare instance - the handle the
    /// member was read into is gone when conversion returns - and animate()
    /// runs script before it gives the timeline to the new Animation, whose
    /// traced edge keeps it from then on: "process a keyframes argument"
    /// (the keyframes' getters and iterators, a collection included) in the
    /// KeyframeEffect constructor's steps (step 2 of animate()). A getter
    /// that deletes `options.timeline` and collects would free it under
    /// animate() (tests/html/bind1_animation_timeline_hold_test.zig).
    timeline_hold: ?engine.Owned = null,

    pub const TimelineMember = union(enum) { missing, value: ?*runtime.Instance };

    pub fn deinit(self: *EffectOptions, allocator: Allocator) void {
        if (self.easing_text) |text| allocator.free(text);
        if (self.pseudo_element) |text| allocator.free(text);
        if (self.id) |text| allocator.free(text);
        if (self.timeline_hold) |hold| hold.release();
        self.* = .{};
    }
};

/// The options argument as the binding converted it -
/// `(unrestricted double or KeyframeEffectOptions)` for the KeyframeEffect
/// constructor, `(unrestricted double or KeyframeAnimationOptions)` for
/// animate() (WebIDL 3.2.25: undefined, null and any object are the
/// dictionary, anything else the double) - null when it was not passed (the
/// default dictionary). Its members were converted in WebIDL's order
/// (EffectTiming's, then KeyframeEffectOptions', then
/// KeyframeAnimationOptions', each in lexicographic order), before any step:
/// Chrome 157, Firefox 159 and Safari 27 all run the option getters before
/// reading the keyframes (probe tmp/probes/bind1-nullmember/report-g3.txt).
pub fn effectOptions(options: anytype, allocator: Allocator) !EffectOptions {
    var out: EffectOptions = .{};
    errdefer out.deinit(allocator);
    const value = options orelse return out;
    switch (value) {
        .double => |duration| out.timing.duration = .{ .number = duration },
        inline else => |dictionary| if (@TypeOf(dictionary) == dictionaries.KeyframeAnimationOptions)
            try readAnimationOptions(&out, dictionary, allocator)
        else
            try readEffectOptions(&out, dictionary, allocator),
    }
    return out;
}

/// KeyframeAnimationOptions into `out`.
fn readAnimationOptions(out: *EffectOptions, dictionary: dictionaries.KeyframeAnimationOptions, allocator: Allocator) !void {
    try readEffectOptions(out, dictionary.base, allocator);
    // KeyframeAnimationOptions: id, rangeEnd, rangeStart, timeline,
    // trigger.
    if (dictionary.id) |id| out.id = try allocator.dupe(u8, id.asSlice());
    // rangeEnd, rangeStart: checked as Web Animations 2 §6.1 says
    // (`rangeOption`); view and scroll timelines' ranges have no effect
    // on a document timeline.
    if (dictionary.rangeEnd) |range| try rangeOption(range, allocator);
    if (dictionary.rangeStart) |range| try rangeOption(range, allocator);
    // 6.8 animate() step 3: the timeline member, or with it missing the
    // default document timeline (a present null is no timeline).
    if (dictionary.timeline.was_passed) {
        if (dictionary.timeline.value) |timeline| {
            // Held in its relevant realm, where its wrapper is.
            out.timeline_hold = try engine.retainValue(timeline.ctx, runtime.JSValue.fromInstance(timeline));
        }
        out.timeline = .{ .value = dictionary.timeline.value };
    }
    // `trigger` (Animation Triggers 1, in the pinned IDL) is converted
    // by the binding - an object that is no AnimationTrigger is a
    // TypeError - and not used: Chrome 157, Firefox 159 and Safari 27
    // never read it (none ships animation triggers, so none counts
    // toward a majority; golden rule 2 leaves the IDL's; probe
    // tmp/probes/bind1-nullmember/report-g3.txt).
}

/// KeyframeEffectOptions into `out`.
fn readEffectOptions(out: *EffectOptions, dictionary: dictionaries.KeyframeEffectOptions, allocator: Allocator) !void {
    // EffectTiming (with Web Animations 2's partial): playbackRate is
    // converted (a TypeError when not finite: a `double`) and not applied -
    // level 1 timing.
    const timing = dictionary.base;
    out.timing.delay = timing.delay;
    out.timing.direction = if (timing.direction) |d| directionOf(d) else null;
    if (timing.duration) |duration| out.timing.duration = durationOf(duration);
    if (timing.easing) |text| {
        out.easing_text = try allocator.dupe(u8, text.asSlice());
        out.timing.easing = out.easing_text;
    }
    out.timing.end_delay = timing.endDelay;
    out.timing.fill = if (timing.fill) |f| fillOf(f) else null;
    out.timing.iteration_start = timing.iterationStart;
    out.timing.iterations = timing.iterations;
    // KeyframeEffectOptions: composite, iterationComposite, pseudoElement.
    if (dictionary.composite) |composite| out.composite = @fromBackingInt(@intCast(@backingInt(composite)));
    if (dictionary.iterationComposite) |operation| out.iteration_accumulate = operation == ._accumulate_;
    if (dictionary.pseudoElement) |pseudo| out.pseudo_element = try allocator.dupe(u8, pseudo.asSlice());
}

fn fillOf(fill: enums.FillMode) timing_mod.FillMode {
    return @fromBackingInt(@intCast(@backingInt(fill)));
}

fn directionOf(direction: enums.PlaybackDirection) timing_mod.Direction {
    return @fromBackingInt(@intCast(@backingInt(direction)));
}

/// Web Animations 2 KeyframeAnimationOptions rangeStart / rangeEnd:
/// `(TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or
/// DOMString)`. A DOMString "is parsed as an animation-range-end value"
/// (`normal | <timeline-range-name> <length-percentage>? |
/// <length-percentage>`), a CSSKeywordValue other than "normal" throws a
/// TypeError, a CSSNumericValue is an offset with no range name, and a
/// TimelineRangeOffset names a range (a <timeline-range-name>; `none` is
/// none) and an offset. Every offset must be computationally independent:
/// font-relative units, which nothing resolves for a script-set range, throw
/// a TypeError (csswg-drafts#13853; WebKit 318815@main, Gecko, and Chromium
/// gating its rejection for Interop 2026 -
/// web-animations/interfaces/Animation/animation-range-invalid.html, Firefox
/// and Safari Technology Preview 11/11: golden rule 2's newer behaviour).
fn rangeOption(value: typedefs.TimelineRangeOffsetOrCSSNumericValueOrCSSKeywordValueOrDOMString, allocator: Allocator) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    switch (value) {
        .csskeyword_value => |instance| {
            const keyword = try interfaces.CSSKeywordValue.get_value(instance);
            defer instance.ctx.allocator.free(keyword);
            if (!std.mem.eql(u8, keyword, "normal")) return error.TypeError;
        },
        .cssnumeric_value => |instance| {
            const serialized = try @import("../style/typed_om.zig").serializeNumeric(instance);
            defer instance.ctx.allocator.free(serialized);
            try text.appendSlice(allocator, serialized);
            return checkRangeText(allocator, text.items, true);
        },
        // TimelineRangeOffset: rangeName (CSSOMString?), offset
        // (CSSNumericValue) - any other object, a platform object of
        // another interface included (WebIDL 3.2.25 step 11).
        .timeline_range_offset => |offset| {
            if (offset.rangeName) |name| {
                if (!isTimelineRangeName(name.asSlice())) return error.TypeError;
                try text.appendSlice(allocator, name.asSlice());
            }
            const instance = offset.offset orelse return;
            const serialized = try @import("../style/typed_om.zig").serializeNumeric(instance);
            defer instance.ctx.allocator.free(serialized);
            if (text.items.len != 0) try text.append(allocator, ' ');
            try text.appendSlice(allocator, serialized);
            return checkRangeText(allocator, text.items, true);
        },
        // The DOMString arm (ToString of anything else).
        .domstring => |string| return checkRangeText(allocator, string.asSlice(), false),
    }
}

/// Scroll Animations 1 <timeline-range-name>.
fn isTimelineRangeName(name: []const u8) bool {
    for ([_][]const u8{ "cover", "contain", "entry", "exit", "entry-crossing", "exit-crossing", "scroll" }) |known| {
        if (std.mem.eql(u8, name, known)) return true;
    }
    return false;
}

/// `text` is one animation-range-end value (`offset_only`: a
/// <length-percentage>, with any range name already checked) whose offset is
/// computationally independent; else a TypeError.
fn checkRangeText(allocator: Allocator, text: []const u8, offset_only: bool) !void {
    const css = @import("css");
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, "animation-range-end", text, "")) return error.TypeError;
    var tokenizer = css.tokenizer.Tokenizer.init(text);
    var items: usize = 0;
    while (true) {
        const token = tokenizer.next();
        switch (token.token_type) {
            .eof => break,
            // One value, not a list.
            .comma => return error.TypeError,
            .whitespace => continue,
            .ident => if (offset_only and items == 0 and std.ascii.eqlIgnoreCase(token.value, "normal")) return error.TypeError,
            .dimension => {
                const unit = token.unit orelse continue;
                inline for (.{ "em", "rem", "ex", "rex", "cap", "rcap", "ch", "rch", "ic", "ric", "lh", "rlh" }) |name|
                    if (css.tokenizer.nameEql(unit, name)) return error.TypeError;
            },
            else => {},
        }
        items += 1;
    }
}

/// KeyframeEffect "pseudo-element parsing" (6.6): null stays null; a valid,
/// supported <pseudo-element-selector> is returned (a legacy single-colon
/// one in its two-colon form); anything else is a SyntaxError. OWNED.
pub fn parsePseudoElement(allocator: Allocator, value: ?[]const u8) error{ SyntaxError, OutOfMemory }!?[]u8 {
    const text = value orelse return null;
    // 3. The legacy Selectors Level 2 single-colon pseudo-elements.
    const legacy = [_][]const u8{ ":before", ":after", ":first-letter", ":first-line" };
    for (legacy) |name| if (std.ascii.eqlIgnoreCase(text, name)) {
        const out = try allocator.alloc(u8, name.len + 1);
        out[0] = ':';
        for (name, 0..) |c, i| out[i + 1] = std.ascii.toLower(c);
        return out;
    };
    // 2. The pseudo-elements Crane's selectors support and that can be an
    // effect target (Blink's and Gecko's animatable pseudo-elements). CSS
    // Forms 1's ::checkmark and ::picker-icon: Chrome animates both, Safari
    // accepts both (customizable-select/checkmark-animation.html,
    // picker-icon-animation.html).
    const supported = [_][]const u8{ "::before", "::after", "::marker", "::first-letter", "::first-line", "::placeholder", "::selection", "::backdrop", "::file-selector-button", "::checkmark", "::picker-icon" };
    for (supported) |name| if (std.ascii.eqlIgnoreCase(text, name)) {
        const out = try allocator.dupe(u8, name);
        return out;
    };
    // CSS View Transitions 1 §3.2: ::view-transition and the named view
    // transition pseudo-elements are effect targets in all three browsers
    // (getAnimations-pseudoElement-option-on-view-transition.html: Chrome
    // and Safari answer [] for them, Firefox their animations - none throws
    // a SyntaxError). Kept as written, lowercased name.
    if (try viewTransitionPseudoElement(allocator, text)) |canonical| return canonical;
    return error.SyntaxError;
}

/// `text` as a view transition pseudo-element selector -
/// "::view-transition", or a named one with its argument - lowercased to
/// its name; null when it is not one.
fn viewTransitionPseudoElement(allocator: Allocator, text: []const u8) error{OutOfMemory}!?[]u8 {
    if (text.len < 2 or text[0] != ':' or text[1] != ':') return null;
    if (std.ascii.eqlIgnoreCase(text, "::view-transition")) return try allocator.dupe(u8, "::view-transition");
    const selector = @import("selector");
    var list = selector.parse(allocator, text) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer list.deinit();
    if (list.selectors.len != 1 or list.selectors[0].combinators.len != 0) return null;
    for (list.selectors[0].compound.simple_selectors) |*simple| switch (simple.*) {
        .PseudoElement => |*pseudo| if (pseudo.isNamedViewTransition()) {
            const open = std.mem.indexOfScalar(u8, text, '(') orelse return null;
            const out = try allocator.dupe(u8, text);
            _ = std.ascii.lowerString(out[0..open], out[0..open]);
            return out;
        } else return null,
        .Universal => {},
        else => return null,
    };
    return null;
}

/// getTiming()'s fill, direction and duration as the dictionary types.
pub fn fillEnum(fill: timing_mod.FillMode) enums.FillMode {
    return @fromBackingInt(@intCast(@backingInt(fill)));
}

pub fn directionEnum(direction: timing_mod.Direction) enums.PlaybackDirection {
    return @fromBackingInt(@intCast(@backingInt(direction)));
}

test "pseudo-element parsing keeps supported names and rewrites legacy ones" {
    const allocator = std.testing.allocator;
    const before = (try parsePseudoElement(allocator, ":before")).?;
    defer allocator.free(before);
    try std.testing.expectEqualStrings("::before", before);
    const marker = (try parsePseudoElement(allocator, "::marker")).?;
    defer allocator.free(marker);
    try std.testing.expectEqualStrings("::marker", marker);
    try std.testing.expect((try parsePseudoElement(allocator, null)) == null);
    try std.testing.expectError(error.SyntaxError, parsePseudoElement(allocator, "::foo"));
    try std.testing.expectError(error.SyntaxError, parsePseudoElement(allocator, "before"));
}
