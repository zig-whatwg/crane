//! A dictionary converted to an ECMAScript object has the shape WebIDL 3.2.18
//! gives it ("converting an IDL dictionary value to an ECMAScript value"):
//!
//! - Step 2: "Let dictionaries be a list consisting of D and all of D's
//!   inherited dictionaries, in order from least to most derived." Step 3:
//!   each dictionary's members "in lexicographical order". The inherited
//!   members are the object's own properties, written first - never a
//!   nested `base` object (codegen keeps an inherited dictionary in a `base`
//!   field; that is storage, not shape).
//! - Step 3.1.2: a member is written when it "exists". A member with a
//!   default value exists whether or not script or the specification gave it
//!   one (WebIDL 2.7, "the value used by default when author code or
//!   specification text does not provide a value for that member") - so a
//!   nullable member whose default is null is written as `null`
//!   (Sanitizer.get()'s `namespace: null`), and a member left unset takes
//!   its default (Blink and Gecko initialise every defaulted member in their
//!   generated dictionaries, so their ToV8 always writes it).
//!
//! Codex row 41 Q5/Q9 (crane/san-get-inherited.html, san-get-null-namespace.html):
//! Sanitizer.get() returned `{base: {name, namespace}, removeAttributes}` and
//! dropped every `namespace: null`. Tested in script, through the generated
//! dictionaries, with values made the way an impl makes them
//! (docs/lessons/codegen-dictionary-input-tests-do-not-verify-return-shapes.md).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const conversions = v8.conversions;

fn Payload(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => |e| Payload(e.payload),
        .optional => |o| Payload(o.child),
        .pointer => |p| if (p.size == .slice) Payload(p.child) else T,
        else => T,
    };
}

fn Arm(comptime U: type, comptime name: []const u8) type {
    return @FieldType(U, name);
}

/// The generated dictionaries, named through the operations that return or
/// take them (tests/v8 has no `dictionaries` import of its own).
const dictionaries = struct {
    /// Sanitizer.get()'s result.
    const SanitizerConfig = Payload(@typeInfo(@TypeOf(interfaces.Sanitizer.call_get)).@"fn".return_type.?);
    const SanitizerElementWithAttributes = Payload(@FieldType(SanitizerConfig, "elements"));
    /// `dictionary SanitizerElementNamespaceWithAttributes : SanitizerElementNamespace`.
    const SanitizerElementNamespaceWithAttributes = Arm(SanitizerElementWithAttributes, "sanitizer_element_namespace_with_attributes");
    /// `DOMString? _namespace = "http://www.w3.org/1999/xhtml"` - a webidl.Opt.
    const SanitizerElementNamespace = @FieldType(SanitizerElementNamespaceWithAttributes, "base");
    const SanitizerAttribute = Payload(@FieldType(SanitizerConfig, "attributes"));
    /// `DOMString? _namespace = null`.
    const SanitizerAttributeNamespace = Arm(SanitizerAttribute, "sanitizer_attribute_namespace");
    /// new Event(type, eventInitDict)'s: `boolean bubbles = false` and two more.
    const EventInit = @FieldType(@typeInfo(@TypeOf(interfaces.Event.call_constructor)).@"fn".params[2].type.?, "value");
};

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

fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

/// `JSON.stringify` of `value` converted as a `T`, plus whether it has an own
/// `base` property; the string is OWNED by `allocator`.
fn shapeOf(comptime T: type, allocator: std.mem.Allocator, value: T) ![]const u8 {
    const e = try env();
    const object = try conversions.toV8Value(T, e.isolate, e.context, value);
    defer ffi.v8_Value_Dispose(object);
    const global = ffi.v8_Context_Global(e.context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(e.isolate, "converted", 9) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, e.context, @ptrCast(key), object)) return error.SetFailed;
    const json = try eval("(Object.hasOwn(converted, 'base') ? 'BASE ' : '') + JSON.stringify(converted)");
    defer ffi.v8_Value_Dispose(json);
    return conversions.fromV8Value([]const u8, allocator, e.isolate, e.context, json);
}

fn expectShape(comptime T: type, value: T, expected: []const u8) !void {
    const shape = try shapeOf(T, testing.allocator, value);
    defer testing.allocator.free(shape);
    try testing.expectEqualStrings(expected, shape);
}

const html_namespace = "http://www.w3.org/1999/xhtml";

test "an inherited dictionary's members are the object's own, least-derived first" {
    // Sanitizer.get()'s canonical element: name and namespace inherited from
    // SanitizerElementNamespace, removeAttributes its own.
    try expectShape(dictionaries.SanitizerElementNamespaceWithAttributes, .{
        .base = .{ .name = runtime.DOMString.initInterned("div"), .namespace = .passed(runtime.DOMString.initInterned(html_namespace)) },
        .removeAttributes = &.{},
    }, "{\"name\":\"div\",\"namespace\":\"" ++ html_namespace ++ "\",\"removeAttributes\":[]}");
}

