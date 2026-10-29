//! A keyframe effect's keyframes (Web Animations 1 5.3.1): "process a
//! keyframes argument" (6.6.3), "compute missing keyframe offsets" (5.3.3),
//! the property names of 6.6.2, and the objects getKeyframes() returns.
//!
//! Values are kept as written in CSS after the property's own grammar
//! accepted them (6.6.3 step 8.1 "parse the property value using the syntax
//! specified for that property ... If the property value is invalid, discard
//! the property-value pair"): the CSS module parses and serializes them
//! (css.declarations), so getKeyframes() returns the serialization of the
//! specified value, as the browsers do. Applying them to style (5.3.2-5.3.4,
//! the effect stack) is a later piece.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#processing-a-keyframes-argument
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const css = @import("css");
const easing_mod = @import("easing.zig");

const Allocator = std.mem.Allocator;
const JSValue = runtime.JSValue;

pub const CompositeOrAuto = enum { replace, add, accumulate, auto };

/// One animation property-value pair: the property's CSS name (a custom
/// property's as written) and its value serialized. Both OWNED.
pub const Property = struct {
    name: []u8,
    value: []u8,
};

pub const Keyframe = struct {
    /// 5.3.1 the keyframe offset; null for one spaced automatically.
    offset: ?f64 = null,
    /// 5.3.3 the computed keyframe offset.
    computed_offset: f64 = 0,
    /// The keyframe-specific easing function. OWNED.
    easing: easing_mod.Easing = .{},
    /// The keyframe-specific composite operation; `.auto` is unset.
    composite: CompositeOrAuto = .auto,
    properties: std.ArrayListUnmanaged(Property) = .empty,

    fn deinit(self: *Keyframe, allocator: Allocator) void {
        self.easing.deinit(allocator);
        for (self.properties.items) |property| {
            allocator.free(property.name);
            allocator.free(property.value);
        }
        self.properties.deinit(allocator);
    }

    fn clone(self: *const Keyframe, allocator: Allocator) Allocator.Error!Keyframe {
        var copy: Keyframe = .{ .offset = self.offset, .computed_offset = self.computed_offset, .composite = self.composite };
        errdefer copy.deinit(allocator);
        copy.easing = try self.easing.clone(allocator);
        try copy.properties.ensureTotalCapacity(allocator, self.properties.items.len);
        for (self.properties.items) |property| {
            const name = try allocator.dupe(u8, property.name);
            errdefer allocator.free(name);
            const value = try allocator.dupe(u8, property.value);
            copy.properties.appendAssumeCapacity(.{ .name = name, .value = value });
        }
        return copy;
    }
};

/// A keyframe effect's keyframes, loosely sorted by offset.
pub const List = struct {
    frames: std.ArrayListUnmanaged(Keyframe) = .empty,

    pub fn deinit(self: *List, allocator: Allocator) void {
        for (self.frames.items) |*frame| frame.deinit(allocator);
        self.frames.deinit(allocator);
        self.* = .{};
    }

    pub fn clone(self: *const List, allocator: Allocator) Allocator.Error!List {
        var copy: List = .{};
        errdefer copy.deinit(allocator);
        try copy.frames.ensureTotalCapacity(allocator, self.frames.items.len);
        for (self.frames.items) |*frame| copy.frames.appendAssumeCapacity(try frame.clone(allocator));
        return copy;
    }
};

// ============================================================================
// 6.6.2 Property names and IDL names
// ============================================================================

