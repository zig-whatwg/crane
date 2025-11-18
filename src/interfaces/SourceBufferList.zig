//! Generated from: media-source.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SourceBufferListImpl = @import("../impls/SourceBufferList.zig");
const EventTarget = @import("EventTarget.zig");

pub const SourceBufferList = struct {
    pub const Meta = struct {
        pub const name = "SourceBufferList";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            length: u32 = undefined,
            onaddsourcebuffer: EventHandler = undefined,
            onremovesourcebuffer: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SourceBufferList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_onaddsourcebuffer = &get_onaddsourcebuffer,
        .get_onremovesourcebuffer = &get_onremovesourcebuffer,

        .set_onaddsourcebuffer = &set_onaddsourcebuffer,
        .set_onremovesourcebuffer = &set_onremovesourcebuffer,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        SourceBufferListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SourceBufferListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SourceBufferListImpl.get_length(state);
    }

    pub fn get_onaddsourcebuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SourceBufferListImpl.get_onaddsourcebuffer(state);
    }

    pub fn set_onaddsourcebuffer(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SourceBufferListImpl.set_onaddsourcebuffer(state, value);
    }

    pub fn get_onremovesourcebuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SourceBufferListImpl.get_onremovesourcebuffer(state);
    }

    pub fn set_onremovesourcebuffer(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SourceBufferListImpl.set_onremovesourcebuffer(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SourceBufferListImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SourceBufferListImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SourceBufferListImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SourceBufferListImpl.call_removeEventListener(state, type_, callback, options);
    }

};