test "each dictionary's members are written in code-unit order, not declaration order" {
    // SanitizerConfig declares elements, removeElements, ..., comments,
    // dataAttributes, javascriptURLs; 3.2.18 writes them sorted.
    try expectShape(dictionaries.SanitizerConfig, .{
        .removeElements = &.{},
        .comments = true,
        .dataAttributes = false,
        .attributes = &.{},
    }, "{\"attributes\":[],\"comments\":true,\"dataAttributes\":false,\"removeElements\":[]}");
}

test "a nullable member whose default is null is written as null" {
    // `DOMString? _namespace = null`: Sanitizer.get()'s unnamespaced attribute.
    try expectShape(dictionaries.SanitizerAttributeNamespace, .{
        .name = runtime.DOMString.initInterned("title"),
        .namespace = null,
    }, "{\"name\":\"title\",\"namespace\":null}");
}

test "a webidl.Opt member not given takes its default; given null, it is null" {
    try expectShape(dictionaries.SanitizerElementNamespace, .{
        .name = runtime.DOMString.initInterned("p"),
    }, "{\"name\":\"p\",\"namespace\":\"" ++ html_namespace ++ "\"}");
    try expectShape(dictionaries.SanitizerElementNamespace, .{
        .name = runtime.DOMString.initInterned("p"),
        .namespace = .passed(null),
    }, "{\"name\":\"p\",\"namespace\":null}");
}

test "a defaulted member the value leaves unset is written with its default" {
    try expectShape(dictionaries.EventInit, .{ .cancelable = true }, "{\"bubbles\":false,\"cancelable\":true,\"composed\":false}");
}

/// A dictionary pair shaped as codegen emits them, with a member of every
/// default kind and a real member named `base` (JsonLdOptions has one: a
/// member, not an inherited dictionary).
const Ancestor = struct {
    zeta: ?bool = null,
    alpha: ?runtime.DOMString = null,
    pub const member_defaults = .{
        .{ "zeta", .{ .boolean = true } },
        .{ "alpha", .{ .string = "a" } },
    };
};
const Descendant = struct {
    base: Ancestor,
    count: ?f64 = null,
    list: ?[]const bool = null,
    nothing: ?runtime.DOMString = null,
    limit: ?f64 = null,
    lowest: ?f64 = null,
    pub const member_defaults = .{
        .{ "count", .{ .number = 1.5 } },
        .{ "list", .empty_sequence },
        .{ "nothing", .null },
        .{ "limit", .positive_infinity },
        .{ "lowest", .negative_infinity },
    };
};
const WithBaseMember = struct {
    base: ?runtime.DOMString = null,
    other: ?bool = null,
};

test "every default kind converts, and only a dictionary-typed `base` is inheritance" {
    // JSON writes the infinities as null; their numbers are checked apart.
    try expectShape(Descendant, .{ .base = .{} }, "{\"alpha\":\"a\",\"zeta\":true,\"count\":1.5,\"limit\":null,\"list\":[],\"lowest\":null,\"nothing\":null}");
    const e = try env();
    const object = try conversions.toV8Value(Descendant, e.isolate, e.context, .{ .base = .{} });
    defer ffi.v8_Value_Dispose(object);
    const global = ffi.v8_Context_Global(e.context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(e.isolate, "converted", 9) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, e.context, @ptrCast(key), object)) return error.SetFailed;
    const check = try eval("converted.limit === Infinity && converted.lowest === -Infinity");
    defer ffi.v8_Value_Dispose(check);
    try testing.expect(ffi.v8_Value_BooleanValue(check, e.isolate));

    // An own property named `base`: the shape helper says so.
    try expectShape(WithBaseMember, .{ .base = runtime.DOMString.initInterned("https://example.com/") }, "BASE {\"base\":\"https://example.com/\"}");
}

test "writing defaults and inherited members leaves no handle behind" {
    const e = try env();
    const value: dictionaries.SanitizerElementNamespaceWithAttributes = .{
        .base = .{ .name = runtime.DOMString.initInterned("div") },
        .removeAttributes = &.{},
    };
    for (0..64) |_| {
        const object = try conversions.toV8Value(@TypeOf(value), e.isolate, e.context, value);
        ffi.v8_Value_Dispose(object);
        const defaults = try conversions.toV8Value(Descendant, e.isolate, e.context, .{ .base = .{} });
        ffi.v8_Value_Dispose(defaults);
    }
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    for (0..2000) |_| {
        const object = try conversions.toV8Value(@TypeOf(value), e.isolate, e.context, value);
        ffi.v8_Value_Dispose(object);
        const defaults = try conversions.toV8Value(Descendant, e.isolate, e.context, .{ .base = .{} });
        ffi.v8_Value_Dispose(defaults);
    }
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(e.isolate);
    // 2,000 rounds keeping one handle each would be 32,000 bytes.
    try testing.expect(after -| before < 16 * 1024);
}
