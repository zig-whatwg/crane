//! Generated from: streams.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TransformStreamDefaultControllerImpl = @import("../impls/TransformStreamDefaultController.zig");

pub const TransformStreamDefaultController = struct {
    pub const Meta = struct {
        pub const name = "TransformStreamDefaultController";
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
            desiredSize: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TransformStreamDefaultController, .{
        .deinit_fn = &deinit_wrapper,

        .get_desiredSize = &get_desiredSize,

        .call_enqueue = &call_enqueue,
        .call_error = &call_error,
        .call_terminate = &call_terminate,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TransformStreamDefaultControllerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TransformStreamDefaultControllerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_desiredSize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TransformStreamDefaultControllerImpl.get_desiredSize(state);
    }

    pub fn call_error(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TransformStreamDefaultControllerImpl.call_error(state, reason);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TransformStreamDefaultControllerImpl.call_terminate(state);
    }

    pub fn call_enqueue(instance: *runtime.Instance, chunk: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TransformStreamDefaultControllerImpl.call_enqueue(state, chunk);
    }

};
