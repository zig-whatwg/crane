//! V8 Type Conversion Layer
//!
//! This module provides bidirectional type conversions between Zig WebIDL runtime types
//! and V8 JavaScript values. All conversions follow WebIDL specification semantics.
//!
//! ## Conversion Flow
//!
//! JavaScript (V8) ←→ Zig (WebIDL Runtime)
//!
//! Examples:
//! - v8::String → runtime.DOMString
//! - v8::Number → runtime.Double / runtime.Long
//! - v8::Array → runtime.sequence(T)
//! - v8::Object → runtime.record(K, V)
//! - v8::Value (any) → runtime.Any (opaque pointer)
//!
//! ## Error Handling
//!
//! Conversions can fail due to type mismatches or out-of-range values.
//! All conversion functions return error unions for proper error propagation.

const std = @import("std");
const log = std.log.scoped(.v8_conv);
const debug = @import("debug.zig");
const v8 = @import("ffi.zig");
const runtime = @import("runtime");
const interface_mod = @import("interface.zig");
const dom_type_info = @import("dom_type_info.zig");
const callback_wrapper = @import("callback_wrapper.zig");
const typedefs = @import("typedefs");
const js_value_mod = @import("js_value.zig");
const pointer_tag = @import("pointer_tag.zig");
const DebugAssertions = pointer_tag.DebugAssertions;
const global_handles = @import("global_handles.zig");
const value_operations = @import("value_operations.zig");
const protocol_engine = @import("engine");
const protocol_support = @import("protocol_support.zig");
const protocol_conversions = @import("protocol_conversions.zig");

/// What a callback-interface argument's wrapper is allocated from: a
/// general-purpose allocator, since the binding makes and frees one per call
/// (the page allocator it used spent a whole page on each). A test swaps in
/// `std.testing.allocator` to see that none outlives its call.
pub var callback_allocator: std.mem.Allocator = std.heap.c_allocator;

/// Release a callback interface argument (`*runtime.CallbackWrapper`) the
/// binding converted, once the call it was converted for has returned: the
/// wrapper, the argument's handle it took over, and its context handle.
pub fn releaseCallbackWrapper(argument: *runtime.CallbackWrapper) void {
    const wrapper: *callback_wrapper.CallbackWrapper = @ptrCast(@alignCast(argument));
    wrapper.deinit();
}

/// Type-safe JavaScript value representation
pub const JSValue = js_value_mod.JSValue;

/// Optional JSValue for WebIDL optional parameters
pub const OptionalJSValue = js_value_mod.OptionalJSValue;

/// Conversion errors that can occur during type conversion
pub const ConversionError = error{
    /// V8 value is not the expected type
    TypeError,

    /// Numeric value is out of range for target type
    RangeError,

    /// String contains invalid UTF-8 or violates constraints
    StringError,

    /// Memory allocation failed during conversion
    OutOfMemory,

    /// Context is required but was null
    NullContext,

    /// Failed to create a V8 Global handle for persistent storage
    GlobalHandleCreationFailed,

    /// A JavaScript exception is already pending in V8 (rethrown from conversion)
    /// When this error is returned, the caller should NOT throw another exception
    ExceptionPending,
};

// ============================================================================
// Helper Functions
// ============================================================================

/// The IDL string of a generated enum's `value`: codegen's `idl_values`
/// table, variant i's exact value at index i (generator.writeEnum). The
/// variant NAME cannot be turned back into it - `_back_forward_` is
/// "back_forward" and `_same_origin_` is "same-origin" - so an enum without
/// the table (one written by hand) falls back to the old rule: the name
/// without its wrapping underscores, the rest turned into hyphens.
pub fn idlEnumValue(comptime T: type, value: T) []const u8 {
    if (comptime @hasDecl(T, "idl_values")) {
        comptime std.debug.assert(T.idl_values.len == std.meta.fields(T).len);
        return T.idl_values[@intFromEnum(value)];
    }
    return switch (value) {
        inline else => |tag| comptime blk: {
            const name = @tagName(tag);
            var start: usize = 0;
            var end: usize = name.len;
            if (name.len > 0 and name[0] == '_') start = 1;
            if (end > start and name[end - 1] == '_') end -= 1;
            var out: [end - start]u8 = undefined;
            for (name[start..end], 0..) |c, i| out[i] = if (c == '_') '-' else c;
            const final = out;
            break :blk &final;
        },
    };
}

/// WebIDL 3.2.23 step 2: the variant of a generated enum whose value is
/// exactly `string` - `idl_values` again, compared code unit for code unit -
/// or null when it is none of them (the conversion's TypeError). An enum
/// without the table matches as before (`enumNameMatches`).
pub fn enumFromIdlValue(comptime T: type, string: []const u8) ?T {
    if (comptime @hasDecl(T, "idl_values")) {
        inline for (T.idl_values, 0..) |idl_value, i| {
            if (std.mem.eql(u8, idl_value, string)) return @enumFromInt(std.meta.fields(T)[i].value);
        }
        return null;
    }
    inline for (std.meta.fields(T)) |field| {
        if (enumNameMatches(field.name, string)) return @enumFromInt(field.value);
    }
    return null;
}

/// Check if a runtime enum name matches a comptime Zig enum field name.
/// Handles the transformation from WebIDL format ("same-origin", "text/html") to Zig format ("_same_origin_", "_text_html_"):
/// - Hyphens in the runtime name match underscores in the field name
/// - Slashes in the runtime name match underscores in the field name (e.g., "text/html" -> "text_html")
/// - Leading/trailing underscores in field name are ignored
fn enumNameMatches(comptime field_name: []const u8, runtime_name: []const u8) bool {
    // Get the normalized field name bounds (strip leading/trailing underscores)
    comptime var start: usize = 0;
    comptime var end: usize = field_name.len;
    if (field_name.len > 0 and field_name[0] == '_') start = 1;
    if (end > start and field_name[end - 1] == '_') end -= 1;
    const normalized_field = field_name[start..end];

    // Length must match
    if (normalized_field.len != runtime_name.len) return false;

    // Compare character by character, treating hyphens and slashes as underscores
    inline for (normalized_field, 0..) |fc, i| {
        const rc = runtime_name[i];
        // Field char is underscore, runtime char can be underscore, hyphen, or slash
        if (fc == '_') {
            if (rc != '_' and rc != '-' and rc != '/') return false;
        } else {
            if (fc != rc) return false;
        }
    }
    return true;
}

// ============================================================================
// JavaScript to Zig (V8 → Runtime)
// ============================================================================

/// WebIDL 3.2.11 USVString: convert to DOMString, then replace every lone
/// surrogate with U+FFFD - Infra's "convert a string into a scalar value
/// string" over the WTF-8 bytes V8 writes. ByteString shares the `[]const u8`
/// type and so passes through here too; WebIDL gives it a TypeError for any
/// code unit above 0xFF instead, which needs the two types told apart in
/// codegen.
pub const replaceLoneSurrogates = @import("infra").string.replaceLoneSurrogatesWtf8;

/// Convert V8 String to Zig DOMString
///
/// Allocates memory for the string contents using the provided allocator.
/// Caller must call DOMString.deinit() when done.
pub fn fromV8String(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.String,
) ConversionError!runtime.DOMString {
    _ = isolate;
    _ = context;

    // Get UTF-8 length (excludes null terminator)
    const length = v8.v8_String_Utf8Length(value);
    if (length < 0) {
        return ConversionError.StringError;
    }

    // Handle empty strings efficiently
    if (length == 0) {
        return runtime.DOMString.empty;
    }

    // Allocate buffer for UTF-8 data
    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);

    // Write UTF-8 to buffer
    const written = v8.v8_String_WriteUtf8(value, buffer.ptr, @intCast(length));
    if (written != length) {
        return ConversionError.StringError;
    }

    // Create DOMString from owned slice
    return runtime.DOMString.initOwned(buffer);
}

/// Convert V8 Value to Zig boolean
pub fn fromV8Boolean(
    isolate: *v8.Isolate,
    value: *v8.Value,
) runtime.Boolean {
    return v8.v8_Value_BooleanValue(value, isolate);
}

/// WebIDL ToNumber, the first step of converting to every numeric type: a
/// string, an object or a boolean is a number, not a TypeError. ToNumber
/// throws a TypeError for a Symbol or a BigInt. An object's valueOf can
/// throw too; NumberValue then answers NaN and V8 rethrows the pending
/// exception when the binding returns, so the call runs with that first - a
/// known gap.
fn toNumber(context: *v8.Context, value: *v8.Value) ConversionError!f64 {
    if (v8.v8_Value_IsSymbol(value) or v8.v8_Value_IsBigInt(value)) {
        return ConversionError.TypeError;
    }
    return v8.v8_Value_NumberValue(value, context);
}

