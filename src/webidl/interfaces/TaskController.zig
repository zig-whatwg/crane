//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskControllerImpl = @import("impls").TaskController;
const AbortController = @import("interfaces").AbortController;
const TaskControllerInit = @import("dictionaries").TaskControllerInit;
const TaskPriority = @import("enums").TaskPriority;

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
        
        // Initialize the instance (Impl receives full instance)
        TaskControllerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: TaskControllerInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try TaskControllerImpl.constructor(instance, init);
        
        return instance;
    }

    /// Extended attributes: [SameObject]
    pub fn get_signal(instance: *runtime.Instance) anyerror!AbortSignal {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_signal) |cached| {
            return cached;
        }
        const value = try TaskControllerImpl.get_signal(instance);
        state.cached_signal = value;
        return value;
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!void {
        
        return try TaskControllerImpl.call_abort(instance, reason);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: TaskPriority) anyerror!void {
        
        return try TaskControllerImpl.call_setPriority(instance, priority);
    }

};
