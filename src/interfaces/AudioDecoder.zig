//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioDecoderImpl = @import("../impls/AudioDecoder.zig");
const EventTarget = @import("EventTarget.zig");

pub const AudioDecoder = struct {
    pub const Meta = struct {
        pub const name = "AudioDecoder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            state: CodecState = undefined,
            decodeQueueSize: u32 = undefined,
            ondequeue: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioDecoder, .{
        .deinit_fn = &deinit_wrapper,

        .get_decodeQueueSize = &get_decodeQueueSize,
        .get_ondequeue = &get_ondequeue,
        .get_state = &get_state,

        .set_ondequeue = &set_ondequeue,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_configure = &call_configure,
        .call_decode = &call_decode,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_flush = &call_flush,
        .call_isConfigSupported = &call_isConfigSupported,
        .call_removeEventListener = &call_removeEventListener,
        .call_reset = &call_reset,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AudioDecoderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioDecoderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try AudioDecoderImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDecoderImpl.get_state(state);
    }

    pub fn get_decodeQueueSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return AudioDecoderImpl.get_decodeQueueSize(state);
    }

    pub fn get_ondequeue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDecoderImpl.get_ondequeue(state);
    }

    pub fn set_ondequeue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        AudioDecoderImpl.set_ondequeue(state, value);
    }

    pub fn call_decode(instance: *runtime.Instance, chunk: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_decode(state, chunk);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_dispatchEvent(state, event);
    }

    pub fn call_flush(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDecoderImpl.call_flush(state);
    }

    pub fn call_isConfigSupported(instance: *runtime.Instance, config: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_isConfigSupported(state, config);
    }

    pub fn call_reset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDecoderImpl.call_reset(state);
    }

    pub fn call_configure(instance: *runtime.Instance, config: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_configure(state, config);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioDecoderImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AudioDecoderImpl.call_removeEventListener(state, type_, callback, options);
    }

};
