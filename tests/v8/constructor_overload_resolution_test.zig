//! An overloaded constructor runs WebIDL's overload resolution algorithm.
//!
//! WebIDL 3.6: pick the constructor from the number of arguments and, where
//! several remain, from the type of the value at the distinguishing argument
//! index; then convert the arguments to THAT constructor's types. A
//! conversion that throws is the call's exception.
//!
//! The resolver used to try ConstructorArgs' variants in order until one
//! converted, so:
//! - a conversion that threw in one variant was left pending while the next
//!   was tried - running its getters and toString()s again;
//! - a value of another type converted into the first variant that took it:
//!   ToNumber(a Uint8ClampedArray) is NaN, so `new ImageData(array, w, h)`
//!   became ImageData(0, w, h);
//! - a constructor whose one argument is a dictionary
//!   (OfflineAudioContext(contextOptions)) was taken for a struct of
//!   arguments, one per dictionary member.
//!
//! The allocator is std.testing.allocator, so what a variant leaves behind
//! fails the test as a leak.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const resolver = v8.interface_mod.overload_resolver;
const Overload = resolver.Overload;

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

fn install(name: []const u8, callback: ffi.FunctionCallback) !void {
    const e = try env();
    const template = ffi.v8_FunctionTemplate_New(e.isolate, callback, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, e.context) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    const global = ffi.v8_Context_Global(e.context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(e.isolate, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, e.context, @ptrCast(key), @ptrCast(function))) return error.SetFailed;
}

/// A dictionary as codegen emits one.
const Options = struct {
    label: ?runtime.DOMString = null,
    length: ?f64 = null,
};

/// ImageData's shape: (unsigned long sw, unsigned long sh) and
/// (ImageDataArray data, unsigned long sw) - the data an `any` here, the
/// way a typed array arm is a reference to its object.
const ImageDataLike = union(enum) {
    numbers: struct { sw: u32, sh: u32 },
    array: struct { data: runtime.JSValue, sw: u32 },
};
const image_data_overloads = &[_]Overload{
    .{ .function = "numbers", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
    .{ .function = "array", .args = &.{ .{ .kinds = &.{.{ .typed_array = "Uint8ClampedArray" }} }, .{ .kinds = &.{.numeric} } } },
};

/// OfflineAudioContext's shape: one dictionary, or three numbers.
const ContextLike = union(enum) {
    options: Options,
    three: struct { channels: u32, length: u32, rate: f32 },
};
const context_overloads = &[_]Overload{
    .{ .function = "options", .args = &.{.{ .kinds = &.{.dictionary} }} },
    .{ .function = "three", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
};

/// Two constructors told apart by their second argument: a string first in
/// both, so it converts once, as the chosen one's.
const TextLike = union(enum) {
    text_number: struct { text: runtime.DOMString, number: f64 },
    text_options: struct { text: runtime.DOMString, options: Options },
};
const text_overloads = &[_]Overload{
    .{ .function = "text_number", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.numeric} } } },
    .{ .function = "text_options", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.dictionary} } } },
};

/// What the last probe resolved: the variant's index, or -1 for an error.
var chosen: i32 = -1;
var chosen_label_len: usize = 0;
var chosen_sw: u32 = 0;

fn Probe(comptime U: type, comptime overloads: []const Overload) type {
    return struct {
        fn callback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
            const e = env_once.?;
            const args = resolver.resolveConstructorOverload(U, overloads, info, testing.allocator, e.isolate, e.context) catch {
                chosen = -1;
                return;
            };
            defer resolver.freeConstructorOverload(U, overloads, testing.allocator, args);
            chosen = @intFromEnum(std.meta.activeTag(args));
            if (U == ContextLike) switch (args) {
                .options => |o| chosen_label_len = if (o.label) |l| l.asSlice().len else 0,
                else => {},
            };
            if (U == ImageDataLike) switch (args) {
                .array => |a| chosen_sw = a.sw,
                .numbers => |n| chosen_sw = n.sw,
            };
        }
    };
}

test "the value at the distinguishing index picks the constructor" {
    try install("imageData", Probe(ImageDataLike, image_data_overloads).callback);
    _ = try evalInt("imageData(new Uint8ClampedArray(16), 2); 0");
    try testing.expectEqual(@as(i32, 1), chosen);
    try testing.expectEqual(@as(u32, 2), chosen_sw);
    _ = try evalInt("imageData(4, 3); 0");
    try testing.expectEqual(@as(i32, 0), chosen);
    try testing.expectEqual(@as(u32, 4), chosen_sw);
}

test "a constructor whose one argument is a dictionary converts that argument as the dictionary" {
    try install("offline", Probe(ContextLike, context_overloads).callback);
    _ = try evalInt("offline({ label: 'x'.repeat(64), length: 8 }); 0");
    try testing.expectEqual(@as(i32, 0), chosen);
    try testing.expectEqual(@as(usize, 64), chosen_label_len);
    _ = try evalInt("offline(1, 2, 3); 0");
    try testing.expectEqual(@as(i32, 1), chosen);
}

test "a conversion that throws is the call's exception, and no other constructor is tried" {
    try install("text", Probe(TextLike, text_overloads).callback);
    // The number selects text_number; converting its text throws once.
    try testing.expectEqual(@as(i32, 1), try evalInt(
        \\let calls = 0;
        \\let caught = null;
        \\try { text({ toString() { calls++; throw 'thrown'; } }, 5); } catch (e) { caught = e; }
        \\caught === 'thrown' ? calls : -calls
    ));
    try testing.expectEqual(@as(i32, -1), chosen);
}

/// Two constructors told apart by a second argument that is a dictionary or
/// a callback: a Symbol is neither, and no later step takes it.
const PickyLike = union(enum) {
    text_options: struct { text: runtime.DOMString, options: Options },
    text_callback: struct { text: runtime.DOMString, callback: runtime.JSValue },
};
const picky_overloads = &[_]Overload{
    .{ .function = "text_options", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.dictionary} } } },
    .{ .function = "text_callback", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.callback_function} } } },
};

test "no constructor takes the value at the distinguishing index: the arguments before it convert, then a TypeError" {
    try install("picky", Probe(PickyLike, picky_overloads).callback);
    // Step 11 converts the arguments before the distinguishing index; step
    // 12.20 throws for the Symbol at it.
    try testing.expectEqual(@as(i32, 1), try evalInt(
        \\let ran = 0;
        \\try { picky({ toString() { ran++; return 't'.repeat(64); } }, Symbol()); } catch (e) {}
        \\ran
    ));
    try testing.expectEqual(@as(i32, -1), chosen);
    // And a conversion there that throws is the exception.
    try testing.expectEqual(@as(i32, 1), try evalInt(
        \\let caught2 = null;
        \\try { picky({ toString() { throw 'first'; } }, Symbol()); } catch (e) { caught2 = e; }
        \\caught2 === 'first' ? 1 : 0
    ));
}

test "too few arguments for any constructor is a TypeError before any conversion" {
    try install("three", Probe(ContextLike, context_overloads).callback);
    try testing.expectEqual(@as(i32, 0), try evalInt(
        \\let got = 0;
        \\try { three({ get label() { got++; return 'x'; } }, 2); } catch (e) {}
        \\got
    ));
    try testing.expectEqual(@as(i32, -1), chosen);
}
