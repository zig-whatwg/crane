//! Reflecting content attributes in IDL attributes (HTML 2.6.1), for an
//! element reflected target.
//!
//! Every [Reflect], [ReflectSetter], [ReflectURL], [ReflectNonNegative],
//! [ReflectPositive] and [ReflectPositiveWithFallback] attribute's generated
//! getter and setter end here when the impl does not implement them itself
//! (`src/webidl/codegen/reflect.zig` writes the call):
//!
//!     return try reflection.get(u32, instance, .{ .name = "colspan", .default = 1, .range = .{ 1, 1000 } });
//!
//! The IDL type picks the algorithm; `Spec` carries the reflected content
//! attribute name and the [ReflectURL], [ReflectNonNegative],
//! [ReflectPositive], [ReflectPositiveWithFallback], [ReflectDefault] and
//! [ReflectRange] modifiers.
//!
//! The element's attributes are reached through its interface, never an impl
//! (AGENTS.md "The impls boundary"). "Get the content attribute" is "get an
//! attribute by namespace and local name" with a null namespace, so it is
//! `getAttributeNS(null, name)` - not `getAttribute(name)`, which matches on
//! qualified name and would find a namespaced attribute whose qualified name
//! happens to be `name`. Setting and deleting are `setAttributeNS(null, ...)`
//! and `removeAttributeNS(null, ...)` for the same reason.
//!
//! Not here: an ElementInternals reflected target (its element's internal
//! content attribute map - codegen reflects nothing on it), `Element?` and
//! `FrozenArray<Element>?` (they hold explicitly set attr-elements), and
//! "limited to only known values" (no [Reflect*] attribute in the IDL is an
//! enumerated one; those are written out by hand).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const URLRecord = @import("url_record").URLRecord;

const DOMString = runtime.DOMString;
const USVString = runtime.USVString;

/// Which "limited to only ..." a numeric reflection is.
pub const Limit = enum {
    none,
    /// [ReflectNonNegative] (long): "limited to only non-negative numbers".
    non_negative,
    /// [ReflectPositive] (unsigned long, double): "limited to only positive
    /// numbers".
    positive,
    /// [ReflectPositiveWithFallback] (unsigned long): "limited to only
    /// positive numbers with fallback".
    positive_with_fallback,
};

/// One reflected attribute, as the generated code states it.
pub const Spec = struct {
    /// The reflected content attribute name.
    name: []const u8,
    /// [ReflectURL]: "treated as a URL".
    url: bool = false,
    limit: Limit = .none,
    /// [ReflectDefault]. An f64 holds every integer default (long, unsigned
    /// long) exactly, and the decimal a double one takes.
    default: ?f64 = null,
    /// [ReflectRange] (unsigned long): "clamped to the range [min, max]".
    range: ?[2]u32 = null,
};

/// The getter steps of a reflected IDL attribute of Zig type `T`.
///
/// A string result is the caller's: script's binding frees it, and a Zig
/// caller must (docs/lessons/architecture-interface-getters-clone-and-hand-you-the-memory.md).
pub fn get(comptime T: type, instance: *runtime.Instance, comptime spec: Spec) !T {
    return switch (T) {
        DOMString => getString(instance, spec),
        ?DOMString => getNullableString(instance, spec),
        USVString => getUSVString(instance, spec),
        bool => getBoolean(instance, spec),
        i32 => getLong(instance, spec),
        u32 => getUnsignedLong(instance, spec),
        f64 => getDouble(instance, spec),
        *runtime.Instance => getTokenList(instance, spec),
        else => @compileError("HTML 2.6.1 reflection of Zig type " ++ @typeName(T) ++ " is not implemented"),
    };
}

