//! A dictionary member present as null converts null by its type.
//!
//! WebIDL 3.2.18 (dictionary): "If jsMemberValue is not undefined, then let
//! idlMemberValue be the result of converting jsMemberValue to an IDL value
//! whose type is the type member is declared to be of" - only undefined is
//! "not present". Codegen types every optional member `?T = null`, and the
//! converter read a present null as Zig's null too, so `{mode: null}` for a
//! LockOptions was "no mode" where it must be a TypeError (null is not a
//! LockMode: ToString gives "null"), and a DOMString member's null was absent
//! rather than "null" (web-locks/acquire.https.any.js, `new Request(url,
//! {mode: null})`). A nullable member - listed by codegen in
//! `nullable_members` - keeps null as null.
//!
//! The predicate's default is pinned: a member the converter cannot convert
//! null for by its own rule keeps reading null as not present.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const conversions = v8.conversions;

/// The generated dictionaries, named through the operations that take them
/// (tests/v8 has no `dictionaries` import of its own).
const dictionaries = struct {
    /// LockManager.request(name, options, callback)'s `options`.
    const LockOptions = @typeInfo(@TypeOf(interfaces.LockManager.call_request__1)).@"fn".params[2].type.?;
    /// new Request(input, init)'s `init`.
    const RequestInit = @FieldType(@typeInfo(@TypeOf(interfaces.Request.call_constructor)).@"fn".params[2].type.?, "value");
    /// element.setHTML(html, options)'s `options`: `(Sanitizer or
    /// SanitizerConfig or SanitizerPresets) sanitizer = "default"`, an inline
    /// union typed runtime.JSValue.
    const SetHTMLOptions = @FieldType(@typeInfo(@TypeOf(interfaces.Element.call_setHTML)).@"fn".params[2].type.?, "value");
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

/// Script's value of `code`, OWNED - an object made as the binding receives
/// a dictionary argument.
fn eval(code: []const u8) !*ffi.Value {
    const e = try env();
    const text = ffi.v8_String_NewFromUtf8(e.isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(e.context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(e.context, script) orelse error.RunFailed;
}

fn field(comptime T: type, comptime name: []const u8) std.builtin.Type.StructField {
    inline for (std.meta.fields(T)) |f| {
        if (comptime std.mem.eql(u8, f.name, name)) return f;
    }
    @compileError("no member " ++ name);
}

const Kind = enum { a };

/// A dictionary as codegen emits one: every optional member `?T = null`.
const Shaped = struct {
    text: ?runtime.DOMString = null,
    flag: ?bool = null,
    count: ?u32 = null,
    kind: ?Kind = null,
    object: ?*runtime.Instance = null,
    nullable_text: ?runtime.DOMString = null,
    value: ?runtime.JSValue = null,
    list: ?[]const runtime.DOMString = null,
    required: runtime.DOMString,

    pub const nullable_members = .{"nullable_text"};
    pub const any_members = .{"value"};
    /// The interface `object` converts to, as codegen lists one
    /// (`interface_members`): without it the member could not convert.
    pub const interface_members = .{.{ "object", "Node" }};
};

test "a present null converts by type only for a non-nullable member with a scalar type - the default is not present" {
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "text")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "flag")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "count")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "kind")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "object")));
    // The defaults: listed nullable, `any`, a sequence, a required member.
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "nullable_text")));
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "value")));
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "list")));
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "required")));
}

test "LockOptions {mode: null} is a TypeError: null is not a LockMode" {
    const e = try env();
    const object = try eval("({ mode: null })");
    defer ffi.v8_Value_Dispose(object);
    try testing.expectError(error.TypeError, conversions.fromV8Value(dictionaries.LockOptions, testing.allocator, e.isolate, e.context, object));
}

test "LockOptions {ifAvailable: null} is false, and an absent member stays absent" {
    const e = try env();
    const object = try eval("({ ifAvailable: null, steal: undefined })");
    defer ffi.v8_Value_Dispose(object);
    const options = try conversions.fromV8Value(dictionaries.LockOptions, testing.allocator, e.isolate, e.context, object);
    try testing.expectEqual(@as(?bool, false), options.ifAvailable);
    try testing.expectEqual(@as(?bool, null), options.steal);
    try testing.expect(options.mode == null);
}

test "a non-nullable DOMString member's null is the string \"null\"; a nullable member's null is null" {
    const e = try env();
    const object = try eval("({ text: null, nullable_text: null, required: 'r' })");
    defer ffi.v8_Value_Dispose(object);
    var shaped = try conversions.fromV8Value(Shaped, testing.allocator, e.isolate, e.context, object);
    defer if (shaped.text) |*t| t.deinit(testing.allocator);
    defer shaped.required.deinit(testing.allocator);
    try testing.expectEqualStrings("null", shaped.text.?.asSlice());
    try testing.expect(shaped.nullable_text == null);
}

test "RequestInit's signal is AbortSignal?: a present null is null" {
    const e = try env();
    const object = try eval("({ signal: null })");
    defer ffi.v8_Value_Dispose(object);
    const init = try conversions.fromV8Value(dictionaries.RequestInit, testing.allocator, e.isolate, e.context, object);
    try testing.expect(init.signal == null);
}

test "an inline union member typed JSValue keeps a present null apart from absent" {
    // WebIDL 3.2.18: only undefined is "not present"; a present null converts
    // by the union's type (3.2.25 step 4: to the SanitizerConfig arm, an empty
    // dictionary). The impl converts the JSValue, so it must see the null:
    // `{sanitizer: null}` read as absent took the default preset
    // (crane/san-options-null.html). Codegen lists the member in
    // `jsvalue_union_members`.
    try testing.expect(@hasDecl(dictionaries.SetHTMLOptions, "jsvalue_union_members"));
    const e = try env();
    const present = try eval("({ sanitizer: null })");
    defer ffi.v8_Value_Dispose(present);
    const given = try conversions.fromV8Value(dictionaries.SetHTMLOptions, testing.allocator, e.isolate, e.context, present);
    try testing.expect(given.sanitizer != null);
    try testing.expect(given.sanitizer.? == .null);

    const absent = try eval("({ sanitizer: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const omitted = try conversions.fromV8Value(dictionaries.SetHTMLOptions, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(omitted.sanitizer == null);
}