/// "IDL attribute name to animation property name" (6.6.2), into `out`:
/// null when `attribute` names no animatable property by its IDL name.
fn animationPropertyName(attribute: []const u8, buffer: []u8) ?[]const u8 {
    // 1. A custom property is its own name.
    if (isCustomPropertyName(attribute)) return attribute;
    // 2-3.
    if (std.mem.eql(u8, attribute, "cssFloat")) return "float";
    if (std.mem.eql(u8, attribute, "cssOffset")) return "offset";
    // 4. CSSOM "IDL attribute to CSS property".
    var len: usize = 0;
    if (std.mem.startsWith(u8, attribute, "webkit")) {
        if (len >= buffer.len) return null;
        buffer[len] = '-';
        len += 1;
    }
    for (attribute) |c| {
        if (std.ascii.isUpper(c)) {
            if (len + 2 > buffer.len) return null;
            buffer[len] = '-';
            buffer[len + 1] = std.ascii.toLower(c);
            len += 2;
        } else {
            if (len >= buffer.len) return null;
            buffer[len] = c;
            len += 1;
        }
    }
    const name = buffer[0..len];
    // Only the attribute names CSSOM derives from a property are keys of
    // "animatable properties" (6.6.3 step 3.2): `background-color` and
    // `float` are not, `backgroundColor` and `cssFloat` are.
    var check: [64]u8 = undefined;
    const back = idlAttributeName(name, &check) orelse return null;
    if (!std.mem.eql(u8, back, attribute)) return null;
    const property = css.properties.lookup(name) orelse return null;
    if (!isAnimatable(property)) return null;
    return name;
}

/// "Animation property name to IDL attribute name" (6.6.2).
pub fn idlAttributeName(property: []const u8, buffer: []u8) ?[]const u8 {
    if (isCustomPropertyName(property)) return property;
    if (std.mem.eql(u8, property, "float")) return "cssFloat";
    if (std.mem.eql(u8, property, "offset")) return "cssOffset";
    // CSSOM "CSS property to IDL attribute", with the lowercase first flag
    // for a -webkit- name.
    var source = property;
    if (std.mem.startsWith(u8, property, "-webkit-")) source = property[1..];
    var len: usize = 0;
    var upper = false;
    for (source) |c| {
        if (c == '-') {
            upper = true;
            continue;
        }
        if (len >= buffer.len) return null;
        buffer[len] = if (upper) std.ascii.toUpper(c) else c;
        upper = false;
        len += 1;
    }
    return buffer[0..len];
}

fn isCustomPropertyName(name: []const u8) bool {
    return name.len > 2 and std.mem.startsWith(u8, name, "--");
}

/// Web Animations 5.2: the properties whose Animation type is "not
/// animatable" - the animation and transition parameters, and those that
/// would change what animates (Blink CSSAnimations::
/// IsAnimationAffectingProperty, Gecko's nsCSSProps::IsAnimatable).
fn isAnimatable(property: css.properties.Property) bool {
    const name = switch (property) {
        .longhand => |l| l.name(),
        .shorthand => |s| s.name(),
    };
    if (std.mem.startsWith(u8, name, "animation") or std.mem.startsWith(u8, name, "transition")) return false;
    if (std.mem.startsWith(u8, name, "scroll-timeline") or std.mem.startsWith(u8, name, "view-timeline")) return false;
    const not_animatable = [_][]const u8{
        "direction",      "unicode-bidi", "writing-mode", "text-orientation", "text-combine-upright",
        "will-change",    "contain",      "container",    "container-name",   "container-type",
        "timeline-scope", "all",
    };
    for (not_animatable) |n| if (std.mem.eql(u8, name, n)) return false;
    return true;
}

// ============================================================================
// 6.6.3 Processing a keyframes argument
// ============================================================================

pub const Error = engine.Error || error{TypeError};

/// "Process a keyframes argument" for `object` (null: no keyframes).
/// Exceptions script throws while it is read come back as
/// `error.ExceptionPending`; the algorithm's own as `error.TypeError`.
pub fn process(realm: runtime.Context, allocator: Allocator, object: ?JSValue) Error!List {
    // 1.
    const input = object orelse return .{};
    if (isNullish(realm, input)) return .{};
    // 2.
    var processed: Builder = .{ .allocator = allocator, .realm = realm };
    errdefer processed.deinit();
    // 3-5.
    const iterated = try engine.iterate(realm, input, Builder.eachKeyframe, &processed);
    if (!iterated) try processed.propertyIndexed(input);
    var list = processed.finish();
    errdefer list.deinit(allocator);
    // 6. "If processed keyframes is not loosely sorted by offset, throw a
    // TypeError."
    var previous: ?f64 = null;
    for (list.frames.items) |frame| {
        const offset = frame.offset orelse continue;
        if (previous) |p| if (offset < p) return error.TypeError;
        previous = offset;
    }
    // 7.
    for (list.frames.items) |frame| {
        const offset = frame.offset orelse continue;
        if (offset < 0 or offset > 1) return error.TypeError;
    }
    // 8. Values were parsed with their grammar as they were read; the
    // easings are parsed now, after every read.
    for (list.frames.items, processed.easing_texts.items) |*frame, text| {
        frame.easing = (try easing_mod.parse(allocator, text)) orelse return error.TypeError;
    }
    // 9. "unused easings".
    for (processed.unused_easings.items) |text| {
        var parsed = (try easing_mod.parse(allocator, text)) orelse return error.TypeError;
        parsed.deinit(allocator);
    }
    processed.freeTexts();
    computeMissingOffsets(list.frames.items);
    return list;
}