/// The setter steps of a reflected IDL attribute of Zig type `T`.
pub fn set(comptime T: type, instance: *runtime.Instance, comptime spec: Spec, value: T) !void {
    return switch (T) {
        DOMString => setContentAttribute(instance, spec.name, value.asSlice()),
        ?DOMString => setNullableString(instance, spec, value),
        USVString => setContentAttribute(instance, spec.name, value),
        bool => setBoolean(instance, spec, value),
        i32 => setLong(instance, spec, value),
        u32 => setUnsignedLong(instance, spec, value),
        f64 => setDouble(instance, spec, value),
        else => @compileError("HTML 2.6.1 reflection of Zig type " ++ @typeName(T) ++ " is not implemented"),
    };
}

// ---------------------------------------------------------------------------
// The element reflected target's four algorithms
// ---------------------------------------------------------------------------

/// "Get the content attribute": the value of the attribute whose namespace is
/// null and local name is `name`, or null. The returned DOMString is released
/// with `instance.ctx.allocator` (a no-op for the borrowed view the DOM hands
/// out today; correct should it ever hand out a copy).
fn getContentAttribute(instance: *runtime.Instance, comptime name: []const u8) !?DOMString {
    return interfaces.Element.call_getAttributeNS(instance, null, DOMString.initInterned(name));
}

/// "Set the content attribute" with `value`: set an attribute value given
/// the element, `name` and `value`. The DOM copies `value`.
fn setContentAttribute(instance: *runtime.Instance, comptime name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttributeNS(instance, null, DOMString.initInterned(name), DOMString.initInterned(value));
}

/// "Delete the content attribute".
fn deleteContentAttribute(instance: *runtime.Instance, comptime name: []const u8) !void {
    try interfaces.Element.call_removeAttributeNS(instance, null, DOMString.initInterned(name));
}

// ---------------------------------------------------------------------------
// DOMString, DOMString?, USVString
// ---------------------------------------------------------------------------

/// DOMString getter. Steps 3-4 (enumerated, limited to only known values) do
/// not apply: see the module comment.
fn getString(instance: *runtime.Instance, comptime spec: Spec) !DOMString {
    const allocator = instance.ctx.allocator;
    // [ReflectURL] on a DOMString (HTMLObjectElement.codeBase, which the IDL
    // declares so): the URL steps, as a DOMString.
    if (spec.url) {
        const url = try urlString(instance, spec);
        // Allocated for the caller unless empty, so it is the DOMString's own.
        return if (url.len == 0) DOMString.initEmpty() else DOMString.initOwned(@constCast(url));
    }
    // Step 2.
    var value = try getContentAttribute(instance, spec.name) orelse {
        // Step 5: "If contentAttributeValue is null, then return the empty
        // string."
        return DOMString.initEmpty();
    };
    defer value.deinit(allocator);
    // Step 6: a copy the caller owns.
    return DOMString.initDupe(allocator, value.asSlice());
}

/// DOMString? getter: the value, or null. No [Reflect*] DOMString? attribute
/// is enumerated (step 4).
fn getNullableString(instance: *runtime.Instance, comptime spec: Spec) !?DOMString {
    var value = try getContentAttribute(instance, spec.name) orelse return null;
    defer value.deinit(instance.ctx.allocator);
    return try DOMString.initDupe(instance.ctx.allocator, value.asSlice());
}

/// DOMString? setter.
fn setNullableString(instance: *runtime.Instance, comptime spec: Spec, value: ?DOMString) !void {
    // Step 1: "If the given value is null, then run this's delete the content
    // attribute."
    const given = value orelse return deleteContentAttribute(instance, spec.name);
    // Step 2: "Otherwise, run this's set the content attribute with the given
    // value."
    try setContentAttribute(instance, spec.name, given.asSlice());
}

/// USVString getter, optionally treated as a URL. Owned by
/// `instance.ctx.allocator` unless empty.
fn getUSVString(instance: *runtime.Instance, comptime spec: Spec) !USVString {
    if (spec.url) return urlString(instance, spec);
    // Step 2.
    var value = try getContentAttribute(instance, spec.name) orelse {
        // A null here reaches step 4 with nothing to convert: the steps have
        // no null check outside the URL case (3.1), and every engine returns
        // the empty string, as the non-nullable type requires.
        return "";
    };
    defer value.deinit(instance.ctx.allocator);
    // Step 4: "Return contentAttributeValue, converted to a scalar value
    // string."
    return scalarValueString(instance.ctx.allocator, value.asSlice());
}

