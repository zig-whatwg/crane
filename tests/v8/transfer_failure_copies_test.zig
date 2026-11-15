//! A transfer that fails frees the copies of the transferred buffers it made,
//! and hands none of them out (v8_wrapper.cpp serializeWithTransfer, the
//! serializer every postMessage and structuredClone uses).
//!
//! HTML StructuredSerializeWithTransfer step 5.4.1 keeps each transferred
//! ArrayBuffer's bytes in its data holder; the adapter copies them out as it
//! walks the transfer list, before anything is detached, into memory the
//! caller frees with v8_Free_ArrayBufferTransferData - on success only. Three
//! of the walk's early returns - a buffer listed twice (step 2.3's
//! DataCloneError), an empty handle, a value that is not an ArrayBuffer -
//! returned without freeing the copies already made, and the other failures
//! freed them but left the freed pointers in the caller's out list.
//! `structuredClone(buffer, { transfer: [buffer, buffer] })` leaked the first
//! copy: leaks --atExit named 1 leak of 16 bytes, malloc'd in
//! serializeWithTransfer, over crane/worker.basic.html ("Phase 6.2: Duplicate
//! transfer throws", an 8-byte buffer; lane mem1 b1).
//!
//! std.testing.allocator cannot see C++ allocations, so the leak is read two
//! ways: the out list after a failure (every entry null - a pointer left there
//! is a copy no caller frees, structured_serialization.zig reads the list only
//! on success), and malloc's own bytes in use over 64 failed transfers of a
//! 1 MiB buffer through the protocol's serializer (macOS mstats, glibc
//! mallinfo2; the leak was 64 MiB).
//!
//! The file shares tests/v8's process: it starts the engine as any file may,
//! makes its own agent, and leaves no isolate entered that it entered.

const std = @import("std");
const builtin = @import("builtin");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

const allocator = std.testing.allocator;

var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;
var test_realm: ?*runtime.ContextData = null;

/// What the last `leftovers` call saw: -1 when the serializer succeeded,
/// else how many entries of its out list it left non-null.
var last_left: i32 = -2;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
    test_realm = null;
}

fn setup() !void {
    const i = try test_agent.open(.{ .realm_allocator = std.heap.page_allocator });
    if (test_realm == null) {
        ffi.v8_Isolate_SetMicrotasksPolicy(i, @backingInt(ffi.MicrotasksPolicy.Explicit));
        const context = test_agent.context.?;
        const r = try test_agent.realmRecord(std.heap.page_allocator, .{ .engine_realm = context, .agent = @ptrCast(i) });
        const d = try test_agent.contextData(std.heap.page_allocator, .{ .engine_ctx = context, .realm = r });
        test_isolate = i;
        test_context = context;
        test_realm = d;
        // `leftovers(value, a, b)`: v8_Value_StructuredSerializeWithTransfer
        // on `value` with the transfer list [a, b] and a zeroed out list,
        // read the way structured_serialization.zig reads it (`last_left`).
        try defineFunction("leftovers", leftoversCallback);
        // `serialize(value, list)`: the protocol's StructuredSerializeWithTransfer,
        // as MessagePort.postMessage and structuredClone run it; true on
        // success, false on a DataCloneError, any other throw left pending.
        try defineFunction("serialize", serializeCallback);
    }
}

fn defineFunction(name: []const u8, callback: ffi.FunctionCallback) !void {
    const template = ffi.v8_FunctionTemplate_New(test_isolate.?, callback, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);
    const function = ffi.v8_FunctionTemplate_GetFunction(template, test_context.?) orelse return error.FunctionFailed;
    defer ffi.v8_Function_Dispose(function);
    try setGlobal(name, @ptrCast(function));
}

fn eval(code: []const u8) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(test_isolate.?, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(test_context.?, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(test_context.?, script) orelse error.RunFailed;
}

fn evalInt(code: []const u8) !i32 {
    const value = try eval(code);
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, test_context.?);
}

fn setGlobal(name: []const u8, handle: *anyopaque) !void {
    const global = ffi.v8_Context_Global(test_context.?) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(test_isolate.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    _ = ffi.v8_Object_Set(global, test_context.?, @ptrCast(key), @ptrCast(@alignCast(handle)));
}

fn leftoversCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const value = info.get(0);
    defer ffi.v8_Global_Dispose(value);
    var list = [_]*ffi.Value{ info.get(1), info.get(2) };
    defer for (list) |item| ffi.v8_Global_Dispose(item);
    var out = [_]ffi.ArrayBufferTransferData{ .{ .data = null, .size = 0 }, .{ .data = null, .size = 0 } };
    var size: usize = 0;
    var code: c_int = 0;
    const options: ffi.StructuredSerializeOptions = .{ .for_storage = false, .agent_cluster = 0 };
    if (ffi.v8_Value_StructuredSerializeWithTransfer(value, &list, list.len, &size, &out, &code, null, &options)) |bytes| {
        ffi.v8_Free_SerializedBuffer(bytes);
        ffi.v8_Free_ArrayBufferTransferData(&out, out.len);
        last_left = -1;
        return;
    }
    // A failure: the caller frees nothing (structured_serialization.zig), so
    // an entry left non-null is a copy that leaks. A DataCloneError (code 3)
    // stays pending for the script.
    var left: i32 = 0;
    for (out) |entry| {
        if (entry.data != null) left += 1;
    }
    last_left = left;
}

