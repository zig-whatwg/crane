//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SFrameDecrypterStreamImpl = @import("../impls/SFrameDecrypterStream.zig");
const EventTarget = @import("EventTarget.zig");
const GenericTransformStream = @import("GenericTransformStream.zig");
const SFrameKeyManagement = @import("SFrameKeyManagement.zig");

pub const SFrameDecrypterStream = struct {
    pub const Meta = struct {
        pub const name = "SFrameDecrypterStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            GenericTransformStream,
            SFrameKeyManagement,
        };
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
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SFrameDecrypterStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_onerror = &get_onerror,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onerror = &set_onerror,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_setEncryptionKey = &call_setEncryptionKey,
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
        SFrameDecrypterStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SFrameDecrypterStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SFrameDecrypterStreamImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_readable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SFrameDecrypterStreamImpl.get_readable(state);
    }

    pub fn get_writable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SFrameDecrypterStreamImpl.get_writable(state);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SFrameDecrypterStreamImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SFrameDecrypterStreamImpl.set_onerror(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SFrameDecrypterStreamImpl.call_dispatchEvent(state, event);
    }

    pub fn call_setEncryptionKey(instance: *runtime.Instance, key: anyopaque, keyID: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SFrameDecrypterStreamImpl.call_setEncryptionKey(state, key, keyID);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SFrameDecrypterStreamImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SFrameDecrypterStreamImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SFrameDecrypterStreamImpl.call_removeEventListener(state, type_, callback, options);
    }

};