/// WebIDL `long`: ToNumber, then ConvertToInt. These helpers used to reject
/// anything that was not already a number, which made `el.colSpan = "3"` a
/// TypeError on the attribute-setter path.
pub fn fromV8Long(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.Long {
    return convertToInt(runtime.Long, try toNumber(context, value));
}

/// WebIDL `unsigned long`: ToNumber, then ConvertToInt.
pub fn fromV8UnsignedLong(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.UnsignedLong {
    return convertToInt(runtime.UnsignedLong, try toNumber(context, value));
}

/// WebIDL § 3.2.4 ConvertToInt, steps 6-10, for a number `x` already
/// produced by ToNumber: NaN, +-0 and +-Infinity give 0; anything else is
/// truncated and wrapped modulo 2^bitLength, into the signed range for a
/// signed type. Never throws - that is [EnforceRange]'s job, not the default.
pub fn convertToInt(comptime T: type, x: f64) T {
    const info = @typeInfo(T).int;
    // Step 6
    if (std.math.isNan(x) or std.math.isInf(x) or x == 0) return 0;
    // Step 7: IntegerPart(x)
    const truncated = @trunc(x);
    // Steps 8-9: x modulo 2^bitLength, in [0, 2^bitLength), on exact
    // integers - a double modulo loses bits once the result needs more than
    // 53. A double of magnitude 2^116 or more is a multiple of 2^64, so it
    // wraps to 0; anything smaller fits an i128 exactly.
    if (@abs(truncated) >= 0x1p116) return 0;
    const whole: i128 = @intFromFloat(truncated);
    const wrapped: i128 = @mod(whole, @as(i128, 1) << info.bits);
    const Unsigned = std.meta.Int(.unsigned, info.bits);
    const bits: Unsigned = @intCast(wrapped);
    // Step 10: a value at or past 2^(bitLength-1) is negative - which is
    // exactly the two's-complement reading of the same bits.
    return @bitCast(bits);
}

/// Which of WebIDL 3.2.4 ConvertToInt's branches an integer conversion takes:
/// the default (`modulo`, steps 8-12), [EnforceRange] (step 6) or [Clamp]
/// (step 7). Codegen lists the arguments, attribute values and dictionary
/// members that carry either extended attribute (`enforce_range`, `clamp`,
/// `enforce_range_members`, `clamp_members`).
pub const IntegerConversion = enum { modulo, enforce_range, clamp };

/// WebIDL 3.2.4 ConvertToInt for `T`, given x = ToNumber(V) (step 4).
///
/// 1-3. bitLength, lowerBound and upperBound: for a 64-bit type the bounds
///      are those of a safe integer, [0, 2^53 - 1] unsigned and
///      [-(2^53 - 1), 2^53 - 1] signed; otherwise the type's own range.
/// 5.   -0 is +0 (no integer type holds a -0).
/// 6.   [EnforceRange]: NaN or an infinity is a TypeError; x = IntegerPart(x);
///      outside [lowerBound, upperBound] is a TypeError.
/// 7.   [Clamp], x not NaN: clamped to [lowerBound, upperBound], then rounded
///      to the nearest integer, ties to even.
/// 8-12. Otherwise `convertToInt` (NaN, +-0, +-Infinity give 0; modulo).
pub fn convertToIntAs(comptime T: type, comptime conversion: IntegerConversion, x: f64) ConversionError!T {
    const info = @typeInfo(T).int;
    // Steps 1-3.
    const safe: f64 = 0x1p53 - 1;
    const lower: f64 = if (info.signedness == .unsigned) 0 else if (info.bits == 64) -safe else @floatFromInt(std.math.minInt(T));
    const upper: f64 = if (info.bits == 64) safe else @floatFromInt(std.math.maxInt(T));
    switch (conversion) {
        .modulo => return convertToInt(T, x),
        .enforce_range => {
            // Step 6.1.
            if (std.math.isNan(x) or std.math.isInf(x)) return ConversionError.TypeError;
            // Step 6.2 (step 5's -0 truncates to 0 either way).
            const whole = @trunc(x);
            // Step 6.3.
            if (whole < lower or whole > upper) return ConversionError.TypeError;
            // Step 6.4.
            return @intFromFloat(whole);
        },
        .clamp => {
            // Step 7 applies only to a number; NaN goes to step 8 (0).
            if (std.math.isNan(x)) return 0;
            // Step 7.1.
            const clamped = @min(@max(x, lower), upper);
            // Step 7.2: round half to even, +0 rather than -0.
            const floor = @floor(clamped);
            const fraction = clamped - floor;
            const rounded = if (fraction < 0.5) floor else if (fraction > 0.5) floor + 1 else if (@mod(floor, 2) == 0) floor else floor + 1;
            // Step 7.3.
            return @intFromFloat(rounded);
        },
    }
}

/// An argument, attribute value or dictionary member of integer type `T` - or
/// a nullable form of one, or an optional argument (`webidl.Opt`) of either -
/// converted with `conversion`'s branch of ConvertToInt. A nullable's null and
/// undefined are null; an optional argument's undefined is "not passed", and
/// its null converts (0). Any other type converts as `fromV8Value` does.
pub fn fromV8ValueInteger(
    comptime T: type,
    comptime conversion: IntegerConversion,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!T {
    if (comptime conversion == .modulo) return fromV8Value(T, allocator, isolate, context, value);
    const info = @typeInfo(T);
    if (info == .int) {
        // Step 4: x = ? ToNumber(V) (a Symbol or a BigInt is a TypeError).
        return convertToIntAs(T, conversion, try toNumber(context, value));
    }
    if (info == .optional) {
        if (v8.v8_Value_IsNullOrUndefined(value)) return null;
        return try fromV8ValueInteger(info.optional.child, conversion, allocator, isolate, context, value);
    }
    if (info == .@"struct" and @hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed")) {
        // Only undefined is a missing optional argument; null converts
        // (ToNumber(null) is 0), as in fromV8Value's optional path.
        if (v8.v8_Value_IsUndefined(value)) return T.notPassed();
        return T.passed(try fromV8ValueInteger(@FieldType(T, "value"), conversion, allocator, isolate, context, value));
    }
    return fromV8Value(T, allocator, isolate, context, value);
}

/// The ConvertToInt branch dictionary `T`'s member `name` takes: codegen lists
/// [EnforceRange] and [Clamp] members in `enforce_range_members` and
/// `clamp_members`.
fn memberIntegerConversion(comptime T: type, comptime name: []const u8) IntegerConversion {
    comptime {
        if (@hasDecl(T, "enforce_range_members")) {
            for (T.enforce_range_members) |member| if (std.mem.eql(u8, member, name)) return .enforce_range;
        }
        if (@hasDecl(T, "clamp_members")) {
            for (T.clamp_members) |member| if (std.mem.eql(u8, member, name)) return .clamp;
        }
        return .modulo;
    }
}

/// WebIDL `long long`: ToNumber, then ConvertToInt (modulo 2^64).
pub fn fromV8LongLong(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.LongLong {
    return convertToInt(runtime.LongLong, try toNumber(context, value));
}

/// WebIDL `unsigned long long`: ToNumber, then ConvertToInt - a negative
/// number wraps, it does not throw.
pub fn fromV8UnsignedLongLong(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.UnsignedLongLong {
    return convertToInt(runtime.UnsignedLongLong, try toNumber(context, value));
}

/// WebIDL `double` and `unrestricted double`: ToNumber. Codegen maps both to
/// f64, so a restricted double's TypeError for NaN and the infinities is not
/// raised - it was not before either, since NaN is a number.
pub fn fromV8Double(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.Double {
    return toNumber(context, value);
}

/// WebIDL 3.2.7 `float` and 3.2.9 `double` - the restricted types - after the
/// conversion `fromV8Float`/`fromV8Double` share with their `unrestricted`
/// forms: "If x is NaN, +Infinity, or -Infinity, then throw a TypeError", and
/// for `float` also a value that rounds to +/-2^128 (float step 5), which is
/// what an f32 that came out infinite from a finite number is. `value` is the
/// converted value: an f64 or f32, its nullable form, an optional argument
/// (`webidl.Opt`), or a sequence of them. The binding calls this where codegen
/// marked a value restricted (`restricted_floats`, `restricted_members`).
pub fn requireFinite(comptime T: type, value: T) ConversionError!void {
    switch (@typeInfo(T)) {
        .float => if (!std.math.isFinite(value)) return ConversionError.TypeError,
        .optional => |o| if (value) |v| try requireFinite(o.child, v),
        .pointer => |ptr| if (comptime ptr.size == .slice) {
            for (value) |v| try requireFinite(ptr.child, v);
        },
        .@"struct" => if (comptime @hasField(T, "was_passed") and @hasField(T, "value")) {
            if (value.was_passed) try requireFinite(@FieldType(T, "value"), value.value);
        },
        else => {},
    }
}

/// WebIDL 3.2.11 step 2 for a value already converted as a string: "If the
/// value of any element of x is greater than 255, then throw a TypeError." The
/// string conversion ByteString shares with USVString (both `[]const u8`)
/// keeps every code unit above 0xFF as such in its WTF-8 - a lone surrogate
/// becomes U+FFFD, above 0xFF too - so the check reads the converted bytes
/// (`codeUnitsFitInByte`). `value` is a string, its nullable form, an
/// optional argument (`webidl.Opt`), or a sequence of them. The binding calls
/// this where codegen marked a value a ByteString (`byte_string_arguments`,
/// `byte_string_members`).
pub fn requireByteString(comptime T: type, value: T) ConversionError!void {
    switch (@typeInfo(T)) {
        .optional => |o| if (value) |v| try requireByteString(o.child, v),
        .pointer => |ptr| if (comptime ptr.size == .slice) {
            if (comptime ptr.child == u8) {
                if (!codeUnitsFitInByte(value)) return ConversionError.TypeError;
            } else {
                for (value) |v| try requireByteString(ptr.child, v);
            }
        },
        .@"struct" => if (comptime @hasField(T, "was_passed") and @hasField(T, "value")) {
            if (value.was_passed) try requireByteString(@FieldType(T, "value"), value.value);
        },
        else => {},
    }
}

/// WebIDL 3.2.11 steps 2-3, after the ordinary owned string conversion.
/// ByteString's elements are octets; USVString's identical Zig type remains
/// UTF-8. Validate the whole value first so a TypeError leaves it unchanged.
/// On allocation failure each part still has exactly one owned allocation,
/// and the caller's ordinary converted-value cleanup remains valid.
pub fn encodeByteStringOwned(comptime T: type, allocator: std.mem.Allocator, value: *T) ConversionError!void {
    try requireByteString(T, value.*);
    try encodeValidatedByteString(T, allocator, value);
}

fn encodeValidatedByteString(comptime T: type, allocator: std.mem.Allocator, value: *T) ConversionError!void {
    switch (@typeInfo(T)) {
        .optional => |optional| if (value.*) |*item| try encodeValidatedByteString(optional.child, allocator, item),
        .pointer => |pointer| if (comptime pointer.size == .slice) {
            if (comptime pointer.child == u8) {
                // ASCII already has one byte per code unit: keep the owned
                // conversion instead of allocating a second copy.
                for (value.*) |byte| {
                    if (byte >= 0x80) break;
                } else return;
                const encoded = @import("infra").bytes.isomorphicEncodeUtf8(allocator, value.*) catch |err| return switch (err) {
                    error.OutOfMemory => ConversionError.OutOfMemory,
                    else => ConversionError.TypeError,
                };
                allocator.free(value.*);
                value.* = encoded;
            } else {
                for (@constCast(value.*)) |*item| try encodeValidatedByteString(pointer.child, allocator, item);
            }
        },
        .@"struct" => if (comptime @hasField(T, "was_passed") and @hasField(T, "value")) {
            if (value.was_passed) try encodeValidatedByteString(@FieldType(T, "value"), allocator, &value.value);
        },
        else => {},
    }
}

/// WebIDL 3.2.14, object: "If V is not an Object, throw a TypeError" - for
/// a value already converted as `any` (both are runtime.JSValue, so codegen
/// marks the `object` positions: `object_arguments`, `object_members`). A
/// `.handle` refers to an object, a function or a Symbol - not an Object; an
/// `.instance` is a platform object; every other arm is a primitive. `value`
/// is a JSValue, its nullable form (null passes: `object?`), an optional
/// argument (`webidl.Opt`), or a sequence of them (each element: a
/// `sequence<object>`'s are converted first and checked after, so a later
/// element's iteration runs before an earlier one's TypeError).
pub fn requireObject(comptime T: type, value: T) ConversionError!void {
    if (comptime T == runtime.JSValue) {
        switch (value) {
            .handle => |h| if (!v8.v8_Value_IsObject(@ptrCast(@alignCast(h.ptr)))) return ConversionError.TypeError,
            .instance => {},
            else => return ConversionError.TypeError,
        }
        return;
    }
    switch (@typeInfo(T)) {
        .optional => |o| if (value) |v| try requireObject(o.child, v),
        .pointer => |ptr| if (comptime ptr.size == .slice) {
            for (value) |v| try requireObject(ptr.child, v);
        },
        .@"struct" => if (comptime @hasField(T, "was_passed") and @hasField(T, "value")) {
            if (value.was_passed) try requireObject(@FieldType(T, "value"), value.value);
        },
        else => {},
    }
}

/// Whether dictionary `T` lists member `name` in `object_members`.
fn isObjectMember(comptime T: type, comptime name: []const u8) bool {
    comptime {
        if (!@hasDecl(T, "object_members")) return false;
        for (T.object_members) |member| {
            if (std.mem.eql(u8, member, name)) return true;
        }
        return false;
    }
}

/// Whether dictionary `T` lists member `name` in `byte_string_members`.
fn isByteStringMember(comptime T: type, comptime name: []const u8) bool {
    comptime {
        if (!@hasDecl(T, "byte_string_members")) return false;
        for (T.byte_string_members) |member| {
            if (std.mem.eql(u8, member, name)) return true;
        }
        return false;
    }
}

/// The interface member `name` of struct `T` converts to. A dictionary's
/// members name their own (`memberInterface`). A struct converted with an
/// interface is a record's entry - codegen writes record<K, V> as a slice of
/// `struct { key: K, value: V }`, and lists the record by its values'
/// interface (`interface_arguments`) - so its `value` converts to that
/// interface. (A record is bound as such a slice and converted as one: a
/// record-typed argument is taken for a variadic argument of key/value
/// dictionaries - MLContext.dispatch's MLNamedTensors - a defect of its own,
/// left as it was; this keeps its values from being any platform object.)
fn structMemberInterface(comptime T: type, comptime Interface: ?type, comptime name: []const u8) ?type {
    comptime {
        if (Interface) |I| {
            if (!@hasField(T, "value")) @compileError(@typeName(T) ++ " converts with an interface but is no record entry");
            return if (std.mem.eql(u8, name, "value")) I else null;
        }
        return memberInterface(T, name);
    }
}

/// The interface dictionary `T`'s member `name` converts to - the one
/// `interface_members` names for it - or null for a member of no interface
/// type.
pub fn memberInterface(comptime T: type, comptime name: []const u8) ?type {
    comptime {
        @setEvalBranchQuota(100_000);
        if (!@hasDecl(T, "interface_members")) return null;
        for (T.interface_members) |member| {
            if (std.mem.eql(u8, member[0], name)) return interfaceNamed(member[1]);
        }
        return null;
    }
}

/// Whether dictionary `T` lists member `name` in `any_members` - or in
/// `jsvalue_union_members`, an inline union typed runtime.JSValue: for both,
/// a present null is `.null`, a value for the impl (WebIDL 3.2.18: only
/// undefined is not present; 3.2.25 converts a union's null by its arms -
/// SetHTMLOptions `{sanitizer: null}` is an empty SanitizerConfig, which read
/// as absent took the default preset).
fn isAnyMember(comptime T: type, comptime name: []const u8) bool {
    comptime {
        for ([_][]const u8{ "any_members", "jsvalue_union_members" }) |table| {
            if (@hasDecl(T, table)) {
                for (@field(T, table)) |member| {
                    if (std.mem.eql(u8, member, name)) return true;
                }
            }
        }
        return false;
    }
}

/// Whether dictionary `T`'s member `field`, present with the value null,
/// converts null by its type (WebIDL 3.2.18 step 4.1.4.3: only undefined is
/// "not present"; a present member's value converts by the member's type) -
/// true for an optional member the IDL does not type as nullable (codegen
/// lists the nullable ones in `nullable_members`) whose type converts null
/// here by its own rule: a string (ToString: "null"), a boolean (false), a
/// number (ToNumber: 0), an enumeration value ("null": a TypeError unless the
/// enumeration has it) or an interface (a TypeError). `{mode: null}` for a
/// LockOptions read as "no mode" (web-locks/acquire.https.any.js).
///
/// False by default: a required member (it converts null by its type
/// already), a nullable member, `any`, a `webidl.Opt` member (its presence
/// is its own), and a type this converter leaves to the impl - a union, a
/// sequence, a dictionary, a callback - which keeps reading a present null
/// as not present.
pub fn presentNullConvertsByType(comptime T: type, comptime field: std.builtin.Type.StructField) bool {
    comptime {
        const info = @typeInfo(field.type);
        if (info != .optional) return false;
        if (isAnyMember(T, field.name)) return false;
        if (@hasDecl(T, "nullable_members")) {
            for (T.nullable_members) |member| {
                if (std.mem.eql(u8, member, field.name)) return false;
            }
        }
        const Payload = info.optional.child;
        if (Payload == runtime.DOMString or Payload == runtime.USVString or Payload == runtime.ByteString) return true;
        if (Payload == *runtime.Instance) return true;
        return switch (@typeInfo(Payload)) {
            .bool, .int, .float, .@"enum" => true,
            else => false,
        };
    }
}

/// Whether dictionary `T` lists member `name` in `restricted_members`.
fn isRestrictedMember(comptime T: type, comptime name: []const u8) bool {
    comptime {
        if (!@hasDecl(T, "restricted_members")) return false;
        for (T.restricted_members) |member| {
            if (std.mem.eql(u8, member, name)) return true;
        }
        return false;
    }
}

/// Convert V8 Value to Zig f32 (float)
pub fn fromV8Float(
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.Float {
    const double = try fromV8Double(context, value);
    return @floatCast(double);
}

/// Convert V8 Value to runtime.Any (opaque pointer)
///
/// The V8 value is type-erased and stored as an opaque pointer.
/// This is used for WebIDL 'any' type parameters.
pub fn fromV8Any(value: *v8.Value) runtime.Any {
    return @ptrCast(value);
}

/// Convert V8 Object to runtime.Object (opaque pointer)
pub fn fromV8Object(value: *v8.Object) runtime.Object {
    return @ptrCast(value);
}

/// Convert V8 Value to JSValue (type-safe)
///
/// This is the preferred way to convert V8 values for WebIDL 'any' type.
/// Unlike fromV8Any, this preserves type information and eliminates the need
/// for unsafe pointer tagging or sentinel values.
///
/// ## Return Values
/// - Primitives (undefined, null, boolean, number) are stored directly
/// - Wrapped Zig instances return `.instance` variant
/// - Functions and objects needing persistence return `.global` variant
/// - Other values return `.local` variant (temporary, scope-bound)
///
/// ## Example
/// ```zig
/// const js_value = try fromV8ValueTyped(v8_value, isolate, context);
/// defer js_value.deinit(allocator); // Clean up if needed
///
/// switch (js_value) {
///     .undefined_value => // handle undefined,
///     .instance => |inst| // use Zig instance,
///     .global => |g| // use V8 object/function,
///     // ...
/// }
/// ```
pub fn fromV8ValueTyped(
    value: *v8.Value,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!JSValue {
    // Check for undefined
    if (v8.v8_Value_IsUndefined(value)) {
        return JSValue.jsUndefined;
    }

    // Check for null
    if (v8.v8_Value_IsNull(value)) {
        return JSValue.jsNull;
    }

    // Check for boolean (optimize: no allocation needed)
    if (v8.v8_Value_IsBoolean(value)) {
        return JSValue.fromBoolean(v8.v8_Value_BooleanValue(value, isolate));
    }

    // Check for number (optimize: no allocation needed)
    if (v8.v8_Value_IsNumber(value)) {
        return JSValue.fromNumber(v8.v8_Value_NumberValue(value, context));
    }

    // Check for object/function - look for wrapped Zig instance first
    if (v8.v8_Value_IsObject(value)) {
        const obj: *v8.Object = @ptrCast(value);
        const field_count = v8.v8_Object_InternalFieldCount(obj);

        // Check if this V8 object wraps a Zig instance
        if (field_count > 0) {
            if (v8.v8_Object_GetAlignedPointerFromInternalField(obj, 0)) |internal_ptr| {
                // This is a wrapped Zig instance - return it directly
                const instance: *runtime.Instance = @ptrCast(@alignCast(internal_ptr));
                return JSValue.fromInstance(instance);
            }
        }

        // Not a wrapped instance - the value IS already a Global handle
        // (from v8_FunctionCallbackInfo_GetArgument which creates and tracks a Global)
        // Just use it directly - no need to call v8_Value_ToGlobal
        return JSValue.fromGlobal(@ptrCast(value));
    }

    // For other values (strings, etc.) - return as local handle
    // NOTE: Local handles are only valid within the current HandleScope!
    return JSValue.fromLocal(value);
}

/// Convert V8 Array to Zig sequence
///
/// Allocates memory for the sequence and converts each element.
/// Caller must free the returned slice when done.
pub fn fromV8Sequence(
    comptime T: type,
    /// The interface each element converts to, for an interface type's
    /// elements (`fromV8ValueAs`); null for any other element type.
    comptime Interface: ?type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    array: *v8.Array,
) ConversionError![]T {
    const length = v8.v8_Array_Length(array);
    const slice = try allocator.alloc(T, length);
    errdefer allocator.free(slice);
    // An element that fails ends the conversion with the ones before it
    // converted - their strings copied, a buffer source's reference kept -
    // and they are freed here, before the slice (errdefers run last first).
    // Kept, every sequence argument that failed part-way leaked them
    // (docs/lessons/architecture-a-conversion-that-fails-part-way-converted-the-rest.md).
    var converted: usize = 0;
    errdefer for (slice[0..converted]) |element| interface_mod.freeSequenceElement(T, allocator, element);

    for (0..length) |i| {
        // Use v8_Object_Get with integer key instead of v8_Array_Get to properly
        // walk the prototype chain for holey arrays. Per WebIDL spec, sequence
        // conversion must use [[Get]] which includes prototype lookup.
        //
        // Both handles are this loop's: the key goes once Get has read it,
        // and the element once its conversion is done with it - by the rule
        // the binding applies to an argument (`releaseElementHandle`). Kept,
        // they were two Globals per element of every sequence argument.
        const index_key = v8.v8_Integer_New(isolate, @intCast(i));
        defer v8.v8_Value_Dispose(@ptrCast(index_key));
        // Get fails only when it threw ("? Get"): the exception is pending.
        const v8_value = v8.v8_Object_Get(@ptrCast(array), context, @ptrCast(index_key)) orelse return ConversionError.ExceptionPending;
        const element = fromV8ValueAs(T, Interface, allocator, isolate, context, v8_value) catch |err| {
            if (comptime interface_mod.argHandleIsCopied(T) or interface_mod.argumentHandleIsKeptInValue(T)) v8.v8_Value_Dispose(v8_value);
            return err;
        };
        releaseElementHandle(T, element, v8_value);
        slice[i] = element;
        converted += 1;
    }

    return slice;
}

/// Release the handle `element` was converted from, when nothing refers to it
/// any more: always for a conversion that copies (`argHandleIsCopied`), and
/// for any other type when the value proves it (`conversionLeavesHandle`: an
/// `any`, an `object` arm or a buffer source that does not refer to it, a
/// null optional). An element that refers to it keeps it until the sequence
/// is freed (`interface.freeSequenceElement`). Any other value keeps it - the
/// conservative answer, as for an argument.
fn releaseElementHandle(comptime T: type, element: T, handle: *v8.Value) void {
    if (comptime interface_mod.argHandleIsCopied(T)) {
        v8.v8_Value_Dispose(handle);
    } else if (interface_mod.conversionLeavesHandle(T, element)) {
        v8.v8_Value_Dispose(handle);
    }
}

/// Convert V8 Object to WebIDL record<K,V>
///
/// Iterates over object properties and creates key-value pairs.
/// Caller must call record.deinit() when done.
pub fn fromV8Record(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    object: *v8.Object,
) ConversionError!runtime.record(K, V) {
    // Get own property names (excludes inherited properties)
    const names = v8.v8_Object_GetOwnPropertyNames(context, object) orelse {
        // If property enumeration fails, return empty record
        return runtime.record(K, V).init(allocator);
    };
    defer v8.v8_Array_Dispose(names);

    const length = v8.v8_Array_Length(names);
    var rec = try runtime.record(K, V).init(allocator);
    errdefer rec.deinit();

    for (0..length) |i| {
        // Get property name as V8 value
        const key_value = v8.v8_Array_Get(names, context, @intCast(i)) orelse continue;
        defer v8.v8_Value_Dispose(key_value);

        // Convert key from V8 to K type
        const key = try fromV8Value(K, allocator, isolate, context, key_value);
        errdefer if (K == runtime.DOMString or K == runtime.USVString or K == runtime.ByteString) {
            // Free string keys on error
            if (@TypeOf(key) == runtime.DOMString) key.deinit();
        };

        // Get property value from object
        const val_v8 = v8.v8_Object_Get(object, context, key_value) orelse {
            // Property disappeared between enumeration and access - skip it
            continue;
        };
        defer v8.v8_Value_Dispose(val_v8);

        // Convert value from V8 to V type
        const value = try fromV8Value(V, allocator, isolate, context, val_v8);
        errdefer if (V == runtime.DOMString or V == runtime.USVString or V == runtime.ByteString) {
            // Free string values on error
            if (@TypeOf(value) == runtime.DOMString) value.deinit();
        };

        // Add key-value pair to record
        try rec.put(key, value);
    }

    return rec;
}

/// Where the binding's conversions run, for the iteration steps the protocol
/// shares (`protocol_conversions.createSequence`): the caller's isolate and
/// context, nothing entered here.
const ConversionSite = struct {
    isolate: *v8.Isolate,
    ctx: *v8.Context,

    pub fn context(self: ConversionSite) *v8.Context {
        return self.ctx;
    }
};

/// A protocol error from the iteration steps as a conversion's: what script
/// threw stays pending, "throw a TypeError" is TypeError, and anything else
/// (the engine failing with nothing thrown) is a TypeError for the binding to
/// throw.
fn conversionErrorOf(err: anyerror) ConversionError {
    return switch (err) {
        error.ExceptionPending => ConversionError.ExceptionPending,
        error.OutOfMemory => ConversionError.OutOfMemory,
        else => ConversionError.TypeError,
    };
}

/// ToString(V)'s code units as WTF-8 (an unpaired surrogate keeps its
/// three-byte form): what V8's WriteUtf8 writes. OWNED; "" is the static
/// empty slice. A Symbol is ToString's TypeError; what a toString() throws
/// is left pending.
fn toStringBytes(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value) ConversionError![]u8 {
    if (v8.v8_Value_IsSymbol(value)) return ConversionError.TypeError;
    const result = v8.v8_Value_ToString_Safe(value, context);
    defer v8.v8_FreeToStringResult(result);
    if (result.exception) |exception| {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return ConversionError.ExceptionPending;
    }
    const string = result.value orelse return ConversionError.TypeError;
    const length = v8.v8_String_Utf8Length(string);
    if (length < 0) return ConversionError.StringError;
    if (length == 0) return @constCast(&[_]u8{});
    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);
    if (v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length)) != length) return ConversionError.StringError;
    return buffer;
}

/// Whether every code unit WTF-8 `bytes` encodes is at most 0xFF: no byte is
/// a lead byte of a longer form. U+0080..U+00FF are C2 or C3 and one
/// continuation byte; U+0100 and above, a surrogate included, start at C4.
pub fn codeUnitsFitInByte(bytes: []const u8) bool {
    for (bytes) |byte| {
        if (byte >= 0xC4) return false;
    }
    return true;
}

/// WebIDL 3.2.11, converting V to ByteString:
///
/// 1. Let x be ? ToString(V).
/// 2. If the value of any element of x is greater than 255, then throw a
///    TypeError.
/// 3. Return an IDL ByteString value whose length is the length of x, and
///    where the value of each element is the value of the corresponding
///    element of x.
///
/// Step 3's code units are held as raw bytes, one byte each. OWNED, as the
/// ordinary string conversion's result is (`interface.freeConvertedArg`).
pub fn fromV8ByteString(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value) ConversionError![]const u8 {
    // 1.
    var x: []const u8 = try toStringBytes(allocator, isolate, context, value);
    errdefer if (x.len > 0) allocator.free(x);
    // 2-3.
    try encodeByteStringOwned([]const u8, allocator, &x);
    return x;
}

/// ECMAScript GetMethod(V, %Symbol.iterator%) for an Object V: the method
/// (OWNED), or null when it is undefined or null. Not callable is a
/// TypeError; a getter's throw is left pending.
fn iteratorMethodOf(isolate: *v8.Isolate, context: *v8.Context, object: *v8.Value) ConversionError!?*v8.Value {
    const at: ConversionSite = .{ .isolate = isolate, .ctx = context };
    return protocol_support.getSymbolMethod(at, object, .iterator) catch |err| conversionErrorOf(err);
}

/// WebIDL 3.2.21.1 "create a sequence from an iterable" - `object` and its
/// @@iterator `method` (BORROWED) - each item converted by `convertItem`, in
/// turn: the item's conversion runs before the next IteratorStepValue, so
/// what it observes interleaves with the iterator as the spec says.
///
/// Each item's handle is released by the rule fromV8Sequence applies to an
/// element (`releaseElementHandle`). On failure the items converted so far
/// are freed (`interface.freeConvertedArg`), and the iterator is not closed:
/// the spec's conversion does not close it. The result is allocated at its
/// exact length, as `interface.freeConvertedArg` frees a sequence.
fn sequenceFromIterable(
    comptime T: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    object: *v8.Value,
    method: *v8.Value,
    comptime convertItem: fn (std.mem.Allocator, *v8.Isolate, *v8.Context, *v8.Value) ConversionError!T,
) ConversionError![]T {
    var items: std.ArrayListUnmanaged(T) = .empty;
    errdefer {
        for (items.items) |item| interface_mod.freeSequenceElement(T, allocator, item);
        items.deinit(allocator);
    }
    var failure: ?ConversionError = null;

    const Collect = struct {
        items: *std.ArrayListUnmanaged(T),
        failure: *?ConversionError,
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        context: *v8.Context,

        fn item(self: @This(), next: *v8.Value) protocol_engine.Error!void {
            // 3. Initialize S_i to the result of converting next to an IDL
            //    value of type T.
            const converted = convertItem(self.allocator, self.isolate, self.context, next) catch |err| {
                if (comptime interface_mod.argHandleIsCopied(T) or interface_mod.argumentHandleIsKeptInValue(T)) v8.v8_Value_Dispose(next);
                self.failure.* = err;
                return error.OperationFailed;
            };
            releaseElementHandle(T, converted, next);
            self.items.append(self.allocator, converted) catch {
                interface_mod.freeSequenceElement(T, self.allocator, converted);
                self.failure.* = ConversionError.OutOfMemory;
                return error.OutOfMemory;
            };
        }
    };

    const at: ConversionSite = .{ .isolate = isolate, .ctx = context };
    protocol_conversions.createSequence(at, object, method, allocator, Collect{
        .items = &items,
        .failure = &failure,
        .allocator = allocator,
        .isolate = isolate,
        .context = context,
    }, Collect.item) catch |err| return failure orelse conversionErrorOf(err);
    return items.toOwnedSlice(allocator);
}

/// `fromV8ValueAs` as a conversion `sequenceFromIterable` can call per item.
fn ItemConversion(comptime T: type, comptime Interface: ?type) type {
    return struct {
        fn convert(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value) ConversionError!T {
            return fromV8ValueAs(T, Interface, allocator, isolate, context, value);
        }
    };
}

/// WebIDL 3.2.21 step 4 for a sequence type `S` (a slice): "create a
/// sequence from V and method", `method` V's @@iterator (BORROWED). An Array
/// is read index by index (`fromV8Sequence`), as before: what its own
/// iterator yields, unless script replaced Array.prototype[@@iterator]. Blink
/// takes the same fast path for anything IsArray()
/// (NativeValueTraits<IDLSequence<T>>::NativeValue,
/// bindings/core/v8/native_value_traits_impl.h, crbug.com/715122). Any other
/// iterable - a Map, a Set, a generator, a platform object's iterator - is
/// iterated.
///
/// `Interface` is the interface each element converts to, for a sequence of
/// an interface type (`fromV8ValueAs`); null for any other element type.
fn sequenceFromMethod(comptime S: type, comptime Interface: ?type, allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value, method: *v8.Value) ConversionError!S {
    const Elem = @typeInfo(S).pointer.child;
    if (v8.v8_Value_IsArray(value)) return fromV8Sequence(Elem, Interface, allocator, isolate, context, @ptrCast(value));
    return sequenceFromIterable(Elem, allocator, isolate, context, value, method, ItemConversion(Elem, Interface).convert);
}

/// WebIDL 3.2.21, converting V to sequence<ByteString> - HeadersInit's
/// inner sequence: an Object (1) whose @@iterator (2) is not undefined (3),
/// created from it (4). OWNED.
fn byteStringSequenceFrom(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value) ConversionError![]const runtime.ByteString {
    // 1. If V is not an Object, throw a TypeError.
    if (!v8.v8_Value_IsObject(value)) return ConversionError.TypeError;
    // 2. Let method be ? GetMethod(V, %Symbol.iterator%).
    // 3. If method is undefined, throw a TypeError.
    const method = (try iteratorMethodOf(isolate, context, value)) orelse return ConversionError.TypeError;
    defer v8.v8_Value_Dispose(method);
    // 4. Return the result of creating a sequence from V and method.
    return sequenceFromIterable(runtime.ByteString, allocator, isolate, context, value, method, fromV8ByteString);
}

/// The record arm's entry type, as codegen emits HeadersInit.
const HeadersRecordEntry = std.meta.Elem(@FieldType(typedefs.HeadersInit, "byte_string_byte_string_record"));

/// WebIDL 3.2.23, converting the Object O to record<ByteString, ByteString>
/// - HeadersInit's record arm. Every key and value is converted as it is
/// reached, so a key that is no ByteString throws before its Get, and a
/// value that is none before the next key's [[GetOwnProperty]]
/// (fetch/api/headers/headers-record.any.js). OWNED: an exact-length slice
/// of entries whose strings are the conversion's.
fn byteStringRecordFrom(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, object: *v8.Value) ConversionError![]const HeadersRecordEntry {
    // 1. If O is not an Object, throw a TypeError (the union took only an
    //    Object here).
    // 2. Let result be a new empty instance of record<ByteString, ByteString>.
    var result: std.ArrayListUnmanaged(HeadersRecordEntry) = .empty;
    errdefer {
        for (result.items) |entry| interface_mod.freeConvertedArg(HeadersRecordEntry, allocator, entry);
        result.deinit(allocator);
    }

    // 3. Let keys be ? O.[[OwnPropertyKeys]]().
    var threw = false;
    const own_keys = v8.v8_Object_OwnPropertyKeysCatching(context, object, &threw);
    if (threw) return rethrowCaught(isolate, own_keys);
    const keys: *v8.Array = @ptrCast(own_keys orelse return ConversionError.TypeError);
    defer v8.v8_Global_Dispose(@ptrCast(keys));

    // 4. For each key of keys:
    const count = v8.v8_Array_Length(keys);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const key = v8.v8_Array_Get(context, keys, i) orelse return ConversionError.TypeError;
        defer v8.v8_Value_Dispose(key);
        // 1. Let desc be ? O.[[GetOwnProperty]](key).
        var enumerable = false;
        const thrown = v8.v8_Object_IsOwnEnumerableCatching(context, object, key, &enumerable, &threw);
        if (threw) return rethrowCaught(isolate, thrown);
        // 2. If desc is not undefined and desc.[[Enumerable]] is true:
        if (!enumerable) continue;
        //    1. Let typedKey be key converted to an IDL value of type K - a
        //       Symbol is ToString's TypeError.
        const typed_key = try fromV8ByteString(allocator, isolate, context, key);
        errdefer interface_mod.freeConvertedArg(runtime.ByteString, allocator, typed_key);
        //    2. Let value be ? Get(O, key).
        const item = v8.v8_Object_GetByKeyCatching(context, object, key, &threw);
        if (threw) return rethrowCaught(isolate, item);
        const item_value = item orelse return ConversionError.TypeError;
        defer v8.v8_Value_Dispose(item_value);
        //    3. Let typedValue be value converted to an IDL value of type V.
        const typed_value = try fromV8ByteString(allocator, isolate, context, item_value);
        errdefer interface_mod.freeConvertedArg(runtime.ByteString, allocator, typed_value);
        //    4. Set result[typedKey] to typedValue. Two keys of O never give
        //       one ByteString: a ByteString is the key's own code units.
        try result.append(allocator, .{ .key = typed_key, .value = typed_value });
    }
    // 5. Return result.
    return result.toOwnedSlice(allocator);
}

/// Make pending a value a Catching call caught (OWNED, taken); a null one -
/// a terminating isolate - leaves nothing to throw.
fn rethrowCaught(isolate: *v8.Isolate, thrown: ?*v8.Value) ConversionError {
    if (thrown) |value| {
        defer v8.v8_Value_Dispose(value);
        v8.v8_Isolate_ThrowException(isolate, value);
    }
    return ConversionError.ExceptionPending;
}

/// WebIDL 3.2.25, converting V to HeadersInit = (sequence<sequence<ByteString>>
/// or record<ByteString, ByteString>). Neither member is nullable,
/// undefined, a dictionary, an interface, a buffer source, a callback or
/// `object`, so steps 1-10 take nothing, and the union has no string,
/// numeric or boolean member for a primitive (steps 12-18):
///
/// - Step 11.2: an Object whose @@iterator is not undefined is the sequence
///   member, created from that method - an Array, a Map, a generator, and a
///   Headers object (its pair iterator yields [name, value] arrays).
/// - Step 11.5: any other Object is the record member.
/// - Step 19: anything else - null, a string, a number - is a TypeError.
///
/// (This tested IsArray instead of @@iterator, so `new Headers(headers)`,
/// `new Request(url, {headers})` and `fetch(url, {headers})` given a Headers
/// object read it as a record of its own enumerable properties - none - and
/// dropped every header; and it read every string as UTF-8 text, with no
/// TypeError for a code unit above 0xFF.)
///
/// Ownership: both arms are exact-length slices of strings this conversion
/// allocated, freed with the argument (`interface.freeConvertedArg`).
fn convertHeadersInit(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!typedefs.HeadersInit {
    // Steps 11 and 19: only an Object can be either member.
    if (!v8.v8_Value_IsObject(value)) return ConversionError.TypeError;
    // 11.2. If types includes a sequence type, then
    //    1. Let method be ? GetMethod(V, %Symbol.iterator%).
    //    2. If method is not undefined, return the result of creating a
    //       sequence of that type from V and method.
    if (try iteratorMethodOf(isolate, context, value)) |method| {
        defer v8.v8_Value_Dispose(method);
        return .{ .sequence_byte_string_sequence = try sequenceFromIterable([]const runtime.ByteString, allocator, isolate, context, value, method, byteStringSequenceFrom) };
    }
    // 11.5. If types includes a record type, then return the result of
    //       converting V to that record type.
    return .{ .byte_string_byte_string_record = try byteStringRecordFrom(allocator, isolate, context, value) };
}

const buffer_sources = @import("webidl").buffer_sources;

/// WebIDL 3.2.25 for AllowSharedBufferSource = (ArrayBuffer or
/// SharedArrayBuffer or [AllowShared] ArrayBufferView) - TextDecoder.decode's
/// input among others - whose flattened member types are ArrayBuffer,
/// SharedArrayBuffer, DataView and the typed arrays:
///
/// - Step 6: an ArrayBuffer (3.2.26 "the result of converting V to
///   ArrayBuffer": a reference to the same object).
/// - Step 7: a SharedArrayBuffer (likewise, to SharedArrayBuffer).
/// - Steps 8-9: a DataView or a typed array, over either kind of buffer
///   ([AllowShared]) - `ArrayBufferView.fromEngine`, as
///   `convertArrayBufferView` makes one, without its step 3.
/// - Step 20: anything else is a TypeError.
///
/// The IDL value is a REFERENCE (`value` itself, BORROWED: see
/// `convertArrayBufferView`), never a slice into the backing store. This was
/// a `.byte_slice` over the store, read here: a later argument's conversion
/// can run script that transfers the buffer and frees that store, and the
/// impl read it afterwards - TextDecoder.decode(input, options), whose
/// options' `stream` getter transfers the input's buffer
/// (encoding/textdecoder-arguments.any.js), read 10,000 freed bytes. The impl
/// copies at its spec's step through
/// `engine.getCopyOfAllowSharedBufferSourceBytes` (a detached buffer reads
/// as empty), after every argument has converted. Blink's bindings hand the
/// impl a DOMArrayBuffer/DOMArrayBufferView the same way, read at use.
///
/// `.array_buffer` and `.shared_array_buffer` point at a struct allocated
/// here (`js` the buffer, no bytes), freed with the argument
/// (`interface.freeConvertedArg`), which also releases the handle.
///
/// null and undefined still read as no bytes (`.byte_slice`, empty, no
/// handle), as before, rather than WebIDL's TypeError: an omitted optional
/// argument reaches here as undefined.
fn convertAllowSharedBufferSource(
    allocator: std.mem.Allocator,
    value: *v8.Value,
) ConversionError!typedefs.AllowSharedBufferSource {
    // Steps 8-9: a view over either kind of buffer - first, as the common
    // case (TextDecoder.decode's input), one FFI call.
    var info: v8.ViewInfo = undefined;
    if (v8.v8_ArrayBufferView_Describe(value, &info)) {
        const view = typedefs.ArrayBufferView.fromEngine(@intCast(@intFromEnum(info.kind)), info.byte_offset, info.length, @ptrCast(value)) orelse
            return ConversionError.TypeError;
        return .{ .array_buffer_view = view };
    }
    // Step 6 (V8's IsArrayBuffer is false for a SharedArrayBuffer).
    if (v8.v8_Value_IsArrayBuffer(value)) {
        const buffer = try allocator.create(buffer_sources.ArrayBuffer);
        buffer.* = .{ .data = &[_]u8{}, .detached = false, .js = @ptrCast(value) };
        return .{ .array_buffer = buffer };
    }
    // Step 7.
    if (v8.v8_Value_IsSharedArrayBuffer(value)) {
        const buffer = try allocator.create(buffer_sources.SharedArrayBuffer);
        buffer.* = .{ .data = &[_]u8{}, .allocator = allocator, .js = @ptrCast(value) };
        return .{ .shared_array_buffer = buffer };
    }
    if (v8.v8_Value_IsNullOrUndefined(value)) return .{ .byte_slice = &[_]u8{} };
    // Step 20.
    return ConversionError.TypeError;
}

/// WebIDL 3.2.26, converting V to an ArrayBufferView - (Int8Array or ... or
/// Float64Array or DataView), not [AllowShared] nor [AllowResizable]:
///
/// 1-2. V must be an Object with a [[TypedArrayName]] or [[DataView]] internal
///      slot: anything else is a TypeError.
/// 3.   IsSharedArrayBuffer(V.[[ViewedArrayBuffer]]) is a TypeError.
/// 4.   (IsFixedLengthArrayBuffer: not checked - the FFI has no resizable
///      predicate yet; a view over a resizable buffer converts.)
/// 5.   "Return the IDL value of type T that is a reference to the same
///      object as V."
///
/// The reference is `value` ITSELF - the handle converted from, no clone. For
/// an argument that is the binding's `info.get(i)` Global, BORROWED for the
/// call and released by the binding once the call returns
/// (`interface.freeConvertedArg`); a dictionary member's or a sequence
/// element's is the Get handle the conversion made for it, released the same
/// way with the dictionary or sequence. Nothing about the object is read but
/// its kind, offset and length: no context, no script.
fn convertArrayBufferView(value: *v8.Value) ConversionError!typedefs.ArrayBufferView {
    var info: v8.ViewInfo = undefined;
    // Steps 1-2: a typed array or a DataView (Describe answers false for
    // anything else).
    if (!v8.v8_ArrayBufferView_Describe(value, &info)) return ConversionError.TypeError;
    // Step 3: not [AllowShared].
    if (info.buffer_shared) return ConversionError.TypeError;
    // Step 5.
    return typedefs.ArrayBufferView.fromEngine(@intCast(@intFromEnum(info.kind)), info.byte_offset, info.length, @ptrCast(value)) orelse
        ConversionError.TypeError;
}

/// WebIDL 3.2.25 for BufferSource = (ArrayBufferView or ArrayBuffer), whose
/// flattened member types are ArrayBuffer, DataView and the typed arrays:
///
/// - Step 6: V has an [[ArrayBufferData]] slot and IsSharedArrayBuffer(V) is
///   false - "the result of converting V to ArrayBuffer" (3.2.26: steps 1-2
///   checked here, step 3 IsFixedLengthArrayBuffer not checked, see
///   `convertArrayBufferView`; step 4 a reference to the same object).
/// - Steps 8-9: a DataView or a typed array - `convertArrayBufferView`.
/// - Step 7: a SharedArrayBuffer matches no member type, and like every other
///   value (step 20) is a TypeError.
///
/// The IDL value is a REFERENCE (`value` itself, BORROWED: see
/// `convertArrayBufferView`), never a copy and never a slice into the backing
/// store. WebCrypto's encrypt, sign and digest normalize the algorithm -
/// running script getters - BEFORE they "get a copy of the bytes held by"
/// the data (41 WPT sites alter or transfer the buffer in such a getter), so a
/// copy taken here would read the bytes too early, and a slice could be freed
/// by the transfer. The impl copies at its spec's step through
/// `engine.getCopyOfBufferSourceBytes` (a detached buffer reads as empty).
///
/// `.array_buffer` points at an ArrayBuffer struct allocated here (`js` the
/// buffer, no bytes), freed with the argument (`interface.freeConvertedArg`).
fn convertBufferSource(allocator: std.mem.Allocator, value: *v8.Value) ConversionError!typedefs.BufferSource {
    // Step 6 (V8's IsArrayBuffer is false for a SharedArrayBuffer).
    if (v8.v8_Value_IsArrayBuffer(value)) {
        const buffer = try allocator.create(buffer_sources.ArrayBuffer);
        buffer.* = .{ .data = &[_]u8{}, .detached = false, .js = @ptrCast(value) };
        return .{ .array_buffer = buffer };
    }
    // Steps 8-9.
    if (v8.v8_Value_IsArrayBufferView(value)) return .{ .array_buffer_view = try convertArrayBufferView(value) };
    // Steps 7 and 20.
    return ConversionError.TypeError;
}

/// WebIDL §3.2.24, converting to BodyInit - flattened, (ReadableStream or
/// Blob or BufferSource or FormData or URLSearchParams or USVString).
///
/// Step 4: a platform object goes to the member interface it implements
/// (File implements Blob). Steps 6-9: an ArrayBuffer, DataView or typed
/// array goes to BufferSource. Anything else - a plain object, a URL, a
/// platform object of another interface - is a USVString, by ToString.
///
/// Ownership, which the argument-cleanup rules in interface.zig depend on
/// (`freeBodyInitArg`): the interface arms are the Instances the wrappers
/// hold, owned by nobody here; the USVString arm is an owned buffer, or a
/// literal "" never freed; the BufferSource arm is always `.array_buffer`,
/// an ArrayBuffer struct AND its bytes, both allocated here - a copy of the
/// bytes the value held, which is what Fetch's "extract a body" takes
/// (BufferSource: "a copy of the bytes held by object"). Copying at
/// conversion rather than holding a view means a getter in a later argument
/// that detaches or resizes the buffer cannot leave the impl reading freed
/// memory.
fn convertBodyInit(
    allocator: std.mem.Allocator,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!typedefs.BodyInit {
    // Step 4: a platform object implementing a member interface.
    if (platformObjectOf(value)) |instance| {
        if (bodyInitArmOf(instance)) |arm| return arm;
    }

    // Steps 6-9: ArrayBuffer, and the ArrayBufferViews (DataView and the
    // typed arrays). Not [AllowShared]: a SharedArrayBuffer is no
    // BufferSource, and a view over one is a TypeError.
    if (v8.v8_Value_IsArrayBuffer(value)) {
        var data: ?*anyopaque = null;
        var len: usize = 0;
        const bytes: []const u8 = if (v8.v8_ArrayBuffer_Bytes(value, &data, &len) and len > 0 and data != null)
            @as([*]const u8, @ptrCast(data.?))[0..len]
        else
            &.{};
        return bodyInitCopy(allocator, bytes);
    }
    if (v8.v8_Value_IsArrayBufferView(value)) {
        var info: v8.ViewInfo = undefined;
        if (!v8.v8_ArrayBufferView_Describe(value, &info)) return ConversionError.TypeError;
        if (info.buffer_shared) return ConversionError.TypeError;
        if (info.buffer_detached or info.byte_length == 0) return bodyInitCopy(allocator, &.{});
        const buffer = v8.v8_ArrayBufferView_Buffer(value) orelse return ConversionError.TypeError;
        defer v8.v8_Global_Dispose(buffer);
        var data: ?*anyopaque = null;
        var len: usize = 0;
        if (!v8.v8_ArrayBuffer_Bytes(buffer, &data, &len) or data == null) return bodyInitCopy(allocator, &.{});
        if (info.byte_offset + info.byte_length > len) return ConversionError.TypeError;
        const all: [*]const u8 = @ptrCast(data.?);
        return bodyInitCopy(allocator, all[info.byte_offset..][0..info.byte_length]);
    }

    // Step 6 for a SharedArrayBuffer: converting it to ArrayBuffer (no
    // [AllowShared]) is a TypeError (3.2.26 step 2) - not a string for step
    // 15 to make "[object SharedArrayBuffer]" of.
    if (v8.v8_Value_IsSharedArrayBuffer(value)) return ConversionError.TypeError;

    // Step 15: USVString - ToString, so null is "null" and a URL its href.
    const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.ExceptionPending;
    defer v8.v8_String_Dispose(string);
    const length = v8.v8_String_Utf8Length(string);
    if (length < 0) return ConversionError.StringError;
    if (length == 0) {
        return .{ .xmlhttp_request_body_init = .{ .usvstring = "" } };
    }
    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);
    const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
    if (written != length) return ConversionError.StringError;
    return .{ .xmlhttp_request_body_init = .{ .usvstring = buffer } };
}

/// The BodyInit arm a platform object goes to: the member interface it
/// implements. Null for any other interface.
fn bodyInitArmOf(instance: *runtime.Instance) ?typedefs.BodyInit {
    const interfaces = @import("interfaces");
    if (instance.stateAs(interfaces.ReadableStream.State) != null) return .{ .readable_stream = instance };
    if (instance.stateAs(interfaces.Blob.State) != null) return .{ .xmlhttp_request_body_init = .{ .blob = instance } };
    if (instance.stateAs(interfaces.FormData.State) != null) return .{ .xmlhttp_request_body_init = .{ .form_data = instance } };
    if (instance.stateAs(interfaces.URLSearchParams.State) != null) return .{ .xmlhttp_request_body_init = .{ .urlsearch_params = instance } };
    return null;
}

/// BodyInit's BufferSource arm over a copy of `bytes`: an ArrayBuffer struct
/// and its data, both owned by the argument (see `convertBodyInit`).
fn bodyInitCopy(allocator: std.mem.Allocator, bytes: []const u8) ConversionError!typedefs.BodyInit {
    const copy = try allocator.create(buffer_sources.ArrayBuffer);
    errdefer allocator.destroy(copy);
    copy.* = try buffer_sources.ArrayBuffer.init(allocator, bytes.len);
    @memcpy(copy.data, bytes);
    return .{ .xmlhttp_request_body_init = .{ .buffer_source = .{ .array_buffer = copy } } };
}

// =============================================================================
// Interface types (WebIDL 3.2.15)
// =============================================================================

/// The generated interface `name` names - an interface type's name as
/// codegen's tables give it (`interface_arguments`,
/// `constructor_interface_arguments`, `interface_members`), a typedef already
/// resolved to its interface. Codegen names only interfaces it generates, so
/// any other name is a compile error.
pub fn interfaceNamed(comptime name: []const u8) type {
    comptime {
        const interfaces = @import("interfaces");
        if (!@hasDecl(interfaces, name)) @compileError("codegen named '" ++ name ++ "' as an interface type, and no generated interface has that name");
        const I = @field(interfaces, name);
        if (@TypeOf(I) != type or !@hasDecl(I, "State")) @compileError("'" ++ name ++ "' is no generated interface with a State");
        return I;
    }
}

/// The platform object `value` is - the Instance its wrapper holds - or null
/// for any other value: a primitive, a function, an object no binding
/// wrapped. It says nothing about WHICH interface the object implements;
/// converting to an interface type is `convertToInterface`.
///
/// A wrapper's internal field 0 holds its Instance, and nothing else ever
/// sets it: every `v8_Object_SetAlignedPointerInInternalField(_, 0, _)` in
/// the adapter stores an Instance or null (a WindowProperties object holds
/// its Window's).
pub fn platformObjectOf(value: *v8.Value) ?*runtime.Instance {
    if (!v8.v8_Value_IsObject(value)) return null;
    // A function has no internal fields to read: no platform object here is
    // callable (a callback interface's function is converted as a callback,
    // never as an interface).
    if (v8.v8_Value_IsFunction(value)) return null;
    return interface_mod.getInstance(runtime.Instance, @ptrCast(value));
}

/// Whether `instance` implements interface `I`: `I`'s State is in its state
/// ancestry, so a File implements Blob and an HTMLDivElement Node. An
/// instance whose vtable has no ancestry implements nothing: every generated
/// vtable has one (`runtime.buildVTable`), and only a hand-made test vtable
/// lacks it - it was accepted as everything, which is how a mock reached an
/// impl as any interface.
pub inline fn implements(instance: *const runtime.Instance, comptime I: type) bool {
    return instance.stateAs(I.State) != null;
}

/// Whether converting to `T` is an interface type conversion, or includes one
/// as a nullable's payload, an optional argument's value or a sequence's
/// elements: the positions `fromV8ValueAs` must be told an interface for
/// (without one, a compile error). A union's arms and a dictionary's members
/// name their own interfaces, so neither is one; nor is anything else.
pub fn needsInterface(comptime T: type) bool {
    if (T == *runtime.Instance) return true;
    const info = @typeInfo(T);
    if (info == .optional) return needsInterface(info.optional.child);
    if (info == .pointer and info.pointer.size == .slice and info.pointer.child != u8) return needsInterface(info.pointer.child);
    if (info == .@"struct" and @hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed")) return needsInterface(@FieldType(T, "value"));
    return false;
}

/// WebIDL 3.2.15, converting V to the interface type I:
///
/// 1. If V implements I, then return the IDL interface type value that
///    represents a reference to that platform object.
/// 2. Throw a TypeError.
///
/// Blink's NativeValueTraits for an interface type asks the same question of
/// the wrapper (V8PerIsolateData::HasInstance(T's WrapperTypeInfo, value),
/// bindings/core/v8/native_value_traits_impl.h) and throws "parameter N is
/// not of type 'T'"; WebKit's JST::toWrapped answers null for any other
/// wrapper and its converter throws (JSDOMConvertInterface.h).
pub fn convertToInterface(comptime I: type, value: *v8.Value) ConversionError!*runtime.Instance {
    const instance = platformObjectOf(value) orelse return ConversionError.TypeError;
    if (!implements(instance, I)) return ConversionError.TypeError;
    return instance;
}

// =============================================================================
// Union arms of interface type (WebIDL §3.2.24 step 4)
// =============================================================================

/// The interface a union arm of type `*runtime.Instance` names, from the
/// arm's name - which codegen derives from the interface's
/// (`sanitizeTypeName` in codegen/generator.zig: an underscore before an
/// upper-case letter that follows a lower-case one, then lower case, so
/// URLSearchParams is `urlsearch_params`). Null when no interface has that
/// name: the arm then cannot be checked, and accepts any platform object.
pub fn unionArmInterface(comptime arm: []const u8) ?type {
    comptime {
        @setEvalBranchQuota(10_000_000);
        const interfaces = @import("interfaces");
        // Typedefs of an interface type take the typedef's name.
        const aliases = .{.{ "window_proxy", "Window" }};
        for (aliases) |alias| {
            if (std.mem.eql(u8, alias[0], arm)) return @field(interfaces, alias[1]);
        }
        for (@typeInfo(interfaces).@"struct".decls) |decl| {
            if (!isArmNameOf(decl.name, arm)) continue;
            const I = @field(interfaces, decl.name);
            if (@TypeOf(I) != type or !@hasDecl(I, "State")) continue;
            return I;
        }
        return null;
    }
}

/// The WebIDL name of the interface `unionArmInterface` finds, for tests
/// (`tests/v8` cannot import `interfaces`).
pub fn unionArmInterfaceName(comptime arm: []const u8) ?[]const u8 {
    const I = comptime unionArmInterface(arm);
    if (comptime I == null) return null;
    return I.?.Meta.name;
}

/// The generated typedefs, re-exported so `tests/v8` can walk every union's
/// interface arms.
pub const generated_typedefs = @import("typedefs");

/// The generated dictionaries, re-exported so `tests/v8` can walk every
/// interface-typed member.
pub const generated_dictionaries = @import("dictionaries");

/// Whether codegen names a union arm of interface `name` `arm`.
fn isArmNameOf(comptime name: []const u8, comptime arm: []const u8) bool {
    comptime {
        var i: usize = 0;
        var prev_was_lower = false;
        for (name) |c| {
            if (std.ascii.isUpper(c)) {
                if (prev_was_lower) {
                    if (i >= arm.len or arm[i] != '_') return false;
                    i += 1;
                }
                if (i >= arm.len or arm[i] != std.ascii.toLower(c)) return false;
                i += 1;
                prev_was_lower = false;
            } else {
                if (i >= arm.len or arm[i] != c) return false;
                i += 1;
                prev_was_lower = std.ascii.isLower(c);
            }
        }
        return i == arm.len;
    }
}

/// The typed array types' names, as [[TypedArrayName]] holds them.
const typed_array_names = [_][]const u8{
    "Int8Array",      "Uint8Array",   "Uint8ClampedArray", "Int16Array",
    "Uint16Array",    "Int32Array",   "Uint32Array",       "BigInt64Array",
    "BigUint64Array", "Float16Array", "Float32Array",      "Float64Array",
};

/// The typed array type a union arm is named for, if any: codegen types a
/// typed array member of a union as runtime.JSValue (the reference to the
/// object, WebIDL 3.2.26) and names the arm after it -
/// ImageDataArray's `uint8clamped_array`, Float32List's `float32array`.
pub fn typedArrayArmName(comptime arm: []const u8) ?[]const u8 {
    inline for (typed_array_names) |name| {
        if (comptime isArmNameOf(name, arm)) return name;
    }
    return null;
}

/// V's [[TypedArrayName]], or null when V is no typed array.
pub fn typedArrayNameOf(value: *v8.Value) ?[]const u8 {
    if (!v8.v8_Value_IsTypedArray(value)) return null;
    if (v8.v8_Value_IsInt8Array(value)) return "Int8Array";
    if (v8.v8_Value_IsUint8Array(value)) return "Uint8Array";
    if (v8.v8_Value_IsUint8ClampedArray(value)) return "Uint8ClampedArray";
    if (v8.v8_Value_IsInt16Array(value)) return "Int16Array";
    if (v8.v8_Value_IsUint16Array(value)) return "Uint16Array";
    if (v8.v8_Value_IsInt32Array(value)) return "Int32Array";
    if (v8.v8_Value_IsUint32Array(value)) return "Uint32Array";
    if (v8.v8_Value_IsBigInt64Array(value)) return "BigInt64Array";
    if (v8.v8_Value_IsBigUint64Array(value)) return "BigUint64Array";
    if (v8.v8_Value_IsFloat16Array(value)) return "Float16Array";
    if (v8.v8_Value_IsFloat32Array(value)) return "Float32Array";
    if (v8.v8_Value_IsFloat64Array(value)) return "Float64Array";
    return null;
}

/// Whether `instance` implements the interface arm `arm` names: its state
/// ancestry holds that interface's State, so File implements Blob. An arm
/// no interface is named for cannot be checked, and is accepted (no
/// generated union has one: tests/v8/union_arm_interface_test.zig). An
/// instance whose vtable carries no ancestry implements none (`implements`).
fn implementsArm(comptime arm: []const u8, instance: *runtime.Instance) bool {
    const Interface = comptime unionArmInterface(arm);
    if (comptime Interface == null) return true;
    return implements(instance, Interface.?);
}

/// WebIDL §3.2.24 step 4 for a union with `*runtime.Instance` arms: if
/// `value` is a platform object, the arm of the first member interface it
/// implements. Arms that name an interface are tried before any that
/// cannot be checked. Null when `value` is no platform object, or one that
/// implements none of them.
fn platformObjectArm(comptime T: type, value: *v8.Value) ?T {
    const instance = platformObjectOf(value) orelse return null;
    return checkedArm(T, instance) orelse uncheckedArm(T, instance);
}

/// Whether `T` is a union whose every arm is an interface - a
/// `*runtime.Instance` - or such a union itself. A union member of a union
/// contributes its own members to the outer one's flattened member types
/// (WebIDL 2.13.29), so its interfaces are the outer union's too:
/// CanvasImageSource's HTMLOrSVGImageElement holds HTMLImageElement and
/// SVGImageElement. Codegen keeps such a member as a nested union.
pub fn isInterfaceUnion(comptime T: type) bool {
    if (@typeInfo(T) != .@"union") return false;
    inline for (@typeInfo(T).@"union".fields) |field| {
        if (field.type != *runtime.Instance and !isInterfaceUnion(field.type)) return false;
    }
    return true;
}

/// The arm of `T` - a nested interface union's included - whose named
/// interface `instance` implements, in member order.
fn checkedArm(comptime T: type, instance: *runtime.Instance) ?T {
    inline for (@typeInfo(T).@"union".fields) |field| {
        if (comptime field.type == *runtime.Instance and unionArmInterface(field.name) != null) {
            if (implementsArm(field.name, instance)) return @unionInit(T, field.name, instance);
        } else if (comptime isInterfaceUnion(field.type)) {
            if (checkedArm(field.type, instance)) |nested| return @unionInit(T, field.name, nested);
        }
    }
    return null;
}

/// The first arm of `T` (a nested interface union's included) that names no
/// interface, and so accepts any platform object.
fn uncheckedArm(comptime T: type, instance: *runtime.Instance) ?T {
    inline for (@typeInfo(T).@"union".fields) |field| {
        if (comptime field.type == *runtime.Instance and unionArmInterface(field.name) == null) {
            return @unionInit(T, field.name, instance);
        } else if (comptime isInterfaceUnion(field.type)) {
            if (uncheckedArm(field.type, instance)) |nested| return @unionInit(T, field.name, nested);
        }
    }
    return null;
}

/// Whether dictionary member type `M` is a sequence (through optionals):
/// its converted value never refers to the handle Get made for the member -
/// the elements are read through handles of their own.
fn isSequenceMember(comptime M: type) bool {
    const info = @typeInfo(M);
    if (info == .optional) return isSequenceMember(info.optional.child);
    return info == .pointer and info.pointer.size == .slice and M != []const u8;
}

/// WebIDL 3.2.18 steps 4-5: a dictionary's members are read least-derived
/// dictionary first, and within one dictionary "in lexicographical order" of
/// their identifiers. Codegen emits a dictionary as its inherited dictionary
/// (`base`, converted by recursion) followed by its own members in IDL
/// declaration order, so the order is imposed here: `base`, then the rest by
/// code unit. Reading `view` before `detail` is observable to a getter.
fn dictionaryMemberOrder(comptime T: type) [std.meta.fields(T).len]std.builtin.Type.StructField {
    comptime {
        @setEvalBranchQuota(20_000);
        var fields = std.meta.fields(T)[0..std.meta.fields(T).len].*;
        std.sort.insertion(std.builtin.Type.StructField, &fields, {}, struct {
            fn lessThan(_: void, a: std.builtin.Type.StructField, b: std.builtin.Type.StructField) bool {
                if (isInheritedDictionaryField(b)) return false;
                if (isInheritedDictionaryField(a)) return true;
                return std.mem.lessThan(u8, a.name, b.name);
            }
        }.lessThan);
        return fields;
    }
}

/// Whether union `T` has an arm for a typed array type (`typedArrayArmName`).
fn hasTypedArrayArm(comptime T: type) bool {
    comptime {
        for (@typeInfo(T).@"union".fields) |field| {
            if (field.type == runtime.JSValue and typedArrayArmName(field.name) != null) return true;
        }
        return false;
    }
}

/// A required dictionary member, as codegen emits one: a field with no
/// default value (generator.generateDictionary writes every other member as
/// `?T = null`). `base` - the inherited dictionary - is converted from the
/// same object and is no member.
fn isRequiredMember(comptime field: std.builtin.Type.StructField) bool {
    return field.default_value_ptr == null and !std.mem.eql(u8, field.name, "base");
}

/// Generic V8 Value to Zig type conversion
///
/// Dispatches to the appropriate conversion function based on target type.
/// A type with an interface-typed position outside a union - `*runtime.Instance`
/// itself, its nullable or optional form, a sequence of it - converts only
/// through `fromV8ValueAs`, which names the interface: here it is a compile
/// error (`interfaceTypeNeedsName`).
pub fn fromV8Value(
    comptime T: type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!T {
    return fromV8ValueAs(T, null, allocator, isolate, context, value);
}

/// WebIDL 3.2.19, attribute assignment with [LegacyTreatNonObjectAsNull]:
/// a non-object becomes null; every object is preserved, callable or not.
/// The value is the same Global, which the binding keeps and frees once the
/// setter returns (a callback value is borrowed, interface.
/// setterValueIsBorrowed). This is never the generic callback conversion.
pub fn fromV8LegacyCallbackAttribute(comptime T: type, value: *v8.Value) ConversionError!T {
    const Child = @typeInfo(T).optional.child;
    if (!v8.v8_Value_IsObject(value)) return null;
    return callbackFunctionValue(Child, value);
}

/// The transitional callback representation is the untagged Global address,
/// never a callable Zig function. BORROWED: the binding frees it with the
/// value, and a consumer that keeps it takes a hold of its own through the
/// protocol (takeCallbackFunction).
fn callbackFunctionValue(comptime T: type, value: *v8.Value) T {
    const address: usize = @intFromPtr(value);
    std.debug.assert(std.mem.isAligned(address, @alignOf(@typeInfo(T).pointer.child)));
    comptime std.debug.assert(@sizeOf(T) == @sizeOf(usize));
    var function_value: T = undefined;
    @memcpy(std.mem.asBytes(&function_value), std.mem.asBytes(&address));
    return function_value;
}

/// `fromV8Value`, where `T`'s interface-typed positions convert to
/// `Interface` (a generated interface; WebIDL 3.2.15: a TypeError unless the
/// value implements it): `*runtime.Instance`, its nullable form, an optional
/// argument of either (`webidl.Opt`), and a sequence's elements. Codegen
/// says which interface each position names (`interface_arguments`,
/// `constructor_interface_arguments`, `interface_members`); the Zig type
/// cannot, since every interface type is `*runtime.Instance`. A union's arms
/// name their own interfaces (`unionArmInterface`), and a dictionary's
/// members theirs (`interface_members`), so neither takes `Interface`.
pub fn fromV8ValueAs(
    comptime T: type,
    comptime Interface: ?type,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!T {
    // Validate the value pointer is properly aligned before any V8 API calls
    // V8 values must be 8-byte aligned on 64-bit systems
    const value_addr = @intFromPtr(value);
    if (value_addr == 0 or (value_addr & 0x7) != 0) {
        // Null or misaligned pointer - this is an internal error
        return ConversionError.TypeError;
    }

    // Handle optional types (nullable)
    const type_info = @typeInfo(T);
    if (type_info == .optional) {
        // Check for null/undefined
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return null;
        }

        const ChildType = type_info.optional.child;

        // WebIDL 3.2.20: a present value converts to the inner type. A
        // nullable callback is strict unless attribute metadata opts in to
        // fromV8LegacyCallbackAttribute above.
        return try fromV8ValueAs(ChildType, Interface, allocator, isolate, context, value);
    }

    // Handle slices (sequence<T> or ByteString)
    if (type_info == .pointer and type_info.pointer.size == .slice) {
        const ElemType = type_info.pointer.child;

        // Special case: []const u8 (ByteString/USVString) - convert using ToString
        // Per WebIDL spec, USVString and DOMString use ToString coercion on any value
        // except Symbol (which throws TypeError).
        // https://webidl.spec.whatwg.org/#idl-USVString
        if (ElemType == u8) {
            // Check for Symbol - throws TypeError per WebIDL spec
            if (v8.v8_Value_IsSymbol_Local(@ptrCast(value))) {
                return ConversionError.TypeError;
            }
            // Use safe ToString that captures exceptions from toString() methods
            // Per WebIDL § 3.2.1, if ToString throws, we must propagate the exception
            const result = v8.v8_Value_ToString_Safe(value, context);
            defer v8.v8_FreeToStringResult(result);

            // If toString() threw an exception, rethrow it and signal caller not to throw again
            if (result.exception) |exc| {
                v8.v8_Isolate_ThrowException(isolate, exc);
                return ConversionError.ExceptionPending;
            }

            const string = result.value orelse return ConversionError.TypeError;
            const length = v8.v8_String_Utf8Length(string);
            if (length < 0) return ConversionError.StringError;
            if (length == 0) return &[_]u8{};

            const buffer = try allocator.alloc(u8, @intCast(length));
            const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
            if (written != length) {
                allocator.free(buffer);
                return ConversionError.StringError;
            }
            // USVString (and ByteString, which shares the Zig type): lone
            // surrogates become U+FFFD.
            replaceLoneSurrogates(buffer);
            return buffer;
        }

        // WebIDL 3.2.21, converting V to sequence<T>:
        // 1. If V is not an Object, throw a TypeError.
        if (!v8.v8_Value_IsObject(value)) return ConversionError.TypeError;
        // 2. Let method be ? GetMethod(V, %Symbol.iterator%).
        // 3. If method is undefined, throw a TypeError.
        const method = (try iteratorMethodOf(isolate, context, value)) orelse return ConversionError.TypeError;
        defer v8.v8_Value_Dispose(method);
        // 4. Return the result of creating a sequence from V and method.
        return try sequenceFromMethod(T, Interface, allocator, isolate, context, value, method);
    }

    // Handle DOMString specially (it's a union type but should be treated as a string)
    // Per WebIDL spec, DOMString uses ToString coercion on any value except Symbol
    // https://webidl.spec.whatwg.org/#idl-DOMString
    // This means null -> "null", undefined -> "undefined", 123 -> "123", etc.
    if (T == runtime.DOMString) {
        // Check for Symbol - throws TypeError per WebIDL spec
        if (v8.v8_Value_IsSymbol(value)) {
            return ConversionError.TypeError;
        }
        // Use safe ToString that captures exceptions from toString() methods
        // Per WebIDL § 3.2.1, if ToString throws, we must propagate the exception
        const result = v8.v8_Value_ToString_Safe(value, context);
        defer v8.v8_FreeToStringResult(result);

        // If toString() threw an exception, rethrow it and signal caller not to throw again
        if (result.exception) |exc| {
            v8.v8_Isolate_ThrowException(isolate, exc);
            return ConversionError.ExceptionPending;
        }

        const string = result.value orelse return ConversionError.TypeError;
        return try fromV8String(allocator, isolate, context, string);
    }

    // Handle HeadersInit specially - parse V8 value to appropriate variant
    if (T == @import("typedefs").HeadersInit) {
        return try convertHeadersInit(allocator, isolate, context, value);
    }

    // Handle BodyInit specially - parse V8 value to appropriate variant
    if (T == @import("typedefs").BodyInit) {
        return try convertBodyInit(allocator, context, value);
    }

    // WebIDL 3.2.26: a buffer source IDL value "is a reference to the same
    // object as V" - the handle converted from, not a copy of its bytes and
    // not a slice into its backing store (see `convertBufferSource`).
    if (T == typedefs.ArrayBufferView) return convertArrayBufferView(value);
    if (T == typedefs.BufferSource) return convertBufferSource(allocator, value);

    if (T == typedefs.AllowSharedBufferSource) {
        return try convertAllowSharedBufferSource(allocator, value);
    }

    // Handle engine-agnostic runtime.JSValue BEFORE generic union handling
    // runtime.JSValue is a special type that wraps JS values for use in impl files
    // We must convert V8 values to the appropriate runtime.JSValue variant
    if (T == runtime.JSValue) {
        // Check for undefined
        if (v8.v8_Value_IsUndefined(value)) {
            return runtime.JSValue{ .undefined = {} };
        }

        // Check for null
        if (v8.v8_Value_IsNull(value)) {
            return runtime.JSValue{ .null = {} };
        }

        // Check for boolean
        if (v8.v8_Value_IsBoolean(value)) {
            return runtime.JSValue{ .boolean = v8.v8_Value_BooleanValue(value, isolate) };
        }

        // Check for number
        if (v8.v8_Value_IsNumber(value)) {
            return runtime.JSValue{ .number = v8.v8_Value_NumberValue(value, context) };
        }

        // Check for string - extract and allocate copy
        if (v8.v8_Value_IsString(value)) {
            const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
            defer v8.v8_String_Dispose(string);
            const length = v8.v8_String_Utf8Length(string);
            if (length < 0) return ConversionError.StringError;
            if (length == 0) {
                return runtime.JSValue{ .string = .{ .data = "", .owned = false } };
            }

            const buffer = try allocator.alloc(u8, @intCast(length));
            const written = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));
            if (written != length) {
                allocator.free(buffer);
                return ConversionError.StringError;
            }
            return runtime.JSValue{ .string = .{ .data = buffer, .owned = true } };
        }

        // An object, function or symbol: the argument's own handle - a
        // Global<Value>* (v8_FunctionCallbackInfo_GetArgument makes one), which
        // the impl borrows for the call.
        return runtime.JSValue{ .handle = .{ .ptr = @ptrCast(value) } };
    }

    // Handle unions (for constructor overloading and type unions)
    if (type_info == .@"union") {
        // Union types require runtime type discrimination per WebIDL specification.
        //
        // For common union patterns (HeadersInit, BodyInit, etc.), we try to
        // find the best matching variant based on the V8 value type.
        //
        // Strategy: At comptime, find which variant matches each JS type category,
        // then dispatch at runtime based on the actual value type.

        const union_info = type_info.@"union";
        const fields = union_info.fields;

        // Find indices for different type categories at comptime
        // Note: []const u8 (ByteString, USVString) could match both string and sequence
        // so we need to check for byte slices specifically

        // String types: DOMString (union), or []const u8 (ByteString/USVString)
        // - or an enumeration: WebIDL 2.13 counts "all enumeration types"
        // among the string types, so 3.2.25 step 15 ("If types includes a
        // string type, then return the result of converting V to that type")
        // takes an enumeration arm - ToString, then a TypeError unless it is
        // one of the values. A valid union has at most one string type (they
        // are not distinguishable); a string arm is still preferred to an
        // enumeration one, as before. Without it, an enumeration arm took
        // nothing: (TaskPriority or TaskSignal), (Sanitizer or
        // SanitizerConfig or SanitizerPresets).
        const string_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == runtime.DOMString) {
                    break :blk i;
                }
                // Check for []const u8 (ByteString, USVString, runtime.ByteString, runtime.USVString)
                const field_info = @typeInfo(field.type);
                if (field_info == .pointer and field_info.pointer.size == .slice and
                    field_info.pointer.child == u8)
                {
                    break :blk i;
                }
            }
            for (fields, 0..) |field, i| {
                if (@typeInfo(field.type) == .@"enum") break :blk i;
            }
            break :blk null;
        };

        // Sequence types: slices that are NOT []const u8
        const sequence_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                const field_info = @typeInfo(field.type);
                if (field_info == .pointer and field_info.pointer.size == .slice) {
                    // Skip []const u8 which is handled as string above
                    if (field_info.pointer.child == u8) continue;
                    break :blk i;
                }
            }
            break :blk null;
        };

        const dict_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                const field_info = @typeInfo(field.type);
                if (field_info == .@"struct" and !@hasDecl(field.type, "Meta")) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        const boolean_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == runtime.Boolean) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        const number_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                const field_info = @typeInfo(field.type);
                if (field_info == .int or field_info == .float or
                    field.type == runtime.Double or field.type == runtime.Long)
                {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Check if this union has only *anyopaque variants (generated for unresolved unions)
        const anyopaque_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == *const anyopaque or field.type == *anyopaque) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Interface pointer types: *runtime.Instance (for unions like NodeOrString)
        // These match JS objects that are wrapped platform objects (DOM nodes, etc.)
        const instance_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == *runtime.Instance) {
                    break :blk i;
                }
            }
            break :blk null;
        };

        // Callback function types: *anyopaque (for unions like TimerHandler)
        // The "Function" callback is generated as *anyopaque to hold V8 GlobalHandle pointers.
        // These match JavaScript functions that need to be stored for later invocation.
        const function_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                // Check for *anyopaque (used for callback.Function)
                if (field.type == *anyopaque) {
                    break :blk i;
                }
                // Also check for *const fn(...) for backwards compatibility with other callbacks
                const field_info = @typeInfo(field.type);
                if (field_info == .pointer and field_info.pointer.size == .one) {
                    const child_info = @typeInfo(field_info.pointer.child);
                    if (child_info == .@"fn") {
                        break :blk i;
                    }
                }
            }
            break :blk null;
        };

        // Buffer source arms: BufferSource (its flattened member types are
        // ArrayBuffer, DataView and the typed arrays) or ArrayBufferView
        // (DataView and the typed arrays).
        const buffer_source_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == typedefs.BufferSource) break :blk i;
            }
            break :blk null;
        };
        const array_buffer_view_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == typedefs.ArrayBufferView) break :blk i;
            }
            break :blk null;
        };

        // The `object` arm: codegen types IDL `object` as runtime.JSValue and
        // names the arm `object` (AlgorithmIdentifier = (object or
        // DOMString)). Matched on the name as well as the type: a JSValue arm
        // under another name is something else - CryptoKeyID's and MLNumber's
        // `bigint`.
        const object_idx: ?usize = comptime blk: {
            for (fields, 0..) |field, i| {
                if (field.type == runtime.JSValue and std.mem.eql(u8, field.name, "object")) break :blk i;
            }
            break :blk null;
        };

        // WebIDL 3.2.25 steps 6, 8 and 9: an ArrayBuffer that is not shared,
        // a DataView or a typed array goes to the buffer source arm, by that
        // arm's own conversion - a view over a SharedArrayBuffer is its
        // TypeError (3.2.26 step 3), not a reason to try the next arm.
        if (buffer_source_idx) |idx| {
            // A SharedArrayBuffer too: step 6 converts it to ArrayBuffer,
            // which throws a TypeError for a shared one (3.2.26 step 2) -
            // it is not left for step 15 to stringify.
            if (v8.v8_Value_IsArrayBuffer(value) or v8.v8_Value_IsSharedArrayBuffer(value) or v8.v8_Value_IsArrayBufferView(value)) {
                return @unionInit(T, fields[idx].name, try fromV8Value(fields[idx].type, allocator, isolate, context, value));
            }
        } else if (array_buffer_view_idx) |idx| {
            if (v8.v8_Value_IsArrayBufferView(value)) {
                return @unionInit(T, fields[idx].name, try fromV8Value(fields[idx].type, allocator, isolate, context, value));
            }
        }

        // WebIDL 3.2.25 step 9: "If V has a [[TypedArrayName]] internal
        // slot, then: if types includes a typed array type whose name is the
        // value of V's [[TypedArrayName]] internal slot, then return the
        // result of converting V to that type" - the IDL value that is a
        // reference to the object: the argument's own handle, as an `object`
        // arm's (released by the binding once the call returns,
        // `interface.releaseAnyArgument`). `new ImageData(new
        // Uint8ClampedArray(16), 2)` was a TypeError: no arm took it.
        if (comptime hasTypedArrayArm(T)) {
            if (typedArrayNameOf(value)) |name| {
                inline for (fields) |field| {
                    if (comptime field.type == runtime.JSValue and typedArrayArmName(field.name) != null) {
                        if (std.mem.eql(u8, name, comptime typedArrayArmName(field.name).?)) {
                            return @unionInit(T, field.name, runtime.JSValue{ .handle = .{ .ptr = @ptrCast(value) } });
                        }
                    }
                }
            }
        }

        // WebIDL 3.2.25 step 11.2, for a union with a sequence member: an
        // Object that no earlier step took - step 5, a platform object
        // implementing a member interface; steps 6-9, the buffer sources
        // above; step 10, a callable given a callback function member, below
        // - is that sequence when its @@iterator is not undefined: an Array,
        // and every other iterable. This tested IsArray, so a Map, a Set, a
        // generator or an iterable platform object went to the dictionary
        // member, or to none; and an Array went to no member at all in a
        // union without a sequence member, where step 11.4 gives it to the
        // dictionary member and step 15 to the string one.
        if (comptime sequence_idx != null) {
            if (v8.v8_Value_IsObject(value) and !(function_idx != null and v8.v8_Value_IsFunction(value))) {
                // Step 5.1.
                if (comptime instance_idx != null) {
                    if (platformObjectArm(T, value)) |arm| return arm;
                }
                // 11.2.1. Let method be ? GetMethod(V, %Symbol.iterator%).
                // 11.2.2. If method is not undefined, return the result of
                //         creating a sequence of that type from V and method.
                if (try iteratorMethodOf(isolate, context, value)) |method| {
                    defer v8.v8_Value_Dispose(method);
                    const idx = comptime sequence_idx.?;
                    return @unionInit(T, fields[idx].name, try sequenceFromMethod(fields[idx].type, null, allocator, isolate, context, value, method));
                }
            }
        }

        // Runtime dispatch based on V8 value type
        // Check function FIRST since functions are also objects in JavaScript.
        // WebIDL §3.2.24 step 11: a callable goes to a callback function arm
        // - if there is one. Otherwise it is just an object and goes on
        // through the object steps and, failing those, to the string step
        // (ToString), so `new Request(URL)` - the URL constructor - is the
        // string it stringifies to.
        if (function_idx != null and v8.v8_Value_IsFunction(value)) {
            if (function_idx) |idx| {
                // IMPORTANT: The 'value' from v8_FunctionCallbackInfo_GetArgument is already
                // a Global<Value>* pointer. We do NOT need to call v8_Value_ToGlobal again.
                // Handle the different callback pointer types
                const FieldType = fields[idx].type;
                if (FieldType == *anyopaque) {
                    // For *anyopaque (callbacks.Function), tag so we can identify it later as GlobalHandle
                    const tagged = pointer_tag.tagPointer(@ptrCast(value), .global_handle);
                    return @unionInit(T, fields[idx].name, @constCast(tagged));
                } else {
                    // For typed function pointer fields (*const fn(...)), do NOT tag the pointer.
                    // Tagged pointers have low bits set which violates Zig's alignment requirements
                    // for function pointers. The union variant type already tells us what it is.
                    const ptr_value: usize = @intFromPtr(value);
                    return @unionInit(T, fields[idx].name, @ptrFromInt(ptr_value));
                }
            }
        } else if (v8.v8_Value_IsString(value)) {
            if (string_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsBoolean(value)) {
            if (boolean_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsNumber(value)) {
            if (number_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        } else if (v8.v8_Value_IsObject(value)) {
            // For objects, we need to distinguish between:
            // 1. Wrapped platform objects (DOM nodes, etc.) - have internal fields
            // 2. Plain JS objects (dictionaries, String objects, etc.) - no internal fields
            //
            // The problem: v8_Object_InternalFieldCount_Raw segfaults on plain objects.
            // Solution: Try instance conversion, but if it returns an instance with null
            // internal pointer, treat it as a plain object.
            if (instance_idx != null) {
                // Try to extract as instance - but first check if we have a string alternative
                // because strings should take priority over treating them as objects
                if (string_idx != null and v8.v8_Value_IsString(value)) {
                    // This is a string, skip instance extraction and let string handling below deal with it
                } else if (platformObjectArm(T, value)) |arm| {
                    // WebIDL §3.2.24 step 4: a platform object goes to the
                    // arm whose interface it implements.
                    return arm;
                } else if (comptime string_idx != null and dict_idx == null and function_idx == null and
                    sequence_idx == null and object_idx == null)
                {
                    // Not a platform object, or one no arm names - a URL
                    // given for (Request or USVString), a Blob for (Node or
                    // DOMString), {toString() {...}} for (TrustedHTML or
                    // DOMString). WebIDL 3.2.25: step 5.1 took no arm; steps
                    // 6-9 (buffer sources) were tried above; step 10 needs a
                    // callback function arm and step 11 a sequence,
                    // dictionary, record, callback interface or `object`
                    // arm, which this union has none of. So step 15: "If
                    // types includes a string type, then return the result
                    // of converting V to that type" - ToString, whose
                    // exception propagates (ExceptionPending).
                    const str_idx = string_idx.?;
                    return @unionInit(T, fields[str_idx].name, try fromV8Value(fields[str_idx].type, allocator, isolate, context, value));
                } else if (comptime dict_idx == null) {
                    // A union with one of step 11's arms as well, but no
                    // dictionary: as before (a toString attempt, then the
                    // arms below). With a dictionary arm, step 11.4 takes the
                    // object before step 15 could stringify it - no
                    // toString() runs, and an enumeration arm (a string type)
                    // never takes an object whose toString() names a value.
                    if (string_idx) |str_idx| {
                        // Call toString() on the object to get a string representation
                        if (v8.v8_Value_ToString(value, context)) |str_value| {
                            const StringFieldType = fields[str_idx].type;
                            if (fromV8Value(StringFieldType, allocator, isolate, context, @ptrCast(str_value))) |str_converted| {
                                return @unionInit(T, fields[str_idx].name, str_converted);
                            } else |_| {
                                // String conversion also failed, fall through
                            }
                        }
                    }
                    // Fall through to dict_idx
                }
            }
            if (dict_idx) |idx| {
                const FieldType = fields[idx].type;
                const converted = try fromV8Value(FieldType, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        }

        // WebIDL 3.2.25 steps 5.2, 6.2, 7.2, 8.2, 9.2, 10.2 and 11.7: an
        // Object no member type above took - a plain object, an array, a
        // callable, a platform object, a buffer - is "the IDL value that is a
        // reference to the object V" when the union includes `object`. The
        // reference is the argument's own handle, as an `any` argument's is:
        // BORROWED for the call and released by the binding once it returns
        // (`interface.releaseAnyArgument`). (`object` is not distinguishable
        // from interface, buffer, callback, dictionary or sequence types, so a
        // valid union has none of the arms the steps above try first.)
        if (object_idx) |idx| {
            if (v8.v8_Value_IsObject(value)) {
                return @unionInit(T, fields[idx].name, runtime.JSValue{ .handle = .{ .ptr = @ptrCast(value) } });
            }
        }

        // Steps 15, 17 and 18 for an Object that no member type above took
        // (no interface, buffer source, callback, dictionary or `object` arm
        // matched it): converted to the string type - ToString, so its
        // toString() runs and what it throws propagates - else the numeric
        // type, else boolean. The instance path above does step 15 itself for
        // a union with interface arms; this is the rest:
        // FontFace(family, (CSSOMString or BufferSource) source, ...) given
        // an object with a toString was a TypeError. A union with a sequence
        // arm reaches here only with an Object that has no @@iterator: step
        // 11.2 above took every iterable one.
        if (comptime instance_idx == null) {
            if (v8.v8_Value_IsObject(value)) {
                if (string_idx) |idx| {
                    return @unionInit(T, fields[idx].name, try fromV8Value(fields[idx].type, allocator, isolate, context, value));
                }
                if (number_idx) |idx| {
                    return @unionInit(T, fields[idx].name, try fromV8Value(fields[idx].type, allocator, isolate, context, value));
                }
                if (boolean_idx) |idx| {
                    return @unionInit(T, fields[idx].name, try fromV8Value(fields[idx].type, allocator, isolate, context, value));
                }
            }
        }

        // WebIDL §3.2.25 "converting to a union", for a value that is not an
        // object and that no step above took.
        if (!v8.v8_Value_IsObject(value)) {
            // Step 4: "If V is null or undefined, then: If types includes a
            // dictionary type, then return the result of converting V to that
            // dictionary type."
            if (v8.v8_Value_IsNullOrUndefined(value)) {
                if (dict_idx) |idx| {
                    const converted = try fromV8Value(fields[idx].type, allocator, isolate, context, value);
                    return @unionInit(T, fields[idx].name, converted);
                }
            }
            // Step 15: "If types includes a string type, then return the
            // result of converting V to that type" - ToString, so null is
            // "null" and 5 is "5"; a Symbol throws.
            if (string_idx) |idx| {
                const converted = try fromV8Value(fields[idx].type, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
            // Step 17: "If types includes a numeric type, then return the
            // result of converting V to that numeric type."
            if (number_idx) |idx| {
                const converted = try fromV8Value(fields[idx].type, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
            // Step 18: "If types includes boolean, then return the result of
            // converting V to boolean."
            if (boolean_idx) |idx| {
                const converted = try fromV8Value(fields[idx].type, allocator, isolate, context, value);
                return @unionInit(T, fields[idx].name, converted);
            }
        }

        // Fallback: If no typed variant matched but we have an anyopaque variant,
        // use it to pass through the V8 value. This handles unions like HeadersInit
        // where codegen generates *anyopaque variants for unresolved types.
        if (anyopaque_idx) |idx| {
            // Pass through the V8 value as an opaque pointer
            // The implementation is responsible for parsing this
            return @unionInit(T, fields[idx].name, @ptrCast(value));
        }

        // No matching variant found - return error
        return ConversionError.TypeError;
    }

    // Handle integers: WebIDL § 3.2.4 ConvertToInt, for a type with neither
    // [EnforceRange] nor [Clamp].
    if (type_info == .int) {
        // Step 1: x = ToNumber(V). ToNumber throws a TypeError for a Symbol or
        // a BigInt. An object's valueOf can throw too; NumberValue then
        // answers 0 and V8 rethrows the pending exception when the binding
        // returns, so the call runs with 0 first - a known gap.
        if (v8.v8_Value_IsSymbol(value) or v8.v8_Value_IsBigInt(value)) {
            return ConversionError.TypeError;
        }
        return convertToInt(T, v8.v8_Value_NumberValue(value, context));
    }

    // Handle enums: WebIDL §3.2.23 - S = ? ToString(V), then a TypeError
    // unless S is one of the enumeration's values. Every value is converted,
    // not only a string: `history.scrollRestoration = 5` is "5", which matches
    // nothing (and used to reach @enumFromInt(5) and panic).
    if (type_info == .@"enum") {
        // ToString throws for a Symbol, or when a toString() throws; the
        // exception is pending then, for the binding to rethrow.
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.ExceptionPending;
        defer v8.v8_String_Dispose(string);
        var dom_string = try fromV8String(allocator, isolate, context, string);
        defer dom_string.deinit(allocator);

        const enum_name = switch (dom_string) {
            .empty => "",
            .interned => |s| s,
            .owned => |s| s,
        };

        // Step 2: "If S is not one of E's enumeration values, then throw a
        // TypeError" - the values exactly as the IDL spells them.
        return enumFromIdlValue(T, enum_name) orelse ConversionError.TypeError;
    }

    // WebIDL 3.2.15, an interface type: "1. If V implements I, then return
    // the IDL interface type value that represents a reference to that
    // platform object. 2. Throw a TypeError." It accepted ANY platform object
    // - every interface type is the one Zig type `*runtime.Instance` - so
    // `fd.append(name, new URLSearchParams(), filename)` handed FormData a
    // URLSearchParams as its Blob, and FormData read its state as a Blob's.
    if (T == *runtime.Instance) {
        const I = comptime Interface orelse @compileError(
            "an interface-typed value converts only to a named interface: " ++
                "convert it with fromV8ValueAs, the interface from codegen's tables " ++
                "(interface_arguments, constructor_interface_arguments, interface_members)",
        );
        return convertToInterface(I, value);
    }

    // Handle function pointers (callbacks)
    //
    // CRITICAL: V8 callback persistence fix
    //
    // When JavaScript passes a callback function (e.g., `new WritableStream({ start: fn })`),
    // the V8 value is a Local<Function> that's only valid within the current HandleScope.
    // If we just store the Local handle pointer, it becomes invalid when the HandleScope ends
    // (typically when the constructor returns).
    //
    // The fix: Create a V8 Global handle immediately during dictionary extraction.
    // Global handles persist until explicitly disposed, surviving HandleScope destruction.
    //
    // A callback function type is a Zig function-pointer type until codegen
    // types callback parameters as engine.CallbackFunction (the protocol's
    // TRANSITIONAL note on takeCallbackFunction): the value holds the
    // function's Global<Value>* and is never called. It is BORROWED for the
    // call, as every converted value is: the binding frees the Global with
    // the value (interface.freeConvertedArg), and a consumer that keeps the
    // callback takes a hold of its own (takeCallbackFunction, which moves the
    // function out of this Global).
    if (type_info == .pointer) {
        const child_info = @typeInfo(type_info.pointer.child);
        if (child_info == .@"fn") {
            // NOTE: value from v8_FunctionCallbackInfo_GetArgument is ALREADY a
            // Global<Value>* of the binding's (the C++ side made it from the
            // argument's Local), so it is the value as it is - still the
            // binding's to free.
            if (!v8.v8_Value_IsFunction(value)) {
                return ConversionError.TypeError;
            }

            // UNTAGGED. A value of a pointer type must be aligned for it - a
            // function is 4-aligned on aarch64 - and it once carried
            // `.global_handle` in its low bits. That is illegal behaviour, and
            // an optimized build acted on it: with the impl's untag inlined
            // after a parameter of this type, LLVM took the low bits as zero
            // and dropped the untag, so a ReleaseSafe runner disposed and
            // cloned Global* + 1 (the alignment trap in v8_Global_Clone, under
            // EventTarget.innerInvoke, on every event handler it ran). The
            // Global from `new` is 16-aligned, so the plain address is a value
            // the type may hold; the union path below already stored its
            // function-pointer arms this way.
            //
            // A byte copy, since no pointer cast turns a Value* into a function
            // pointer; both are one machine word.
            return callbackFunctionValue(T, value);
        }
    }

    // Handle webidl.Opt (Optional wrapper type)
    // This must come before generic struct handling since Opt is a struct
    if (type_info == .@"struct" and @hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed")) {
        // This is a webidl.Opt(InnerType) - convert the inner value and wrap it
        // Get the inner type from the 'value' field using comptime struct field access
        const InnerType = comptime blk: {
            const fields = std.meta.fields(T);
            for (fields) |field| {
                if (std.mem.eql(u8, field.name, "value")) {
                    break :blk field.type;
                }
            }
            // Opt types always have a 'value' field
            @compileError("webidl.Opt type missing 'value' field");
        };

        // WebIDL 3.7.x, overload resolution step 4 / "converting arguments":
        // an optional argument whose value is undefined is not passed (its
        // default applies); EVERY other value, null included, is converted
        // to the argument's type. So null is null for a nullable type, 0 for
        // a number (ToNumber), false for a boolean, "null" for a string, the
        // defaults for a dictionary (3.2.18 steps 1-3), and a TypeError for
        // an interface, callback or sequence type. Null used to read as not
        // passed for every non-string type (idbfactory_open's null version).
        if (v8.v8_Value_IsUndefined(value)) {
            return T.notPassed();
        }
        const inner_value = try fromV8ValueAs(InnerType, Interface, allocator, isolate, context, value);
        return T.passed(inner_value);
    }

    // Handle structs (dictionaries vs interfaces)
    if (type_info == .@"struct") {
        // Check if this is a WebIDL interface (has Meta subtype)
        if (@hasDecl(T, "Meta")) {
            // This is a WebIDL interface, not a dictionary
            // TODO: Extract *runtime.Instance from V8 object's internal field
            // For now, interfaces in constructor parameters are not fully supported
            return error.TypeError;
        }

        // WebIDL 3.2.18 steps 1-3: "If jsDict is not undefined, null or an
        // Object, throw a TypeError"; undefined and null are a dictionary
        // whose every member reads as undefined - its defaults, as `{}`
        // gives them. (Null for an optional dictionary argument now reaches
        // here instead of reading as not passed; a union's dictionary arm
        // takes null and undefined the same way, 3.2.25 step 4.)
        const object: ?*v8.Object = if (v8.v8_Value_IsObject(value))
            @as(*v8.Object, @ptrCast(value))
        else if (v8.v8_Value_IsNullOrUndefined(value))
            null
        else
            return ConversionError.TypeError;

        var result: T = undefined;
        const members = comptime dictionaryMemberOrder(T);
        // A member that fails to convert - its Get threw, its value is the
        // wrong type, a restricted float is NaN - ends the conversion with
        // the members before it converted: they are freed here, as
        // `interface.freeConvertedArg` frees a whole dictionary (what each
        // allocated, and an `any` member's handle). Kept, a RequestInit
        // whose `duplex` was missing leaked its body's copy.
        var converted: usize = 0;
        errdefer inline for (members, 0..) |field, index| {
            if (index < converted) {
                interface_mod.freeConvertedArg(field.type, allocator, @field(result, field.name));
                interface_mod.releaseAnyArgument(field.type, @field(result, field.name));
            }
        };
        inline for (members) |field| {
            // Special handling for 'base' field in dictionary inheritance
            // In WebIDL, child dictionaries inherit parent fields directly on the object
            // e.g., { bubbles: true, oldVersion: 1 } not { base: { bubbles: true }, oldVersion: 1 }
            if (comptime std.mem.eql(u8, field.name, "base")) {
                const field_type_info = @typeInfo(field.type);
                if (field_type_info == .@"struct") {
                    // Recursively extract parent dictionary fields from the same object
                    @field(result, field.name) = try fromV8Value(
                        field.type,
                        allocator,
                        isolate,
                        context,
                        value, // Pass the same object, not a nested property
                    );
                    converted += 1;
                    continue;
                }
            }

            // Get property name
            const field_name_str = v8.v8_String_NewFromUtf8(
                isolate,
                field.name.ptr,
                @intCast(field.name.len),
            );
            defer if (field_name_str) |n| v8.v8_String_Dispose(n);

            // Get property value from object - or, for an undefined or null
            // dictionary, undefined (a Global of our own, as Get's is).
            const field_v8_opt = if (object) |o|
                v8.v8_Object_Get(o, context, @ptrCast(field_name_str))
            else
                v8.v8_Undefined(isolate);

            if (field_v8_opt) |field_v8| {
                // Get made this handle for the member, and it is released when
                // the member's conversion copied out of it - the rule the
                // binding applies to arguments. Kept, an object member (a
                // Headers, a signal) pinned its page. A sequence member never
                // refers to it either: its elements are read through handles
                // of their own (v8_Array_Get) - kept, StructuredSerializeOptions'
                // `transfer` leaked one per postMessage(message, options).
                const member_handle_released = comptime interface_mod.argHandleIsCopied(field.type) or isSequenceMember(field.type);
                defer if (member_handle_released) v8.v8_Value_Dispose(field_v8);
                // Step 4.1.4.4: "Otherwise, if jsMemberValue is undefined and
                // member is required, then throw a TypeError." Codegen emits a
                // required member as the one kind of field with no default
                // (every other member is `?T = null`). It converted undefined
                // instead - 0, "undefined".
                if (comptime isRequiredMember(field)) {
                    if (v8.v8_Value_IsUndefined(field_v8)) {
                        if (!member_handle_released) v8.v8_Value_Dispose(field_v8);
                        return ConversionError.TypeError;
                    }
                }
                // WebIDL 3.2.18: a member is present unless it is undefined.
                // An `any` member present as null is the value null
                // (`any_members`); converted as an optional, it would read as
                // not present.
                const is_any_member = comptime isAnyMember(T, field.name);
                const null_converts_by_type = comptime presentNullConvertsByType(T, field);
                if (is_any_member and v8.v8_Value_IsNull(field_v8)) {
                    // Nothing keeps the handle Get made (the defer above
                    // releases it only for a copying conversion).
                    if (!member_handle_released) v8.v8_Value_Dispose(field_v8);
                    @field(result, field.name) = runtime.JSValue.jsNull;
                } else if (null_converts_by_type and v8.v8_Value_IsNull(field_v8)) {
                    // A present null of a member whose type is not nullable:
                    // the value null, converted by that type (WebIDL 3.2.18
                    // step 4.1.4.3). Null is a primitive: nothing keeps the
                    // handle. An [EnforceRange] or [Clamp] member's null is
                    // ToNumber's 0 - in range, and clamped to itself.
                    const Payload = @typeInfo(field.type).optional.child;
                    const converted_null = fromV8ValueAs(Payload, comptime structMemberInterface(T, Interface, field.name), allocator, isolate, context, field_v8);
                    if (!member_handle_released) v8.v8_Value_Dispose(field_v8);
                    @field(result, field.name) = try converted_null;
                } else if (comptime interface_mod.argumentHandleIsKeptInValue(field.type)) {
                    // An `any` member, an `object` arm or a buffer source:
                    // kept only when the value still refers to it (a `.handle`
                    // JSValue, a buffer source's reference); a primitive was
                    // copied out, and its handle goes now - the rule the
                    // binding applies to such an argument. A buffer source's
                    // goes when the dictionary is freed (`freeConvertedArg`).
                    const member = fromV8Value(field.type, allocator, isolate, context, field_v8) catch |err| {
                        v8.v8_Value_Dispose(field_v8);
                        return err;
                    };
                    if (interface_mod.keptArgumentHandle(field.type, member) == null) v8.v8_Value_Dispose(field_v8);
                    @field(result, field.name) = member;
                } else if (comptime memberIntegerConversion(T, field.name) != .modulo) {
                    // An [EnforceRange] or [Clamp] member: its branch of
                    // ConvertToInt, on the number before it wraps.
                    @field(result, field.name) = try fromV8ValueInteger(
                        field.type,
                        comptime memberIntegerConversion(T, field.name),
                        allocator,
                        isolate,
                        context,
                        field_v8,
                    );
                } else {
                    // Convert field value - an interface-typed member to the
                    // interface `interface_members` names.
                    const member = fromV8ValueAs(
                        field.type,
                        comptime structMemberInterface(T, Interface, field.name),
                        allocator,
                        isolate,
                        context,
                        field_v8,
                    ) catch |err| {
                        // A strict callback conversion adopts its input only
                        // on success. Ordinary copying members already have
                        // the defer above; unknown types keep the safe default.
                        if (comptime callbackConversionAdoptsInput(field.type) and !member_handle_released)
                            v8.v8_Value_Dispose(field_v8);
                        return err;
                    };
                    // A member that converted to nothing - absent or null,
                    // a callback member's included - leaves Get's handle
                    // referred to by nothing (`conversionLeavesHandle`):
                    // QueuingStrategy's absent `size` kept one per strategy.
                    // A handle the copied rule releases is never released here.
                    if (!member_handle_released and interface_mod.conversionLeavesHandle(field.type, member)) v8.v8_Value_Dispose(field_v8);
                    @field(result, field.name) = member;
                }
                converted += 1;
                // A restricted `double` or `float` member: NaN and the
                // infinities are a TypeError, as part of this member's
                // conversion - before the next member is read.
                if (comptime isRestrictedMember(T, field.name)) try requireFinite(field.type, @field(result, field.name));
                // A ByteString member (`byte_string_members`, RequestInit's
                // method): a code unit above 0xFF is a TypeError, likewise.
                if (comptime isByteStringMember(T, field.name)) try encodeByteStringOwned(field.type, allocator, &@field(result, field.name));
                // An `object` member (`object_members`, StructuredSerializeOptions'
                // `transfer`): a value that is not an Object is a TypeError.
                if (comptime isObjectMember(T, field.name)) try requireObject(field.type, @field(result, field.name));
            } else {
                // Get returns an empty handle only when it THREW (an absent
                // member reads as undefined, handled above): WebIDL § 3.2.18
                // "Let jsMemberValue be ? Get(jsDict, key)" - the conversion
                // is abrupt and the exception is already pending.
                return ConversionError.ExceptionPending;
            }
        }
        return result;
    }

    // Handle void (used for no-argument constructors)
    if (T == void) {
        // Void doesn't need conversion from V8
        return {};
    }

    // Handle primitive and special types using if-chain to avoid compile errors
    if (T == runtime.Boolean) return fromV8Boolean(isolate, value);
    if (T == runtime.Long) return try fromV8Long(context, value);
    if (T == runtime.UnsignedLong) return try fromV8UnsignedLong(context, value);
    if (T == runtime.LongLong) return try fromV8LongLong(context, value);
    if (T == runtime.UnsignedLongLong) return try fromV8UnsignedLongLong(context, value);
    if (T == u64) return try fromV8UnsignedLongLong(context, value);
    if (T == runtime.Double) return try fromV8Double(context, value);
    if (T == runtime.Float) return try fromV8Float(context, value);
    if (T == runtime.DOMString) {
        // Use ToString coercion for all values except Symbol (WebIDL standard behavior)
        if (v8.v8_Value_IsSymbol_Local(@ptrCast(value))) {
            return ConversionError.TypeError;
        }
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;
        return try fromV8String(allocator, isolate, context, string);
    }
    if (T == runtime.Any) return fromV8Any(value);

    // Handle V8-specific JSValue (type-safe JavaScript value wrapper)
    // Note: This is the V8-specific JSValue from engines/v8/js_value.zig
    if (T == JSValue) {
        return try fromV8ValueTyped(value, isolate, context);
    }

    // Handle V8-specific OptionalJSValue (for optional 'any' parameters)
    if (T == OptionalJSValue) {
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return OptionalJSValue.notPassed;
        }
        return OptionalJSValue.fromValue(try fromV8ValueTyped(value, isolate, context));
    }

    // Handle engine-agnostic runtime.OptionalJSValue
    if (T == runtime.OptionalJSValue) {
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return runtime.OptionalJSValue.notPassed;
        }
        return runtime.OptionalJSValue.fromValue(try fromV8Value(runtime.JSValue, allocator, isolate, context, value));
    }

    if (T == *const anyopaque) {
        // ============================================================================
        // POINTER TAGGING DOCUMENTATION
        // ============================================================================
        //
        // ## Overview
        //
        // This is the PRODUCER side of the pointer tagging contract. When converting
        // V8 values to `*const anyopaque`, we tag the returned pointer so consumers
        // can safely determine what type of pointer they received.
        //
        // ## Why Tagging is Necessary
        //
        // Dictionary fields and WebIDL 'any' type parameters are declared as
        // `*const anyopaque` in Zig. Without tagging, consumers cannot distinguish:
        // - A V8 Local<Value> handle (temporary, for primitives/strings)
        // - A V8 Global<Value> handle (persisted, for functions/objects)
        // - A Zig *runtime.Instance (wrapped interface, not a V8 pointer at all!)
        //
        // CRITICAL: If a V8 object wraps a Zig instance, we MUST return the Instance
        // pointer, NOT the V8 pointer. Otherwise, callers casting to *runtime.Instance
        // will crash by interpreting V8 memory as Zig structs.
        //
        // ## Tagging Contract
        //
        // **PRODUCER (here in fromV8Value):**
        // - Tags ALL `*const anyopaque` return values using TaggedPointer.init()
        // - Detection logic:
        //   1. If V8 object with internal fields → extract Instance, tag as .runtime_instance
        //   2. If function/object needing persistence → create Global, tag as .global_handle
        //   3. Otherwise → tag Local handle as .local_value
        //
        // **CONSUMERS (engine.zig, binding.zig, impl code):**
        // - MUST use TaggedPointer.fromRaw() or untagPointer() before using the pointer
        // - Check the tag to determine how to handle:
        //   - .runtime_instance: Cast to *runtime.Instance, use directly
        //   - .global_handle/.local_value: Cast to V8 FFI type, call V8 APIs
        //   - .untagged: Legacy compatibility (assume V8 Local handle)
        //
        // ## V8 Handle Lifetimes
        //
        // - Local<Value>: Stack-bound to current HandleScope, becomes invalid when scope ends
        // - Global<Value>: Persists until explicitly disposed, safe across scopes
        // - Functions/objects stored for later callback MUST use Global handles
        // - Primitives are safe as Local (V8 copies values internally)
        //
        // ## Example Consumer Code
        //
        // ```zig
        // fn processAnyValue(tagged_ptr: *const anyopaque) void {
        //     const tagged = TaggedPointer.fromRaw(@intFromPtr(tagged_ptr));
        //     switch (untagged.tag) {
        //         .runtime_instance => {
        //             const instance: *runtime.Instance = @ptrCast(@alignCast(untagged.ptr));
        //             // Use as Zig instance...
        //         },
        //         .global_handle, .local_value, .untagged => {
        //             const v8_value: *ffi.Value = @ptrCast(untagged.ptr);
        //             // Call V8 FFI functions...
        //         },
        //     }
        // }
        // ```
        //
        // ============================================================================

        const TaggedPointer = pointer_tag.TaggedPointer;

        // Step 1: Check if V8 object wraps a Zig instance
        // Detection: Objects with internal fields store Zig instances in field 0
        if (v8.v8_Value_IsObject(value)) {
            const obj: *v8.Object = @ptrCast(value);
            const field_count = v8.v8_Object_InternalFieldCount(obj);
            if (field_count > 0) {
                if (v8.v8_Object_GetAlignedPointerFromInternalField(obj, 0)) |internal_ptr| {
                    // TAGGING: .runtime_instance - this is a Zig object, NOT a V8 handle
                    // Consumer MUST NOT pass this to V8 FFI functions!
                    DebugAssertions.logTaggedPointerCreation(@ptrCast(internal_ptr), .runtime_instance);
                    return TaggedPointer.init(internal_ptr, .runtime_instance).toConstPtr();
                }
                // Internal field null - object not fully initialized, fall through
            }
        }

        // Step 2: Create WEAK Global handle for functions/objects needing persistence
        // NOTE: Local handles become invalid when HandleScope ends
        //
        // MEMORY MANAGEMENT: We use weak Global handles (not strong) because:
        // - Strong handles require manual disposal → causes memory leaks if forgotten
        // - Weak handles let V8 GC clean them up when JS no longer references them
        // - This matches JavaScript semantics: object is kept alive by JS references
        //
        // The weak handle with null callback means:
        // - Handle survives HandleScope (essential for callbacks stored in dictionaries)
        // - V8 can GC the value when no JS references remain
        // - No Zig-side cleanup callback needed (we don't track these handles)
        if (v8.v8_Value_IsFunction(value) or v8.v8_Value_IsObject(value)) {
            if (v8.v8_Value_ToWeakGlobal(isolate, @ptrCast(value), null, null)) |global| {
                // TAGGING: .global_handle - V8 Global<Value>* (weak), survives HandleScope
                // Consumer: untag before V8 FFI, V8 GC handles disposal
                DebugAssertions.logTaggedPointerCreation(@ptrCast(global), .global_handle);
                return TaggedPointer.init(global, .global_handle).toConstPtr();
            }
            // Global creation failed (OOM), fall through to Local
        }

        // Step 3: Return Local handle for primitives
        // TAGGING: .local_value - V8 Local<Value>*, temporary handle
        // Consumer: untag before V8 FFI, only valid within current HandleScope
        DebugAssertions.logTaggedPointerCreation(@ptrCast(@constCast(value)), .local_value);
        return TaggedPointer.init(@ptrCast(@constCast(value)), .local_value).toConstPtr();
    }

    // Callback interface types (EventListener, NodeFilter, XPathNSResolver):
    // the argument as this adapter's CallbackWrapper, which the engine-neutral
    // `*runtime.CallbackWrapper` names opaquely. BORROWED by the impl for the
    // call: the binding releases it when the call returns
    // (`releaseCallbackWrapper`), and an impl that keeps the callback takes a
    // CallbackInterface of its own (takeCallbackInterface).
    if (T == *runtime.CallbackWrapper) {
        const wrapper = callback_wrapper.createFromV8Value(
            callback_allocator,
            isolate,
            context,
            value,
            "handleEvent", // Default method name for callback interfaces
        ) catch return ConversionError.TypeError;
        return @ptrCast(wrapper orelse return ConversionError.TypeError);
    }
    if (T == ?*runtime.CallbackWrapper) {
        // Optional callback - null/undefined is valid
        if (v8.v8_Value_IsNullOrUndefined(value)) {
            return null;
        }
        const wrapper = callback_wrapper.createFromV8Value(
            callback_allocator,
            isolate,
            context,
            value,
            "handleEvent",
        ) catch return ConversionError.TypeError;
        return if (wrapper) |w| @ptrCast(w) else null;
    }

    // Handle pointer types that might be generated by codegen for buffer sources
    // This catches things like *ArrayBuffer, *TypedArray, etc.
    if (type_info == .pointer and type_info.pointer.size == .one) {
        const ChildType = type_info.pointer.child;
        const child_info = @typeInfo(ChildType);

        // Check if child type is a struct (like ArrayBuffer)
        if (child_info == .@"struct") {
            // For now, return TypeError - buffer source conversion requires
            // special V8 API calls that aren't yet implemented
            // TODO: Implement V8 ArrayBuffer/TypedArray extraction
            return ConversionError.TypeError;
        }
    }

    // If we get here, it's an unsupported type
    @compileError("Unsupported type for V8 conversion: " ++ @typeName(T));
}

// ============================================================================
// Zig to JavaScript (Runtime → V8)
// ============================================================================

/// A new V8 string of the code units `bytes` encodes. A Zig string from
/// script is WTF-8: fromV8Value writes a JavaScript string with WriteUtf8
/// and no REPLACE_INVALID_UTF8, so an unpaired surrogate arrives as its
/// three-byte form (ED A0..BF xx), and a DOMString keeps it. V8's UTF-8
/// decoder would make each of those bytes a U+FFFD, so a string holding a
/// surrogate code point is made from its UTF-16 instead - the decode
/// value_operations.ownHandle does for the protocol's own copies. Every other
/// string (ASCII, well-formed UTF-8) keeps String::NewFromUtf8. A new Global
/// the caller owns; null when V8 refuses it (longer than String::kMaxLength).
pub fn newStringFromWtf8(isolate: *v8.Isolate, bytes: []const u8) ?*v8.Value {
    if (bytes.len == 0) return @ptrCast(v8.v8_String_Empty(isolate));
    if (value_operations.hasSurrogateCodePoint(bytes)) return value_operations.stringFromWtf8(isolate, bytes) catch null;
    return @ptrCast(v8.v8_String_NewFromUtf8(isolate, bytes.ptr, @intCast(bytes.len)));
}

/// WebIDL 3.2.11, ByteString to ECMAScript: byte n becomes code unit n.
/// The IDL metadata selects this, never the Zig type (USVString is also a
/// byte slice). The returned Global<Value> is the caller's, including null.
pub fn byteStringToV8(comptime T: type, isolate: *v8.Isolate, value: T) ConversionError!*v8.Value {
    if (@typeInfo(T) == .optional) {
        if (value) |bytes| return byteStringToV8(@typeInfo(T).optional.child, isolate, bytes);
        return v8.v8_Null(isolate) orelse ConversionError.OutOfMemory;
    }
    if (T != []const u8 and T != []u8) @compileError("ByteString result must be a byte slice");
    if (value.len > std.math.maxInt(c_int)) return ConversionError.StringError;
    var small: [256]u16 = undefined;
    const units = if (value.len <= small.len) small[0..value.len] else try std.heap.page_allocator.alloc(u16, value.len);
    defer if (value.len > small.len) std.heap.page_allocator.free(units);
    for (value, units) |byte, *unit| unit.* = byte;
    return v8.v8_Value_StringFromTwoByte(isolate, units.ptr, @intCast(units.len)) orelse ConversionError.StringError;
}

/// Convert Zig DOMString to V8 String (its code units kept: newStringFromWtf8).
pub fn toV8String(
    isolate: *v8.Isolate,
    value: runtime.DOMString,
) *v8.String {
    // Get string slice from DOMString
    const slice = switch (value) {
        .empty => "",
        .interned => |s| s,
        .owned => |s| s,
    };

    const string = newStringFromWtf8(isolate, slice) orelse {
        // Fallback to empty string if creation fails
        return v8.v8_String_Empty(isolate).?;
    };
    return @ptrCast(string);
}

/// Convert Zig boolean to V8 Boolean
pub fn toV8Boolean(
    isolate: *v8.Isolate,
    value: runtime.Boolean,
) *v8.Boolean {
    // Use v8_Boolean_New to create a proper V8 Boolean
    const v8_bool = v8.v8_Boolean_New(isolate, value) orelse unreachable;
    return @ptrCast(v8_bool);
}

/// Convert Zig i32 (long) to V8 Number
pub fn toV8Long(
    isolate: *v8.Isolate,
    value: runtime.Long,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig u32 (unsigned long) to V8 Number
pub fn toV8UnsignedLong(
    isolate: *v8.Isolate,
    value: runtime.UnsignedLong,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig i64 (long long) to V8 Number
pub fn toV8LongLong(
    isolate: *v8.Isolate,
    value: runtime.LongLong,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig u64 (unsigned long long) to V8 Number
pub fn toV8UnsignedLongLong(
    isolate: *v8.Isolate,
    value: runtime.UnsignedLongLong,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatFromInt(value));
}

/// Convert Zig f64 (double) to V8 Number
pub fn toV8Double(
    isolate: *v8.Isolate,
    value: runtime.Double,
) *v8.Number {
    return v8.v8_Number_New(isolate, value);
}

/// Convert Zig f32 (float) to V8 Number
pub fn toV8Float(
    isolate: *v8.Isolate,
    value: runtime.Float,
) *v8.Number {
    return v8.v8_Number_New(isolate, @floatCast(value));
}

/// Convert runtime.Any (opaque pointer) to V8 Value
pub fn toV8Any(value: runtime.Any) *v8.Value {
    return @ptrCast(@alignCast(value));
}

/// Convert runtime.Object (opaque pointer) to V8 Object
pub fn toV8Object(value: runtime.Object) *v8.Object {
    return @ptrCast(@alignCast(value));
}

/// Convert Zig undefined to V8 Undefined
pub fn toV8Undefined(isolate: *v8.Isolate) *v8.Value {
    return v8.v8_Undefined(isolate) orelse unreachable; // Undefined always succeeds
}

/// Convert Zig null to V8 Null
pub fn toV8Null(isolate: *v8.Isolate) *v8.Value {
    return v8.v8_Null(isolate) orelse unreachable; // Null always succeeds
}

/// Convert Zig enum to V8 String (for WebIDL enums): WebIDL 3.2.24, "the
/// result of converting an IDL enumeration type value to an ECMAScript value
/// is the String value that represents the same sequence of code units as
/// the enumeration value" - `idlEnumValue`.
pub fn enumToV8String(comptime T: type, isolate: *v8.Isolate, value: T) *v8.Value {
    const string = idlEnumValue(T, value);
    if (v8.v8_String_NewFromUtf8(isolate, string.ptr, @intCast(string.len))) |str| {
        return @ptrCast(str);
    }
    return v8.v8_Undefined(isolate) orelse unreachable;
}

/// Convert Zig sequence to V8 Array
pub fn toV8Sequence(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    slice: []const T,
) ConversionError!*v8.Array {
    const array = v8.v8_Array_New(isolate, @intCast(slice.len));
    errdefer v8.v8_Array_Dispose(array);

    for (slice, 0..) |item, i| {
        const v8_value = try toV8Value(T, isolate, context, item);
        // Released once the array has it, when it was made here
        // (`memberValueIsOwned`, the rule every value put into an object
        // follows: a string, a number, a nested dictionary or sequence; a
        // union element by its active member - URLPattern exec()'s inputs, a
        // sequence<URLPatternInput>, leaked its String every call; an `any`
        // element by its arm); kept - a wrapper, an impl's handle - otherwise.
        // Asked of the type alone, runtime.JSValue read as a union of its arms
        // and released a sequence<any> element's handle, the impl's.
        defer if (memberValueIsOwned(T, item)) v8.v8_Value_Dispose(v8_value);
        _ = v8.v8_Array_Set(array, context, @intCast(i), v8_value);
    }

    return array;
}

/// Convert WebIDL record<K,V> to V8 Object
pub fn toV8Record(
    comptime K: type,
    comptime V: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    rec: runtime.record(K, V),
) ConversionError!*v8.Object {
    // CROSS-REALM SUPPORT: Create object in specified context for correct prototype chain
    const object = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;

    for (rec.entries) |entry| {
        const key_str = if (K == runtime.DOMString)
            toV8String(isolate, entry.key)
        else
            // For ByteString/USVString, convert to string.
            //
            // `interned`, not `owned`: entry.key is borrowed from rec.entries and
            // outlives nothing here. Claiming ownership of it made this DOMString
            // responsible for freeing the record's own key - the exact confusion
            // that `owned: []const u8` used to permit silently.
            // TODO: Proper conversion for different string types
            toV8String(isolate, runtime.DOMString.initInterned(entry.key));

        const value_v8 = try toV8Value(V, isolate, context, entry.value);
        _ = v8.v8_Object_Set(object, context, @ptrCast(key_str), value_v8);
    }

    return object;
}

/// ALLOWLIST: the raw function-pointer conversion's value IS its input Global
/// on success (freed with the value, interface.freeConvertedArg), and holds
/// nothing when it fails. Unknown pointer and aggregate types remain false;
/// nullable callbacks have the same rule.
pub fn callbackConversionAdoptsInput(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info == .optional) return callbackConversionAdoptsInput(info.optional.child);
    return info == .pointer and info.pointer.size == .one and @typeInfo(info.pointer.child) == .@"fn";
}

/// Whether `T` is a dictionary as toV8Value converts one: a struct that is
/// none of the special struct types (an interface, an optional argument, an
/// ArrayBufferView) - its conversion is an object made for the call.
fn isDictionaryValue(comptime T: type) bool {
    @setEvalBranchQuota(100_000);
    if (@typeInfo(T) != .@"struct") return false;
    if (@hasDecl(T, "Meta")) return false;
    if (@hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed")) return false;
    if (T == typedefs.ArrayBufferView) return false;
    if (T == JSValue or T == OptionalJSValue or T == runtime.OptionalJSValue) return false;
    if (@hasDecl(T, "ResultType") and @hasField(T, "handle")) return false;
    return true;
}

/// Whether toV8Value(T, ...) of EVERY value of type `T` is a Global made for
/// the call: what `interface.getterValueIsOwned` allows (numbers, booleans,
/// strings, enums, their nullable forms), a nested dictionary (an object made
/// here) and a sequence or record (an array or object made here). The type
/// half of `memberValueIsOwned`, which the converters ask: a type whose
/// values convert differently - a union, a webidl.Opt, an `any` - answers
/// false here and is decided there, by its value.
fn dictionaryMemberValueIsOwned(comptime T: type) bool {
    @setEvalBranchQuota(100_000);
    if (interface_mod.getterValueIsOwned(T)) return true;
    if (isDictionaryValue(T)) return true;
    const info = @typeInfo(T);
    if (info == .pointer and info.pointer.size == .slice) return true;
    if (info == .optional) return dictionaryMemberValueIsOwned(info.optional.child);
    return false;
}

/// Whether toV8Value(runtime.JSValue, ...) of `value` makes a Global for the
/// call, which the converter releases once the object it is put in has it:
/// an ALLOWLIST of the arms converted by making one - undefined, null, a
/// boolean, a number, a string (toV8Undefined, toV8Null, toV8Boolean,
/// v8_Number_New and newStringFromWtf8 each make a Global). A `.handle` is
/// the impl's own handle and an `.instance` converts to its wrapper, the
/// wrapper cache's: releasing either is a use-after-free, so they are kept,
/// and so is any arm not named here (tests/v8/record_value_ownership_test.zig
/// pins the default). A JSValue's TYPE cannot answer this, which is why
/// `dictionaryMemberValueIsOwned(runtime.JSValue)` keeps them all: a record
/// of them - URLPattern exec()'s groups - leaked one Global per entry.
pub fn jsValueConversionIsFresh(value: runtime.JSValue) bool {
    return switch (value) {
        .undefined, .null, .boolean, .number, .string => true,
        .handle, .instance => false,
    };
}

/// Whether toV8Value treats `T` as a webidl.Opt - the test its Opt branch
/// makes, so that this answers for exactly the values that branch converts.
fn isOptValue(comptime T: type) bool {
    return @typeInfo(T) == .@"struct" and @hasDecl(T, "notPassed") and
        @hasDecl(T, "wasPassed") and @hasDecl(T, "getValue");
}

/// Whether toV8Value converts a `T` by its generic union branch - the active
/// member as a value of its own type. The unions it converts by a branch of
/// their own (both JSValues and OptionalJSValues, a DOMString, an
/// ArrayBufferView) are not: their arms are representations, and read as
/// members, runtime.JSValue's `.handle` (a plain struct) looked like a
/// dictionary made for the call.
fn convertsByActiveMember(comptime T: type) bool {
    if (@typeInfo(T) != .@"union") return false;
    inline for (.{ JSValue, OptionalJSValue, runtime.JSValue, runtime.OptionalJSValue, runtime.DOMString, typedefs.ArrayBufferView }) |Own| {
        if (T == Own) return false;
    }
    return true;
}

/// Whether toV8Value(T, ..., value) of a value it puts INTO an object or array
/// it is building - a dictionary member, a sequence element, a record's key or
/// value - is a Global made for this conversion, which the converter releases
/// once CreateDataProperty (v8_Object_CreateDataProperty, v8_Array_Set) has
/// defined the property: V8 copies the value into the object, so the Global
/// made only to pass it is the converter's, and kept it is one per member per
/// call for the agent's life.
///
/// An ALLOWLIST read off the VALUE, because a type cannot answer for a union,
/// a webidl.Opt or an `any` (docs/lessons/architecture-a-jsvalue-s-type-
/// cannot-say-whether-its-conversion-is-fresh.md). Each arm is toV8Value's
/// own branch for the value:
///
/// - a runtime.JSValue: its arm (`jsValueConversionIsFresh`): undefined, null,
///   a boolean, number or string are made here; a `.handle` is the impl's and
///   an `.instance` the wrapper cache's wrapper - kept. A
///   runtime.OptionalJSValue not passed is a fresh undefined (toV8Undefined),
///   passed it is its JSValue. The V8 adapter's own JSValue types stay kept.
/// - a type every value of which is made here (`dictionaryMemberValueIsOwned`:
///   a number, boolean, string or enum, a dictionary, a sequence or record).
/// - a webidl.Opt: not passed, the undefined toV8Undefined makes; passed, its
///   inner value's answer. (A dictionary member not passed is no property at
///   all, so nothing is made for it there.)
/// - an optional: null is the Null toV8Null makes; otherwise its child's
///   answer - a ?(DOMString or object) member by its active member.
/// - a union toV8Value converts by its active member (`unionValueIsOwned`).
///
/// Anything else - a platform object's wrapper, an `*anyopaque`, a member type
/// not named - answers false: the handle is kept, the safe default
/// (tests/v8/dictionary_member_ownership_test.zig pins it). Codex row 41 Q21:
/// by type alone every union, Opt and `any` member was kept, and
/// Sanitizer.get() leaked 5,687 Globals on sanitizer-config.html.
pub fn memberValueIsOwned(comptime T: type, value: T) bool {
    @setEvalBranchQuota(100_000);
    if (comptime T == JSValue or T == OptionalJSValue) return false;
    if (comptime T == runtime.JSValue) return jsValueConversionIsFresh(value);
    if (comptime T == runtime.OptionalJSValue) return switch (value) {
        .not_passed => true,
        .passed => |passed| jsValueConversionIsFresh(passed),
    };
    if (comptime dictionaryMemberValueIsOwned(T)) return true;
    if (comptime isOptValue(T)) {
        if (!value.wasPassed()) return true;
        return memberValueIsOwned(@TypeOf(value.getValue()), value.getValue());
    }
    const info = @typeInfo(T);
    if (comptime info == .optional) {
        const child = value orelse return true;
        return memberValueIsOwned(info.optional.child, child);
    }
    if (comptime convertsByActiveMember(T)) return unionValueIsOwned(T, value);
    return false;
}

/// Whether toV8Value's result for a `T` returned by an operation is the
/// binding's to release: a dictionary's object is made for the call.
pub fn dictionaryValueIsOwned(comptime T: type) bool {
    return isDictionaryValue(T);
}

/// Release what a dictionary an operation RETURNED hands over with its
/// JavaScript values: each runtime.JSValue member's `.handle` (a member of
/// its inherited dictionary included), once toV8Value has built the object
/// from it - or failed to.
///
/// The rule: a JSValue member of a returned dictionary is handed to the
/// binding with engine.Owned.take(), exactly as a JSValue result is
/// (convertReturnValue's runtime.JSValue case), so the binding owns it.
/// toV8Value cannot know that - a `.handle` member of a dictionary it
/// converts anywhere else is the impl's own (`memberValueIsOwned`) - so it
/// keeps it, and V8 has copied the value into the object by the time this
/// runs. Kept, NavigationResult's committed and finished promises leaked two
/// Globals per navigation API call: 1,154 of the 1,170 leaks under leaks
/// --atExit over navigation-api/ (lane leaks5).
///
/// Every other arm is not a hold: undefined, null, a boolean, a number and
/// a string are values, and an `.instance` converts to the wrapper cache's
/// wrapper. A member not set (null, an Opt not passed) holds nothing.
///
/// The same holds for a [Default] toJSON record (codegen's `default_to_json`
/// struct), which an operation returns the same way. Audited 2026-10-18:
/// only NavigationResult hands a `.handle` over today. The other returned
/// dictionaries with a runtime.JSValue member (EffectTiming,
/// ComputedEffectTiming, MediaTrackCapabilities, MediaTrackSettings,
/// AuthenticationExtensionsClientOutputs) and toJSON records with one
/// (NotRestoredReasons, PaymentResponse, DigitalCredential,
/// PerformanceNavigationTiming, PerformanceLongTaskTiming, ContactAddress,
/// LayoutShift, PerformanceLongAnimationFrameTiming) are NotImplemented;
/// PerformanceResourceTiming's sets serverTiming to undefined, waiting for
/// this member ownership (its call_toJSON says so). An impl must never put a
/// handle it keeps into one: hand over a hold (engine.retainValue(...).take()).
/// tests/v8/returned_dictionary_handles_test.zig pins it.
pub fn releaseReturnedDictionaryHandles(comptime T: type, value: T) void {
    @setEvalBranchQuota(100_000);
    if (comptime !isDictionaryValue(T)) return;
    inline for (std.meta.fields(T)) |field| {
        const field_value = @field(value, field.name);
        if (comptime isInheritedDictionaryField(field)) {
            releaseReturnedDictionaryHandles(field.type, field_value);
        } else {
            releaseReturnedMember(field.type, field_value);
        }
    }
}

/// One member of a returned dictionary (`releaseReturnedDictionaryHandles`):
/// a runtime.JSValue's `.handle`, through an optional or a webidl.Opt.
fn releaseReturnedMember(comptime M: type, value: M) void {
    if (comptime M == runtime.JSValue) {
        switch (value) {
            .handle => |h| v8.v8_Global_Dispose(@ptrCast(@alignCast(h.ptr))),
            else => {},
        }
    } else if (comptime @typeInfo(M) == .optional) {
        if (value) |child| releaseReturnedMember(@typeInfo(M).optional.child, child);
    } else if (comptime isOptValue(M)) {
        if (value.wasPassed()) releaseReturnedMember(@TypeOf(value.getValue()), value.getValue());
    }
}

/// Whether toV8Value(T, ..., value) of a union `T` is a Global made for the
/// call: toV8Value converts the ACTIVE member as a value of its own type, so
/// the member decides, by the rule any value put into an object follows
/// (`memberValueIsOwned`: a string, number, boolean or enum, a dictionary, a
/// sequence; an `object` member by its JSValue arm; a nested union by its own
/// active member). Anything else - an interface member's wrapper (the wrapper
/// cache's), an `object` member's handle, an `*anyopaque` member (converted to
/// its instance's wrapper) - stays kept, the conservative answer. A union
/// toV8Value converts by a branch of its own (a JSValue, a DOMString, an
/// ArrayBufferView) is answered as that value, never as a union of its arms.
pub fn unionValueIsOwned(comptime T: type, value: T) bool {
    if (comptime !convertsByActiveMember(T)) return memberValueIsOwned(T, value);
    if (comptime @typeInfo(T).@"union".tag_type == null) {
        return false;
    } else {
        switch (value) {
            inline else => |payload| {
                const Member = @TypeOf(payload);
                if (comptime Member == *const anyopaque or Member == *anyopaque) return false;
                return memberValueIsOwned(Member, payload);
            },
        }
    }
}

/// Whether `field` is a dictionary's inherited dictionary: codegen keeps it
/// in a field named `base` whose type is the inherited dictionary's struct.
/// Only that: JsonLdOptions has a MEMBER named `base` (`USVString? base`).
fn isInheritedDictionaryField(comptime field: std.builtin.Type.StructField) bool {
    return comptime std.mem.eql(u8, field.name, "base") and isDictionaryValue(field.type);
}

/// Defines `key` on `obj` (CreateDataPropertyOrThrow: defined, never
/// assigned, so no setter on Object.prototype runs) as `value`, which the
/// caller keeps.
fn defineMember(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, comptime key: []const u8, value: *v8.Value) ConversionError!void {
    const key_v8 = v8.v8_String_NewFromUtf8(isolate, key.ptr, @intCast(key.len)) orelse return ConversionError.OutOfMemory;
    defer v8.v8_String_Dispose(key_v8);
    _ = v8.v8_Object_CreateDataProperty(obj, context, key_v8, value);
}

/// The index of member `name` in dictionary `T`'s `member_defaults` (codegen
/// lists each optional member that has an IDL default), or null.
fn memberDefaultIndex(comptime T: type, comptime name: []const u8) ?usize {
    comptime {
        @setEvalBranchQuota(100_000);
        if (!@hasDecl(T, "member_defaults")) return null;
        for (T.member_defaults, 0..) |entry, index| {
            if (std.mem.eql(u8, entry[0], name)) return index;
        }
        return null;
    }
}

/// Member type `M`'s value type: through a webidl.Opt and an optional.
fn MemberPayload(comptime M: type) type {
    if (isOptValue(M)) return MemberPayload(@FieldType(M, "value"));
    if (@typeInfo(M) == .optional) return MemberPayload(@typeInfo(M).optional.child);
    return M;
}

/// Whether every field of struct `T` has a default, so that `.{}` is a value
/// of it - a dictionary with no required member (WebIDL lets only such a
/// dictionary member default to `{}`).
fn defaultsToEmpty(comptime T: type) bool {
    comptime {
        for (std.meta.fields(T)) |f| {
            if (f.default_value_ptr == null and !isInheritedDictionaryField(f)) return false;
            if (isInheritedDictionaryField(f) and !defaultsToEmpty(f.type)) return false;
        }
        return true;
    }
}

/// The empty value of dictionary `T` (`{}`): every member unset, the
/// inherited dictionary's too.
fn emptyDictionary(comptime T: type) T {
    var result: T = undefined;
    inline for (std.meta.fields(T)) |f| {
        if (comptime isInheritedDictionaryField(f)) {
            @field(result, f.name) = emptyDictionary(f.type);
        } else {
            @field(result, f.name) = f.defaultValue().?;
        }
    }
    return result;
}

/// Member type `M`'s IDL default `default` (a `member_defaults` tag literal)
/// as an ECMAScript value, made for the call (OWNED): WebIDL 2.7 interprets
/// a dictionary member's default as an optional argument's - null, a
/// boolean, a number (the infinities, NaN), a string (an enumeration's value
/// is its string), [] an empty sequence, {} the member dictionary with its
/// own defaults.
fn memberDefaultToV8(comptime M: type, comptime default: anytype, isolate: *v8.Isolate, context: *v8.Context) ConversionError!*v8.Value {
    const D = @TypeOf(default);
    if (comptime @typeInfo(D) == .enum_literal) {
        const tag = comptime @tagName(default);
        if (comptime std.mem.eql(u8, tag, "null")) return toV8Null(isolate);
        if (comptime std.mem.eql(u8, tag, "positive_infinity")) return @ptrCast(v8.v8_Number_New(isolate, std.math.inf(f64)));
        if (comptime std.mem.eql(u8, tag, "negative_infinity")) return @ptrCast(v8.v8_Number_New(isolate, -std.math.inf(f64)));
        if (comptime std.mem.eql(u8, tag, "nan")) return @ptrCast(v8.v8_Number_New(isolate, std.math.nan(f64)));
        if (comptime std.mem.eql(u8, tag, "empty_sequence")) {
            return @ptrCast(v8.v8_Array_NewInContext(context, 0) orelse return ConversionError.OutOfMemory);
        }
        if (comptime std.mem.eql(u8, tag, "empty_dictionary")) {
            const Payload = MemberPayload(M);
            if (comptime isDictionaryValue(Payload) and defaultsToEmpty(Payload)) {
                return toV8Value(Payload, isolate, context, emptyDictionary(Payload));
            }
            // A union member typed JSValue whose default is its dictionary
            // arm's `{}`: an object with no member.
            return @ptrCast(v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory);
        }
        @compileError("unknown dictionary member default ." ++ tag);
    }
    if (comptime @hasField(D, "boolean")) return @ptrCast(toV8Boolean(isolate, default.boolean));
    if (comptime @hasField(D, "number")) return @ptrCast(v8.v8_Number_New(isolate, @as(f64, default.number)));
    if (comptime @hasField(D, "string")) return newStringFromWtf8(isolate, default.string) orelse ConversionError.StringError;
    @compileError("unknown dictionary member default " ++ @typeName(D));
}

/// WebIDL 3.2.18, an IDL dictionary value to an ECMAScript value, steps 2-3:
/// the members of D and of every dictionary it inherits, "in order from least
/// to most derived", each dictionary's "in lexicographical order" - written
/// to the one object `obj`. Codegen keeps the inherited dictionary in a
/// `base` field, so its members are written first, onto `obj` itself: kept
/// as a property, Sanitizer.get()'s elements were `{base: {name, namespace},
/// removeAttributes}` (Codex row 41 Q9). Declaration order is not the order
/// either (`dictionaryMemberOrder`, the same order the members are read in).
///
/// Step 3.1.2, "If dictionary[key] exists": a required member, an optional
/// one that is not null, a webidl.Opt that was passed - and, when the value
/// leaves it unset, a member with an IDL default (`member_defaults`), which
/// always exists (WebIDL 2.7; Blink and Gecko initialise every defaulted
/// member, so their ToV8 always writes it). A nullable member whose default
/// is null is so written as null (Sanitizer.get()'s `namespace: null`).
/// Anything else is no property at all.
fn writeDictionaryMembers(comptime T: type, isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, value: T) ConversionError!void {
    @setEvalBranchQuota(100_000);
    const members = comptime dictionaryMemberOrder(T);
    inline for (members) |field| {
        const field_value = @field(value, field.name);
        if (comptime isInheritedDictionaryField(field)) {
            try writeDictionaryMembers(field.type, isolate, context, obj, field_value);
        } else {
            const present = if (comptime isOptValue(field.type))
                field_value.wasPassed()
            else if (comptime @typeInfo(field.type) == .optional)
                field_value != null
            else
                true;
            const default_index = comptime memberDefaultIndex(T, field.name);
            if (present) {
                const field_v8 = try toV8Value(field.type, isolate, context, field_value);
                // Released once defined when it was made here
                // (`memberValueIsOwned`: a union member by its active member,
                // an Opt by its inner value, an `any` by its arm).
                defer if (memberValueIsOwned(field.type, field_value)) v8.v8_Value_Dispose(field_v8);
                try defineMember(isolate, context, obj, field.name, field_v8);
            } else if (comptime default_index != null) {
                // Every default is made for this member: released once defined.
                const default_v8 = try memberDefaultToV8(field.type, T.member_defaults[default_index.?][1], isolate, context);
                defer v8.v8_Value_Dispose(default_v8);
                try defineMember(isolate, context, obj, field.name, default_v8);
            }
        }
    }
}

/// A [Default] toJSON result (codegen marks its struct `default_to_json`) is
/// not a dictionary: WebIDL 3.7.4.1 sets map[id] to every JSON-typed
/// attribute's value, in the interface's attribute order, and creates a data
/// property for each - so a nullable attribute that is null is a property
/// whose value is null (toV8Value's null for an optional that is null).
fn writeDefaultToJsonMembers(comptime T: type, isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, value: T) ConversionError!void {
    inline for (std.meta.fields(T)) |field| {
        const field_value = @field(value, field.name);
        const field_v8 = try toV8Value(field.type, isolate, context, field_value);
        // A null is the Null toV8Null made (`memberValueIsOwned`).
        defer if (memberValueIsOwned(field.type, field_value)) v8.v8_Value_Dispose(field_v8);
        try defineMember(isolate, context, obj, field.name, field_v8);
    }
}

pub fn toV8Value(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: T,
) ConversionError!*v8.Value {
    // CRITICAL: Handle JSValue types first - they're special union types that need
    // custom conversion, not generic union handling (which would convert
    // the StringValue inner struct to an object with "data" and "owned" fields)

    // Handle V8-specific JSValue (from engines/v8/js_value.zig)
    if (T == JSValue) {
        return value.toV8(isolate);
    }
    if (T == OptionalJSValue) {
        return switch (value) {
            .not_passed => toV8Undefined(isolate),
            .passed => |v| v.toV8(isolate),
        };
    }

    // An ArrayBufferView that refers to a JavaScript object converts back to
    // that object (borrowed: the IDL value keeps its handle).
    if (T == typedefs.ArrayBufferView) {
        const js = value.jsHandle() orelse return toV8Undefined(isolate);
        return @ptrCast(@alignCast(js));
    }

    // Handle engine-agnostic JSValue (from runtime/js_value.zig)
    // This is used by WebIDL impls that want to remain engine-agnostic
    if (T == runtime.JSValue) {
        return switch (value) {
            .undefined => toV8Undefined(isolate),
            .null => toV8Null(isolate),
            .boolean => |b| @ptrCast(toV8Boolean(isolate, b)),
            .number => |n| @ptrCast(v8.v8_Number_New(isolate, n)),
            // WTF-8: its lone surrogates kept (newStringFromWtf8).
            .string => |s| newStringFromWtf8(isolate, s.data) orelse return ConversionError.StringError,
            .handle => |h| blk: {
                // SAFETY CHECK: V8 Global handles must be 8-byte aligned.
                // If the pointer is not aligned, it's likely a Zig pointer that was
                // incorrectly stored via fromAnyopaque() - return undefined instead of crashing.
                const ptr_addr = @intFromPtr(h.ptr);
                if (ptr_addr % 8 != 0) {
                    // Not a valid V8 handle - this is a bug in the calling code
                    // but we handle it gracefully instead of crashing
                    debug.print("WARNING: Misaligned handle in runtime.JSValue: 0x{x}\n", .{ptr_addr});
                    break :blk toV8Undefined(isolate);
                }

                // For both Global and Local handles, return the pointer directly.
                // The caller (setReturnValue) will use SetReturnValueGlobal which
                // handles Global<Value>* pointers correctly by calling Get() internally.
                // For Local handles, this also works because SetReturnValueGlobal
                // can handle both Global and Local pointers - it checks if the
                // pointer is valid and handles conversion appropriately.
                break :blk @ptrCast(h.ptr);
            },
            .instance => |i| instanceToV8(isolate, @ptrCast(@alignCast(i))),
        };
    }
    if (T == runtime.OptionalJSValue) {
        return switch (value) {
            .not_passed => toV8Undefined(isolate),
            .passed => |v| try toV8Value(runtime.JSValue, isolate, context, v),
        };
    }

    // A DOMString is a tagged union (empty, interned, owned) with a meaning
    // of its own: a string. Before the generic union branch below, which
    // converts the active field - and the empty variant's field is `void`,
    // which made an empty DOMString reach script as undefined
    // (DOMStringList[0] while item(0) was "").
    if (T == runtime.DOMString) return @ptrCast(toV8String(isolate, value));

    // Handle webidl.Opt types (WebIDL optional parameters)
    // These are structs with was_passed and value fields, used for optional parameters
    // that need to distinguish between "not passed" and "passed with value"
    if (@typeInfo(T) == .@"struct") {
        if (@hasDecl(T, "notPassed") and @hasDecl(T, "wasPassed") and @hasDecl(T, "getValue")) {
            // This is a webidl.Opt type
            if (!value.wasPassed()) {
                // Not passed -> undefined
                return toV8Undefined(isolate);
            } else {
                // Passed -> convert inner value
                const InnerType = @TypeOf(value.getValue());
                return try toV8Value(InnerType, isolate, context, value.getValue());
            }
        }
    }

    // Handle optional types (nullable)
    const type_info = @typeInfo(T);
    if (type_info == .optional) {
        if (value) |v| {
            // Recursively convert the child value
            const ChildType = type_info.optional.child;
            return try toV8Value(ChildType, isolate, context, v);
        } else {
            // null becomes V8 Null
            return toV8Null(isolate);
        }
    }

    // Handle error unions
    if (type_info == .error_union) {
        const unwrapped = value catch |err| {
            // Convert error to V8 exception. The message is read into the
            // Error (v8_Exception_Error makes a Local of it) and released:
            // kept, it was a Global per failed call.
            const err_name = @errorName(err);
            const err_msg = v8.v8_String_NewFromUtf8(isolate, err_name.ptr, @intCast(err_name.len)) orelse {
                // Fallback to generic error if string creation fails
                const fallback = v8.v8_String_NewFromUtf8(isolate, "Error".ptr, 5).?;
                defer v8.v8_String_Dispose(fallback);
                return @ptrCast(v8.v8_Exception_Error(fallback));
            };
            defer v8.v8_String_Dispose(err_msg);
            return @ptrCast(v8.v8_Exception_Error(err_msg));
        };
        const PayloadType = type_info.error_union.payload;
        return try toV8Value(PayloadType, isolate, context, unwrapped);
    }

    // Handle slices (sequence<T>)
    if (type_info == .pointer and type_info.pointer.size == .slice) {
        const ElemType = type_info.pointer.child;
        // Special case: []const u8 and []u8 are strings, not arrays
        if (ElemType == u8) {
            // WTF-8: its lone surrogates kept (newStringFromWtf8).
            return newStringFromWtf8(isolate, value) orelse ConversionError.StringError;
        }

        // Special case: Slice of structs with "key" and "value" fields => WebIDL record type
        // Convert to JavaScript object where key becomes property name
        const elem_type_info = @typeInfo(ElemType);
        if (elem_type_info == .@"struct") {
            const has_key = @hasField(ElemType, "key");
            const has_value = @hasField(ElemType, "value");
            const field_count = std.meta.fields(ElemType).len;
            if (has_key and has_value and field_count == 2) {
                // This is a record-like type - convert to object. WebIDL
                // 3.2.20: "Let result be OrdinaryObjectCreate(%Object.prototype%)"
                // (of `context`'s realm) and for each entry "Perform
                // ! CreateDataPropertyOrThrow(result, jsKey, jsValue)" -
                // defined, never assigned. Every key and value made here is
                // released once the object has it, as the dictionary branch
                // does: kept, they were two Globals per entry.
                const obj = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;
                errdefer v8.v8_Object_Dispose(obj);
                const KeyType = std.meta.fieldInfo(ElemType, .key).type;
                const ValueType = std.meta.fieldInfo(ElemType, .value).type;
                for (value) |entry| {
                    const key_v8 = try toV8Value(KeyType, isolate, context, entry.key);
                    defer if (memberValueIsOwned(KeyType, entry.key)) v8.v8_Value_Dispose(key_v8);
                    // Get value - handle anyopaque as string pointer
                    const is_string_pointer = comptime (ValueType == *const anyopaque or ValueType == *anyopaque);
                    const val_v8 = blk: {
                        if (comptime is_string_pointer) {
                            // The value is a pointer to a string slice
                            const str_ptr: *const []const u8 = @ptrCast(@alignCast(entry.value));
                            break :blk newStringFromWtf8(isolate, str_ptr.*) orelse return ConversionError.StringError;
                        } else {
                            break :blk try toV8Value(ValueType, isolate, context, entry.value);
                        }
                    };
                    // The string made from a string pointer, and a value
                    // `memberValueIsOwned` says was made for this entry (a
                    // JSValue by its arm - jsValueConversionIsFresh - a union
                    // by its active member), go once CreateDataProperty has
                    // copied them into the object.
                    defer if (is_string_pointer or memberValueIsOwned(ValueType, entry.value)) v8.v8_Value_Dispose(val_v8);
                    _ = v8.v8_Object_CreateDataProperty(obj, context, @ptrCast(key_v8), val_v8);
                }
                return @ptrCast(obj);
            }
        }

        return @ptrCast(try toV8Sequence(ElemType, isolate, context, value));
    }

    // Handle integers (all sizes, signed and unsigned)
    if (type_info == .int) {
        const num = v8.v8_Number_New(isolate, @floatFromInt(value));
        return @ptrCast(num);
    }

    // Handle floats (f32, f64, etc.)
    if (type_info == .float) {
        const num = v8.v8_Number_New(isolate, @floatCast(value));
        return @ptrCast(num);
    }

    // Handle booleans
    if (type_info == .bool or T == bool) {
        return @ptrCast(toV8Boolean(isolate, value));
    }

    // Handle enums: WebIDL 3.2.24, the String of the enumeration value's
    // code units (`idlEnumValue`).
    if (type_info == .@"enum") {
        return enumToV8String(T, isolate, value);
    }

    // Structs: a dictionary (WebIDL 3.2.18), or a [Default] toJSON result.
    if (type_info == .@"struct") {
        // "Let O be OrdinaryObjectCreate(%Object.prototype%)" - of `context`'s
        // realm (default-toJSON-cross-realm.html). The object is the caller's
        // (`dictionaryValueIsOwned`); every key and member value made for it
        // is released once the object has it. Kept, a dictionary an
        // operation returned leaked a Global per member (Navigation.navigate's
        // result, URLPattern.exec's).
        const obj = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;
        errdefer v8.v8_Object_Dispose(obj);
        if (comptime @hasDecl(T, "default_to_json")) {
            try writeDefaultToJsonMembers(T, isolate, context, obj, value);
        } else {
            try writeDictionaryMembers(T, isolate, context, obj, value);
        }
        return @ptrCast(obj);
    }

    // Handle unions (convert active field to V8)
    if (type_info == .@"union") {
        const union_info = type_info.@"union";
        const fields = union_info.fields;

        // Use inline switch to dispatch on active field at runtime
        inline for (fields) |field| {
            if (std.mem.eql(u8, @tagName(value), field.name)) {
                const field_value = @field(value, field.name);

                // Special case: *const anyopaque and *anyopaque are wrapped interface instances
                // These need to be converted back to V8 objects using instanceToV8
                if (field.type == *const anyopaque or field.type == *anyopaque) {
                    // The anyopaque pointer is actually a *runtime.Instance
                    const instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(field_value)));
                    return instanceToV8(isolate, instance);
                }

                // For other types, recursively convert
                return try toV8Value(field.type, isolate, context, field_value);
            }
        }

        // No active field found (shouldn't happen with valid union)
        return toV8Undefined(isolate);
    }

    // Handle void (return undefined)
    if (T == void) {
        return toV8Undefined(isolate);
    }

    // Handle *runtime.Instance pointers - these need to be wrapped as V8 objects
    // This enables toV8Sequence to work with []const *runtime.Instance
    // Use comptime type check to handle both direct type and type aliases (like WindowProxy)
    if (T == *runtime.Instance) {
        return instanceToV8(isolate, value);
    }
    if (T == *const runtime.Instance) {
        return instanceToV8(isolate, @constCast(value));
    }

    // Handle pointers - Check if pointer child is runtime.Instance to handle type aliases
    if (type_info == .pointer) {
        const child_type = type_info.pointer.child;
        // Check if this is a pointer to runtime.Instance (handles type aliases like WindowProxy)
        if (child_type == runtime.Instance) {
            const instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(value)));
            return instanceToV8(isolate, instance);
        }
        // Return undefined for unknown pointer types to prevent crashes
        return toV8Undefined(isolate);
    }

    // Handle WebIDL primitive types with explicit conversion functions
    // Note: Most types should be handled by the checks above (int, float, bool, enum, struct, pointer, etc.)
    // This switch only catches specific runtime types that need special handling
    if (T == runtime.Boolean) return @ptrCast(toV8Boolean(isolate, value));
    if (T == runtime.Long) return @ptrCast(toV8Long(isolate, value));
    if (T == runtime.UnsignedLong) return @ptrCast(toV8UnsignedLong(isolate, value));
    if (T == runtime.LongLong) return @ptrCast(toV8LongLong(isolate, value));
    if (T == runtime.UnsignedLongLong) return @ptrCast(toV8UnsignedLongLong(isolate, value));
    if (T == u64) return @ptrCast(toV8UnsignedLongLong(isolate, value));
    if (T == runtime.Double) return @ptrCast(toV8Double(isolate, value));
    if (T == runtime.Float) return @ptrCast(toV8Float(isolate, value));
    // runtime.DOMString: at the top, before the generic union branch.
    // SAFETY: runtime.Any is *anyopaque which might not be a valid V8 Value pointer
    // Return undefined instead of blindly casting to prevent crashes
    if (T == runtime.Any) return toV8Undefined(isolate);

    // NOTE: JSValue and OptionalJSValue are handled at the top of this function
    // to ensure they're converted correctly before generic union handling runs

    // If we get here, it's an unsupported type that wasn't handled by any of the above cases
    // This should be rare - most types are covered by generic handlers (int, float, struct, pointer, etc.)
    @compileError("Unsupported type for V8 conversion: " ++ @typeName(T) ++
        ". If this is a struct, make sure it's being handled by the struct case above.");
}

// ============================================================================
// Argument Extraction Helpers
// ============================================================================

/// Extract and convert function arguments from V8 callback info
///
/// This is a convenience function for extracting multiple arguments at once.
/// Returns a tuple of converted arguments matching the parameter types.
///
/// Example:
/// ```zig
/// const args = try extractArgs(
///     .{ runtime.DOMString, runtime.Long, runtime.Boolean },
///     allocator,
///     info,
/// );
/// defer allocator.free(args[0]); // Free DOMString if owned
///
/// const label = args[0];
/// const count = args[1];
/// const enabled = args[2];
/// ```
pub fn extractArgs(
    comptime Types: anytype,
    allocator: std.mem.Allocator,
    info: *const v8.FunctionCallbackInfo,
) ConversionError!Types {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    const length = info.length();

    const type_info = @typeInfo(@TypeOf(Types));
    if (type_info != .Struct or !type_info.Struct.is_tuple) {
        @compileError("Types must be a tuple of types");
    }

    const fields = type_info.Struct.fields;
    var result: Types = undefined;

    inline for (fields, 0..) |field, i| {
        if (i >= length) {
            // Not enough arguments provided
            return ConversionError.TypeError;
        }

        const v8_value = info.get(@intCast(i));
        result[i] = try fromV8Value(
            field.type,
            allocator,
            isolate,
            context,
            v8_value,
        );
    }

    return result;
}

/// Check if V8 argument at index exists and is not undefined
pub fn hasArgument(info: *const v8.FunctionCallbackInfo, index: c_int) bool {
    if (index >= info.length()) {
        return false;
    }
    const value = info.get(index);
    return !v8.v8_Value_IsUndefined(value);
}

/// Get optional argument with default value
pub fn getOptionalArg(
    comptime T: type,
    allocator: std.mem.Allocator,
    info: *const v8.FunctionCallbackInfo,
    index: c_int,
    default: T,
) ConversionError!T {
    if (!hasArgument(info, index)) {
        return default;
    }

    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    const v8_value = info.get(index);

    return try fromV8Value(T, allocator, isolate, context, v8_value);
}

// ============================================================================
// Return Value Helpers
// ============================================================================

/// Set return value for V8 callback
///
/// Converts Zig value to V8 and sets it as the return value of the callback.
pub fn setReturnValue(
    comptime T: type,
    info: *const v8.FunctionCallbackInfo,
    value: T,
) ConversionError!void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate).?;
    defer v8.v8_Context_Dispose(context);
    const v8_value = try toV8Value(T, isolate, context, value);
    info.setReturnValue(v8_value);
}

/// Set undefined as return value. No handle is made for it: the setter's
/// null case is V8's ReturnValue::SetUndefined. Made through toV8Undefined,
/// the Global was never released - one per void namespace call.
pub fn setReturnUndefined(info: *const v8.FunctionCallbackInfo) void {
    v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnValueGlobal(info, null);
}

/// Set null as return value. setReturnValue copies the handle into the
/// call's return slot, so the one made here is released after it.
pub fn setReturnNull(info: *const v8.FunctionCallbackInfo) void {
    const isolate = info.getIsolate();
    const v8_value = toV8Null(isolate);
    info.setReturnValue(v8_value);
    v8.v8_Value_Dispose(v8_value);
}

// ============================================================================
// Exception Helpers
// ============================================================================
//
// Every handle a helper makes is owned (a `v8_*` call that returns a pointer
// allocates a Global), and each one is released here - the message string,
// the keys, the constructor it looked up, and the exception itself, once it
// is thrown: `v8_Isolate_ThrowException` hands V8 a Local of it, and V8 keeps
// the value it is throwing. An exception handle left behind is a Global into
// the realm that made it, and keeps that realm - every object in it - alive
// for the life of the process; one per binding "Illegal invocation" kept
// every frame realm a WPT sweep made
// (docs/lessons/architecture-engine-code-defines-a-realm-s-properties-it-never-assigns-them.md).

/// Throw a TypeError in V8
pub fn throwTypeError(
    isolate: *v8.Isolate,
    message: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    defer v8.v8_String_Dispose(msg_str);
    const exception = v8.v8_Exception_TypeErrorInContext(context, msg_str) orelse return; // Failed to create exception
    defer v8.v8_Value_Dispose(exception);
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a TypeError from a specific context's realm (for cross-realm support).
///
/// Per WebIDL spec, when a method throws TypeError for invalid `this`,
/// the error must come from the method's realm (callee's realm), not the caller's realm.
/// This is essential for cross-realm scenarios like:
///
/// ```javascript
/// const other = iframe.contentWindow;
/// const notElement = Object.create(other.HTMLElement.prototype);
/// // This must throw other.TypeError (iframe's TypeError), NOT main window's TypeError
/// Object.getOwnPropertyDescriptor(other.HTMLElement.prototype, "title").get.call(notElement);
/// ```
///
/// @param isolate - The V8 isolate
/// @param context - The context/realm where the TypeError should originate (callee's realm)
/// @param message - The error message
pub fn throwTypeErrorFromContext(
    isolate: *v8.Isolate,
    context: *v8.Context,
    message: []const u8,
) void {
    // CRITICAL: Enter the context before creating and throwing the exception.

    // This ensures that:
    // 1. The TypeError object is an instance of context.TypeError
    // 2. The stack trace and other details are correctly associated with this realm
    // 3. The exception is thrown within this context
    v8.v8_Context_Enter(context);
    defer v8.v8_Context_Exit(context);

    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    defer v8.v8_String_Dispose(msg_str);

    const exception = v8.v8_Exception_TypeErrorInContext(context, msg_str) orelse {
        // Fallback to regular TypeError if context-specific creation fails
        const fallback = v8.v8_Exception_TypeError(msg_str) orelse return;
        defer v8.v8_Value_Dispose(fallback);
        v8.v8_Isolate_ThrowException(isolate, fallback);
        return;
    };
    defer v8.v8_Value_Dispose(exception);
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a RangeError in V8
pub fn throwRangeError(
    isolate: *v8.Isolate,
    message: []const u8,
) void {
    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    defer v8.v8_String_Dispose(msg_str);
    const exception = v8.v8_Exception_RangeError(msg_str) orelse return;
    defer v8.v8_Value_Dispose(exception);
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a generic Error in V8
pub fn throwError(
    isolate: *v8.Isolate,
    message: []const u8,
) void {
    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse return; // Failed to create string, can't throw
    defer v8.v8_String_Dispose(msg_str);
    const exception = v8.v8_Exception_Error(msg_str) orelse return;
    defer v8.v8_Value_Dispose(exception);
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw an Error with a specific name property set (DOMException fallback)
///
/// This is used when we can't create a proper DOMException instance but need
/// to throw an error with the correct `.name` property for WPT tests.
/// Per WebIDL spec, tests check `e.name === "SyntaxError"` etc.
fn throwDOMExceptionFallback(
    isolate: *v8.Isolate,
    name: []const u8,
    message: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        throwError(isolate, message);
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Create the error message string
    const msg_str = v8.v8_String_NewFromUtf8(
        isolate,
        message.ptr,
        @intCast(message.len),
    ) orelse {
        throwError(isolate, message);
        return;
    };
    defer v8.v8_String_Dispose(msg_str);

    // Create a generic Error
    const exception = v8.v8_Exception_Error(msg_str) orelse {
        throwError(isolate, message);
        return;
    };
    defer v8.v8_Value_Dispose(exception);

    // Set the .name property to the DOMException name
    const name_key = v8.v8_String_NewFromUtf8(isolate, "name", 4) orelse {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return;
    };
    defer v8.v8_String_Dispose(name_key);
    const name_value = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return;
    };
    defer v8.v8_String_Dispose(name_value);
    _ = v8.v8_Object_Set(@ptrCast(exception), context, @ptrCast(name_key), @ptrCast(name_value));

    // Set the .code property to the legacy error code
    const code_key = v8.v8_String_NewFromUtf8(isolate, "code", 4) orelse {
        v8.v8_Isolate_ThrowException(isolate, exception);
        return;
    };
    defer v8.v8_String_Dispose(code_key);
    const code = getLegacyCodeForDOMExceptionName(name);
    const code_value = v8.v8_Number_New(isolate, @floatFromInt(code));
    defer v8.v8_Value_Dispose(@ptrCast(code_value));
    _ = v8.v8_Object_Set(@ptrCast(exception), context, @ptrCast(code_key), @ptrCast(code_value));

    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Get legacy error code for a DOMException name
fn getLegacyCodeForDOMExceptionName(name: []const u8) u16 {
    const legacy_codes = std.StaticStringMap(u16).initComptime(.{
        .{ "IndexSizeError", 1 },
        .{ "HierarchyRequestError", 3 },
        .{ "WrongDocumentError", 4 },
        .{ "InvalidCharacterError", 5 },
        .{ "NoModificationAllowedError", 7 },
        .{ "NotFoundError", 8 },
        .{ "NotSupportedError", 9 },
        .{ "InUseAttributeError", 10 },
        .{ "InvalidStateError", 11 },
        .{ "SyntaxError", 12 },
        .{ "InvalidModificationError", 13 },
        .{ "NamespaceError", 14 },
        .{ "InvalidAccessError", 15 },
        .{ "TypeMismatchError", 17 },
        .{ "SecurityError", 18 },
        .{ "NetworkError", 19 },
        .{ "AbortError", 20 },
        .{ "URLMismatchError", 21 },
        .{ "QuotaExceededError", 22 },
        .{ "TimeoutError", 23 },
        .{ "InvalidNodeTypeError", 24 },
        .{ "DataCloneError", 25 },
    });
    return legacy_codes.get(name) orelse 0;
}

/// Throw a DOMException in V8
///
/// Creates a proper DOMException instance with the correct name and message properties.
/// This is essential for WebIDL error handling where tests check:
/// - e instanceof DOMException === true
/// - e.name === "ErrorName"
/// - e.code === <legacy code>
///
/// If DOMException constructor is not available, falls back to generic Error.
pub fn throwDOMException(
    isolate: *v8.Isolate,
    name: []const u8,
    message: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Context_Dispose(context);
    // The derived interface (WebIDL 2.8.3), not a DOMException named so.
    if (isQuotaExceededError(name)) {
        if (newQuotaExceededError(isolate, context, message)) |exception| {
            defer v8.v8_Value_Dispose(exception);
            v8.v8_Isolate_ThrowException(isolate, exception);
            return;
        }
    }
    // Owned: `v8_Context_Global` allocates a Global<Object> where V8's own
    // `Context::Global()` returns a borrowed Local. Disposing releases OUR
    // handle; the global object itself stays rooted by the context.
    // Not applied in context_manager.zig, which hands its global to
    // `WindowImpl.setBoundV8Global` and so keeps it.
    const global = v8.v8_Context_Global(context) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Object_Dispose(global);

    // Get the DOMException constructor from global
    const dom_exception_key = v8.v8_String_NewFromUtf8(isolate, "DOMException", 12) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(dom_exception_key);
    const dom_exception_ctor = v8.v8_Object_Get(global, context, @ptrCast(dom_exception_key)) orelse {
        // DOMException not registered, fall back to Error with .name property
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(dom_exception_ctor);

    if (!v8.v8_Value_IsFunction(dom_exception_ctor)) {
        // DOMException is not a function, fall back to Error with .name property
        throwDOMExceptionFallback(isolate, name, message);
        return;
    }

    // Create V8 strings for the arguments
    const v8_message = v8.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(v8_message);
    const v8_name = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(v8_name);

    // Use Reflect.construct to call the constructor
    // Reflect.construct(DOMException, [message, name])
    const reflect_key = v8.v8_String_NewFromUtf8(isolate, "Reflect", 7) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(reflect_key);
    const reflect_obj = v8.v8_Object_Get(global, context, @ptrCast(reflect_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(reflect_obj);
    const construct_key = v8.v8_String_NewFromUtf8(isolate, "construct", 9) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(construct_key);
    const construct_fn_value = v8.v8_Object_Get(@ptrCast(reflect_obj), context, @ptrCast(construct_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(construct_fn_value);
    if (!v8.v8_Value_IsFunction(construct_fn_value)) {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    }
    const construct_fn: *v8.Function = @ptrCast(construct_fn_value);

    // Create argument array: [message, name]
    const args_array = v8.v8_Array_New(isolate, 2);
    defer v8.v8_Array_Dispose(args_array);
    _ = v8.v8_Array_Set(args_array, context, 0, @ptrCast(v8_message));
    _ = v8.v8_Array_Set(args_array, context, 1, @ptrCast(v8_name));

    // Call Reflect.construct(DOMException, [message, name])
    var args = [_]*v8.Value{ dom_exception_ctor, @ptrCast(args_array) };
    const exception = v8.v8_Function_Call(construct_fn, context, reflect_obj, 2, &args) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(exception);

    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a DOMException from a specific context's realm
///
/// Per WebIDL spec, DOMExceptions should be thrown from the function's realm
/// or the caller's realm depending on the error type. For cross-origin security
/// errors, this should be the caller's realm so the caller's try/catch can catch it.
pub fn throwDOMExceptionFromContext(
    isolate: *v8.Isolate,
    context: *v8.Context,
    name: []const u8,
    message: []const u8,
) void {
    log.debug("[throwDOMExceptionFromContext] name={s}\n", .{name});
    // The derived interface (WebIDL 2.8.3), not a DOMException named so.
    if (isQuotaExceededError(name)) {
        if (newQuotaExceededError(isolate, context, message)) |exception| {
            defer v8.v8_Value_Dispose(exception);
            v8.v8_Isolate_ThrowException(isolate, exception);
            return;
        }
    }
    // Owned: `v8_Context_Global` allocates a Global<Object> where V8's own
    // `Context::Global()` returns a borrowed Local. Disposing releases OUR
    // handle; the global object itself stays rooted by the context.
    // Not applied in context_manager.zig, which hands its global to
    // `WindowImpl.setBoundV8Global` and so keeps it.
    const global = v8.v8_Context_Global(context) orelse {
        log.debug("[throwDOMExceptionFromContext] fallback - no global\n", .{});
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Object_Dispose(global);

    // Get the DOMException constructor from the specified context's global
    const dom_exception_key = v8.v8_String_NewFromUtf8(isolate, "DOMException", 12) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(dom_exception_key);
    const dom_exception_ctor = v8.v8_Object_Get(global, context, @ptrCast(dom_exception_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(dom_exception_ctor);

    if (!v8.v8_Value_IsFunction(dom_exception_ctor)) {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    }

    // Create V8 strings for the arguments
    const v8_message = v8.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(v8_message);
    const v8_name = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(v8_name);

    // Use Reflect.construct to call the constructor
    const reflect_key = v8.v8_String_NewFromUtf8(isolate, "Reflect", 7) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(reflect_key);
    const reflect_obj = v8.v8_Object_Get(global, context, @ptrCast(reflect_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(reflect_obj);
    const construct_key = v8.v8_String_NewFromUtf8(isolate, "construct", 9) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_String_Dispose(construct_key);
    const construct_fn_value = v8.v8_Object_Get(@ptrCast(reflect_obj), context, @ptrCast(construct_key)) orelse {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(construct_fn_value);
    if (!v8.v8_Value_IsFunction(construct_fn_value)) {
        throwDOMExceptionFallback(isolate, name, message);
        return;
    }
    const construct_fn: *v8.Function = @ptrCast(construct_fn_value);

    // Create argument array: [message, name]
    const args_array = v8.v8_Array_New(isolate, 2);
    defer v8.v8_Array_Dispose(args_array);
    _ = v8.v8_Array_Set(args_array, context, 0, @ptrCast(v8_message));
    _ = v8.v8_Array_Set(args_array, context, 1, @ptrCast(v8_name));

    // Call Reflect.construct(DOMException, [message, name])
    var args = [_]*v8.Value{ dom_exception_ctor, @ptrCast(args_array) };
    const exception = v8.v8_Function_Call(construct_fn, context, reflect_obj, 2, &args) orelse {
        log.debug("[throwDOMExceptionFromContext] fallback - Reflect.construct failed\n", .{});
        throwDOMExceptionFallback(isolate, name, message);
        return;
    };
    defer v8.v8_Value_Dispose(exception);

    log.debug("[throwDOMExceptionFromContext] throwing exception\n", .{});
    v8.v8_Isolate_ThrowException(isolate, exception);
}

/// WebIDL 2.8.3 "Predefined DOMException derived interfaces": a
/// QuotaExceededError is an instance of the QuotaExceededError interface
/// (with `quota` and `requested`, here both null) - not a DOMException that is
/// merely named so. A new one in `context`'s realm, made by its constructor
/// (interfaces.QuotaExceededError.call_constructor, whose steps 1-2 initialize
/// the DOMException base through the DOMException-owned hook,
/// src/dom/dom_exceptions.zig), as its wrapper: an OWNED Global. Null when the
/// realm is not one the engine hosts or the constructor fails.
fn newQuotaExceededError(isolate: *v8.Isolate, context: *v8.Context, message: []const u8) ?*v8.Value {
    const interfaces = @import("interfaces");
    const QuotaExceededError = interfaces.QuotaExceededError;
    const realm = @import("context_manager.zig").get(context) orelse return null;
    const params = @typeInfo(@TypeOf(QuotaExceededError.call_constructor)).@"fn".params;
    const Message = params[1].type.?;
    const Options = params[2].type.?;
    const instance = QuotaExceededError.call_constructor(realm, Message.passed(runtime.DOMString.initInterned(message)), Options.notPassed()) catch return null;
    v8.v8_Context_Enter(context);
    defer v8.v8_Context_Exit(context);
    const wrapper = instanceToV8(isolate, instance);
    if (v8.v8_Value_IsUndefined(wrapper)) return null;
    return v8.v8_Global_Clone(wrapper);
}

fn isQuotaExceededError(name: []const u8) bool {
    return std.mem.eql(u8, name, "QuotaExceededError");
}

/// A new DOMException named `name` with `message`, made by `context`'s
/// DOMException constructor - the value an algorithm rejects a promise with,
/// or stores as an abort reason, where throwDOMExceptionFromContext throws it.
/// Owned; null only if V8 refused (the constructor is missing, or threw).
pub fn newDOMExceptionFromContext(
    isolate: *v8.Isolate,
    context: *v8.Context,
    name: []const u8,
    message: []const u8,
) ?*v8.Value {
    // The derived interface (WebIDL 2.8.3), not a DOMException named so.
    if (isQuotaExceededError(name)) {
        if (newQuotaExceededError(isolate, context, message)) |exception| return exception;
    }
    const global = v8.v8_Context_Global(context) orelse return null;
    defer v8.v8_Object_Dispose(global);
    const key = v8.v8_String_NewFromUtf8(isolate, "DOMException", 12) orelse return null;
    defer v8.v8_String_Dispose(key);
    const ctor = v8.v8_Object_Get(global, context, @ptrCast(key)) orelse return null;
    defer v8.v8_Value_Dispose(ctor);
    if (!v8.v8_Value_IsFunction(ctor)) return null;

    const v8_message = v8.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse return null;
    defer v8.v8_String_Dispose(v8_message);
    const v8_name = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    defer v8.v8_String_Dispose(v8_name);
    var args = [_]*v8.Value{ @ptrCast(v8_message), @ptrCast(v8_name) };
    const exception = v8.v8_Function_NewInstance(@ptrCast(ctor), context, 2, &args) orelse return null;
    return @ptrCast(exception);
}

/// List of DOMException names as defined by WebIDL spec
/// Used to determine if an error name is a DOMException or a simple exception
pub const dom_exception_names = [_][]const u8{
    "IndexSizeError",
    "HierarchyRequestError",
    "WrongDocumentError",
    "InvalidCharacterError",
    "NoModificationAllowedError",
    "NotFoundError",
    "NotSupportedError",
    "InUseAttributeError",
    "InvalidStateError",
    "SyntaxError",
    "InvalidModificationError",
    "NamespaceError",
    "InvalidAccessError",
    "SecurityError",
    "NetworkError",
    "AbortError",
    "URLMismatchError",
    "QuotaExceededError",
    "TimeoutError",
    "InvalidNodeTypeError",
    "DataCloneError",
    "EncodingError",
    "NotReadableError",
    "UnknownError",
    "ConstraintError",
    "DataError",
    "TransactionInactiveError",
    "ReadOnlyError",
    "VersionError",
    "OperationError",
    "NotAllowedError",
};

/// Check if an error name is a DOMException name
pub fn isDOMExceptionName(name: []const u8) bool {
    for (dom_exception_names) |dom_name| {
        if (std.mem.eql(u8, name, dom_name)) {
            return true;
        }
    }
    return false;
}

/// Throw an appropriate exception based on the error name
pub fn throwWebIDLError(
    isolate: *v8.Isolate,
    error_name: []const u8,
) void {
    const context = v8.v8_Isolate_GetCurrentContext(isolate);
    defer if (context) |c| v8.v8_Context_Dispose(c);
    throwWebIDLErrorFromContext(isolate, context.?, error_name);
}

/// Throw an appropriate exception from a specific context's realm
pub fn throwWebIDLErrorFromContext(
    isolate: *v8.Isolate,
    context: *v8.Context,
    error_name: []const u8,
) void {
    if (isDOMExceptionName(error_name)) {
        // Use the specified context's DOMException constructor
        // This is critical for cross-origin errors: throwing in the caller's
        // context allows the caller's try/catch to catch the exception.
        throwDOMExceptionFromContext(isolate, context, error_name, error_name);
    } else if (std.mem.eql(u8, error_name, "TypeError")) {
        throwTypeErrorFromContext(isolate, context, "TypeError");
    } else if (std.mem.eql(u8, error_name, "NotEnoughArguments")) {
        // WebIDL overload resolution: fewer arguments than any overload
        // requires is a TypeError (step "if S is empty, throw a TypeError").
        throwTypeErrorFromContext(isolate, context, "Not enough arguments");
    } else if (std.mem.eql(u8, error_name, "RangeError")) {
        // TODO: implement throwRangeErrorFromContext
        throwRangeError(isolate, "RangeError");
    } else if (std.mem.eql(u8, error_name, "InvalidEncoding")) {
        throwRangeError(isolate, "The encoding label provided is invalid.");
    } else if (std.mem.eql(u8, error_name, "ReplacementEncoding")) {
        throwRangeError(isolate, "The encoding label provided is a replacement encoding.");
    } else if (std.mem.eql(u8, error_name, "DecodingError")) {
        throwTypeErrorFromContext(isolate, context, "The encoded data was not valid.");
    } else if (std.mem.eql(u8, error_name, "NotImplemented")) {
        throwDOMException(isolate, "NotSupportedError", "This feature is not yet implemented");
    } else {
        throwError(isolate, error_name);
    }
}

// ============================================================================
// Console Value Conversion
// ============================================================================

/// Convert V8 Value to ConsoleValue for console logging
///
/// This function inspects the V8 value type and creates an appropriate
/// ConsoleValue representation. Strings and BigInts allocate memory that
/// must be freed by calling ConsoleValue.deinit().
pub fn toConsoleValue(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!runtime.ConsoleValue {
    // Check type and convert accordingly

    // Undefined
    if (v8.v8_Value_IsUndefined(value)) {
        return runtime.ConsoleValue{ .undefined = {} };
    }

    // Null
    if (v8.v8_Value_IsNull(value)) {
        return runtime.ConsoleValue{ .null = {} };
    }

    // Boolean
    if (v8.v8_Value_IsBoolean(value)) {
        const bool_val = v8.v8_Value_BooleanValue(value, isolate);
        return runtime.ConsoleValue{ .boolean = bool_val };
    }

    // Number
    if (v8.v8_Value_IsNumber(value)) {
        const num_val = v8.v8_Value_NumberValue(value, context);
        return runtime.ConsoleValue{ .number = num_val };
    }

    // String
    if (v8.v8_Value_IsString(value)) {
        const string = v8.v8_Value_ToString(value, context) orelse return ConversionError.TypeError;

        // Get string length
        const length = v8.v8_String_Utf8Length(string);

        // Allocate buffer
        const buffer = try allocator.alloc(u8, @intCast(length));
        errdefer allocator.free(buffer);

        // Write UTF-8 to buffer
        _ = v8.v8_String_WriteUtf8(string, buffer.ptr, @intCast(length));

        return runtime.ConsoleValue{ .string = buffer };
    }

    // Symbol
    if (v8.v8_Value_IsSymbol_Local(@ptrCast(value))) {
        return runtime.ConsoleValue{ .symbol = @ptrCast(value) };
    }

    // BigInt (convert to string representation)
    if (v8.v8_Value_IsBigInt(value)) {
        // For now, return placeholder
        // TODO: Implement BigInt to string conversion
        const bigint_str = try allocator.dupe(u8, "0");
        return runtime.ConsoleValue{ .bigint = bigint_str };
    }

    // Everything else is an Object
    return runtime.ConsoleValue{ .object = @ptrCast(value) };
}

// ============================================================================
// Instance to V8 Object Conversion (Phase 5: Streams Integration)
// ============================================================================

/// Convert runtime.Instance to V8 Object
///
/// This creates or retrieves a V8 wrapper object for a Zig runtime instance.
/// Used when passing controller instances to JavaScript callbacks.
///
/// Currently simplified: creates a plain V8 Object.
/// TODO: Use full V8Interface infrastructure for proper prototype chain.
///
/// Example:
/// ```zig
/// const controller_v8 = try instanceToV8Object(
///     controller_instance,
///     isolate,
///     context,
/// );
/// defer v8.v8_Object_Dispose(controller_v8);
/// ```
pub fn instanceToV8Object(
    instance: *runtime.Instance,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!*v8.Object {
    _ = instance; // TODO: Use instance state to populate V8 object

    // For now, create a plain V8 Object
    // In a full implementation, this would:
    // 1. Check if instance already has a V8 wrapper (stored in internal field)
    // 2. If not, create V8 Object with correct prototype
    // 3. Store instance pointer in V8 Object internal field
    // 4. Store V8 Object reference in instance for future lookups

    const obj = v8.v8_Object_New(isolate) orelse return ConversionError.OutOfMemory;
    _ = context; // Will be needed for property setup

    // TODO: Set up properties and methods using V8Interface infrastructure
    // For now, return plain object (sufficient for callbacks that don't access controller)

    return obj;
}

/// Convert runtime.Instance to V8 Value with correct prototype chain
///
/// This is the preferred function for returning interface instances from
/// property getters and methods. It uses the template registry to wrap
/// the instance with the correct V8 prototype chain.
///
/// Unlike instanceToV8Object (which creates a plain object), this function:
/// 1. Looks up the interface name from the instance's vtable
/// 2. Wraps the instance with the correct FunctionTemplate
/// 3. Returns a cached wrapper if one exists (preserving object identity)
///
/// Example:
/// ```zig
/// // In a property getter returning *runtime.Instance:
/// const v8_value = conv.instanceToV8(isolate, instance);
/// info.setReturnValue(v8_value);
/// ```
pub fn instanceToV8(isolate: *v8.Isolate, instance: *runtime.Instance) *v8.Value {
    return instanceToV8Checked(isolate, instance) catch v8.v8_Undefined(isolate) orelse unreachable;
}

/// `instanceToV8`, except that a wrap that ran out of memory - its wrapper
/// cache could not take the instance - is that error rather than undefined:
/// the instance is not wrapped, owns no wrapper, and stays its caller's
/// (Codex row 15 Q22). Every other failure to wrap (no template for the
/// interface, no context) is still undefined.
pub fn instanceToV8Checked(isolate: *v8.Isolate, instance: *runtime.Instance) error{OutOfMemory}!*v8.Value {
    const template_registry = @import("template_registry.zig");

    // Safety check: if instance pointer looks invalid, return undefined
    // This can happen with use-after-free or invalid pointers from DOM methods
    if (@intFromPtr(instance) < 0x1000) {
        // Pointer is in low memory region (likely null or invalid)
        return v8.v8_Undefined(isolate) orelse unreachable;
    }

    // Get interface name from instance vtable
    const interface_name = template_registry.getInstanceInterfaceName(instance);

    // A Window's one wrapper is its realm's global - the WindowProxy it is
    // bound to (dom.window_globals): `iframe.contentWindow`, an event's
    // view or source, `frames[i]` all answer that object, with the realm's
    // interface objects on it.
    // The length first: the compare runs for every object wrapped - every
    // `list[i]` - and std.mem.eql is a call chain in the Debug build (5% of
    // an Array.prototype.indexOf over a NodeList, with the same test in
    // wrapInstanceAsV8Object). Same answer: only "Window" has both.
    if (interface_name.len == "Window".len and std.mem.eql(u8, interface_name, "Window")) {
        return windowProxyOrNull(isolate, instance);
    }

    // A platform object has one wrapper, made in its relevant realm - the
    // realm it was created in, `instance.ctx` - whichever realm is current
    // (engine-protocol.md, "Realms"; the protocol's own operations do the
    // same through protocol_support.relevantWrapper). Wrapping in the current
    // realm made a second wrapper, in another realm's wrapper cache, for a
    // node a frame's script had already seen: `frame.contentDocument.body`
    // read from the parent was not the frame's own `document.body`.
    //
    // The realm's context is BORROWED from its record: the wrapper cache is
    // looked up, and the object made, in it (V8 enters it for the call). The
    // current context stands in only when the relevant realm has no engine
    // realm of this agent behind it - it ended, or it is another agent's -
    // and that handle, from v8_Isolate_GetCurrentContext, is this call's.
    // (It used to be released on the other branch too, which disposed the
    // realm's own context handle.)
    const relevant = relevantContext(isolate, instance);
    const current: ?*v8.Context = if (relevant == null) v8.v8_Isolate_GetCurrentContext(isolate) else null;
    defer if (current) |c| v8.v8_Context_Dispose(c);
    const context: *v8.Context = relevant orelse current orelse return v8.v8_Undefined(isolate) orelse unreachable;

    // Wrap with correct prototype using template registry
    const v8_obj = template_registry.wrapInstanceAsV8Object(
        instance,
        interface_name,
        isolate,
        context,
    ) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        // Template not registered or other error, return undefined
        return v8.v8_Undefined(isolate) orelse unreachable;
    };

    return @ptrCast(v8_obj);
}

/// A Window as script sees it: the global it is bound to (a `Global<Object>*`,
/// BORROWED from the realm's wrapper cache, which SetReturnValueGlobal reads),
/// or null when it has none to answer with: its teardown ran (a realm's end
/// frees its state, the binding with it).
/// Never an ordinary wrapper: a Window wrapped in another realm's cache was
/// freed by that cache's sweep - its destructor run a second time and its
/// slot returned - while every holder of it read on (lane winslot1, E3;
/// tests/v8/window_dead_conversion_test.zig). Blink's DOMWindow::Wrap
/// answers v8::Null for a window with no frame
/// (core/frame/dom_window.cc).
fn windowProxyOrNull(isolate: *v8.Isolate, window: *runtime.Instance) *v8.Value {
    const bound_global = @import("dom").window_globals.boundGlobal(window) orelse
        return v8.v8_Null(isolate) orelse unreachable;
    return @ptrCast(bound_global);
}

/// `instance`'s relevant realm's context, BORROWED from the realm record -
/// or null when that realm has no engine realm of `isolate` behind it (it
/// ended: context_manager nulls a retired realm's engine_ctx; or it belongs
/// to another agent).
fn relevantContext(isolate: *v8.Isolate, instance: *runtime.Instance) ?*v8.Context {
    const realm = instance.ctx;
    const engine_ctx = realm.engine_ctx orelse return null;
    if (@import("realm_entry.zig").agentOf(realm) != isolate) return null;
    return @ptrCast(@alignCast(engine_ctx));
}

/// Chunk type tag for type-safe chunk conversion
///
/// When passing chunks through Streams, we wrap them in this tagged union
/// to preserve type information. This avoids unsafe type punning.
pub const ChunkType = enum {
    v8_value, // Already a V8 Value
    instance, // runtime.Instance
    string, // []const u8
    number_f64, // f64
    number_i32, // i32
    boolean, // bool
    undefined_type, // Explicitly undefined
};

/// Type-safe chunk wrapper
///
/// Use this when passing chunks through Streams to preserve type information.
pub const Chunk = union(ChunkType) {
    v8_value: *v8.Value,
    instance: *runtime.Instance,
    string: []const u8,
    number_f64: f64,
    number_i32: i32,
    boolean: bool,
    undefined_type: void,
};

/// Convert a type-safe Chunk to V8 Value
///
/// This is the preferred way to convert chunks - type-safe and explicit.
///
/// Example:
/// ```zig
/// const chunk = Chunk{ .string = "hello" };
/// const chunk_v8 = try chunkToV8ValueSafe(chunk, isolate, context);
/// defer v8.v8_Value_Dispose(chunk_v8);
/// ```
pub fn chunkToV8ValueSafe(
    chunk: Chunk,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!*v8.Value {
    return switch (chunk) {
        .v8_value => |v| v,

        .instance => |inst| blk: {
            const obj = try instanceToV8Object(inst, isolate, context);
            break :blk @ptrCast(obj);
        },

        .string => |str| newStringFromWtf8(isolate, str) orelse return ConversionError.OutOfMemory,

        .number_f64 => |num| blk: {
            const v8_num = v8.v8_Number_New(isolate, num);
            break :blk @ptrCast(v8_num);
        },

        .number_i32 => |num| blk: {
            const v8_num = v8.v8_Number_New(isolate, @floatFromInt(num));
            break :blk @ptrCast(v8_num);
        },

        .boolean => |b| blk: {
            // TODO: Implement v8_Boolean_New in v8_wrapper.cpp
            // For now, use number conversion (0/1) cast to boolean
            const num_val: f64 = if (b) 1.0 else 0.0;
            const v8_num = v8.v8_Number_New(isolate, num_val);
            break :blk @ptrCast(v8_num);
        },

        .undefined_type => blk: {
            _ = chunk.undefined_type;
            const undef = v8.v8_Undefined(isolate) orelse
                return ConversionError.OutOfMemory;
            break :blk undef;
        },
    };
}

/// Convert an opaque chunk pointer to a V8 Value (legacy/unsafe)
///
/// **DEPRECATED**: Use chunkToV8ValueSafe() with Chunk union instead.
///
/// This function attempts to guess the chunk type from an opaque pointer,
/// which is inherently unsafe. It's kept for backward compatibility but
/// should be replaced with the type-safe Chunk approach.
///
/// Example:
/// ```zig
/// const chunk_v8 = try chunkToV8Value(
///     chunk_ptr,
///     isolate,
///     context,
/// );
/// defer v8.v8_Value_Dispose(chunk_v8);
/// ```
pub fn chunkToV8Value(
    chunk: *const anyopaque,
    isolate: *v8.Isolate,
    context: *v8.Context,
) ConversionError!*v8.Value {
    _ = chunk;
    _ = context;

    // Without type information, we can't safely convert
    // Return undefined as safe fallback
    //
    // TODO: Migrate call sites to use Chunk union + chunkToV8ValueSafe()

    const undef = v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
    return undef;
}

// ============================================================================
// Generic Conversion Functions
// ============================================================================

/// Generic Zig to V8 value conversion
///
/// Handles conversion of common Zig types to V8 values.
/// Used by Promise.resolve() and other generic APIs.
///
/// Supported types:
/// - void: converts to undefined
/// - bool: converts to V8 Boolean
/// - integers: convert to V8 Number
/// - floats: convert to V8 Number
/// - []const u8 / DOMString: convert to V8 String
/// - *anyopaque: returns as-is (assumes already a V8 Value)
/// - structs with value/done fields: creates iterator result object
pub fn toV8(
    comptime T: type,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: T,
) ConversionError!*v8.Value {
    const info = @typeInfo(T);

    switch (info) {
        .void => {
            return v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
        },
        .bool => {
            return toV8Boolean(isolate, value);
        },
        .int, .comptime_int => {
            const float_val: f64 = @floatFromInt(value);
            return @ptrCast(v8.v8_Number_New(isolate, float_val) orelse return ConversionError.OutOfMemory);
        },
        .float, .comptime_float => {
            return @ptrCast(v8.v8_Number_New(isolate, @floatCast(value)) orelse return ConversionError.OutOfMemory);
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice and ptr_info.child == u8) {
                // []const u8 - convert to string, its lone surrogates kept
                return newStringFromWtf8(isolate, value) orelse ConversionError.OutOfMemory;
            } else if (ptr_info.child == anyopaque) {
                // *anyopaque - assume it's already a V8 value pointer
                return @ptrCast(value);
            } else {
                // Unsupported pointer type
                return ConversionError.TypeError;
            }
        },
        .@"struct" => {
            // Check if it's an IteratorResult-like struct
            if (@hasField(T, "value") and @hasField(T, "done")) {
                // Create { value: X, done: Y } object
                // CROSS-REALM SUPPORT: Create object in specified context
                const obj = v8.v8_Object_NewInContext(context) orelse return ConversionError.OutOfMemory;

                // Set "done" property
                const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse
                    return ConversionError.OutOfMemory;
                const done_value: *v8.Value = @ptrCast(toV8Boolean(isolate, value.done));
                _ = v8.v8_Object_Set(obj, context, @ptrCast(done_key), done_value);

                // Set "value" property
                const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse
                    return ConversionError.OutOfMemory;

                // Value may be runtime.JSValue (tagged union) or *anyopaque
                // Handle both cases for compatibility
                const value_v8: *v8.Value = if (value.value) |v| blk: {
                    // Check if v is a runtime.JSValue by checking if it has asEngineHandle
                    const V = @TypeOf(v);
                    if (@typeInfo(V) == .@"union") {
                        // This is a runtime.JSValue - convert using toV8Value which handles
                        // Global/Local handle scopes correctly
                        break :blk toV8Value(V, isolate, context, v) catch {
                            break :blk v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
                        };
                    } else if (@typeInfo(V) == .pointer) {
                        // Legacy *anyopaque case - assume it's already a Global handle
                        break :blk @ptrCast(v);
                    } else {
                        break :blk v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
                    }
                } else v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;

                _ = v8.v8_Object_Set(obj, context, @ptrCast(value_key), value_v8);

                return @ptrCast(obj);
            }
            return ConversionError.TypeError;
        },
        .optional => |opt_info| {
            if (value) |v| {
                return toV8(opt_info.child, isolate, context, v);
            } else {
                return v8.v8_Null(isolate) orelse return ConversionError.OutOfMemory;
            }
        },
        else => {
            return ConversionError.TypeError;
        },
    }
}

// ============================================================================
// V8 Value Type Detection (for external JSValue conversion)
// ============================================================================

/// V8 value type tag (used by callers to build their own JSValue)
///
/// This allows modules with JSValue access to convert V8 values without
/// this module needing to import streams_common (avoiding circular deps).
pub const V8ValueType = enum {
    undefined,
    null_type,
    boolean,
    number,
    string,
    object,
    typed_array,
    other,
};

/// Detect the type of a V8 Value
///
/// Returns a type tag that callers can use to build JSValue or other types.
pub fn detectV8ValueType(value: *v8.Value) V8ValueType {
    if (v8.v8_Value_IsUndefined(value)) return .undefined;
    if (v8.v8_Value_IsNull(value)) return .null_type;
    if (v8.v8_Value_IsBoolean(value)) return .boolean;
    if (v8.v8_Value_IsNumber(value)) return .number;
    if (v8.v8_Value_IsString(value)) return .string;
    if (v8.v8_Value_IsTypedArray(value)) return .typed_array;
    if (v8.v8_Value_IsObject(value)) return .object;
    return .other;
}

/// Extract boolean value from V8 Value
pub fn extractV8Boolean(isolate: *v8.Isolate, value: *v8.Value) bool {
    return v8.v8_Value_BooleanValue(value, isolate);
}

/// Extract number value from V8 Value
pub fn extractV8Number(context: *v8.Context, value: *v8.Value) f64 {
    return v8.v8_Value_NumberValue(value, context);
}

/// Extract string from V8 Value (allocates)
pub fn extractV8StringAlloc(
    allocator: std.mem.Allocator,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError![]u8 {
    const str = v8.v8_Value_ToString(value, context) orelse return ConversionError.StringError;
    defer v8.v8_String_Dispose(str);

    const length = v8.v8_String_Utf8Length(str);
    if (length < 0) return ConversionError.StringError;

    if (length == 0) {
        return &[_]u8{};
    }

    const buffer = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(buffer);

    const written = v8.v8_String_WriteUtf8(str, buffer.ptr, @intCast(length));
    if (written != length) {
        return ConversionError.StringError;
    }

    return buffer;
}

/// Create V8 undefined value
pub fn createV8Undefined(isolate: *v8.Isolate) ConversionError!*v8.Value {
    return v8.v8_Undefined(isolate) orelse return ConversionError.OutOfMemory;
}

/// Create V8 null value
pub fn createV8Null(isolate: *v8.Isolate) ConversionError!*v8.Value {
    return v8.v8_Null(isolate) orelse return ConversionError.OutOfMemory;
}

/// Create V8 boolean value
pub fn createV8Boolean(isolate: *v8.Isolate, value: bool) ConversionError!*v8.Value {
    return v8.v8_Boolean_New(isolate, value) orelse return ConversionError.OutOfMemory;
}

/// Create V8 number value
pub fn createV8Number(isolate: *v8.Isolate, value: f64) ConversionError!*v8.Value {
    return @ptrCast(v8.v8_Number_New(isolate, value));
}

/// Create V8 string value from slice
pub fn createV8String(isolate: *v8.Isolate, value: []const u8) ConversionError!*v8.Value {
    return newStringFromWtf8(isolate, value) orelse ConversionError.OutOfMemory;
}

// ============================================================================
// Symbol.iterator Helpers (for WebIDL sequence conversion)
// ============================================================================

/// Entry from iterating a sequence<sequence<USVString>> (e.g., for URLSearchParams)
pub const SequencePair = struct {
    name: []const u8,
    value: []const u8,
};

/// Iterate a V8 object using Symbol.iterator and return name-value pairs.
/// This implements the WebIDL sequence<sequence<USVString>> conversion.
///
/// Per the URL Standard, URLSearchParams constructor accepts:
/// 1. A string (query string)
/// 2. A sequence<sequence<USVString>> where each inner sequence has exactly 2 items
/// 3. A record<USVString, USVString>
///
/// This function handles case 2 by:
/// - Getting Symbol.iterator from the object
/// - Calling the iterator to get an iterator object
/// - Iterating with next() until done
/// - Each yielded value must be iterable and produce exactly 2 string items
///
/// Returns null if the object is not iterable.
/// Returns error.TypeError if inner sequences don't have exactly 2 elements.
pub fn iterateAsSequencePairs(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!?[]SequencePair {
    // Must be an object to be iterable
    if (!v8.v8_Value_IsObject(value)) {
        return null;
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get Symbol.iterator
    const symbol_iterator = v8.v8_Symbol_GetIterator(isolate) orelse return null;

    // Get the @@iterator method from the object
    const iterator_method = v8.v8_Object_GetPropertyWithSymbol(context, obj, symbol_iterator) orelse return null;

    // Must be a function
    if (!v8.v8_Value_IsFunction(iterator_method)) {
        return null;
    }
    const iterator_fn: *v8.Function = @ptrCast(iterator_method);

    // Call the iterator function with the object as 'this'
    var dummy_args: [0]*v8.Value = undefined;
    const iterator_obj = v8.v8_Function_Call(iterator_fn, context, @ptrCast(obj), 0, &dummy_args) orelse return null;

    if (!v8.v8_Value_IsObject(iterator_obj)) {
        return null;
    }

    // Get the "next" method from the iterator
    const next_key = v8.v8_String_NewFromUtf8(isolate, "next", 4) orelse return ConversionError.OutOfMemory;
    const next_method = v8.v8_Object_Get(@ptrCast(iterator_obj), context, @ptrCast(next_key)) orelse return null;

    if (!v8.v8_Value_IsFunction(next_method)) {
        return null;
    }
    const next_fn: *v8.Function = @ptrCast(next_method);

    // Collect pairs by iterating
    var pairs: std.ArrayList(SequencePair) = .empty;
    errdefer {
        for (pairs.items) |pair| {
            if (pair.name.len > 0) allocator.free(pair.name);
            if (pair.value.len > 0) allocator.free(pair.value);
        }
        pairs.deinit(allocator);
    }

    const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse return ConversionError.OutOfMemory;
    const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse return ConversionError.OutOfMemory;

    // Iterate
    while (true) {
        // Call next()
        var next_args: [0]*v8.Value = undefined;
        const result = v8.v8_Function_Call(next_fn, context, iterator_obj, 0, &next_args) orelse break;

        if (!v8.v8_Value_IsObject(result)) break;

        // Check if done
        const done_val = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(done_key)) orelse break;
        if (v8.v8_Value_BooleanValue(done_val, isolate)) break;

        // Get the yielded value
        const yielded = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(value_key)) orelse continue;

        // The yielded value must be iterable (inner sequence) with exactly 2 elements
        // Iterate it to get name and value
        const pair_result = try iteratePairElements(allocator, isolate, context, yielded);
        if (pair_result == null) {
            // Not a valid pair - throw TypeError
            return ConversionError.TypeError;
        }
        try pairs.append(allocator, pair_result.?);
    }

    return try pairs.toOwnedSlice(allocator);
}

/// Iterate an inner sequence to extract exactly 2 string elements.
/// Returns null if the value is not iterable or doesn't have exactly 2 elements.
fn iteratePairElements(
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!?SequencePair {
    // Handle array case (most common)
    if (v8.v8_Value_IsArray(value)) {
        const arr: *v8.Array = @ptrCast(value);
        const len = v8.v8_Array_Length(arr);

        // Must have exactly 2 elements
        if (len != 2) {
            return null;
        }

        // Get elements
        const elem0 = v8.v8_Array_Get(context, arr, 0) orelse return null;
        const elem1 = v8.v8_Array_Get(context, arr, 1) orelse return null;

        // Convert to strings using ToString
        const name = try extractV8StringAlloc(allocator, context, elem0);
        errdefer allocator.free(name);
        const val = try extractV8StringAlloc(allocator, context, elem1);

        return SequencePair{
            .name = name,
            .value = val,
        };
    }

    // Handle general iterable case using Symbol.iterator
    if (!v8.v8_Value_IsObject(value)) {
        return null;
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get Symbol.iterator
    const symbol_iterator = v8.v8_Symbol_GetIterator(isolate) orelse return null;
    const iterator_method = v8.v8_Object_GetPropertyWithSymbol(context, obj, symbol_iterator) orelse return null;

    if (!v8.v8_Value_IsFunction(iterator_method)) {
        return null;
    }
    const iterator_fn: *v8.Function = @ptrCast(iterator_method);

    // Call the iterator
    var dummy_args: [0]*v8.Value = undefined;
    const iterator_obj = v8.v8_Function_Call(iterator_fn, context, @ptrCast(obj), 0, &dummy_args) orelse return null;

    if (!v8.v8_Value_IsObject(iterator_obj)) {
        return null;
    }

    // Get next method
    const next_key = v8.v8_String_NewFromUtf8(isolate, "next", 4) orelse return ConversionError.OutOfMemory;
    const next_method = v8.v8_Object_Get(@ptrCast(iterator_obj), context, @ptrCast(next_key)) orelse return null;

    if (!v8.v8_Value_IsFunction(next_method)) {
        return null;
    }
    const next_fn: *v8.Function = @ptrCast(next_method);

    const done_key = v8.v8_String_NewFromUtf8(isolate, "done", 4) orelse return ConversionError.OutOfMemory;
    const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse return ConversionError.OutOfMemory;

    // Collect exactly 2 elements
    var elements: [2][]u8 = .{ &[_]u8{}, &[_]u8{} };
    var count: usize = 0;

    while (count < 3) { // Iterate up to 3 times to detect if there are more than 2 elements
        var next_args: [0]*v8.Value = undefined;
        const result = v8.v8_Function_Call(next_fn, context, iterator_obj, 0, &next_args) orelse break;

        if (!v8.v8_Value_IsObject(result)) break;

        const done_val = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(done_key)) orelse break;
        if (v8.v8_Value_BooleanValue(done_val, isolate)) break;

        const elem = v8.v8_Object_Get(@ptrCast(result), context, @ptrCast(value_key)) orelse continue;

        if (count < 2) {
            elements[count] = try extractV8StringAlloc(allocator, context, elem);
        }
        count += 1;
    }

    // Must have exactly 2 elements
    if (count != 2) {
        // Free any allocated strings
        if (elements[0].len > 0) allocator.free(elements[0]);
        if (elements[1].len > 0) allocator.free(elements[1]);
        return null;
    }

    return SequencePair{
        .name = elements[0],
        .value = elements[1],
    };
}

/// Check if a V8 value is iterable (has Symbol.iterator method).
pub fn isIterable(isolate: *v8.Isolate, context: *v8.Context, value: *v8.Value) bool {
    if (!v8.v8_Value_IsObject(value)) {
        // Strings are iterable but we handle them separately
        return v8.v8_Value_IsString(value);
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get Symbol.iterator
    const symbol_iterator = v8.v8_Symbol_GetIterator(isolate) orelse return false;
    const iterator_method = v8.v8_Object_GetPropertyWithSymbol(context, obj, symbol_iterator) orelse return false;

    return v8.v8_Value_IsFunction(iterator_method);
}

/// Iterate a V8 object as record<USVString, USVString> for URLSearchParams.
/// Returns the object's own enumerable string-keyed properties as pairs.
pub fn iterateAsRecordPairs(
    allocator: std.mem.Allocator,
    context: *v8.Context,
    value: *v8.Value,
) ConversionError!?[]SequencePair {
    if (!v8.v8_Value_IsObject(value)) {
        return null;
    }
    const obj: *v8.Object = @ptrCast(value);

    // Get own property names
    const names = v8.v8_Object_GetOwnPropertyNames(context, obj) orelse return null;

    const length = v8.v8_Array_Length(names);
    if (length == 0) {
        return &[_]SequencePair{};
    }

    var pairs: std.ArrayList(SequencePair) = .empty;
    errdefer {
        for (pairs.items) |pair| {
            if (pair.name.len > 0) allocator.free(pair.name);
            if (pair.value.len > 0) allocator.free(pair.value);
        }
        pairs.deinit(allocator);
    }

    for (0..length) |i| {
        const key_val = v8.v8_Array_Get(context, names, @intCast(i)) orelse continue;
        const prop_val = v8.v8_Object_Get(obj, context, key_val) orelse continue;

        const key_str = try extractV8StringAlloc(allocator, context, key_val);
        errdefer allocator.free(key_str);
        const val_str = try extractV8StringAlloc(allocator, context, prop_val);

        try pairs.append(allocator, SequencePair{
            .name = key_str,
            .value = val_str,
        });
    }

    return try pairs.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "conversion module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}
