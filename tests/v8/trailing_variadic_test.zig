//! A trailing variadic argument through the real binding: `op(a, ...rest)`
//! collects every argument from `rest`'s index, as a sole variadic does, and
//! no handle outlives the call.
//!
//! The binding's two- and three-parameter paths converted the ONE value at
//! the variadic's index as the whole slice: TrustedTypePolicy.createHTML(input,
//! ...arguments) threw a TypeError for any extra argument, while createHTML(x)
//! - an empty slice by default - worked. The target here is a policy whose
//! createHTML callback reports what it got.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;
var policy_exposed = false;

fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    v8.interface_bindings.registerAllInterfaces(i, context);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

fn eval(code: []const u8) !*ffi.Value {
    const context = context_once.?;
    const text = ffi.v8_String_NewFromUtf8(isolate_once.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context_once.?);
}

fn setGlobal(name: []const u8, value: *ffi.Value) !void {
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate_once.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), value)) return error.SetFailed;
}

/// `testPolicy`: a TrustedTypePolicy whose createHTML answers
/// "<input>|<count of extra arguments>|<extras joined by commas>".
fn policy() !void {
    const r = try realm();
    if (policy_exposed) return;
    const function = try eval("(s, ...rest) => s + '|' + rest.length + '|' + rest.join(',')");
    defer ffi.v8_Value_Dispose(function);
    const held = try engine.retainValue(r, runtime.JSValue.fromHandle(@ptrCast(function)));
    const callback: engine.CallbackFunction = .{ .function = held, .context = null };
    defer callback.release();
    const instance = try dom.trusted_types.createPolicy(r, "variadic", .{ .html = callback });
    try setGlobal("testPolicy", v8.conversions.instanceToV8(isolate_once.?, instance));
    policy_exposed = true;
}

test "a trailing variadic takes no, one or several extra arguments" {
    try policy();
    try std.testing.expectEqual(@as(i32, 1), try evalInt("testPolicy.createHTML('x').toString() === 'x|0|' ? 1 : 0"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("testPolicy.createHTML('x', 'a').toString() === 'x|1|a' ? 1 : 0"));
    try std.testing.expectEqual(@as(i32, 1), try evalInt("testPolicy.createHTML('x', 'a', 2, null).toString() === 'x|3|a,2,' ? 1 : 0"));
    // Objects pass through as themselves.
    try std.testing.expectEqual(@as(i32, 1), try evalInt("testPolicy.createHTML('x', {toString() { return 'o' }}).toString() === 'x|1|o' ? 1 : 0"));
}

/// V8's global handle bytes left by 64 runs of `body`, after a collection.
fn handleBytesLeftBy(comptime body: []const u8) !i64 {
    const isolate = isolate_once.?;
    const loop = "(() => { for (let i = 0; i < {N}; i++) { " ++ body ++ " } return 0 })()";
    _ = try evalInt(comptime replaceN(loop, "2"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    _ = try evalInt(comptime replaceN(loop, "64"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    return @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate))) - before;
}

fn replaceN(comptime loop: []const u8, comptime n: []const u8) []const u8 {
    const at = std.mem.indexOf(u8, loop, "{N}").?;
    return loop[0..at] ++ n ++ loop[at + 3 ..];
}

fn oneHandleBytes() i64 {
    const isolate = isolate_once.?;
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const one = ffi.v8_Number_New(isolate, 1);
    const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    ffi.v8_Value_Dispose(@ptrCast(one));
    return @intCast(with_one - start);
}

test "the extra arguments' handles go when the call returns" {
    try policy();
    const control_left = try handleBytesLeftBy("testPolicy.createHTML('x');");
    const left = try handleBytesLeftBy("testPolicy.createHTML('x', {}, [], 'a');");
    const one = oneHandleBytes();
    if (left - control_left >= one * 8) {
        std.debug.print("64 calls with three extra arguments left {d} bytes of global handles; the control left {d} ({d} a handle)\n", .{ left, control_left, one });
        return error.HandlesLeaked;
    }
}
