//! Generated from: media-source.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ManagedMediaSourceImpl = @import("../impls/ManagedMediaSource.zig");
const MediaSource = @import("MediaSource.zig");

pub const ManagedMediaSource = struct {
    pub const Meta = struct {
        pub const name = "ManagedMediaSource";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MediaSource;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            streaming: bool = undefined,
            onstartstreaming: EventHandler = undefined,
            onendstreaming: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ManagedMediaSource, .{
        .deinit_fn = &deinit_wrapper,

        .get_activeSourceBuffers = &get_activeSourceBuffers,
        .get_canConstructInDedicatedWorker = &get_canConstructInDedicatedWorker,
        .get_duration = &get_duration,
        .get_handle = &get_handle,
        .get_onendstreaming = &get_onendstreaming,
        .get_onsourceclose = &get_onsourceclose,
        .get_onsourceended = &get_onsourceended,
        .get_onsourceopen = &get_onsourceopen,
        .get_onstartstreaming = &get_onstartstreaming,
        .get_readyState = &get_readyState,
        .get_sourceBuffers = &get_sourceBuffers,
        .get_streaming = &get_streaming,

        .set_duration = &set_duration,
        .set_onendstreaming = &set_onendstreaming,
        .set_onsourceclose = &set_onsourceclose,
        .set_onsourceended = &set_onsourceended,
        .set_onsourceopen = &set_onsourceopen,
        .set_onstartstreaming = &set_onstartstreaming,

        .call_addEventListener = &call_addEventListener,
        .call_addSourceBuffer = &call_addSourceBuffer,
        .call_clearLiveSeekableRange = &call_clearLiveSeekableRange,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_endOfStream = &call_endOfStream,
        .call_isTypeSupported = &call_isTypeSupported,
        .call_removeEventListener = &call_removeEventListener,
        .call_removeSourceBuffer = &call_removeSourceBuffer,
        .call_setLiveSeekableRange = &call_setLiveSeekableRange,
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
        ManagedMediaSourceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ManagedMediaSourceImpl.constructor(state);
        
        return instance;
    }

    /// Extended attributes: [SameObject], [Exposed=DedicatedWorker]
    pub fn get_handle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_handle) |cached| {
            return cached;
        }
        const value = ManagedMediaSourceImpl.get_handle(state);
        state.cached_handle = value;
        return value;
    }

    pub fn get_sourceBuffers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_sourceBuffers(state);
    }

    pub fn get_activeSourceBuffers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_activeSourceBuffers(state);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_readyState(state);
    }

    pub fn get_duration(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_duration(state);
    }

    pub fn set_duration(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.set_duration(state, value);
    }

    pub fn get_onsourceopen(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_onsourceopen(state);
    }

    pub fn set_onsourceopen(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.set_onsourceopen(state, value);
    }

    pub fn get_onsourceended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_onsourceended(state);
    }

    pub fn set_onsourceended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.set_onsourceended(state, value);
    }

    pub fn get_onsourceclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_onsourceclose(state);
    }

    pub fn set_onsourceclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.set_onsourceclose(state, value);
    }

    pub fn get_canConstructInDedicatedWorker(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_canConstructInDedicatedWorker(state);
    }

    pub fn get_streaming(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_streaming(state);
    }

    pub fn get_onstartstreaming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_onstartstreaming(state);
    }

    pub fn set_onstartstreaming(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.set_onstartstreaming(state, value);
    }

    pub fn get_onendstreaming(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.get_onendstreaming(state);
    }

    pub fn set_onendstreaming(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedMediaSourceImpl.set_onendstreaming(state, value);
    }

    pub fn call_endOfStream(instance: *runtime.Instance, error_: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_endOfStream(state, error_);
    }

    pub fn call_setLiveSeekableRange(instance: *runtime.Instance, start: f64, end: f64) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_setLiveSeekableRange(state, start, end);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_when(state, type_, options);
    }

    pub fn call_addSourceBuffer(instance: *runtime.Instance, type_: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_addSourceBuffer(state, type_);
    }

    pub fn call_removeSourceBuffer(instance: *runtime.Instance, sourceBuffer: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_removeSourceBuffer(state, sourceBuffer);
    }

    pub fn call_isTypeSupported(instance: *runtime.Instance, type_: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_isTypeSupported(state, type_);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_clearLiveSeekableRange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedMediaSourceImpl.call_clearLiveSeekableRange(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedMediaSourceImpl.call_removeEventListener(state, type_, callback, options);
    }

};