/// 5.3.3 "compute missing keyframe offsets".
pub fn computeMissingOffsets(frames: []Keyframe) void {
    if (frames.len == 0) return;
    // 1. (NaN stands for null while computing.)
    for (frames) |*frame| frame.computed_offset = frame.offset orelse std.math.nan(f64);
    // 2.
    if (frames.len > 1 and std.math.isNan(frames[0].computed_offset)) frames[0].computed_offset = 0;
    // 3.
    if (std.math.isNan(frames[frames.len - 1].computed_offset)) frames[frames.len - 1].computed_offset = 1;
    // 4.
    var a: usize = 0;
    while (a < frames.len) {
        if (std.math.isNan(frames[a].computed_offset)) {
            a += 1;
            continue;
        }
        var b = a + 1;
        while (b < frames.len and std.math.isNan(frames[b].computed_offset)) b += 1;
        if (b >= frames.len) break;
        const n: f64 = @floatFromInt(b - a);
        const start = frames[a].computed_offset;
        const end = frames[b].computed_offset;
        var k = a + 1;
        while (k < b) : (k += 1) {
            const index: f64 = @floatFromInt(k - a);
            frames[k].computed_offset = start + (end - start) * index / n;
        }
        a = b;
    }
}

/// The steps' working state: the keyframes, and the easing strings, which
/// 6.6.3 step 8 parses after every property has been read.
const Builder = struct {
    allocator: Allocator,
    realm: runtime.Context,
    frames: std.ArrayListUnmanaged(Keyframe) = .empty,
    easing_texts: std.ArrayListUnmanaged([]u8) = .empty,
    unused_easings: std.ArrayListUnmanaged([]u8) = .empty,

    fn deinit(self: *Builder) void {
        for (self.frames.items) |*frame| frame.deinit(self.allocator);
        self.frames.deinit(self.allocator);
        self.freeTexts();
    }

    fn freeTexts(self: *Builder) void {
        for (self.easing_texts.items) |text| self.allocator.free(text);
        self.easing_texts.deinit(self.allocator);
        for (self.unused_easings.items) |text| self.allocator.free(text);
        self.unused_easings.deinit(self.allocator);
        self.easing_texts = .empty;
        self.unused_easings = .empty;
    }

    fn finish(self: *Builder) List {
        const list: List = .{ .frames = self.frames };
        self.frames = .empty;
        return list;
    }

    /// 5.3.6-5.3.7 for one item of an iterable.
    fn eachKeyframe(data: ?*anyopaque, item: JSValue) engine.Error!void {
        const self: *Builder = @ptrCast(@alignCast(data.?));
        // 6. "If Type(nextItem) is not Undefined, Null or Object, throw a
        // TypeError."
        const kind = engine.typeOf(self.realm, item);
        if (kind != .undefined and kind != .null and kind != .object) return error.TypeError;
        // 7.
        try self.keyframeLike(item);
    }

    /// "Process a keyframe-like object" with allow lists false, appended.
    fn keyframeLike(self: *Builder, input: JSValue) engine.Error!void {
        var frame: Keyframe = .{};
        errdefer frame.deinit(self.allocator);
        // 1. BaseKeyframe, members in order: composite, easing, offset.
        const composite = try self.member(input, "composite");
        defer if (composite) |value| value.release();
        if (composite) |value| frame.composite = compositeOf(self.realm, value.borrow()) catch |err| return mapError(err);
        const easing = try self.member(input, "easing");
        defer if (easing) |value| value.release();
        const easing_text = if (easing) |value| try engine.convertToDOMString(self.realm, value.borrow(), self.allocator) else try self.allocator.dupe(u8, "linear");
        errdefer self.allocator.free(easing_text);
        const offset = try self.member(input, "offset");
        defer if (offset) |value| value.release();
        if (offset) |value| frame.offset = nullableDouble(self.realm, value.borrow()) catch |err| return mapError(err);
        // 2-8.
        if (!isNullish(self.realm, input)) try self.readProperties(input, &frame, false);
        try self.easing_texts.ensureUnusedCapacity(self.allocator, 1);
        try self.frames.append(self.allocator, frame);
        self.easing_texts.appendAssumeCapacity(easing_text);
    }

    /// The property-indexed form (6.6.3 step 5, "Otherwise").
    fn propertyIndexed(self: *Builder, input: JSValue) engine.Error!void {
        // A non-object is no dictionary (WebIDL dictionary conversion).
        const kind = engine.typeOf(self.realm, input);
        if (kind != .object) return error.TypeError;
        // 1. BasePropertyIndexedKeyframe.
        var composites: std.ArrayListUnmanaged(CompositeOrAuto) = .empty;
        defer composites.deinit(self.allocator);
        var easings: std.ArrayListUnmanaged([]u8) = .empty;
        defer {
            for (easings.items) |text| self.allocator.free(text);
            easings.deinit(self.allocator);
        }
        var offsets: std.ArrayListUnmanaged(?f64) = .empty;
        defer offsets.deinit(self.allocator);
        if (try self.member(input, "composite")) |value| {
            defer value.release();
            try self.listOrOne(CompositeOrAuto, value.borrow(), &composites, compositeOf);
        }
        if (try self.member(input, "easing")) |value| {
            defer value.release();
            try self.listOrOne([]u8, value.borrow(), &easings, domString);
        }
        if (try self.member(input, "offset")) |value| {
            defer value.release();
            // (double? or sequence<double?>): null is the nullable double.
            if (isNullish(self.realm, value.borrow())) try offsets.append(self.allocator, null) else try self.listOrOne(?f64, value.borrow(), &offsets, nullableDouble);
        }
        // The property values, each a list.
        var indexed: Keyframe = .{};
        defer indexed.deinit(self.allocator);
        var lists: std.ArrayListUnmanaged([][]u8) = .empty;
        defer {
            for (lists.items) |list| {
                for (list) |text| self.allocator.free(text);
                self.allocator.free(list);
            }
            lists.deinit(self.allocator);
        }
        try self.readIndexedProperties(input, &indexed, &lists);
        // 2. Each property's own keyframes, offsets computed per property.
        var processed: std.ArrayListUnmanaged(Keyframe) = .empty;
        defer {
            for (processed.items) |*frame| frame.deinit(self.allocator);
            processed.deinit(self.allocator);
        }
        for (indexed.properties.items, lists.items) |property, values| {
            const first = processed.items.len;
            for (values) |value| {
                var frame: Keyframe = .{};
                errdefer frame.deinit(self.allocator);
                if (try parsedValue(self.allocator, property.name, value)) |serialized| {
                    errdefer self.allocator.free(serialized);
                    const name = try self.allocator.dupe(u8, property.name);
                    errdefer self.allocator.free(name);
                    try frame.properties.append(self.allocator, .{ .name = name, .value = serialized });
                }
                try processed.append(self.allocator, frame);
            }
            computeMissingOffsets(processed.items[first..]);
        }
        // 3. Sort by computed offset (stable).
        std.sort.block(Keyframe, processed.items, {}, struct {
            fn lessThan(_: void, a: Keyframe, b: Keyframe) bool {
                return a.computed_offset < b.computed_offset;
            }
        }.lessThan);
        // 4. Merge adjacent keyframes with equal computed offsets.
        var merged: std.ArrayListUnmanaged(Keyframe) = .empty;
        errdefer {
            for (merged.items) |*frame| frame.deinit(self.allocator);
            merged.deinit(self.allocator);
        }
        for (processed.items) |*frame| {
            if (merged.items.len != 0 and merged.items[merged.items.len - 1].computed_offset == frame.computed_offset) {
                const into = &merged.items[merged.items.len - 1];
                try into.properties.appendSlice(self.allocator, frame.properties.items);
                frame.properties.clearRetainingCapacity();
                continue;
            }
            try merged.append(self.allocator, .{ .computed_offset = frame.computed_offset, .properties = frame.properties });
            frame.properties = .empty;
        }
        // 5-6. Offsets, by position.
        for (merged.items, 0..) |*frame, i| {
            frame.offset = if (i < offsets.items.len) offsets.items[i] else null;
        }
        // 7-11. Easings, repeated; the excess kept as unused.
        if (easings.items.len == 0) try easings.append(self.allocator, try self.allocator.dupe(u8, "linear"));
        try self.easing_texts.ensureUnusedCapacity(self.allocator, merged.items.len);
        for (merged.items, 0..) |_, i| {
            self.easing_texts.appendAssumeCapacity(try self.allocator.dupe(u8, easings.items[i % easings.items.len]));
        }
        if (easings.items.len > merged.items.len) {
            for (easings.items[merged.items.len..]) |text| try self.unused_easings.append(self.allocator, try self.allocator.dupe(u8, text));
        }
        // 12. Composites, repeated; auto leaves the keyframe's unset.
        if (composites.items.len != 0) {
            for (merged.items, 0..) |*frame, i| frame.composite = composites.items[i % composites.items.len];
        }
        try self.frames.appendSlice(self.allocator, merged.items);
        merged.deinit(self.allocator);
        merged = .empty;
    }

    /// A dictionary member: Get(input, name), null when undefined (not
    /// present). OWNED.
    fn member(self: *Builder, input: JSValue, name: []const u8) engine.Error!?engine.Owned {
        if (isNullish(self.realm, input)) return null;
        const value = try engine.getProperty(self.realm, input, name);
        if (engine.typeOf(self.realm, value.borrow()) == .undefined) {
            value.release();
            return null;
        }
        return value;
    }

    /// 6.6.3 "process a keyframe-like object" steps 3-8, allow lists false:
    /// the animation properties, read in code point order, each value parsed
    /// with its property's grammar and discarded when invalid (step 8.1).
    fn readProperties(self: *Builder, input: JSValue, frame: *Keyframe, comptime _: bool) engine.Error!void {
        const names = try self.animationProperties(input);
        defer self.freeNames(names);
        for (names) |entry| {
            const raw = try engine.getProperty(self.realm, input, entry.attribute);
            defer raw.release();
            const text = try engine.convertToDOMString(self.realm, raw.borrow(), self.allocator);
            defer self.allocator.free(text);
            const serialized = (try parsedValue(self.allocator, entry.property, text)) orelse continue;
            errdefer self.allocator.free(serialized);
            const name = try self.allocator.dupe(u8, entry.property);
            errdefer self.allocator.free(name);
            try frame.properties.append(self.allocator, .{ .name = name, .value = serialized });
        }
    }

    /// The same with allow lists true: each value a DOMString or a sequence
    /// of them, kept unparsed until each becomes a keyframe.
    fn readIndexedProperties(self: *Builder, input: JSValue, indexed: *Keyframe, lists: *std.ArrayListUnmanaged([][]u8)) engine.Error!void {
        const names = try self.animationProperties(input);
        defer self.freeNames(names);
        for (names) |entry| {
            const raw = try engine.getProperty(self.realm, input, entry.attribute);
            defer raw.release();
            var values: std.ArrayListUnmanaged([]u8) = .empty;
            errdefer {
                for (values.items) |text| self.allocator.free(text);
                values.deinit(self.allocator);
            }
            try self.listOrOne([]u8, raw.borrow(), &values, domString);
            const name = try self.allocator.dupe(u8, entry.property);
            errdefer self.allocator.free(name);
            const empty = try self.allocator.alloc(u8, 0);
            errdefer self.allocator.free(empty);
            try lists.ensureUnusedCapacity(self.allocator, 1);
            try indexed.properties.append(self.allocator, .{ .name = name, .value = empty });
            lists.appendAssumeCapacity(try values.toOwnedSlice(self.allocator));
        }
    }

    const Name = struct { attribute: []u8, property: []u8 };

    /// Steps 3-6: the input's enumerable own names that are animatable
    /// properties' IDL names or custom property names, sorted by code point.
    fn animationProperties(self: *Builder, input: JSValue) engine.Error![]Name {
        const keys = try engine.enumerableOwnPropertyKeys(self.realm, input, self.allocator);
        defer {
            for (keys) |key| self.allocator.free(key);
            self.allocator.free(keys);
        }
        var names: std.ArrayListUnmanaged(Name) = .empty;
        errdefer self.freeNames(names.items);
        for (keys) |key| {
            var buffer: [64]u8 = undefined;
            const property = animationPropertyName(key, &buffer) orelse continue;
            const attribute = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(attribute);
            const css_name = try self.allocator.dupe(u8, property);
            errdefer self.allocator.free(css_name);
            try names.append(self.allocator, .{ .attribute = attribute, .property = css_name });
        }
        std.mem.sort(Name, names.items, {}, struct {
            fn lessThan(_: void, a: Name, b: Name) bool {
                return std.mem.lessThan(u8, a.attribute, b.attribute);
            }
        }.lessThan);
        return names.toOwnedSlice(self.allocator);
    }

    fn freeNames(self: *Builder, names: []const Name) void {
        for (names) |entry| {
            self.allocator.free(entry.attribute);
            self.allocator.free(entry.property);
        }
        self.allocator.free(names);
    }

    /// A WebIDL (T or sequence<T>) member: an iterable object is the
    /// sequence; anything else the one T.
    fn listOrOne(self: *Builder, comptime T: type, value: JSValue, out: *std.ArrayListUnmanaged(T), comptime convert: fn (runtime.Context, JSValue) anyerror!T) engine.Error!void {
        const Collect = struct {
            builder: *Builder,
            out: *std.ArrayListUnmanaged(T),
            fn each(data: ?*anyopaque, item: JSValue) engine.Error!void {
                const collect: *@This() = @ptrCast(@alignCast(data.?));
                const converted = convertAs(T, convert, collect.builder, item) catch |err| return mapError(err);
                collect.out.append(collect.builder.allocator, converted) catch return error.OutOfMemory;
            }
        };
        if (engine.typeOf(self.realm, value) == .object) {
            var collect: Collect = .{ .builder = self, .out = out };
            if (try engine.iterate(self.realm, value, Collect.each, &collect)) return;
        }
        const one = convertAs(T, convert, self, value) catch |err| return mapError(err);
        try out.append(self.allocator, one);
    }

    fn convertAs(comptime T: type, comptime convert: fn (runtime.Context, JSValue) anyerror!T, self: *Builder, value: JSValue) anyerror!T {
        if (T == []u8) return engine.convertToDOMString(self.realm, value, self.allocator);
        return convert(self.realm, value);
    }
};

