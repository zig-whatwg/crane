//! A conversion that fails part-way frees what it had already converted.
//!
//! A dictionary's members are converted one by one (WebIDL 3.2.18), and an
//! overloaded constructor's arguments one by one into the variant the
//! resolver is trying. When a later member or argument fails - its Get
//! throws, ToNumber throws, a restricted float is NaN - the earlier ones are
//! already converted: a string copied, an `any` handle kept. Nothing freed
//! them. RequestInit's body leaked that way (fetch/api/request/
//! request-init-stream.any.js), and so did every `new URLPattern(...)` whose
//! first variant failed on its second argument.
//!
//! The allocator is std.testing.allocator, so a member left behind fails the
//! test as a leak.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const resolver = v8.interface_mod.overload_resolver;

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

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, env_once.?.context);
}

/// A dictionary as codegen emits one: optional members, a restricted
/// `double` listed in `restricted_members`.
const Plain = struct {
    a: ?runtime.DOMString = null,
    b: ?f64 = null,
    pub const restricted_members = [_][]const u8{"b"};
};

/// One that inherits: its parent's members come first, as `base`.
const Parent = struct {
    a: ?runtime.DOMString = null,
};
const Child = struct {
    base: Parent = .{},
    c: ?f64 = null,
    pub const restricted_members = [_][]const u8{"c"};
};

test "a dictionary whose later member fails frees the members before it" {
    const e = try env();
    // `a` converts (an owned copy), then `b` is NaN: a TypeError.
    const object = try eval("({ a: 'a'.repeat(64), b: NaN })");
    defer ffi.v8_Value_Dispose(object);
    try testing.expectError(error.TypeError, v8.conversions.fromV8Value(Plain, testing.allocator, e.isolate, e.context, object));
}

test "a dictionary whose own member fails frees its inherited members" {
    const e = try env();
    const object = try eval("({ a: 'a'.repeat(64), c: Infinity })");
    defer ffi.v8_Value_Dispose(object);
    try testing.expectError(error.TypeError, v8.conversions.fromV8Value(Child, testing.allocator, e.isolate, e.context, object));
}

test "a dictionary that converts whole is the caller's to free" {
    const e = try env();
    const object = try eval("({ a: 'a'.repeat(64), b: 1.5 })");
    defer ffi.v8_Value_Dispose(object);
    const converted = try v8.conversions.fromV8Value(Plain, testing.allocator, e.isolate, e.context, object);
    defer v8.interface_mod.freeConvertedArg(Plain, testing.allocator, converted);
    try testing.expectEqualStrings("a" ** 64, converted.a.?.asSlice());
    try testing.expectEqual(@as(f64, 1.5), converted.b.?);
}

/// An overloaded constructor's arguments, as codegen emits them: a variant
/// per overload, a struct of its arguments.
const Overloads = union(enum) {
    string_number: struct {
        text: runtime.DOMString,
        number: f64,
    },
};
/// Its overload set, as codegen writes `constructor_overloads`.
const overloads = &[_]resolver.Overload{
    .{ .function = "string_number", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.numeric} } } },
};

/// `probe(...)`: resolves `Overloads` from its arguments with the testing
/// allocator, and frees what it built.
const Probe = struct {
    var failed: bool = false;

    fn callback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
        const e = env_once.?;
        const args = resolver.resolveConstructorOverload(Overloads, overloads, info, testing.allocator, e.isolate, e.context) catch {
            failed = true;
            return;
        };
        failed = false;
        resolver.freeConstructorOverload(Overloads, overloads, testing.allocator, args);
    }

    fn install() !void {
        const e = try env();
        const template = ffi.v8_FunctionTemplate_New(e.isolate, callback, null) orelse return error.TemplateFailed;
        defer ffi.v8_FunctionTemplate_Dispose(template);
        const function = ffi.v8_FunctionTemplate_GetFunction(template, e.context) orelse return error.FunctionFailed;
        defer ffi.v8_Function_Dispose(function);
        const global = ffi.v8_Context_Global(e.context) orelse return error.NoGlobal;
        defer ffi.v8_Object_Dispose(global);
        const key = ffi.v8_String_NewFromUtf8(e.isolate, "probe", 5) orelse return error.StringFailed;
        defer ffi.v8_String_Dispose(key);
        if (!ffi.v8_Object_Set(global, e.context, @ptrCast(key), @ptrCast(function))) return error.SetFailed;
    }
};

test "an overload variant whose later argument fails frees the arguments before it" {
    try Probe.install();
    // `text` converts (an owned copy), then ToNumber(Symbol()) fails: the
    // call fails. (What reaches script is
    // the binding's to throw; the probe throws nothing.)
    _ = try evalInt("try { probe('t'.repeat(64), Symbol()); 0 } catch (e) { 1 }");
    try testing.expect(Probe.failed);
}

test "the arguments of the overload chosen are freed with freeConstructorOverload" {
    try Probe.install();
    try testing.expectEqual(@as(i32, 0), try evalInt("probe('t'.repeat(64), 2); 0"));
    try testing.expect(!Probe.failed);
}
