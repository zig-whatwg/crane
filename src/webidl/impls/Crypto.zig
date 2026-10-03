//! Implementation for Crypto interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const engine = @import("engine");
const host = @import("host");
const random = @import("webcrypto").random;
const same_object = @import("same_object.zig");
const Crypto = interfaces.Crypto;

pub const State = Crypto.State;

pub const ImplError = error{
    NotImplemented,
};

/// The associated SubtleCrypto is traced from this Crypto's wrapper.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    subtle: ?*runtime.Instance = null,
    subtle_edge: same_object.Traced = .{ .slot = .{ .name = "subtle" } },
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.subtle_edge.release(instance);
    // The collector owns a child that has been handed to script; it can
    // outlive this Crypto, or have been collected first during teardown.
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Getter for subtle
pub fn get_subtle(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    // WebCrypto §10.2.1: the associated SubtleCrypto, in this object's realm.
    if (internal.subtle) |subtle| return subtle;
    const subtle = try interfaces.SubtleCrypto.init(internal.allocator, instance.ctx);
    internal.subtle = subtle;
    internal.subtle_edge.hold(instance, subtle);
    return subtle;
}

/// Operation: getRandomValues
pub fn call_getRandomValues(instance: *runtime.Instance, array: typedefs.ArrayBufferView) anyerror!typedefs.ArrayBufferView {
    // WebCrypto §10.1.1 step 1: only the nine integer typed array types.
    switch (array) {
        .int8_array, .uint8_array, .uint8_clamped_array, .int16_array, .uint16_array, .int32_array, .uint32_array, .bigint64_array, .biguint64_array => {},
        else => return domException(instance.ctx, "TypeMismatchError"),
    }
    if (array.jsHandle()) |handle| {
        const value = runtime.JSValue.fromAnyopaque(handle);
        const description = engine.describeArrayBufferView(instance.ctx, value) orelse return domException(instance.ctx, "TypeMismatchError");
        // Steps 2-4: the quota concerns the current view, not its backing buffer.
        if (description.byte_length > 65536) return quotaExceeded(instance.ctx);
        if (description.byte_length != 0) {
            const bytes = try instance.ctx.allocator.alloc(u8, description.byte_length);
            defer instance.ctx.allocator.free(bytes);
            // Steps 5-6: obtain entropy before touching the destination view.
            random.fill(host.io(), bytes) catch return error.OperationError;
            try engine.writeIntoArrayBufferView(instance.ctx, value, bytes, 0);
        }
    } else {
        // Native callers have a real BufferSource rather than an engine view.
        if (array.getByteLength() > 65536) return quotaExceeded(instance.ctx);
        const bytes = try array.asBytes();
        if (bytes.len != 0) random.fill(host.io(), @constCast(bytes)) catch return error.OperationError;
    }
    // Step 7: return the very same object. The argument's reference is
    // borrowed for the call, and the binding releases it before it converts
    // the result, which is the binding's own (ArrayBufferView.jsHandle): the
    // same object goes back over a hold of the binding's.
    const js = array.jsValue(runtime.JSValue) orelse return array;
    const held = try engine.retainValue(instance.ctx, js);
    return array.withJsHandle(held.take().handle.ptr);
}

/// Operation: randomUUID
pub fn call_randomUUID(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const text = random.uuid(host.io(), instance.ctx.allocator) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.OperationError,
    };
    return runtime.DOMString.initOwned(text);
}

fn domException(realm: runtime.Context, name: []const u8) anyerror {
    const exception = engine.createDOMException(realm, name, "Invalid random-value destination") catch |err| return err;
    defer exception.release();
    engine.throwValue(realm, exception.borrow()) catch |err| return err;
    return error.ExceptionPending;
}

fn quotaExceeded(realm: runtime.Context) anyerror {
    // WebCrypto §10.1.1 step 4: the WebIDL derived exception, with null amounts.
    const exception = interfaces.QuotaExceededError.call_constructor(realm, .{ .was_passed = false, .value = undefined }, .{ .was_passed = false, .value = undefined }) catch |err| return err;
    defer if (!engine.hasWrapper(exception)) runtime.Instance.deinit(exception);
    engine.throwValue(realm, .{ .instance = exception }) catch |err| return err;
    return error.ExceptionPending;
}
