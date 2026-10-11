//! Encoding §§7.5–7.6, installed as native Streams §9.3 algorithms.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const encoding = @import("encoding");
const engine = @import("engine");
const js = @import("streams_js.zig");
const st = @import("streams_transform.zig");
const Interface = interfaces.TextEncoderStream;
const Codec = encoding.streams.Encoder;
pub const State = Interface.State;
pub const ImplError = error{ TypeError, RangeError, InvalidState, OutOfMemory };

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
        // Codec state belongs to the transform's controller, not this wrapper.
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Interface.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = instance.getState(State).own._internal.?;
    const realm = try js.Realm.ofContext(ctx);
    const codec = try ctx.allocator.create(Codec);
    codec.* = .{ .allocator = ctx.allocator };
    // setUp takes ownership at the call, including on failure.
    internal.transform = try st.setUp(realm, ctx, .{ .ctx = codec, .vtable = &transformer });
    return instance;
}

pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("utf-8");
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
    // ToString can cancel and free ctx. Encoder contains only scalar state,
    // so the active algorithm can finish on this copy even after cancellation.
    var active = codec.*;
    const Convert = struct {
        realm: runtime.Context,
        chunk: runtime.JSValue,
        bytes: ?[]u8 = null,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.bytes = try engine.convertToDOMString(self.realm, self.chunk, self.realm.allocator);
        }
    };
    var conversion: Convert = .{ .realm = realm.ctx, .chunk = chunk.value };
    // WebIDL conversion can run script; preserve its exact thrown value.
    if (engine.completionOf(realm.ctx, Convert.run, &conversion) catch |err| return js.fromEngineError(err)) |thrown| {
        defer thrown.release();
        return realm.promiseRejectedWith(.{ .realm = realm.ctx, .value = thrown.value });
    }
    defer realm.ctx.allocator.free(conversion.bytes.?);
    return push(&active, realm, controller, conversion.bytes.?, false, codec);
}

fn flush(raw: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
    const codec: *Codec = @ptrCast(@alignCast(raw.?));
    return push(codec, realm, controller, &.{}, true, null);
}

fn push(codec: *Codec, realm: js.Realm, controller: *runtime.Instance, input: []const u8, final: bool, commit_to: ?*Codec) js.Error!js.Value {
    const allocator = codec.allocator;
    const bytes = codec.push(input, final) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return realm.promiseRejectedWithTypeError("Invalid encoded data");
    };
    defer allocator.free(bytes);
    if (commit_to) |original| {
        if (st.controllerOf(controller).?.transformer != null) original.* = codec.*;
    }
    // Encoding's encode-and-enqueue steps: no output fulfils the transform;
    // nonempty output goes through enqueue, whose own error rejects the write.
    // Blink follows this order in TextEncoderStream::Transformer::Transform:
    // third_party/blink/renderer/modules/encoding/text_encoder_stream.cc.
    if (bytes.len != 0) {
        const buffer = engine.createArrayBuffer(realm.ctx, bytes) catch |err| return js.fromEngineError(err);
        defer buffer.release();
        const view = engine.createArrayBufferView(realm.ctx, .uint8_array, buffer.value, 0, bytes.len) catch |err| return js.fromEngineError(err);
        defer view.release();
        const value: js.Value = .{ .realm = realm.ctx, .value = view.value };
        if (try st.controllerEnqueueCompletion(realm, controller, value)) |thrown| {
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
    codec.allocator.destroy(codec);
}

const transformer: st.Transformer.VTable = .{
    .transform = transform,
    .flush = flush,
    .cancel = cancel,
    .deinit = destroyCodec,
};
