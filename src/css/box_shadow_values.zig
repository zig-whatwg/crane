//! CSS Backgrounds 3 §6.1: owned, ordered box-shadow values.
//!
//! Q172 PART2 selects the single noninherited Backgrounds 3 longhand.
//! Browser evidence: main/tmp/analysis/integrator-probes-1024c/ (q172,
//! Chrome 155 / Firefox 158 / Safari 27). Per-layer none/outset and the
//! Borders 4 longhands remain excluded by that ruling.
//!
//! Design references (not copied): Blink CSSShadowValue::CustomCSSText /
//! Equals, StyleBuilderConverter::ConvertShadow, and
//! ComputedStyleUtils::ValueForShadowData preserve typed components and
//! distinguish computed StyleColor from receiver-time color resolution.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Color = values.Color;

/// One §6.1 shadow. Only lengths[0..count] are initialized and owned.
/// Specified values preserve omitted components; computed values have a
/// color and all four lengths. No field borrows authored source text.
pub const Shadow = struct {
    color: ?Color = null,
    lengths: [4]Value = undefined,
    count: u3 = 0,
    inset: bool = false,

    fn retain(self: Shadow) void {
        if (self.color) |color| color.retain();
        for (self.lengths[0..self.count]) |value| value.retain();
    }

    fn release(self: Shadow) void {
        if (self.color) |color| color.release();
        for (self.lengths[0..self.count]) |value| value.release();
    }

    fn eql(self: Shadow, other: Shadow) bool {
        if (self.count != other.count or self.inset != other.inset) return false;
        if (self.color) |color| {
            if (!color.eql(other.color orelse return false)) return false;
        } else if (other.color != null) return false;
        for (self.lengths[0..self.count], other.lengths[0..other.count]) |a, b|
            if (!a.eql(b)) return false;
        return true;
    }

    fn serialize(self: Shadow, out: *std.ArrayList(u8), allocator: Allocator, computed: bool, current: ?Color) Allocator.Error!void {
        // CSSOM §6.7.2 / Backgrounds 3 §6.1 canonical order: color,
        // the adjacent length group, then inset. Preserve optionality.
        if (self.color) |color| {
            if (current) |receiver| {
                // Absolute (including wide-gamut) colors need no graph
                // resolution or intermediate allocation at this boundary.
                if (color.containsCurrentColor()) {
                    const resolved = try color.resolveComputed(allocator, .{ .current = receiver });
                    defer resolved.release();
                    try resolved.serializeComputed(out, allocator);
                } else try color.serializeComputed(out, allocator);
            } else if (computed) try color.serializeComputed(out, allocator) else try color.serializeSpecified(out, allocator);
            try out.append(allocator, ' ');
        }
        for (self.lengths[0..self.count], 0..) |value, index| {
            if (index != 0) try out.append(allocator, ' ');
            try properties.serializeValue(.outline_offset, value, out, allocator);
        }
        if (self.inset) try out.appendSlice(allocator, " inset");
    }
};

/// Immutable, refcounted nonempty shadow list. Owns both typed leaves and
/// canonical serialization, allocated with its stored original allocator.
/// The allocation-free `none` value stays Value.kw(.none), outside this type.
pub const BoxShadow = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    items: []const Shadow,
    text: *values.SharedText,
    computed: bool,

    /// Retain this immutable value independently of its declaration/style.
    pub fn ref(self: *BoxShadow) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    /// Release one reference, and all leaves/storage at the final release.
    pub fn unref(self: *BoxShadow) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |item| item.release();
        self.allocator.free(self.items);
        self.text.unref();
        self.allocator.destroy(self);
    }

    /// Structural equality includes component presence and every owner's
    /// typed identity, including random/math identity absent from text.
    pub fn eql(self: *const BoxShadow, other: *const BoxShadow) bool {
        if (self == other) return true;
        if (self.computed != other.computed or self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| if (!a.eql(b)) return false;
        return true;
    }

    /// Retain borrowed specified components only after every allocation has
    /// succeeded. On error, none of the caller's references are consumed.
    pub fn create(allocator: Allocator, items: []const Shadow) Allocator.Error!*BoxShadow {
        return createInternal(allocator, items, false);
    }

    fn createInternal(allocator: Allocator, items: []const Shadow, computed: bool) Allocator.Error!*BoxShadow {
        std.debug.assert(items.len != 0);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        for (items, 0..) |item, index| {
            std.debug.assert(item.count >= 2 and item.count <= 4);
            if (index != 0) try out.appendSlice(allocator, ", ");
            try item.serialize(&out, allocator, computed, null);
        }
        const text = try values.SharedText.create(allocator, out.items);
        errdefer text.unref();
        const owned = try allocator.dupe(Shadow, items);
        errdefer allocator.free(owned);
        const self = try allocator.create(BoxShadow);
        self.* = .{ .allocator = allocator, .items = owned, .text = text, .computed = computed };
        for (owned) |item| item.retain();
        return self;
    }

    /// Forward dependency discovery over every effective color and length.
    pub fn needsTreeCounts(self: *const BoxShadow) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.needsTreeCounts()) return true;
            for (item.lengths[0..item.count]) |value| if (value.needsTreeCounts()) return true;
        }
        return false;
    }

    /// Forward random-base dependencies without inspecting owner graphs.
    pub fn needsRandomBase(self: *const BoxShadow) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.needsRandomBase()) return true;
            for (item.lengths[0..item.count]) |value| if (value.needsRandomBase()) return true;
        }
        return false;
    }

    /// Forward the caller's capability policy. Cascade keeps box-shadow
    /// outside its geometry-tolerant grammars, so computation requires all
    /// metrics needed for the four absolute lengths and the computed color.
    pub fn needsUnavailableMetrics(self: *const BoxShadow, geometry_length: bool) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.needsUnavailableMetrics(geometry_length)) return true;
            for (item.lengths[0..item.count]) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
        }
        return false;
    }

    /// Query the retained computed Color graph, without text scanning.
    pub fn containsCurrentColor(self: *const BoxShadow) bool {
        for (self.items) |item| {
            if (item.color) |color| if (color.containsCurrentColor()) return true;
        }
        return false;
    }

    /// §6.1 computed value: four absolute lengths, computed color, inset.
    /// The existing winning-source component context is borrowed only for
    /// this call. Color 4 §6.4 currentcolor stays symbolic for inheritance.
    pub fn compute(self: *const BoxShadow, allocator: Allocator, context: anytype) Allocator.Error!*BoxShadow {
        const items = try allocator.alloc(Shadow, self.items.len);
        var initialized: usize = 0;
        defer {
            for (items[0..initialized]) |item| item.release();
            allocator.free(items);
        }
        for (self.items, 0..) |item, index| {
            items[index] = try computeShadow(item, context);
            initialized += 1;
        }
        return createInternal(allocator, items, true);
    }

    /// CSSOM §9 / Color 4 §§15.5, 16: resolve colors against the receiver,
    /// leaving the immutable inherited lengths and symbolic colors intact.
    /// Absolute/selected-away graphs append cached text directly, allowing
    /// a preallocated output buffer to succeed with a failing allocator.
    pub fn serializeResolved(self: *const BoxShadow, current: Color, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        std.debug.assert(self.computed);
        if (!self.containsCurrentColor()) return out.appendSlice(allocator, self.text.bytes);
        for (self.items, 0..) |item, index| {
            if (index != 0) try out.appendSlice(allocator, ", ");
            try item.serialize(out, allocator, true, current);
        }
    }
};

