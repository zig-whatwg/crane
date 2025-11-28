//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskControllerImpl = @import("impls").TaskController;
const AbortController = @import("interfaces").AbortController;
const TaskControllerInit = @import("dictionaries").TaskControllerInit;
const TaskPriority = @import("enums").TaskPriority;
const AbortSignal = @import("interfaces").AbortSignal;

pub const TaskController = struct {
    pub const Meta = struct {
        pub const name = "TaskController";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbortController;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setPriority", "call_setPriority", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setPriority",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "abort",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*TaskControllerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_setPriority = &call_setPriority,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TaskControllerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskControllerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: TaskControllerInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TaskControllerImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: TaskPriority) anyerror!void {
        
        return try TaskControllerImpl.call_setPriority(instance, priority);
    }

};
