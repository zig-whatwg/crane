//! HTML StructuredSerializeWithTransfer and StructuredDeserializeWithTransfer
//! (2.7.5, 2.7.7) as V8 implements them for the Engine table - what
//! MessagePort, Worker and the worker's global scope post.
//!
//! One serializer: the same V8 ValueSerializer path as the table's
//! structuredSerializeForStorage / structuredDeserialize
//! (`v8_Value_StructuredSerializeWithTransfer`, whose delegate throws the
//! spec's "DataCloneError" DOMException), here with a transfer list. The
//! transferred ArrayBuffers' contents leave the engine as bytes the caller
//! owns; the transferred platform objects leave as the Instances they are,
//! for the caller to run their transfer steps (a MessagePort's) - which
//! platform objects are transferable is the caller's knowledge, asked through
//! `runtime.TransferableCheck`.

const std = @import("std");
const runtime = @import("runtime");
const EngineError = runtime.EngineError;

const ffi = @import("ffi.zig");
const engine = @import("engine.zig");
const conversions = @import("conversions.zig");
const value_operations = @import("value_operations.zig");

/// A Global of our own for `value` - always one the caller disposes.
fn ownGlobal(isolate: *ffi.Isolate, context: *ffi.Context, value: runtime.JSValue) EngineError!*ffi.Value {
    return value_operations.ownHandle(isolate, context, value);
}

/// Engine table `structuredSerializeWithTransfer`.
pub fn structuredSerializeWithTransfer(
    realm: runtime.Context,
    value: runtime.JSValue,
    transfer_list: []const runtime.JSValue,
    check: runtime.TransferableCheck,
    check_data: ?*anyopaque,
    allocator: std.mem.Allocator,
) EngineError!runtime.SerializedWithTransfer {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    const isolate = entered.isolate;
    const context = entered.scope.context;

    // The transfer list, split: ArrayBuffers go to V8's serializer, platform
    // objects to the caller's transfer steps. Every Global here is ours.
    var buffers: std.ArrayListUnmanaged(*ffi.Value) = .empty;
    defer {
        for (buffers.items) |buffer| ffi.v8_Global_Dispose(buffer);
        buffers.deinit(allocator);
    }
    var objects: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    errdefer objects.deinit(allocator);

    // Step 2: For each transferable of transferList:
    for (transfer_list) |item| {
        const transferable = try ownGlobal(isolate, context, item);
        if (ffi.v8_Value_IsArrayBuffer(transferable)) {
            // An ArrayBuffer: V8 checks detached and duplicate buffers (steps
            // 2.3, 5.1) as it takes it.
            buffers.append(allocator, transferable) catch {
                ffi.v8_Global_Dispose(transferable);
                return EngineError.OutOfMemory;
            };
            continue;
        }
        defer ffi.v8_Global_Dispose(transferable);
        // Step 2.1: neither [[ArrayBufferData]] nor [[Detached]] - not a
        // transferable platform object (a SharedArrayBuffer lands here too,
        // step 2.2) - is a DataCloneError.
        if (!ffi.v8_Value_IsObject(transferable)) return EngineError.DataCloneError;
        const instance = conversions.fromV8Value(*runtime.Instance, allocator, isolate, context, transferable) catch
            return EngineError.DataCloneError;
        switch (check(check_data, instance)) {
            .not_transferable => return EngineError.DataCloneError,
            // Step 5.2: an object whose [[Detached]] is true.
            .detached => return EngineError.DataCloneError,
            .transferable => {},
        }
        // Step 2.3: If memory[transferable] exists, throw a DataCloneError.
        for (objects.items) |seen| {
            if (seen == instance) return EngineError.DataCloneError;
        }
        objects.append(allocator, instance) catch return EngineError.OutOfMemory;
    }

    // Step 3: Let serialized be ? StructuredSerializeInternal(value, false,
    // memory). Steps 5.1-5.4 for the ArrayBuffers: their contents are copied
    // out and the originals detached.
    const subject = try ownGlobal(isolate, context, value);
    defer ffi.v8_Global_Dispose(subject);
    const buffer_data = allocator.alloc(ffi.ArrayBufferTransferData, buffers.items.len) catch return EngineError.OutOfMemory;
    defer allocator.free(buffer_data);
    var size: usize = 0;
    var code: c_int = 0;
    const bytes = ffi.v8_Value_StructuredSerializeWithTransfer(
        subject,
        buffers.items.ptr,
        buffers.items.len,
        &size,
        buffer_data.ptr,
        &code,
    ) orelse return switch (code) {
        1 => EngineError.DataCloneError,
        3 => EngineError.ExceptionPending,
        else => EngineError.OperationFailed,
    };
    defer ffi.v8_Free_SerializedBuffer(bytes);
    defer ffi.v8_Free_ArrayBufferTransferData(buffer_data.ptr, buffer_data.len);

    // Step 6: the result, in memory the caller owns.
    const serialized = allocator.dupe(u8, bytes[0..size]) catch return EngineError.OutOfMemory;
    errdefer allocator.free(serialized);
    const contents = allocator.alloc([]u8, buffer_data.len) catch return EngineError.OutOfMemory;
    var copied: usize = 0;
    errdefer {
        for (contents[0..copied]) |c| allocator.free(c);
        allocator.free(contents);
    }
    for (buffer_data, 0..) |data, i| {
        const source: [*]const u8 = if (data.data) |d| @ptrCast(d) else undefined;
        contents[i] = allocator.dupe(u8, if (data.size > 0) source[0..data.size] else &.{}) catch return EngineError.OutOfMemory;
        copied += 1;
    }
    return .{
        .serialized = serialized,
        .array_buffers = contents,
        .platform_objects = objects.toOwnedSlice(allocator) catch return EngineError.OutOfMemory,
    };
}

/// Engine table `structuredDeserializeWithTransfer`: OWNED `.handle`.
pub fn structuredDeserializeWithTransfer(
    realm: runtime.Context,
    serialized: []const u8,
    array_buffers: []const []const u8,
) EngineError!runtime.JSValue {
    const entered = try engine.enterRealm(realm);
    defer entered.leaveAgent();
    defer entered.leaveScope();
    // Step 2: each transferred ArrayBuffer made anew in the target realm, from
    // its contents (V8 copies them). Step 3: StructuredDeserialize.
    var stack: [16]ffi.ArrayBufferTransferData = undefined;
    const heap = if (array_buffers.len > stack.len)
        std.heap.page_allocator.alloc(ffi.ArrayBufferTransferData, array_buffers.len) catch return EngineError.OutOfMemory
    else
        null;
    defer if (heap) |h| std.heap.page_allocator.free(h);
    const data = heap orelse stack[0..array_buffers.len];
    for (array_buffers, 0..) |contents, i| {
        data[i] = .{ .data = if (contents.len > 0) @ptrCast(@constCast(contents.ptr)) else null, .size = contents.len };
    }
    var code: c_int = 0;
    const value = ffi.v8_Value_DeserializeWithTransfer_CrossIsolate(serialized.ptr, serialized.len, data.ptr, data.len, &code) orelse
        return EngineError.DataCloneError;
    return .{ .handle = .{ .ptr = @ptrCast(value), .needs_disposal = true, .handle_scope = .global } };
}
