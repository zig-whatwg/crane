//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-23T01:18:34Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "postTask", "call_postTask", 1 },
            .{ "yield", "call_yield", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postTask",
            "yield",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_postTask = &call_postTask,
        .call_yield = &call_yield,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SchedulerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SchedulerImpl.deinit(instance);
    }

    pub fn call_postTask(instance: *runtime.Instance, callback: SchedulerPostTaskCallback, options: SchedulerPostTaskOptions) anyerror!*const anyopaque {
        
        return try SchedulerImpl.call_postTask(instance, callback, options);
    }

    pub fn call_yield(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SchedulerImpl.call_yield(instance);
    }

};