fn isNullish(realm: runtime.Context, value: JSValue) bool {
    const kind = engine.typeOf(realm, value);
    return kind == .null or kind == .undefined;
}

fn mapError(err: anyerror) engine.Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError => error.TypeError,
        error.ExceptionPending => error.ExceptionPending,
        else => error.OperationFailed,
    };
}

fn domString(_: runtime.Context, _: JSValue) anyerror![]u8 {
    unreachable; // convertAs converts DOMStrings with the builder's allocator.
}

/// CompositeOperationOrAuto: ToString, then one of the enumeration's values.
fn compositeOf(realm: runtime.Context, value: JSValue) anyerror!CompositeOrAuto {
    var buffer: [16]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const text = engine.convertToDOMString(realm, value, fixed.allocator()) catch |err| switch (err) {
        error.OutOfMemory => return error.TypeError,
        else => return err,
    };
    inline for (.{ "replace", "add", "accumulate", "auto" }, 0..) |name, i| {
        if (std.mem.eql(u8, text, name)) return @enumFromInt(i);
    }
    return error.TypeError;
}

/// double?: null is null; any other value converts, and must be finite.
fn nullableDouble(realm: runtime.Context, value: JSValue) anyerror!?f64 {
    if (isNullish(realm, value)) return null;
    const number = try engine.convertToUnrestrictedDouble(realm, value);
    if (!std.math.isFinite(number)) return error.TypeError;
    return number;
}

