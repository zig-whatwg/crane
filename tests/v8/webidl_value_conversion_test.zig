//! WebIDL value conversions at the binding seam: exact enumeration values,
//! [Default] toJSON nulls, typed array union arms, and what record, sequence
//! and dictionary conversions make and require.
//!
//! One file, four sections, each with its own account of the defect; one
//! test binary, since every tests/v8 file is a full engine compile.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const conv = v8.conversions;
const iface = v8.interface_mod;
const ImageDataArray = conv.generated_typedefs.ImageDataArray;
const Float32List = conv.generated_typedefs.Float32List;

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

fn env() !Env {
    if (env_once) |e| return e;
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

/// Script's value of `code`, OWNED.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

// ===========================================================================
// An enumeration value crosses the binding exactly as the IDL spells it.
//
// WebIDL 3.2.23: a string converts to the enumeration value it equals, or
// is a TypeError; 3.2.24: a value converts to the String of its code units.
// The binding derived both from the Zig variant's name - `_back_forward_`
// - by turning every `_` into `-` on the way out and accepting `-`, `_` or
// `/` for each `_` on the way in, so PerformanceNavigationTiming.type read
// "back-forward" and "back-forward" was accepted where only "back_forward"
// is a value. Codegen's `idl_values` table is the answer in both
// directions; the enum below is shaped as codegen writes one.
// ===========================================================================
/// As generator.writeEnum emits NavigationTimingType - plus a value with a
/// hyphen and an empty one.
const Nav = enum {
    _navigate_,
    _back_forward_,
    _same_origin_,
    __,

    pub const idl_values = [_][]const u8{ "navigate", "back_forward", "same-origin", "" };
};

fn str(text: []const u8) !*ffi.Value {
    const e = try env();
    const s = ffi.v8_String_NewFromUtf8(e.isolate, text.ptr, @intCast(text.len)) orelse return error.StringFailed;
    return @ptrCast(s);
}

fn expectString(value: *ffi.Value, expected: []const u8) !void {
    const e = try env();
    var converted = try conv.fromV8Value(runtime.DOMString, testing.allocator, e.isolate, e.context, value);
    defer converted.deinit(testing.allocator);
    try testing.expectEqualStrings(expected, converted.asSlice());
}

test "a string converts to the value it spells, and only that one" {
    const e = try env();
    const exact = try str("back_forward");
    defer ffi.v8_Value_Dispose(exact);
    try testing.expectEqual(Nav._back_forward_, try conv.fromV8Value(Nav, testing.allocator, e.isolate, e.context, exact));

    const hyphenated = try str("same-origin");
    defer ffi.v8_Value_Dispose(hyphenated);
    try testing.expectEqual(Nav._same_origin_, try conv.fromV8Value(Nav, testing.allocator, e.isolate, e.context, hyphenated));

    const empty = try str("");
    defer ffi.v8_Value_Dispose(empty);
    try testing.expectEqual(Nav.__, try conv.fromV8Value(Nav, testing.allocator, e.isolate, e.context, empty));

    // Spellings the variant name would have matched are not values.
    for ([_][]const u8{ "back-forward", "same_origin", "back/forward", "_navigate_" }) |wrong| {
        const value = try str(wrong);
        defer ffi.v8_Value_Dispose(value);
        try testing.expectError(error.TypeError, conv.fromV8Value(Nav, testing.allocator, e.isolate, e.context, value));
    }
}

test "a value converts to the string the IDL spells, through both output paths" {
    const e = try env();
    const back = try conv.toV8Value(Nav, e.isolate, e.context, ._back_forward_);
    defer ffi.v8_Value_Dispose(back);
    try expectString(back, "back_forward");

    const same = conv.enumToV8String(Nav, e.isolate, ._same_origin_);
    defer ffi.v8_Value_Dispose(same);
    try expectString(same, "same-origin");

    const back2 = conv.enumToV8String(Nav, e.isolate, ._back_forward_);
    defer ffi.v8_Value_Dispose(back2);
    try expectString(back2, "back_forward");

    const empty = try conv.toV8Value(Nav, e.isolate, e.context, .__);
    defer ffi.v8_Value_Dispose(empty);
    try expectString(empty, "");
}

// ===========================================================================
// A [Default] toJSON result keeps its null members; a dictionary does not.
//
// WebIDL 3.7.4.1's default toJSON steps put every JSON-typed attribute's
// value in the map - null included - and create a data property for each
// entry. A dictionary converted to JavaScript (3.2.18) defines only the
// members that are present. Both are Zig structs with optional fields, so
// codegen marks the toJSON one `default_to_json` and the conversion reads
// it: PerformanceNavigationTiming.toJSON() must have
// `notRestoredReasons: null`.
// ===========================================================================
/// As writer.writeToJSONStruct emits one.
const TimingToJSON = struct {
    start: f64,
    notRestoredReasons: ?*runtime.Instance,
    label: ?runtime.DOMString,

    pub const default_to_json = true;
};

/// A dictionary with the same members.
const TimingDict = struct {
    start: ?f64 = null,
    notRestoredReasons: ?*runtime.Instance = null,
    label: ?runtime.DOMString = null,
};

/// JSON.stringify(value), as a Zig string the caller frees.
fn stringify(value: *ffi.Value) ![]const u8 {
    const e = try env();
    const global = ffi.v8_Context_Global(e.context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(e.isolate, "probe", 5) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, e.context, @ptrCast(key), value)) return error.SetFailed;
    const code = "JSON.stringify(probe)";
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, code.len) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const result = ffi.v8_Script_Run(e.context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(result);
    var s = try conv.fromV8Value(runtime.DOMString, testing.allocator, e.isolate, e.context, result);
    defer s.deinit(testing.allocator);
    return testing.allocator.dupe(u8, s.asSlice());
}

