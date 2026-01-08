//! Implementation for OfflineAudioContext interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const OfflineAudioContext = interfaces.OfflineAudioContext;
const BaseAudioContextImpl = @import("BaseAudioContext.zig");

pub const State = OfflineAudioContext.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for OfflineAudioContext
pub const InternalState = struct {
    number_of_channels: u32,
    length: u32,
    oncomplete: ?typedefs.EventHandler,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up BaseAudioContext internal state (includes AudioWorklet)
    BaseAudioContextImpl.deinit(instance);
}

/// Constructor implementation
pub fn call_constructor(ctx: runtime.Context, args: interfaces.OfflineAudioContext.ConstructorArgs) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &OfflineAudioContext.vtable, ctx);
    errdefer deinit(instance);

    // Extract constructor parameters
    const number_of_channels: u32, const length: u32, const sample_rate: f32 = switch (args) {
        .unsigned_long_unsigned_long_float => |a| .{ a.numberOfChannels, a.length, a.sampleRate },
        .OfflineAudioContextOptions => |opts| .{
            opts.numberOfChannels orelse 2,
            opts.length,
            opts.sampleRate,
        },
    };

    // Initialize BaseAudioContext internal state with the sample rate
    _ = try BaseAudioContextImpl.getOrCreateInternalState(instance, ctx.getAllocator(), sample_rate);

    // Store OfflineAudioContext-specific state in the flattened state
    const state = instance.getState(State);
    state.own.length = length;
    state.own.oncomplete = null;
    _ = number_of_channels; // Used for audio processing, stored in parent

    return instance;
}

/// Getter for length
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.getState(State);
    return state.own.length;
}

/// Getter for oncomplete
pub fn get_oncomplete(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.oncomplete orelse null;
}

/// Setter for oncomplete
pub fn set_oncomplete(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const state = instance.getState(State);
    state.own.oncomplete = value;
}

/// Operation: suspend
pub fn call_suspend(instance: *runtime.Instance, suspendTime: f64) anyerror!runtime.JSValue {
    _ = instance;
    _ = suspendTime;
    return error.NotImplemented;
}

/// Operation: startRendering
pub fn call_startRendering(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: resume
pub fn call_resume(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