/// The "treated as a URL" steps (USVString getter step 3, then step 4),
/// owned by `instance.ctx.allocator` unless empty.
fn urlString(instance: *runtime.Instance, comptime spec: Spec) ![]const u8 {
    // Steps 1-2.
    var value = try getContentAttribute(instance, spec.name) orelse {
        // Step 3.1: "If contentAttributeValue is null, then return the empty
        // string."
        return "";
    };
    defer value.deinit(instance.ctx.allocator);
    // Steps 3.2-3.3: "Let urlString be the result of
    // encoding-parsing-and-serializing a URL given contentAttributeValue,
    // relative to element's node document. If urlString is not failure, then
    // return urlString."
    if (try encodingParseAndSerialize(instance, value.asSlice())) |url| return url;
    // Step 4.
    return scalarValueString(instance.ctx.allocator, value.asSlice());
}

/// HTML "encoding-parsing-and-serializing a URL" given `input`, relative to
/// `element`'s node document: the URL parser run against the document base
/// URL, serialized - or null for failure. Owned by `element.ctx.allocator`.
///
/// Deviation, stated: "encoding-parsing" uses the document's character
/// encoding for the query; this parses as UTF-8, which is every document's
/// encoding but a legacy one's. Crane's other encoding-parse sites
/// (script src, window.open) do the same.
fn encodingParseAndSerialize(element: *runtime.Instance, input: []const u8) !?[]const u8 {
    const allocator = element.ctx.allocator;
    // "the document base URL" of the element's node document, which Node's
    // baseURI serializes. Owned by the element's context allocator.
    const base = interfaces.Node.get_baseURI(element) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => "",
    };
    defer if (base.len > 0) allocator.free(base);

    var base_record: ?URLRecord = if (base.len > 0) api_parser.parseURL(allocator, base, null) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => null,
    } else null;
    defer if (base_record) |*record| record.deinit();

    var record = api_parser.parseURL(allocator, input, if (base_record) |*record| record else null) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
    defer record.deinit();
    return try url_serializer.serialize(allocator, &record, false);
}

/// Infra "convert to a scalar value string": every lone surrogate - WTF-8 in
/// Crane's strings - becomes U+FFFD. Owned by `allocator` unless empty.
fn scalarValueString(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    if (value.len == 0) return "";
    return std.unicode.wtf8ToUtf8LossyAlloc(allocator, value) catch |err| switch (err) {
        error.OutOfMemory => return err,
        // Not WTF-8 at all: the replacement is per byte sequence; copying it
        // unchanged is the least surprising of the wrong answers.
        error.InvalidWtf8 => try allocator.dupe(u8, value),
    };
}

// ---------------------------------------------------------------------------
// boolean
// ---------------------------------------------------------------------------

/// boolean getter: "If contentAttributeValue is null, then return false.
/// Return true." Presence is all that counts - `disabled="false"` is true.
fn getBoolean(instance: *runtime.Instance, comptime spec: Spec) !bool {
    return interfaces.Element.call_hasAttributeNS(instance, null, DOMString.initInterned(spec.name));
}

/// boolean setter.
fn setBoolean(instance: *runtime.Instance, comptime spec: Spec, value: bool) !void {
    // Step 1: false deletes the content attribute; step 2: true sets it to
    // the empty string.
    if (value) {
        try setContentAttribute(instance, spec.name, "");
    } else {
        try deleteContentAttribute(instance, spec.name);
    }
}

// ---------------------------------------------------------------------------
// long
// ---------------------------------------------------------------------------