test "a default toJSON result defines a null attribute as null" {
    const e = try env();
    const object = try conv.toV8Value(TimingToJSON, e.isolate, e.context, .{ .start = 1.5, .notRestoredReasons = null, .label = null });
    defer ffi.v8_Value_Dispose(object);
    const json = try stringify(object);
    defer testing.allocator.free(json);
    try testing.expectEqualStrings("{\"start\":1.5,\"notRestoredReasons\":null,\"label\":null}", json);
}

test "a dictionary leaves an absent member out" {
    const e = try env();
    const object = try conv.toV8Value(TimingDict, e.isolate, e.context, .{ .start = 1.5 });
    defer ffi.v8_Value_Dispose(object);
    const json = try stringify(object);
    defer testing.allocator.free(json);
    try testing.expectEqualStrings("{\"start\":1.5}", json);
}

// ===========================================================================
// A typed array converts to the union arm named for its type.
//
// WebIDL 3.2.25 step 9: a value with a [[TypedArrayName]] converts to the
// union's typed array type of that name - "a reference to the same object"
// (3.2.26). Codegen types such an arm as runtime.JSValue named for the
// type (ImageDataArray = `(Uint8ClampedArray or Float16Array)` is
// `uint8clamped_array` / `float16array`), and no step of the union
// conversion matched it: `new ImageData(new Uint8ClampedArray(16), 2)`
// failed its data argument. The arm holds the argument's own handle, as an
// `object` arm does, and the binding releases it after the call - the
// predicates must say so, or every call leaks the handle.
// ===========================================================================
test "a typed array arm is named for its type" {
    try testing.expectEqualStrings("Uint8ClampedArray", conv.typedArrayArmName("uint8clamped_array").?);
    try testing.expectEqualStrings("Float16Array", conv.typedArrayArmName("float16array").?);
    try testing.expectEqualStrings("Float32Array", conv.typedArrayArmName("float32array").?);
    try testing.expect(conv.typedArrayArmName("object") == null);
    try testing.expect(conv.typedArrayArmName("glfloat_sequence") == null);
}

test "a Uint8ClampedArray converts to ImageDataArray's uint8clamped_array arm, as a reference" {
    const e = try env();
    const value = try eval("new Uint8ClampedArray(16)");
    defer ffi.v8_Value_Dispose(value);
    const converted = try conv.fromV8Value(ImageDataArray, testing.allocator, e.isolate, e.context, value);
    try testing.expect(converted == .uint8clamped_array);
    try testing.expect(converted.uint8clamped_array == .handle);
    try testing.expectEqual(@intFromPtr(value), @intFromPtr(converted.uint8clamped_array.handle.ptr));
}

