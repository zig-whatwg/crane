//! WebIDL 3.2.25, converting to a union whose arms are an interface, a
//! dictionary and an enumeration - (Sanitizer or SanitizerConfig or
//! SanitizerPresets), the shape member_unions.zig names for a dictionary
//! member the binding converts in its place:
//!
//! - step 4: null or undefined is the dictionary arm (its defaults);
//! - step 5: a platform object implementing the interface is that arm;
//! - step 11: any other object is the dictionary arm;
//! - step 15: anything else is the string type - and 2.13 counts every
//!   enumeration among the string types, so the enumeration arm takes it:
//!   ToString, then a TypeError unless it is one of the values.
//!
//! The union conversion knew no enumeration arm: "default" for (Sanitizer or
//! SanitizerConfig or SanitizerPresets), "background" for (TaskPriority or
//! TaskSignal), were TypeErrors.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = v8.ffi;
const conversions = v8.conversions;

var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;
var test_realm: ?runtime.Context = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
    test_realm = null;
}

fn realm() !runtime.Context {
    const i = try test_agent.open(.{});
    if (test_realm == null) {
        const context = test_agent.context.?;
        const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        v8.interface_bindings.registerAllInterfaces(i, context);
        test_isolate = i;
        test_context = context;
        test_realm = r;
    }
    return test_realm.?;
}

fn eval(code: []const u8) !*ffi.Value {
    _ = try realm();
    const context = test_context.?;
    const text = ffi.v8_String_NewFromUtf8(test_isolate.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

/// An enumeration as codegen emits one, its values spelled as the IDL does.
const Presets = enum {
    default,
    pub const idl_values = [_][]const u8{"default"};
};

/// A dictionary as codegen emits one.
const Config = struct {
    comments: ?bool = null,
};

/// (AbortSignal or Config or Presets): the interface arm named as codegen
/// names one (`unionArmInterface`).
const Choice = union(enum) {
    abort_signal: *runtime.Instance,
    config: Config,
    presets: Presets,
};

fn convert(code: []const u8) !Choice {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return conversions.fromV8Value(Choice, testing.allocator, test_isolate.?, test_context.?, value);
}

test "a string that is one of the values is the enumeration arm; any other is a TypeError" {
    defer test_agent.close();
    const preset = try convert("'default'");
    try testing.expect(preset == .presets and preset.presets == .default);
    try testing.expectError(error.TypeError, convert("'bogus'"));
    // Step 15 for a number: ToString(5) is "5", no value of the enumeration.
    try testing.expectError(error.TypeError, convert("5"));
}

test "null and undefined are the dictionary arm" {
    defer test_agent.close();
    const from_null = try convert("null");
    try testing.expect(from_null == .config and from_null.config.comments == null);
    const from_undefined = try convert("undefined");
    try testing.expect(from_undefined == .config);
}

test "an object that is no platform object is the dictionary arm" {
    defer test_agent.close();
    const config = try convert("({ comments: true })");
    try testing.expect(config == .config and config.config.comments.? == true);
}

test "a platform object implementing the interface is the interface arm" {
    defer test_agent.close();
    const signal = try convert("new AbortController().signal");
    try testing.expect(signal == .abort_signal);
    try testing.expect(conversions.implements(signal.abort_signal, interfaces.AbortSignal));
}

/// A string arm is still preferred to an enumeration arm.
const StringFirst = union(enum) {
    presets: Presets,
    domstring: runtime.DOMString,
};

test "with both a string and an enumeration arm, a string goes to the string arm" {
    defer test_agent.close();
    const value = try eval("'bogus'");
    defer ffi.v8_Value_Dispose(value);
    var converted = try conversions.fromV8Value(StringFirst, testing.allocator, test_isolate.?, test_context.?, value);
    try testing.expect(converted == .domstring);
    converted.domstring.deinit(testing.allocator);
}
