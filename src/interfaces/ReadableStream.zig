//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamImpl = @import("../impls/ReadableStream.zig");

pub const ReadableStream = struct {
    pub const Meta = struct {
        pub const name = "ReadableStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            locked: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,

        .call_cancel = &call_cancel,
        .call_from = &call_from,
        .call_getReader = &call_getReader,
        .call_pipeThrough = &call_pipeThrough,
        .call_pipeTo = &call_pipeTo,
        .call_tee = &call_tee,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ReadableStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ReadableStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, underlyingSource: anyopaque, strategy: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ReadableStreamImpl.constructor(state, underlyingSource, strategy);
        
        return instance;
    }

    pub fn get_locked(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ReadableStreamImpl.get_locked(state);
    }

    pub fn call_from(instance: *runtime.Instance, asyncIterable: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamImpl.call_from(state, asyncIterable);
    }

    pub fn call_pipeThrough(instance: *runtime.Instance, transform: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamImpl.call_pipeThrough(state, transform, options);
    }

    pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamImpl.call_cancel(state, reason);
    }

    pub fn call_getReader(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamImpl.call_getReader(state, options);
    }

    pub fn call_pipeTo(instance: *runtime.Instance, destination: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableStreamImpl.call_pipeTo(state, destination, options);
    }

    pub fn call_tee(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableStreamImpl.call_tee(state);
    }

};
