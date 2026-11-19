//! The timing dictionaries of the Web Animations API (6.5.1, 6.6.4, 6.8):
//! "update the timing properties of an animation effect" (6.5.4), and the
//! (unrestricted double or KeyframeEffectOptions / KeyframeAnimationOptions)
//! argument of the KeyframeEffect constructor and animate(), which the
//! binding hands over unconverted.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-effecttiming-dictionaries
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const enums = @import("enums");
const interfaces = @import("interfaces");
const timing_mod = @import("timing.zig");
const easing_mod = @import("easing.zig");
const model = @import("model.zig");

const Allocator = std.mem.Allocator;
const JSValue = runtime.JSValue;

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
pub fn fromOptionalEffectTiming(realm: runtime.Context, dict: anytype, easing_buffer: *std.ArrayList(u8), allocator: Allocator) !OptionalTiming {
    var input: OptionalTiming = .{
        .delay = dict.delay,
        .end_delay = dict.endDelay,
        .fill = if (dict.fill) |f| @fromBackingInt(@intCast(@backingInt(f))) else null,
        .iteration_start = dict.iterationStart,
        .iterations = dict.iterations,
        .direction = if (dict.direction) |d| @fromBackingInt(@intCast(@backingInt(d))) else null,
    };
    if (dict.duration) |value| input.duration = try durationOf(realm, value, allocator);
    if (dict.easing) |text| {
        try easing_buffer.appendSlice(allocator, text.asSlice());
        input.easing = easing_buffer.items;
    }
    return input;
}

/// The (unrestricted double or CSSNumericValue or DOMString) `duration`.
fn durationOf(realm: runtime.Context, value: JSValue, allocator: Allocator) !Duration {
    switch (engine.typeOf(realm, value)) {
        .number => return .{ .number = try engine.convertToUnrestrictedDouble(realm, value) },
        .object => {
            // A CSSNumericValue: Crane's document timelines take a time in
            // milliseconds as a number only (Web Animations 2 6.5.1 converts
            // a time-typed value; Typed OM values are not supported here).
            if (engine.convertToPlatformObject(realm, value) != null) return .invalid;
        },
        else => {},
    }
    const text = try engine.convertToDOMString(realm, value, allocator);
    defer allocator.free(text);
    return if (std.mem.eql(u8, text, "auto")) .auto else .invalid;
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

    pub const TimelineMember = union(enum) { missing, value: ?*runtime.Instance };

    pub fn deinit(self: *EffectOptions, allocator: Allocator) void {
        if (self.easing_text) |text| allocator.free(text);
        if (self.pseudo_element) |text| allocator.free(text);
        if (self.id) |text| allocator.free(text);
        self.* = .{};
    }
};