test "a typed array of another type matches no arm" {
    const e = try env();
    const value = try eval("new Int8Array(16)");
    defer ffi.v8_Value_Dispose(value);
    try testing.expectError(error.TypeError, conv.fromV8Value(ImageDataArray, testing.allocator, e.isolate, e.context, value));
}

test "a Float32Array converts to Float32List's float32array arm" {
    const e = try env();
    const value = try eval("new Float32Array(4)");
    defer ffi.v8_Value_Dispose(value);
    const converted = try conv.fromV8Value(Float32List, testing.allocator, e.isolate, e.context, value);
    try testing.expect(converted == .float32array);
}

test "the binding releases a typed array arm's handle after the call" {
    // Pinned so a typed array argument neither leaks its handle (the
    // conservative answer) nor is released twice.
    try testing.expect(iface.anyHandleIsKeptOnlyAsHandle(ImageDataArray));
    try testing.expect(!iface.argHandleIsCopied(ImageDataArray));
    const e = try env();
    const value = try eval("new Uint8ClampedArray(4)");
    defer ffi.v8_Value_Dispose(value);
    const converted = try conv.fromV8Value(ImageDataArray, testing.allocator, e.isolate, e.context, value);
    try testing.expectEqual(@intFromPtr(value), @intFromPtr(iface.anyArgumentHandle(ImageDataArray, converted).?));
    // Float32List's other arm, a sequence of floats, copies: the converted
    // value says whether the handle is still referred to.
    try testing.expect(iface.anyHandleIsKeptOnlyAsHandle(Float32List));
    const list = try eval("[1, 2]");
    defer ffi.v8_Value_Dispose(list);
    const from_list = try conv.fromV8Value(Float32List, testing.allocator, e.isolate, e.context, list);
    defer iface.freeConvertedArg(Float32List, testing.allocator, from_list);
    try testing.expect(from_list == .glfloat_sequence);
    try testing.expect(iface.anyArgumentHandle(Float32List, from_list) == null);
}

// ===========================================================================
// Records, sequences and dictionaries: what their conversions make is
// released, and a required dictionary member is required.
//
// - toV8Value of a record (a slice of {key, value}) made a Global for each
// key and each value and released none of them - the dictionary branch's
// leak, fixed there in binding batch 1 and left here. A sequence's
// elements were the same.
// - fromV8Sequence freed its slice when an element failed, but not the
// elements before it - their strings.
// - WebIDL 3.2.18 step 4.1.4.4: "if jsMemberValue is undefined and member
// is required, then throw a TypeError". The member converted undefined
// instead (0 for a number, "undefined" for a string).
//
// std.testing.allocator catches the Zig side; V8's live global-handle
// count (docs/lessons/testing-a-handle-leak-test-needs-v8-s-live-count.md)
// the handles.
// ===========================================================================
/// What one Global costs in V8's count.
fn oneHandleBytes(isolate: *ffi.Isolate) i64 {
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const one = ffi.v8_Number_New(isolate, 1);
    const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    ffi.v8_Value_Dispose(@ptrCast(one));
    return @intCast(with_one - start);
}

/// Global-handle bytes left by 64 conversions of `value` to JavaScript, each
/// result released as the binding releases an owned one.
fn handleBytesLeftByToV8(comptime T: type, value: T) !i64 {
    const e = try env();
    // Twice first, so that what the first conversion makes once is not counted.
    for (0..2) |_| ffi.v8_Value_Dispose(try conv.toV8Value(T, e.isolate, e.context, value));
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate));
    for (0..64) |_| ffi.v8_Value_Dispose(try conv.toV8Value(T, e.isolate, e.context, value));
    return @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate))) - before;
}

const Entry = struct {
    key: runtime.DOMString,
    value: runtime.DOMString,
};