/// `value` parsed with `property`'s grammar (6.6.3 step 8.1) and serialized;
/// null when the grammar rejects it. OWNED.
fn parsedValue(allocator: Allocator, property: []const u8, value: []const u8) Allocator.Error!?[]u8 {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    if (!try block.setProperty(.{ .allocator = allocator }, property, value, "")) return null;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try block.getPropertyValue(property, &out);
    return try out.toOwnedSlice(allocator);
}

// ============================================================================
// getKeyframes()
// ============================================================================

/// The objects getKeyframes() returns (6.6, steps 3-4), as a new Array of
/// `realm`. OWNED.
pub fn toObjects(realm: runtime.Context, allocator: Allocator, list: *const List) !engine.Owned {
    var objects: std.ArrayListUnmanaged(engine.Owned) = .empty;
    defer {
        for (objects.items) |object| object.release();
        objects.deinit(allocator);
    }
    var texts: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (texts.items) |text| allocator.free(text);
        texts.deinit(allocator);
    }
    for (list.frames.items) |*frame| {
        var members: std.ArrayListUnmanaged(runtime.DictionaryMember) = .empty;
        defer members.deinit(allocator);
        var easing_text: std.ArrayList(u8) = .empty;
        defer easing_text.deinit(allocator);
        try frame.easing.serialize(&easing_text, allocator);
        const composite_name: []const u8 = switch (frame.composite) {
            .replace => "replace",
            .add => "add",
            .accumulate => "accumulate",
            .auto => "auto",
        };
        try members.append(allocator, .{ .name = "offset", .value = if (frame.offset) |o| .{ .number = o } else .null });
        try members.append(allocator, .{ .name = "computedOffset", .value = .{ .number = frame.computed_offset } });
        try members.append(allocator, .{ .name = "easing", .value = JSValue.fromStringRef(easing_text.items) });
        try members.append(allocator, .{ .name = "composite", .value = JSValue.fromStringRef(composite_name) });
        for (frame.properties.items) |property| {
            var buffer: [64]u8 = undefined;
            const attribute = idlAttributeName(property.name, &buffer) orelse continue;
            const name = try allocator.dupe(u8, attribute);
            try texts.append(allocator, name);
            try members.append(allocator, .{ .name = name, .value = JSValue.fromStringRef(property.value) });
        }
        const object = try engine.createDictionaryObject(realm, members.items);
        try objects.append(allocator, object);
    }
    const values = try allocator.alloc(JSValue, objects.items.len);
    defer allocator.free(values);
    for (objects.items, values) |object, *value| value.* = object.borrow();
    return engine.createSequenceOfValues(realm, values);
}