/// long getter, optionally limited to only non-negative numbers, optionally
/// with a default value.
fn getLong(instance: *runtime.Instance, comptime spec: Spec) !i32 {
    comptime std.debug.assert(spec.limit == .none or spec.limit == .non_negative);
    // Step 1.
    var content = try getContentAttribute(instance, spec.name);
    defer if (content) |*c| c.deinit(instance.ctx.allocator);
    // Step 2.
    if (content) |value| {
        // Step 2.1.
        const parsed = if (spec.limit == .non_negative)
            parseNonNegativeInteger(value.asSlice())
        else
            parseInteger(value.asSlice());
        // Step 2.2: "If parsedValue is not an error and is within the long
        // range, then return parsedValue."
        if (parsed) |n| {
            if (n >= std.math.minInt(i32) and n <= std.math.maxInt(i32)) return @intCast(n);
        }
    }
    // Step 3.
    if (spec.default) |d| return @intFromFloat(d);
    // Step 4.
    if (spec.limit == .non_negative) return -1;
    // Step 5.
    return 0;
}

/// long setter.
fn setLong(instance: *runtime.Instance, comptime spec: Spec, value: i32) !void {
    // Step 1: "If the reflected IDL attribute is limited to only non-negative
    // numbers and the given value is negative, then throw an
    // "IndexSizeError" DOMException."
    if (spec.limit == .non_negative and value < 0) return error.IndexSizeError;
    // Step 2: the shortest valid integer - `{d}` is exactly that.
    var buffer: [16]u8 = undefined;
    try setContentAttribute(instance, spec.name, std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable);
}

// ---------------------------------------------------------------------------
// unsigned long
// ---------------------------------------------------------------------------

/// The largest value an unsigned long reflection returns or writes: the long
/// range's, so a value survives a round trip through a signed attribute.
const max_unsigned_long_reflected: u32 = 2147483647;

/// The minimum of the unsigned long getter steps 2-4 and setter steps 2-3.
fn unsignedMinimum(comptime spec: Spec, comptime clamped: bool) u32 {
    var minimum: u32 = 0;
    if (spec.limit == .positive or spec.limit == .positive_with_fallback) minimum = 1;
    if (clamped) if (spec.range) |range| {
        minimum = range[0];
    };
    return minimum;
}

/// unsigned long getter, optionally limited to only positive numbers (with
/// or without fallback) or clamped to a range, optionally with a default.
fn getUnsignedLong(instance: *runtime.Instance, comptime spec: Spec) !u32 {
    comptime std.debug.assert(spec.limit != .non_negative);
    // Step 1.
    var content = try getContentAttribute(instance, spec.name);
    defer if (content) |*c| c.deinit(instance.ctx.allocator);
    // Steps 2-4.
    const minimum = comptime unsignedMinimum(spec, true);
    // Step 5.
    const maximum: u32 = if (spec.range) |range| range[1] else max_unsigned_long_reflected;
    // Step 6.
    if (content) |value| {
        // Step 6.1.
        if (parseNonNegativeInteger(value.asSlice())) |n| {
            // Step 6.2: in range.
            if (n >= minimum and n <= maximum) return @intCast(n);
            // Step 6.3: clamped.
            if (spec.range != null) {
                if (n < minimum) return minimum;
                return maximum;
            }
        }
    }
    // Step 7.
    if (spec.default) |d| return @intFromFloat(d);
    // Step 8.
    return minimum;
}

/// unsigned long setter. "Clamped to the range has no effect on the setter
/// steps."
fn setUnsignedLong(instance: *runtime.Instance, comptime spec: Spec, value: u32) !void {
    // Step 1: "If the reflected IDL attribute is limited to only positive
    // numbers and the given value is 0, then throw an "IndexSizeError"
    // DOMException."
    if (spec.limit == .positive and value == 0) return error.IndexSizeError;
    // Steps 2-3.
    const minimum = comptime unsignedMinimum(spec, false);
    // Step 4.
    var new_value: u32 = minimum;
    // Step 5.
    if (spec.default) |d| new_value = @intFromFloat(d);
    // Step 6.
    if (value >= minimum and value <= max_unsigned_long_reflected) new_value = value;
    // Step 7: the shortest valid non-negative integer.
    var buffer: [16]u8 = undefined;
    try setContentAttribute(instance, spec.name, std.fmt.bufPrint(&buffer, "{d}", .{new_value}) catch unreachable);
}

