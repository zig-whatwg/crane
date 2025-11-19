//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SchedulerImpl = @import("impls").Scheduler;
const SchedulerPostTaskCallback = @import("callbacks").SchedulerPostTaskCallback;
const SchedulerPostTaskOptions = @import("dictionaries").SchedulerPostTaskOptions;

pub const Scheduler = struct {
    pub const Meta = struct {
        pub const name = "Scheduler";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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

    pub const vtable = runtime.buildVTable(Scheduler, .{
        .deinit_fn = &deinit_wrapper,

        .call_postTask = &call_postTask,
        .call_yield = &call_yield,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SchedulerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SchedulerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_postTask(instance: *runtime.Instance, callback: SchedulerPostTaskCallback, options: SchedulerPostTaskOptions) anyerror!anyopaque {
        
        return try SchedulerImpl.call_postTask(instance, callback, options);
    }

    pub fn call_yield(instance: *runtime.Instance) anyerror!anyopaque {
        return try SchedulerImpl.call_yield(instance);
    }

};
