//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ReadableByteStreamControllerImpl = @import("../impls/ReadableByteStreamController.zig");

pub const ReadableByteStreamController = struct {
    pub const Meta = struct {
        pub const name = "ReadableByteStreamController";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            byobRequest: ?ReadableStreamBYOBRequest = null,
            desiredSize: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ReadableByteStreamController, .{
        .deinit_fn = &deinit_wrapper,

        .get_byobRequest = &get_byobRequest,
        .get_desiredSize = &get_desiredSize,

        .call_close = &call_close,
        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ReadableByteStreamControllerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ReadableByteStreamControllerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_byobRequest(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableByteStreamControllerImpl.get_byobRequest(state);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableByteStreamControllerImpl.get_desiredSize(state);
    }

    pub fn call_error(instance: *runtime.Instance, e: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableByteStreamControllerImpl.call_error(state, e);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ReadableByteStreamControllerImpl.call_close(state);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ReadableByteStreamControllerImpl.call_enqueue(state, chunk);
    }

};