// ---------------------------------------------------------------------------
// double
// ---------------------------------------------------------------------------

/// double getter, optionally limited to only positive numbers, optionally
/// with a default.
fn getDouble(instance: *runtime.Instance, comptime spec: Spec) !f64 {
    comptime std.debug.assert(spec.limit == .none or spec.limit == .positive);
    // Step 1.
    var content = try getContentAttribute(instance, spec.name);
    defer if (content) |*c| c.deinit(instance.ctx.allocator);
    // Step 2.
    if (content) |value| {
        // Step 2.1.
        if (parseFloatingPoint(value.asSlice())) |parsed| {
            // Step 2.2.
            if (parsed > 0) return parsed;
            // Step 2.3.
            if (spec.limit != .positive) return parsed;
        }
    }
    // Step 3.
    if (spec.default) |d| return d;
    // Step 4.
    return 0;
}

/// double setter. Infinity and NaN never arrive: WebIDL's `double`
/// conversion throws a TypeError for them first.
fn setDouble(instance: *runtime.Instance, comptime spec: Spec, value: f64) !void {
    // Step 1: "If the reflected IDL attribute is limited to only positive
    // numbers and the given value is not greater than 0, then return."
    if (spec.limit == .positive and !(value > 0)) return;
    // Step 2: "the best representation of the number as a floating-point
    // number".
    var buffer: [32]u8 = undefined;
    try setContentAttribute(instance, spec.name, numberToString(&buffer, value));
}

// ---------------------------------------------------------------------------
// DOMTokenList
// ---------------------------------------------------------------------------

/// DOMTokenList getter: "a DOMTokenList object whose associated element is
/// this and associated attribute's local name is the reflected content
/// attribute name". Its setter is [PutForwards=value], which the generated
/// interface writes, so there is none here.
///
/// A new list per call: every such attribute is [SameObject], and the
/// generated getter caches the first one it is handed.
fn getTokenList(instance: *runtime.Instance, comptime spec: Spec) !*runtime.Instance {
    const list = try interfaces.DOMTokenList.init(instance.ctx.allocator, instance.ctx);
    errdefer interfaces.DOMTokenList.deinit(list);
    // DOMTokenList.init installed the association this needs.
    try dom.token_lists.associate(list, instance, spec.name);
    return list;
}

// ---------------------------------------------------------------------------
// HTML 2.3.4 Numbers
// ---------------------------------------------------------------------------

/// Infra's ASCII whitespace: TAB, LF, FF, CR and SPACE. Not
/// `std.ascii.isWhitespace`, which also takes VT - and "\u000B7" is an
/// error to the rules below, not 7.
fn isAsciiWhitespace(c: u8) bool {
    return c == '\t' or c == '\n' or c == 0x0C or c == '\r' or c == ' ';
}

/// HTML 2.3.4.1 "rules for parsing integers"; null is an error. The value
/// saturates at the i64 range, which is far outside every range a caller
/// checks it against, so a saturated value is out of range exactly when the
/// true one is.
pub fn parseInteger(input: []const u8) ?i64 {
    // Step 2.
    var position: usize = 0;
    // Step 3.
    var negative = false;
    // Step 4: skip ASCII whitespace.
    while (position < input.len and isAsciiWhitespace(input[position])) position += 1;
    // Step 5.
    if (position >= input.len) return null;
    // Step 6.
    if (input[position] == '-') {
        negative = true;
        position += 1;
        if (position >= input.len) return null;
    } else if (input[position] == '+') {
        position += 1;
        if (position >= input.len) return null;
    }
    // Step 7.
    if (!std.ascii.isDigit(input[position])) return null;
    // Step 8: collect ASCII digits, as a base-ten integer.
    var value: i64 = 0;
    while (position < input.len and std.ascii.isDigit(input[position])) : (position += 1) {
        value = value *| 10 +| @as(i64, input[position] - '0');
    }
    // Step 9.
    return if (negative) -value else value;
}