fn noPlatformObjects(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

fn serializeCallback(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const realm = test_realm.?;
    const value_handle = info.get(0);
    defer ffi.v8_Global_Dispose(value_handle);
    const list_handle = info.get(1);
    defer ffi.v8_Global_Dispose(list_handle);
    // The transfer list as the binding converts it: sequence<object>.
    const list = v8.webidl_conversions.convertToSequenceOfObjects(realm, .{ .handle = .{ .ptr = @ptrCast(list_handle) } }, allocator) catch return;
    defer {
        for (list) |item| v8.engine.v8ReleaseValue(item);
        allocator.free(list);
    }
    const succeeded = if (v8.structured_serialization.structuredSerializeWithTransfer(realm, .{ .handle = .{ .ptr = @ptrCast(value_handle) } }, list, noPlatformObjects, null, allocator)) |result| blk: {
        var owned = result;
        owned.deinit(allocator);
        break :blk true;
    } else |err| switch (err) {
        error.DataCloneError => false,
        // Anything else is left for the script to see (pending), or an
        // engine failure the script cannot see: either way not a result.
        else => return,
    };
    const answer = ffi.v8_Boolean_New(info.getIsolate(), succeeded) orelse return;
    defer ffi.v8_Value_Dispose(@ptrCast(answer));
    info.setReturnValue(@ptrCast(answer));
}

/// malloc's bytes in use, where this process can read them: macOS's mstats
/// (<malloc/malloc.h>), glibc's mallinfo2 (in-use bytes of every arena, and
/// of the mmapped chunks). Null elsewhere.
fn mallocInUse() ?usize {
    if (comptime builtin.os.tag.isDarwin()) return Darwin.mstats().bytes_used;
    if (comptime builtin.os.tag == .linux and builtin.abi.isGnu()) {
        const m = Glibc.mallinfo2();
        return m.uordblks + m.hblkhd;
    }
    return null;
}

const Darwin = struct {
    const MStats = extern struct {
        bytes_total: usize,
        chunks_used: usize,
        bytes_used: usize,
        chunks_free: usize,
        bytes_free: usize,
    };
    extern "c" fn mstats() MStats;
};

const Glibc = struct {
    const Mallinfo2 = extern struct {
        arena: usize,
        ordblks: usize,
        smblks: usize,
        hblks: usize,
        hblkhd: usize,
        usmblks: usize,
        fsmblks: usize,
        uordblks: usize,
        fordblks: usize,
        keepcost: usize,
    };
    extern "c" fn mallinfo2() Mallinfo2;
};

test "a buffer listed twice is a DataCloneError that leaves no copy in the out list" {
    defer test_agent.close();
    try setup();
    last_left = -2;
    // Code 1 - a bad transfer list - has thrown nothing.
    const value = try eval("(() => { const b = new ArrayBuffer(8); leftovers(b, b, b); return b.byteLength; })()");
    defer ffi.v8_Value_Dispose(value);
    try std.testing.expectEqual(@as(i32, 8), ffi.v8_Value_Int32Value(value, test_context.?));
    // Before the fix: 1, the first buffer's copy, which no caller freed.
    try std.testing.expectEqual(@as(i32, 0), last_left);
}

test "a value that does not serialize leaves no copy in the out list, and both buffers attached" {
    defer test_agent.close();
    try setup();
    last_left = -2;
    // The walk copies both buffers; the value (a function) then throws -
    // the spec's DataCloneError where the realm has DOMException, an Error
    // in this bare context - which the script catches.
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const a = new ArrayBuffer(8), b = new ArrayBuffer(16);
        \\  try { leftovers(() => {}, a, b); return -1; }
        \\  catch (e) { return e instanceof Error && a.byteLength === 8 && b.byteLength === 16 ? 1 : 0; }
        \\})()
    ));
    try std.testing.expectEqual(@as(i32, 0), last_left);
}

test "a transfer that succeeds hands out both copies and detaches both buffers" {
    defer test_agent.close();
    try setup();
    last_left = -2;
    try std.testing.expectEqual(@as(i32, 1), try evalInt(
        \\(() => {
        \\  const a = new ArrayBuffer(8), b = new ArrayBuffer(16);
        \\  leftovers({ a, b }, a, b);
        \\  return a.byteLength === 0 && b.byteLength === 0 ? 1 : 0;
        \\})()
    ));
    try std.testing.expectEqual(@as(i32, -1), last_left);
}

test "64 failed transfers of a 1 MiB buffer through the protocol leave malloc's bytes in use where they were" {
    defer test_agent.close();
    try setup();
    // One buffer for every round, made before the first reading: a failed
    // transfer detaches nothing, and a buffer per round would be 64 MiB of
    // backing stores in malloc until a collection.
    const made = try eval("globalThis.big = new ArrayBuffer(1024 * 1024); serialize(1, [big, big]) === false ? 1 : 0");
    defer ffi.v8_Value_Dispose(made);
    try std.testing.expectEqual(@as(i32, 1), ffi.v8_Value_Int32Value(made, test_context.?));
    const before = mallocInUse() orelse return error.SkipZigTest;
    try std.testing.expectEqual(@as(i32, 64), try evalInt(
        \\(() => {
        \\  let refused = 0;
        \\  for (let i = 0; i < 64; i++) if (serialize(1, [big, big]) === false) refused++;
        \\  return big.byteLength === 1048576 ? refused : -1;
        \\})()
    ));
    const after = mallocInUse().?;
    // Before the fix each refusal dropped its 1 MiB copy: 64 MiB. 8 MiB is
    // slack for the engine's own malloc traffic over the loop.
    const grown = if (after > before) after - before else 0;
    if (grown >= 8 * 1024 * 1024) {
        std.debug.print("malloc's bytes in use grew {d} over 64 refused transfers of a 1 MiB buffer\n", .{grown});
        return error.TestUnexpectedResult;
    }
}
