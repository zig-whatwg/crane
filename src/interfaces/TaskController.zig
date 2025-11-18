//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskControllerImpl = @import("../impls/TaskController.zig");
const AbortController = @import("AbortController.zig");

pub const TaskController = struct {
    pub const Meta = struct {
        pub const name = "TaskController";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbortController;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TaskController, .{
        .deinit_fn = &deinit_wrapper,

        .get_signal = &get_signal,

        .call_abort = &call_abort,
        .call_setPriority = &call_setPriority,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TaskControllerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TaskControllerImpl.deinit(state);
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
        try TaskControllerImpl.constructor(state, init);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_signal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_signal) |cached| {
            return cached;
        }
        const value = TaskControllerImpl.get_signal(state);
        state.cached_signal = value;
        return value;
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TaskControllerImpl.call_abort(state, reason);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TaskControllerImpl.call_setPriority(state, priority);
    }

};