/// HTML 2.3.4.2 "rules for parsing non-negative integers"; null is an error.
pub fn parseNonNegativeInteger(input: []const u8) ?i64 {
    // Steps 2-3.
    const value = parseInteger(input) orelse return null;
    // Step 4: "-0" is zero, not negative.
    if (value < 0) return null;
    // Step 5.
    return value;
}

/// HTML 2.3.4.3 "rules for parsing floating-point number values"; null is
/// an error.
///
/// Steps 1-14 find the number's digits, fraction and exponent; steps 15-18
/// round the exact value to the nearest double, ties to even, with 2^1024 as
/// the overflow point. That is IEEE 754 round-to-nearest, which
/// `std.fmt.parseFloat` computes exactly from the same digits - so this
/// collects them and hands it a normalized string, rather than accumulating
/// `value += digit / divisor` in floating point, which would round at every
/// digit.
pub fn parseFloatingPoint(input: []const u8) ?f64 {
    // Step 2.
    var position: usize = 0;
    // Steps 3-5 are carried as `negative`, `integer`, `fraction`, `exponent`.
    var negative = false;
    var integer: []const u8 = "";
    var fraction: []const u8 = "";
    var exponent: i64 = 0;
    // Step 6.
    while (position < input.len and isAsciiWhitespace(input[position])) position += 1;
    // Step 7.
    if (position >= input.len) return null;
    // Step 8.
    if (input[position] == '-') {
        negative = true;
        position += 1;
        if (position >= input.len) return null;
    } else if (input[position] == '+') {
        position += 1;
        if (position >= input.len) return null;
    }
    // Step 9: ".5" starts at the fraction, with a value of zero.
    const starts_with_fraction = input[position] == '.' and position + 1 < input.len and std.ascii.isDigit(input[position + 1]);
    if (!starts_with_fraction) {
        // Step 10.
        if (!std.ascii.isDigit(input[position])) return null;
        // Step 11.
        const start = position;
        while (position < input.len and std.ascii.isDigit(input[position])) position += 1;
        integer = input[start..position];
    }
    conversion: {
        // Step 12.
        if (position >= input.len) break :conversion;
        // Step 13, "fraction".
        if (input[position] == '.') {
            // 13.1.
            position += 1;
            // 13.2: nothing that continues a number follows the point.
            if (position >= input.len) break :conversion;
            const c = input[position];
            if (!std.ascii.isDigit(c) and c != 'e' and c != 'E') break :conversion;
            // 13.3 skips to step 14 for an exponent; 13.4-13.8 collect the
            // fraction's digits.
            if (std.ascii.isDigit(c)) {
                const start = position;
                while (position < input.len and std.ascii.isDigit(input[position])) position += 1;
                fraction = input[start..position];
                // 13.7.
                if (position >= input.len) break :conversion;
            }
        }
        // Step 14.
        if (input[position] == 'e' or input[position] == 'E') {
            // 14.1-14.2.
            position += 1;
            if (position >= input.len) break :conversion;
            // 14.3.
            var exponent_negative = false;
            if (input[position] == '-') {
                exponent_negative = true;
                position += 1;
                if (position >= input.len) break :conversion;
            } else if (input[position] == '+') {
                position += 1;
                if (position >= input.len) break :conversion;
            }
            // 14.4: "1e x" ignores the e.
            if (!std.ascii.isDigit(input[position])) break :conversion;
            // 14.5-14.6.
            var magnitude: i64 = 0;
            while (position < input.len and std.ascii.isDigit(input[position])) : (position += 1) {
                magnitude = magnitude *| 10 +| @as(i64, input[position] - '0');
            }
            exponent = if (exponent_negative) -magnitude else magnitude;
        }
    }

    // Steps 15-18. The exponent is clamped where it no longer changes the
    // result for any digit string shorter than the clamp.
    const clamped = std.math.clamp(exponent, -1_000_000, 1_000_000);
    var fallback = std.heap.stackFallback(256, std.heap.page_allocator);
    const allocator = fallback.get();
    const text = std.fmt.allocPrint(allocator, "{s}{s}.{s}e{d}", .{
        if (negative) "-" else "",
        if (integer.len > 0) integer else "0",
        if (fraction.len > 0) fraction else "0",
        clamped,
    }) catch return null;
    defer allocator.free(text);
    const value = std.fmt.parseFloat(f64, text) catch return null;
    // Step 17: 2^1024 and -2^1024 are errors.
    if (std.math.isInf(value)) return null;
    // Step 16: S has no -0.
    if (value == 0) return 0;
    // Step 18.
    return value;
}