test "a record converted to JavaScript releases its keys and values" {
    const e = try env();
    const entries = [_]Entry{
        .{ .key = runtime.DOMString.initInterned("alpha"), .value = runtime.DOMString.initInterned("one") },
        .{ .key = runtime.DOMString.initInterned("beta"), .value = runtime.DOMString.initInterned("two") },
    };
    const left = try handleBytesLeftByToV8([]const Entry, &entries);
    // Four handles a conversion leaked before: 256 over 64 runs.
    try testing.expect(left < oneHandleBytes(e.isolate) * 8);
}

test "a record's properties are defined, not assigned" {
    const e = try env();
    // A setter on Object.prototype must not run: CreateDataProperty.
    ffi.v8_Value_Dispose(try eval("var setterRan = 0; Object.defineProperty(Object.prototype, 'gamma', { set(v) { setterRan++; }, configurable: true }); 0"));
    defer if (eval("delete Object.prototype.gamma; 0")) |v| ffi.v8_Value_Dispose(v) else |_| {};
    const entries = [_]Entry{.{ .key = runtime.DOMString.initInterned("gamma"), .value = runtime.DOMString.initInterned("three") }};
    const object = try conv.toV8Value([]const Entry, e.isolate, e.context, &entries);
    defer ffi.v8_Value_Dispose(object);
    const ran = try eval("setterRan");
    defer ffi.v8_Value_Dispose(ran);
    try testing.expectEqual(@as(i32, 0), ffi.v8_Value_Int32Value(ran, e.context));
}

test "a sequence converted to JavaScript releases its elements" {
    const e = try env();
    const strings = [_]runtime.DOMString{ runtime.DOMString.initInterned("a"), runtime.DOMString.initInterned("b"), runtime.DOMString.initInterned("c") };
    const left = try handleBytesLeftByToV8([]const runtime.DOMString, &strings);
    try testing.expect(left < oneHandleBytes(e.isolate) * 8);
}

test "a sequence whose later element fails frees the elements before it" {
    const e = try env();
    const array = try eval("['a'.repeat(64), 'b'.repeat(64), Symbol()]");
    defer ffi.v8_Value_Dispose(array);
    try testing.expectError(error.TypeError, conv.fromV8Value([]const runtime.DOMString, testing.allocator, e.isolate, e.context, array));
}

/// A dictionary with a required member, as codegen emits one: no `?`, no
/// default.
const WithRequired = struct {
    label: ?runtime.DOMString = null,
    length: u32,
};

test "a required dictionary member that is undefined is a TypeError" {
    const e = try env();
    // `label` converts first (lexicographic order), then `length` is missing.
    const missing = try eval("({ label: 'x'.repeat(64) })");
    defer ffi.v8_Value_Dispose(missing);
    try testing.expectError(error.TypeError, conv.fromV8Value(WithRequired, testing.allocator, e.isolate, e.context, missing));

    const explicit = try eval("({ length: undefined })");
    defer ffi.v8_Value_Dispose(explicit);
    try testing.expectError(error.TypeError, conv.fromV8Value(WithRequired, testing.allocator, e.isolate, e.context, explicit));

    // An undefined dictionary has every member undefined.
    const undef = try eval("undefined");
    defer ffi.v8_Value_Dispose(undef);
    try testing.expectError(error.TypeError, conv.fromV8Value(WithRequired, testing.allocator, e.isolate, e.context, undef));
}

test "a required dictionary member that is present converts" {
    const e = try env();
    const present = try eval("({ length: 7, label: 'y'.repeat(64) })");
    defer ffi.v8_Value_Dispose(present);
    const converted = try conv.fromV8Value(WithRequired, testing.allocator, e.isolate, e.context, present);
    defer iface.freeConvertedArg(WithRequired, testing.allocator, converted);
    try testing.expectEqual(@as(u32, 7), converted.length);
    // null is not undefined: a required member that is null converts (0).
    const null_length = try eval("({ length: null })");
    defer ffi.v8_Value_Dispose(null_length);
    const from_null = try conv.fromV8Value(WithRequired, testing.allocator, e.isolate, e.context, null_length);
    try testing.expectEqual(@as(u32, 0), from_null.length);
}
