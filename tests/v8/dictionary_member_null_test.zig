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
//! A member whose type is a union converts a present null by the union
//! (WebIDL 3.2.25: step 4 to its dictionary member, step 15 to its string
//! member - "null" -, step 17 to its numeric member - 0 -, step 18 to
//! boolean - false -, else step 20's TypeError), as Chrome, Firefox and
//! Safari do (lane bind1 B5, probe tmp/probes/bind1-nullmember, 2026-11-23:
//! `new Response('', {headers: null})` is a TypeError, `performance.measure(
//! 'm', {start: null})` names the mark "null", `new IntersectionObserver(f,
//! {threshold: null})` has thresholds [0], in all three). It read as not
//! present once B2 typed such members: while they were runtime.JSValue the
//! impl saw the null (`jsvalue_union_members`).
//!
//! The predicate's default is pinned: a member the converter cannot convert
//! null for by its own rule keeps reading null as not present.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const conversions = v8.conversions;

/// The generated dictionaries, named through the operations that take them
/// (tests/v8 has no `dictionaries` import of its own).
const dictionaries = struct {
    /// LockManager.request(name, options, callback)'s `options`.
    const LockOptions = @typeInfo(@TypeOf(interfaces.LockManager.call_request__1)).@"fn".param_types[2].?;
    /// new Request(input, init)'s `init`.
    const RequestInit = @FieldType(@typeInfo(@TypeOf(interfaces.Request.call_constructor)).@"fn".param_types[2].?, "value");
    /// port.postMessage(message, options)'s `options`: `sequence<object>
    /// transfer = []`.
    const StructuredSerializeOptions = @FieldType(@typeInfo(@TypeOf(interfaces.MessagePort.call_postMessage__1)).@"fn".param_types[2].?, "value");
    /// new MessageEvent(type, init)'s `init`: `sequence<MessagePort> ports = []`.
    const MessageEventInit = @FieldType(@typeInfo(@TypeOf(interfaces.MessageEvent.call_constructor)).@"fn".param_types[2].?, "value");
    /// element.setHTML(html, options)'s `options`: `(Sanitizer or
    /// SanitizerConfig or SanitizerPresets) sanitizer = "default"`, an inline
    /// union with a generated type (lane bind1 B5).
    const SetHTMLOptions = @FieldType(@typeInfo(@TypeOf(interfaces.Element.call_setHTML)).@"fn".param_types[2].?, "value");
    /// effect.updateTiming(timing)'s `timing`: `(unrestricted double or
    /// DOMString) duration`, a generated union (lane bind1 B5, the last
    /// area: it was runtime.JSValue, converted by dom/animations/options.zig).
    const OptionalEffectTiming = @FieldType(@typeInfo(@TypeOf(interfaces.AnimationEffect.call_updateTiming)).@"fn".param_types[1].?, "value");
    /// new IntersectionObserver(callback, options)'s `options`: `(double or
    /// sequence<double>) threshold = 0`, a generated union (lane bind1 B5).
    const IntersectionObserverInit = @FieldType(@typeInfo(@TypeOf(interfaces.IntersectionObserver.call_constructor)).@"fn".param_types[2].?, "value");
};

const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
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

fn field(comptime T: type, comptime name: []const u8) Zig017Field {
    inline for (zig017FieldsOfType(T)) |f| {
        if (comptime std.mem.eql(u8, f.name, name)) return f;
    }
    @compileError("no member " ++ name);
}

const Kind = enum { a };

