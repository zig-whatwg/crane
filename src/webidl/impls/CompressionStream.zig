//! Compression §§4–5 over the native Streams §9.3 transformer seam.
//! DEFLATE and container validation live in the engine-free compression module.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const engine = @import("engine");
const compression = @import("compression");
const js = @import("streams_js.zig");
const st = @import("streams_transform.zig");
const Interface = interfaces.CompressionStream;
const Codec = compression.Encoder;
pub const State = Interface.State;
pub const ImplError = error{ TypeError, InvalidState, OutOfMemory };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    transform: ?*runtime.Instance = null,
};

pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // Only the controller owns the codec. Script may retain the stream
        // sides after this API object has been collected.
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

pub fn call_constructor(ctx: runtime.Context, format: enums.CompressionFormat) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Interface.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const realm = try js.Realm.ofContext(ctx);
    const codec = try Codec.create(ctx.allocator, switch (format) {
        ._deflate_ => .deflate,
        ._deflate_raw_ => .deflate_raw,
        ._gzip_ => .gzip,
    });
    // setUp takes ownership at the call, including on failure.
    instance.getState(State).own._internal.?.transform = try st.setUp(realm, ctx, .{ .ctx = codec, .vtable = &transformer });
    return instance;
}

pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidState;
    return interfaces.TransformStream.get_readable(internal.transform orelse return error.InvalidState);
}

pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.InvalidState;
    return interfaces.TransformStream.get_writable(internal.transform orelse return error.InvalidState);
}

fn transform(raw: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance, chunk: js.Value) js.Error!js.Value {
    const codec: *Codec = @ptrCast(@alignCast(raw.?));
    const Copy = struct {
        realm: runtime.Context,
        chunk: runtime.JSValue,
        bytes: ?[]u8 = null,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.bytes = (try engine.getCopyOfBufferSourceBytes(self.realm, self.chunk, self.realm.allocator)) orelse return error.TypeError;
        }
    };
    var copy: Copy = .{ .realm = realm.ctx, .chunk = chunk.value };
    if (engine.completionOf(realm.ctx, Copy.run, &copy) catch |err| return js.fromEngineError(err)) |thrown| {
        defer thrown.release();
        return realm.promiseRejectedWith(.{ .realm = realm.ctx, .value = thrown.value });
    }
    defer realm.ctx.allocator.free(copy.bytes.?);
    return push(codec, realm, controller, copy.bytes.?, false);
}

fn flush(raw: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
    const codec: *Codec = @ptrCast(@alignCast(raw.?));
    return push(codec, realm, controller, &.{}, true);
}

fn push(codec: *Codec, realm: js.Realm, controller: *runtime.Instance, input: []const u8, final: bool) js.Error!js.Value {
    const allocator = codec.allocator;
    const bytes = codec.push(input, final) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidData => return realm.promiseRejectedWithTypeError("Invalid or incomplete compressed data"),
    };
    defer allocator.free(bytes);
    // Finish reading the input before enqueue can run author code. The
    // returned Uint8Array owns a copy, independently of the codec buffers.
    if (bytes.len != 0) {
        const buffer = engine.createArrayBuffer(realm.ctx, bytes) catch |err| return js.fromEngineError(err);
        defer buffer.release();
        const view = engine.createArrayBufferView(realm.ctx, .uint8_array, buffer.value, 0, bytes.len) catch |err| return js.fromEngineError(err);
        defer view.release();
        if (try st.controllerEnqueueCompletion(realm, controller, .{ .realm = realm.ctx, .value = view.value })) |thrown| {
            defer js.dispose(thrown);
            return realm.promiseRejectedWith(thrown);
        }
    }
    return realm.promiseResolvedWithUndefined();
}

fn cancel(_: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, _: js.Value) js.Error!js.Value {
    return realm.promiseResolvedWithUndefined();
}

fn destroyCodec(raw: ?*anyopaque, _: std.mem.Allocator) void {
    const codec: *Codec = @ptrCast(@alignCast(raw.?));
    codec.destroy();
}

const transformer: st.Transformer.VTable = .{
    .transform = transform,
    .flush = flush,
    .cancel = cancel,
    .deinit = destroyCodec,
};