test "property names map between IDL attributes and CSS properties (6.6.2)" {
    var buffer: [64]u8 = undefined;
    try std.testing.expectEqualStrings("background-color", animationPropertyName("backgroundColor", &buffer).?);
    try std.testing.expect(animationPropertyName("background-color", &buffer) == null);
    try std.testing.expectEqualStrings("float", animationPropertyName("cssFloat", &buffer).?);
    try std.testing.expect(animationPropertyName("float", &buffer) == null);
    try std.testing.expectEqualStrings("--x", animationPropertyName("--x", &buffer).?);
    try std.testing.expect(animationPropertyName("animationName", &buffer) == null);
    try std.testing.expect(animationPropertyName("transitionDuration", &buffer) == null);
    try std.testing.expect(animationPropertyName("display", &buffer) != null);
    try std.testing.expect(animationPropertyName("notAProperty", &buffer) == null);
    try std.testing.expectEqualStrings("marginLeft", idlAttributeName("margin-left", &buffer).?);
    try std.testing.expectEqualStrings("cssOffset", idlAttributeName("offset", &buffer).?);
}

test "missing offsets are spaced between their neighbours (5.3.3)" {
    var frames = [_]Keyframe{ .{}, .{ .offset = 0.5 }, .{}, .{}, .{} };
    computeMissingOffsets(&frames);
    try std.testing.expectEqual(@as(f64, 0), frames[0].computed_offset);
    try std.testing.expectEqual(@as(f64, 0.5), frames[1].computed_offset);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), frames[2].computed_offset, 1e-12);
    try std.testing.expectEqual(@as(f64, 1), frames[4].computed_offset);
    var single = [_]Keyframe{.{}};
    computeMissingOffsets(&single);
    try std.testing.expectEqual(@as(f64, 1), single[0].computed_offset);
}