/// ECMA-262 Number::toString(x) (radix 10): "the best representation of the
/// number as a floating-point number" (HTML 2.3.4.3). The digits are the
/// shortest that round-trip, the closest of those to `x` - which is what
/// Ryu, behind `std.fmt.float`, produces; the layout is ECMAScript's, which
/// `{d}` is not (1e21 is "1e+21", 1e-7 is "1e-7").
pub fn numberToString(buffer: *[32]u8, x: f64) []const u8 {
    // Steps 1-3.
    if (std.math.isNan(x)) return "NaN";
    if (x == 0) return "0";
    if (std.math.isInf(x)) return if (x < 0) "-Infinity" else "Infinity";

    // Step 5: k digits, and n with x = 0.d1..dk * 10^n.
    var scientific: [std.fmt.float.bufferSize(.scientific, f64)]u8 = undefined;
    const rendered = std.fmt.float.render(&scientific, @abs(x), .{ .mode = .scientific }) catch unreachable;
    const e_at = std.mem.indexOfScalar(u8, rendered, 'e').?;
    var digits: [20]u8 = undefined;
    var k: usize = 0;
    for (rendered[0..e_at]) |c| {
        if (c == '.') continue;
        digits[k] = c;
        k += 1;
    }
    while (k > 1 and digits[k - 1] == '0') k -= 1;
    const n: i32 = (std.fmt.parseInt(i32, rendered[e_at + 1 ..], 10) catch unreachable) + 1;

    var w = std.Io.Writer.fixed(buffer);
    // Step 4.
    if (x < 0) w.writeByte('-') catch unreachable;
    const kk: i32 = @intCast(k);
    if (kk <= n and n <= 21) {
        // Step 6: the digits, then n - k zeros.
        w.writeAll(digits[0..k]) catch unreachable;
        w.splatByteAll('0', @intCast(n - kk)) catch unreachable;
    } else if (0 < n and n <= 21) {
        // Step 7: the first n digits, a point, the rest.
        const point: usize = @intCast(n);
        w.writeAll(digits[0..point]) catch unreachable;
        w.writeByte('.') catch unreachable;
        w.writeAll(digits[point..k]) catch unreachable;
    } else if (-6 < n and n <= 0) {
        // Step 8: "0.", -n zeros, the digits.
        w.writeAll("0.") catch unreachable;
        w.splatByteAll('0', @intCast(-n)) catch unreachable;
        w.writeAll(digits[0..k]) catch unreachable;
    } else {
        // Steps 9-10: exponential, with the exponent's sign always written.
        const e = n - 1;
        w.writeByte(digits[0]) catch unreachable;
        if (k > 1) {
            w.writeByte('.') catch unreachable;
            w.writeAll(digits[1..k]) catch unreachable;
        }
        w.print("e{c}{d}", .{ @as(u8, if (e < 0) '-' else '+'), @abs(e) }) catch unreachable;
    }
    return w.buffered();
}