/// A dictionary as codegen emits one: every optional member `?T = null`.
const Shaped = struct {
    pub const webidl_dictionary = true;
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

/// Unions as codegen emits them (typedefs, each with its arms table), and a
/// dictionary whose members they type.
const TextOrNumber = union(enum) {
    domstring: runtime.DOMString,
    double: f64,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "double", .kind = .numeric },
    };
};
const NumberOrList = union(enum) {
    double: f64,
    double_sequence: []const f64,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "double", .kind = .numeric },
        .{ .field = "double_sequence", .kind = .{ .sequence = null } },
    };
};
const FlagOrList = union(enum) {
    boolean: bool,
    double_sequence: []const f64,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "double_sequence", .kind = .{ .sequence = null } },
    };
};
const Inner = struct {
    pub const webidl_dictionary = true;
    count: ?u32 = null,
};
const OptionsOrFlag = union(enum) {
    inner: Inner,
    boolean: bool,
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "inner", .kind = .dictionary },
        .{ .field = "boolean", .kind = .boolean },
    };
};
const Unioned = struct {
    pub const webidl_dictionary = true;
    text_or_number: ?TextOrNumber = null,
    number_or_list: ?NumberOrList = null,
    flag_or_list: ?FlagOrList = null,
    options_or_flag: ?OptionsOrFlag = null,
    nullable_union: ?TextOrNumber = null,

    pub const nullable_members = .{"nullable_union"};
};

test "a present null on a union member converts by the union: the predicate" {
    try testing.expect(comptime conversions.presentNullConvertsByType(Unioned, field(Unioned, "text_or_number")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Unioned, field(Unioned, "number_or_list")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Unioned, field(Unioned, "flag_or_list")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Unioned, field(Unioned, "options_or_flag")));
    // A nullable union member's null is null.
    try testing.expect(!comptime conversions.presentNullConvertsByType(Unioned, field(Unioned, "nullable_union")));
    // The generated ones: RequestInit's `HeadersInit headers` converts null
    // by the union; `BodyInit? body` is nullable.
    try testing.expect(comptime conversions.presentNullConvertsByType(dictionaries.RequestInit, field(dictionaries.RequestInit, "headers")));
    try testing.expect(!comptime conversions.presentNullConvertsByType(dictionaries.RequestInit, field(dictionaries.RequestInit, "body")));
}

test "a union member's null is its string member's \"null\" (step 15, before the numeric member's 0)" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ text_or_number: null })");
    defer ffi.v8_Value_Dispose(object);
    var unioned = try conversions.fromV8Value(Unioned, testing.allocator, e.isolate, e.context, object);
    defer if (unioned.text_or_number) |*member| member.domstring.deinit(testing.allocator);
    try testing.expect(unioned.text_or_number != null);
    try testing.expect(unioned.text_or_number.? == .domstring);
    try testing.expectEqualStrings("null", unioned.text_or_number.?.domstring.asSlice());
}

test "a union member's null is its numeric member's 0 (step 17), else boolean's false (step 18)" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ number_or_list: null, flag_or_list: null })");
    defer ffi.v8_Value_Dispose(object);
    const unioned = try conversions.fromV8Value(Unioned, testing.allocator, e.isolate, e.context, object);
    try testing.expect(unioned.number_or_list != null);
    try testing.expectEqual(@as(f64, 0), unioned.number_or_list.?.double);
    try testing.expect(unioned.flag_or_list != null);
    try testing.expectEqual(false, unioned.flag_or_list.?.boolean);
}

test "a union member's null is its dictionary member, empty (step 4)" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ options_or_flag: null })");
    defer ffi.v8_Value_Dispose(object);
    const unioned = try conversions.fromV8Value(Unioned, testing.allocator, e.isolate, e.context, object);
    try testing.expect(unioned.options_or_flag != null);
    try testing.expect(unioned.options_or_flag.? == .inner);
    try testing.expect(unioned.options_or_flag.?.inner.count == null);
}

test "a nullable union member's null is null, and undefined is not present for every union member" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ nullable_union: null, text_or_number: undefined, number_or_list: undefined, flag_or_list: undefined, options_or_flag: undefined })");
    defer ffi.v8_Value_Dispose(object);
    const unioned = try conversions.fromV8Value(Unioned, testing.allocator, e.isolate, e.context, object);
    try testing.expect(unioned.nullable_union == null);
    try testing.expect(unioned.text_or_number == null);
    try testing.expect(unioned.number_or_list == null);
    try testing.expect(unioned.flag_or_list == null);
    try testing.expect(unioned.options_or_flag == null);
}

