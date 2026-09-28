//! The live Context Global counter counts every Context Global the wrapper
//! makes.
//!
//! v8_Context_Dispose subtracts one from `live_context_globals` for whatever
//! it is handed, so every function that returns a new Global<Context> must
//! add one. Several did not - v8_FunctionCallbackInfo_GetFunctionCreationContext,
//! which every binding getter and method call takes, among them - so the
//! counter fell by one per call: gc_bench read -1.00 per cycle for a plain
//! `probe.nodeType`, and engine-boundary read -1 per worker realm
//! (v8_Context_NewWithGlobalConstructor). A real leak then read as nothing,
//! or as the drift's opposite. These pin the balance: a creation site added
//! without its count turns them red.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is; V8 is never torn down here.
fn realm() !void {
    if (isolate_once != null) return;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    isolate_once = i;
    context_once = context;
}

/// Script's value of `expression`, as an integer.
fn scriptInt(expression: []const u8) !i32 {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

test "binding getter and method calls leave live_context_globals unchanged" {
    try realm();
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    v8.interface_bindings.Event.registerGlobalFast(isolate_once.?, context, global, "Event");
    // The first calls make what later ones reuse.
    try std.testing.expectEqual(@as(i32, 4), try scriptInt("globalThis.e = new Event('ping'); e.stopPropagation(); e.type.length"));

    const before = ffi.v8_Debug_LiveContextGlobals();
    // 64 getter calls and 64 method calls through the binding.
    try std.testing.expectEqual(@as(i32, 256), try scriptInt("let n = 0; for (let i = 0; i < 64; i++) { n += e.type.length; e.stopPropagation(); } n"));
    const after = ffi.v8_Debug_LiveContextGlobals();
    if (after != before) {
        std.debug.print("live_context_globals {d} -> {d} over 128 binding calls\n", .{ before, after });
        return error.CounterDrift;
    }
}

test "a context made with a global constructor and disposed leaves live_context_globals unchanged" {
    try realm();
    const isolate = isolate_once.?;
    const template = ffi.v8_FunctionTemplate_New(isolate, null, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);

    const before = ffi.v8_Debug_LiveContextGlobals();
    for (0..4) |_| {
        const made = ffi.v8_Context_NewWithGlobalConstructor(isolate, template) orelse return error.ContextCreationFailed;
        ffi.v8_Context_Dispose(made);
        const plain = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
        ffi.v8_Context_Dispose(plain);
    }
    const after = ffi.v8_Debug_LiveContextGlobals();
    if (after != before) {
        std.debug.print("live_context_globals {d} -> {d} over 8 contexts made and disposed\n", .{ before, after });
        return error.CounterDrift;
    }
}