/// Convert `options` - (unrestricted double or KeyframeEffectOptions), or
/// with `animation_options` (unrestricted double or
/// KeyframeAnimationOptions) - by WebIDL's union and dictionary conversions:
/// members read in order, each converted as it is read.
pub fn effectOptions(realm: runtime.Context, options: ?JSValue, allocator: Allocator, animation_options: bool) !EffectOptions {
    var out: EffectOptions = .{};
    errdefer out.deinit(allocator);
    // A missing argument is the default dictionary.
    const value = options orelse return out;
    const kind = engine.typeOf(realm, value);
    // WebIDL union: null, undefined and objects are the dictionary; a Number,
    // or anything else (by ToNumber), the unrestricted double.
    if (kind != .undefined and kind != .null and kind != .object) {
        const duration = try engine.convertToUnrestrictedDouble(realm, value);
        out.timing.duration = .{ .number = duration };
        return out;
    }
    if (kind != .object) return out;
    const Reader = struct {
        realm: runtime.Context,
        object: JSValue,
        fn get(self: @This(), name: []const u8) !?engine.Owned {
            const member = try engine.getProperty(self.realm, self.object, name);
            if (engine.typeOf(self.realm, member.borrow()) == .undefined) {
                member.release();
                return null;
            }
            return member;
        }
    };
    const reader: Reader = .{ .realm = realm, .object = value };
    // EffectTiming (with Web Animations 2's partial), in lexicographic
    // order: delay, direction, duration, easing, endDelay, fill,
    // iterationStart, iterations, playbackRate.
    if (try reader.get("delay")) |m| {
        defer m.release();
        out.timing.delay = try restrictedDouble(realm, m.borrow());
    }
    if (try reader.get("direction")) |m| {
        defer m.release();
        out.timing.direction = try enumOf(timing_mod.Direction, realm, m.borrow(), &.{ "normal", "reverse", "alternate", "alternate-reverse" });
    }
    if (try reader.get("duration")) |m| {
        defer m.release();
        out.timing.duration = try durationOf(realm, m.borrow(), allocator);
    }
    if (try reader.get("easing")) |m| {
        defer m.release();
        out.easing_text = try engine.convertToDOMString(realm, m.borrow(), allocator);
        out.timing.easing = out.easing_text;
    }
    if (try reader.get("endDelay")) |m| {
        defer m.release();
        out.timing.end_delay = try restrictedDouble(realm, m.borrow());
    }
    if (try reader.get("fill")) |m| {
        defer m.release();
        out.timing.fill = try enumOf(timing_mod.FillMode, realm, m.borrow(), &.{ "none", "forwards", "backwards", "both", "auto" });
    }
    if (try reader.get("iterationStart")) |m| {
        defer m.release();
        out.timing.iteration_start = try restrictedDouble(realm, m.borrow());
    }
    if (try reader.get("iterations")) |m| {
        defer m.release();
        out.timing.iterations = try engine.convertToUnrestrictedDouble(realm, m.borrow());
    }
    if (try reader.get("playbackRate")) |m| {
        defer m.release();
        // Web Animations 2's effect playback rate: converted (a TypeError
        // when not finite), not applied - level 1 timing.
        _ = try restrictedDouble(realm, m.borrow());
    }
    // KeyframeEffectOptions: composite, iterationComposite, pseudoElement.
    if (try reader.get("composite")) |m| {
        defer m.release();
        out.composite = try enumOf(model.Composite, realm, m.borrow(), &.{ "replace", "add", "accumulate" });
    }
    if (try reader.get("iterationComposite")) |m| {
        defer m.release();
        out.iteration_accumulate = try enumOf(enum { replace, accumulate }, realm, m.borrow(), &.{ "replace", "accumulate" }) == .accumulate;
    }
    if (try reader.get("pseudoElement")) |m| {
        defer m.release();
        if (engine.typeOf(realm, m.borrow()) != .null) out.pseudo_element = try engine.convertToDOMString(realm, m.borrow(), allocator);
    }
    if (!animation_options) return out;
    // KeyframeAnimationOptions: id, rangeEnd, rangeStart, timeline, trigger.
    if (try reader.get("id")) |m| {
        defer m.release();
        out.id = try engine.convertToDOMString(realm, m.borrow(), allocator);
    }
    // rangeEnd, rangeStart: converted and checked as Web Animations 2 §6.1
    // says (`rangeOption`); view and scroll timelines' ranges have no effect
    // on a document timeline.
    if (try reader.get("rangeEnd")) |m| {
        defer m.release();
        try rangeOption(realm, m.borrow(), allocator);
    }
    if (try reader.get("rangeStart")) |m| {
        defer m.release();
        try rangeOption(realm, m.borrow(), allocator);
    }
    if (try reader.get("timeline")) |m| {
        defer m.release();
        if (engine.typeOf(realm, m.borrow()) == .null) {
            out.timeline = .{ .value = null };
        } else {
            const instance = engine.convertToPlatformObject(realm, m.borrow()) orelse return error.TypeError;
            if (instance.stateAs(interfaces.AnimationTimeline.State) == null) return error.TypeError;
            out.timeline = .{ .value = instance };
        }
    }
    if (try reader.get("trigger")) |m| m.release();
    return out;
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
fn rangeOption(realm: runtime.Context, value: JSValue, allocator: Allocator) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    if (engine.typeOf(realm, value) == .object) if (engine.convertToPlatformObject(realm, value)) |instance| {
        if (instance.stateAs(interfaces.CSSKeywordValue.State) != null) {
            const keyword = try interfaces.CSSKeywordValue.get_value(instance);
            defer instance.ctx.allocator.free(keyword);
            if (!std.mem.eql(u8, keyword, "normal")) return error.TypeError;
            return;
        }
        if (instance.stateAs(interfaces.CSSNumericValue.State) != null) {
            const serialized = try @import("../style/typed_om.zig").serializeNumeric(instance);
            defer instance.ctx.allocator.free(serialized);
            try text.appendSlice(allocator, serialized);
            return checkRangeText(allocator, text.items, true);
        }
    };
    if (engine.typeOf(realm, value) == .object) {
        // TimelineRangeOffset: rangeName (CSSOMString?), offset
        // (CSSNumericValue).
        const name = try engine.getProperty(realm, value, "rangeName");
        defer name.release();
        switch (engine.typeOf(realm, name.borrow())) {
            .undefined, .null => {},
            else => {
                const decoded = try engine.convertToDOMString(realm, name.borrow(), allocator);
                defer allocator.free(decoded);
                if (!isTimelineRangeName(decoded)) return error.TypeError;
                try text.appendSlice(allocator, decoded);
            },
        }
        const offset = try engine.getProperty(realm, value, "offset");
        defer offset.release();
        if (engine.typeOf(realm, offset.borrow()) != .undefined) {
            const instance = engine.convertToPlatformObject(realm, offset.borrow()) orelse return error.TypeError;
            if (instance.stateAs(interfaces.CSSNumericValue.State) == null) return error.TypeError;
            const serialized = try @import("../style/typed_om.zig").serializeNumeric(instance);
            defer instance.ctx.allocator.free(serialized);
            if (text.items.len != 0) try text.append(allocator, ' ');
            try text.appendSlice(allocator, serialized);
            return checkRangeText(allocator, text.items, true);
        }
        return;
    }
    // The union's DOMString arm (ToString of anything else).
    const string = try engine.convertToDOMString(realm, value, allocator);
    defer allocator.free(string);
    return checkRangeText(allocator, string, false);
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

/// WebIDL `double`: ToNumber, and a TypeError when not finite.
fn restrictedDouble(realm: runtime.Context, value: JSValue) !f64 {
    const number = try engine.convertToUnrestrictedDouble(realm, value);
    if (!std.math.isFinite(number)) return error.TypeError;
    return number;
}

/// A WebIDL enumeration: ToString, then one of `names` (in the enum's
/// order), else a TypeError.
fn enumOf(comptime E: type, realm: runtime.Context, value: JSValue, comptime names: []const []const u8) !E {
    var buffer: [32]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const text = engine.convertToDOMString(realm, value, fixed.allocator()) catch |err| switch (err) {
        error.OutOfMemory => return error.TypeError,
        else => return err,
    };
    inline for (names, 0..) |name, i| {
        if (std.mem.eql(u8, text, name)) return @fromBackingInt(@intCast(i));
    }
    return error.TypeError;
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