/// Parse Backgrounds 3 §6.1 `none | <shadow>#`; null means invalid grammar,
/// while allocation failure propagates. The outer declaration parser owns
/// CSS-wide keywords, Syntax 3 EOF repair, and the complete-input check.
pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    // Quirks Appendices: this property has neither unitless-length nor
    // hashless-color quirks. Keep every other parsing/provenance option.
    var strict = options;
    strict.quirks = false;

    // §6.1 (1): none represents no shadows, not a layer in a list.
    if (stream.peek().token_type == .ident and tokenizer.nameEql(stream.peek().value, "none")) {
        _ = stream.next();
        return Value.kw(.none);
    }

    // §6.1 (2): preserve front-to-back list order with no fixed layer cap.
    var items: std.ArrayList(Shadow) = .empty;
    defer {
        for (items.items) |item| item.release();
        items.deinit(options.allocator);
    }
    while (true) {
        const item = try parseShadow(strict, stream) orelse return null;
        errdefer item.release();
        try items.append(options.allocator, item);
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
        // The next iteration must supply a full shadow, so empty and
        // trailing comma layers reject and release the entire prefix.
    }
    return .{ .box_shadow = try BoxShadow.create(options.allocator, items.items) };
}

fn parseShadow(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Shadow {
    var result: Shadow = .{};
    var moved = false;
    defer if (!moved) result.release();
    while (true) {
        const token = stream.peek();
        if (token.token_type == .eof or token.token_type == .comma) break;

        // §6.1 (3): color and inset are unordered single groups around one
        // mandatory, adjacent group of two to four lengths.
        if (token.token_type == .ident and tokenizer.nameEql(token.value, "inset")) {
            if (result.inset) return null;
            result.inset = true;
            _ = stream.next();
            continue;
        }
        if (result.color == null) {
            const checkpoint = stream.*;
            if (try parseColor(options, stream)) |color| {
                result.color = color;
                continue;
            }
            stream.* = checkpoint;
        }
        if (result.count != 0) return null;
        while (result.count < 4) {
            const checkpoint = stream.*;
            const value = try parseLength(options, stream, result.count == 2) orelse {
                stream.* = checkpoint;
                break;
            };
            result.lengths[result.count] = value;
            result.count += 1;
        }
        if (result.count < 2) return null;
    }
    if (result.count < 2) return null;
    moved = true;
    return result;
}

fn parseColor(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Color {
    const value = try properties.parseLonghand(options, .color, stream) orelse return null;
    // Transfer the owned Color from the temporary tagged Value.
    std.debug.assert(value == .color);
    return value.color;
}

fn parseLength(options: properties.ParseOptions, stream: *properties.Stream, blur: bool) Allocator.Error!?Value {
    // §6.1 (4) / Values 4 §10.12: reject negative literal blur, but admit
    // negative calculations and clamp their TOP-LEVEL computed result.
    const token = stream.peek();
    if (math.isFunction(token)) return properties.mathValue(options, stream, .{
        .kind = .length,
        .minimum = if (blur) 0 else -std.math.floatMax(f64),
    });
    if (blur) if (token.numeric_value) |number| if (number < 0) return null;
    // Strict public <length>, including extended units. No percentages,
    // auto, anchors, or another property's compatibility quirks.
    return properties.parseLonghand(options, .outline_offset, stream);
}

fn computeShadow(shadow: Shadow, context: anytype) Allocator.Error!Shadow {
    var result = Shadow{ .inset = shadow.inset };
    errdefer result.release();
    // §6.1 (5): synthesized defaults use the same owner computation as
    // authored values. No parent/source/context pointer escapes this call.
    result.color = try context.color(shadow.color orelse .current);
    while (result.count < 4) : (result.count += 1) {
        result.lengths[result.count] = try context.length(if (result.count < shadow.count)
            shadow.lengths[result.count]
        else
            Value.px(0));
    }
    return result;
}