test "RequestInit {headers: null} is a TypeError: null is no sequence and no record (step 20)" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ headers: null })");
    defer ffi.v8_Value_Dispose(object);
    try testing.expectError(error.TypeError, conversions.fromV8Value(dictionaries.RequestInit, testing.allocator, e.isolate, e.context, object));
    // Absent stays absent.
    const absent = try eval("({ headers: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const init = try conversions.fromV8Value(dictionaries.RequestInit, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(init.headers == null);
}

test "a present null converts by type only for a non-nullable member with a scalar or sequence type - the default is not present" {
    defer test_agent.close();
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "text")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "flag")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "count")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "kind")));
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "object")));
    // A sequence (WebIDL 3.2.21 step 1, and a record's 3.2.23 step 1: null is
    // not an Object - a TypeError).
    try testing.expect(comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "list")));
    // The defaults: listed nullable, `any`, a required member.
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "nullable_text")));
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "value")));
    try testing.expect(!comptime conversions.presentNullConvertsByType(Shaped, field(Shaped, "required")));
}

test "LockOptions {mode: null} is a TypeError: null is not a LockMode" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ mode: null })");
    defer ffi.v8_Value_Dispose(object);
    try testing.expectError(error.TypeError, conversions.fromV8Value(dictionaries.LockOptions, testing.allocator, e.isolate, e.context, object));
}

test "LockOptions {ifAvailable: null} is false, and an absent member stays absent" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ ifAvailable: null, steal: undefined })");
    defer ffi.v8_Value_Dispose(object);
    const options = try conversions.fromV8Value(dictionaries.LockOptions, testing.allocator, e.isolate, e.context, object);
    try testing.expectEqual(@as(?bool, false), options.ifAvailable);
    try testing.expectEqual(@as(?bool, null), options.steal);
    try testing.expect(options.mode == null);
}

test "a non-nullable DOMString member's null is the string \"null\"; a nullable member's null is null" {
    defer test_agent.close();
    const e = try env();
    const object = try eval("({ text: null, nullable_text: null, required: 'r' })");
    defer ffi.v8_Value_Dispose(object);
    var shaped = try conversions.fromV8Value(Shaped, testing.allocator, e.isolate, e.context, object);
    defer if (shaped.text) |*t| t.deinit(testing.allocator);
    defer shaped.required.deinit(testing.allocator);
    try testing.expectEqualStrings("null", shaped.text.?.asSlice());
    try testing.expect(shaped.nullable_text == null);
}

