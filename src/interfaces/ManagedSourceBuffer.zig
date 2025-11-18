//! Generated from: media-source.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ManagedSourceBufferImpl = @import("../impls/ManagedSourceBuffer.zig");
const SourceBuffer = @import("SourceBuffer.zig");

pub const ManagedSourceBuffer = struct {
    pub const Meta = struct {
        pub const name = "ManagedSourceBuffer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SourceBuffer;
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
            onbufferedchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ManagedSourceBuffer, .{
        .deinit_fn = &deinit_wrapper,

        .get_appendWindowEnd = &get_appendWindowEnd,
        .get_appendWindowStart = &get_appendWindowStart,
        .get_audioTracks = &get_audioTracks,
        .get_buffered = &get_buffered,
        .get_mode = &get_mode,
        .get_onabort = &get_onabort,
        .get_onbufferedchange = &get_onbufferedchange,
        .get_onerror = &get_onerror,
        .get_onupdate = &get_onupdate,
        .get_onupdateend = &get_onupdateend,
        .get_onupdatestart = &get_onupdatestart,
        .get_textTracks = &get_textTracks,
        .get_timestampOffset = &get_timestampOffset,
        .get_updating = &get_updating,
        .get_videoTracks = &get_videoTracks,

        .set_appendWindowEnd = &set_appendWindowEnd,
        .set_appendWindowStart = &set_appendWindowStart,
        .set_mode = &set_mode,
        .set_onabort = &set_onabort,
        .set_onbufferedchange = &set_onbufferedchange,
        .set_onerror = &set_onerror,
        .set_onupdate = &set_onupdate,
        .set_onupdateend = &set_onupdateend,
        .set_onupdatestart = &set_onupdatestart,
        .set_timestampOffset = &set_timestampOffset,

        .call_abort = &call_abort,
        .call_addEventListener = &call_addEventListener,
        .call_appendBuffer = &call_appendBuffer,
        .call_changeType = &call_changeType,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_remove = &call_remove,
        .call_removeEventListener = &call_removeEventListener,
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
        ManagedSourceBufferImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_mode(state);
    }

    pub fn set_mode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_mode(state, value);
    }

    pub fn get_updating(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_updating(state);
    }

    pub fn get_buffered(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_buffered(state);
    }

    pub fn get_timestampOffset(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_timestampOffset(state);
    }

    pub fn set_timestampOffset(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_timestampOffset(state, value);
    }

    pub fn get_audioTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_audioTracks(state);
    }

    pub fn get_videoTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_videoTracks(state);
    }

    pub fn get_textTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_textTracks(state);
    }

    pub fn get_appendWindowStart(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_appendWindowStart(state);
    }

    pub fn set_appendWindowStart(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_appendWindowStart(state, value);
    }

    pub fn get_appendWindowEnd(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_appendWindowEnd(state);
    }

    pub fn set_appendWindowEnd(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_appendWindowEnd(state, value);
    }

    pub fn get_onupdatestart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_onupdatestart(state);
    }

    pub fn set_onupdatestart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_onupdatestart(state, value);
    }

    pub fn get_onupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_onupdate(state);
    }

    pub fn set_onupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_onupdate(state, value);
    }

    pub fn get_onupdateend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_onupdateend(state);
    }

    pub fn set_onupdateend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_onupdateend(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_onerror(state, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_onabort(state, value);
    }

    pub fn get_onbufferedchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.get_onbufferedchange(state);
    }

    pub fn set_onbufferedchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ManagedSourceBufferImpl.set_onbufferedchange(state, value);
    }

    pub fn call_appendBuffer(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_appendBuffer(state, data);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_when(state, type_, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ManagedSourceBufferImpl.call_abort(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_dispatchEvent(state, event);
    }

    pub fn call_changeType(instance: *runtime.Instance, type_: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_changeType(state, type_);
    }

    pub fn call_remove(instance: *runtime.Instance, start: f64, end: f64) anyopaque {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_remove(state, start, end);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ManagedSourceBufferImpl.call_removeEventListener(state, type_, callback, options);
    }

};