test "RequestInit's signal is AbortSignal?: a present null is passed, with the value null; an absent one is not passed" {
    defer test_agent.close();
    // Fetch's Request constructor step 29: "If init["signal"] exists, then
    // set signal to it" - {signal: null} removes the input's signal
    // (fetch/api/abort/general.any.js "Signal removed by setting to null").
    const e = try env();
    const object = try eval("({ signal: null })");
    defer ffi.v8_Value_Dispose(object);
    const init = try conversions.fromV8Value(dictionaries.RequestInit, testing.allocator, e.isolate, e.context, object);
    try testing.expect(init.signal.wasPassed());
    try testing.expect(init.signal.getValue() == null);

    const absent = try eval("({ signal: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const omitted = try conversions.fromV8Value(dictionaries.RequestInit, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(!omitted.signal.wasPassed());
}

test "StructuredSerializeOptions {transfer: null} is a TypeError: null is not a sequence<object>" {
    defer test_agent.close();
    // webmessaging/with-options/null-transfer.html: postMessage('', {transfer:
    // null}) throws a TypeError (WebIDL 3.2.18 step 4.1.4.3 converts the
    // present null by sequence<object>, whose step 1 throws). Read as absent,
    // it posted with an empty transfer list.
    const e = try env();
    const object = try eval("({ transfer: null })");
    defer ffi.v8_Value_Dispose(object);
    try testing.expectError(error.TypeError, conversions.fromV8Value(dictionaries.StructuredSerializeOptions, testing.allocator, e.isolate, e.context, object));
}

test "MessageEventInit {ports: null} is a TypeError; {transfer: undefined} stays absent" {
    defer test_agent.close();
    // html/webappapis/scripting/events/messageevent-constructor.https.html
    // "Passing null for ports member".
    const e = try env();
    const ports = try eval("({ ports: null })");
    defer ffi.v8_Value_Dispose(ports);
    try testing.expectError(error.TypeError, conversions.fromV8Value(dictionaries.MessageEventInit, testing.allocator, e.isolate, e.context, ports));
    const absent = try eval("({ transfer: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const options = try conversions.fromV8Value(dictionaries.StructuredSerializeOptions, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(options.transfer == null);
}

test "OptionalEffectTiming {duration: null} is the union's string member, \"null\"; a number is the double; undefined is not present" {
    defer test_agent.close();
    // 3.2.25 step 15: null is no Number, and the union has a string member,
    // so it converts to "null" - which "update the timing properties"
    // (Web Animations 1 6.5.4 step 3) rejects: updateTiming({duration: null})
    // is a TypeError in Chrome, Firefox and Safari (probe
    // tmp/probes/bind1-nullmember/report-g3.txt). The member has a generated
    // union type since lane bind1 B5; until then it was the last
    // runtime.JSValue member and the impl converted it.
    // hasdecl: a generated dictionary; codegen writes the `pub` declaration
    // only while a member is typed runtime.JSValue - its absence is the claim.
    try testing.expect(!@hasDecl(dictionaries.OptionalEffectTiming, "jsvalue_union_members"));
    const e = try env();
    const present = try eval("({ duration: null })");
    defer ffi.v8_Value_Dispose(present);
    const given = try conversions.fromV8Value(dictionaries.OptionalEffectTiming, testing.allocator, e.isolate, e.context, present);
    var duration = given.duration.?;
    defer if (duration == .domstring) duration.domstring.deinit(testing.allocator);
    try testing.expect(given.duration.? == .domstring);
    try testing.expectEqualStrings("null", given.duration.?.domstring.asSlice());

    const number = try eval("({ duration: 250 })");
    defer ffi.v8_Value_Dispose(number);
    const timed = try conversions.fromV8Value(dictionaries.OptionalEffectTiming, testing.allocator, e.isolate, e.context, number);
    try testing.expect(timed.duration.? == .double);
    try testing.expectEqual(@as(f64, 250), timed.duration.?.double);

    const absent = try eval("({ duration: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const omitted = try conversions.fromV8Value(dictionaries.OptionalEffectTiming, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(omitted.duration == null);
}

test "IntersectionObserverInit {threshold: null} is the union's double member, 0; a sequence keeps its order; undefined is not present" {
    defer test_agent.close();
    // 3.2.25 step 17: null is no sequence (step 11 needs an Object) and the
    // union has a numeric member, so it converts to the double 0 - Chrome,
    // Firefox and Safari all answer thresholds [0] for {threshold: null}.
    // The member has a generated union type since lane bind1 B5 (it was
    // runtime.JSValue, and the constructor discarded it).
    // hasdecl: a generated dictionary; codegen writes the `pub` declaration
    // only while a member is typed runtime.JSValue - its absence is the claim.
    try testing.expect(!@hasDecl(dictionaries.IntersectionObserverInit, "jsvalue_union_members"));
    const e = try env();
    const present = try eval("({ threshold: null })");
    defer ffi.v8_Value_Dispose(present);
    const given = try conversions.fromV8Value(dictionaries.IntersectionObserverInit, testing.allocator, e.isolate, e.context, present);
    try testing.expect(given.threshold.? == .double);
    try testing.expectEqual(@as(f64, 0), given.threshold.?.double);

    const list = try eval("({ threshold: [0.5, 0] })");
    defer ffi.v8_Value_Dispose(list);
    const many = try conversions.fromV8Value(dictionaries.IntersectionObserverInit, testing.allocator, e.isolate, e.context, list);
    defer testing.allocator.free(many.threshold.?.double_sequence);
    try testing.expectEqualSlices(f64, &.{ 0.5, 0 }, many.threshold.?.double_sequence);

    const absent = try eval("({ threshold: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const omitted = try conversions.fromV8Value(dictionaries.IntersectionObserverInit, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(omitted.threshold == null);
}

test "SetHTMLOptions {sanitizer: null} is the union's SanitizerConfig member, empty; undefined is not present" {
    defer test_agent.close();
    // 3.2.25 step 4: null converts to the union's dictionary member - an
    // empty SanitizerConfig, which is not the member's "default" preset:
    // `{sanitizer: null}` read as absent took the default preset
    // (crane/san-options-null.html). The member has a generated union type
    // since lane bind1 B5 (it was runtime.JSValue, converted by
    // html/sanitizer.zig), so the binding converts the null.
    // hasdecl: a generated dictionary; codegen writes the `pub` declaration
    // only while a member is typed runtime.JSValue - its absence is the claim.
    try testing.expect(!@hasDecl(dictionaries.SetHTMLOptions, "jsvalue_union_members"));
    const e = try env();
    const present = try eval("({ sanitizer: null })");
    defer ffi.v8_Value_Dispose(present);
    const given = try conversions.fromV8Value(dictionaries.SetHTMLOptions, testing.allocator, e.isolate, e.context, present);
    try testing.expect(given.sanitizer != null);
    try testing.expect(given.sanitizer.? == .sanitizer_config);
    const config = given.sanitizer.?.sanitizer_config;
    try testing.expect(config.elements == null and config.removeElements == null and config.attributes == null and config.comments == null);

    const preset = try eval("({ sanitizer: 'default' })");
    defer ffi.v8_Value_Dispose(preset);
    const named = try conversions.fromV8Value(dictionaries.SetHTMLOptions, testing.allocator, e.isolate, e.context, preset);
    try testing.expect(named.sanitizer.? == .sanitizer_presets);

    const absent = try eval("({ sanitizer: undefined })");
    defer ffi.v8_Value_Dispose(absent);
    const omitted = try conversions.fromV8Value(dictionaries.SetHTMLOptions, testing.allocator, e.isolate, e.context, absent);
    try testing.expect(omitted.sanitizer == null);
}

// Zig 0.17 compat: 0.16's StructField/UnionField/EnumField list, rebuilt at comptime from
// Zig 0.17's struct-of-arrays @typeInfo (a comptime-only element type: calls run at comptime).
// The binding's own type: presentNullConvertsByType takes a conversions.Zig017Field.
const Zig017Field = conversions.Zig017Field;
fn zig017FieldsOf(comptime info: anytype) [info.field_names.len]Zig017Field {
    var out: [info.field_names.len]Zig017Field = undefined;
    if (@hasField(@TypeOf(info), "field_values")) {
        for (info.field_names, info.field_values, 0..) |n, v, i| out[i] = .{ .name = n, .value = v };
        return out;
    }
    for (info.field_names, info.field_types, info.field_attrs, 0..) |n, t, a, i| out[i] = .{
        .name = n,
        .type = t,
        .default_value_ptr = if (@hasField(@TypeOf(a), "default_value_ptr")) a.default_value_ptr else null,
        .is_comptime = if (@hasField(@TypeOf(a), "comptime")) a.@"comptime" else false,
        .alignment = a.@"align",
    };
    return out;
}
fn zig017FieldsOfType(comptime T: type) [@import("std").meta.fieldNames(T).len]Zig017Field {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| zig017FieldsOf(s),
        .@"union" => |u| zig017FieldsOf(u),
        .@"enum" => |e| zig017FieldsOf(e),
        else => @compileError("zig017FieldsOfType: not a struct, union or enum"),
    };
}
