//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TaskPriorityChangeEventImpl = @import("impls").TaskPriorityChangeEvent;
const Event = @import("interfaces").Event;
const TaskPriorityChangeEventInit = @import("dictionaries").TaskPriorityChangeEventInit;
const TaskPriority = @import("enums").TaskPriority;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TaskPriorityChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "TaskPriorityChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
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
            .{ "previousPriority", "get_previousPriority", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "previousPriority", "get_previousPriority", null },
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
            previousPriority: TaskPriority = undefined,
            _internal: ?*TaskPriorityChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_previousPriority = &get_previousPriority,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TaskPriorityChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskPriorityChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, priorityChangeEventInitDict: TaskPriorityChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TaskPriorityChangeEventImpl.call_constructor(allocator, ctx, @"type", priorityChangeEventInitDict);
    }

    pub fn get_previousPriority(instance: *runtime.Instance) anyerror!TaskPriority {
        return try TaskPriorityChangeEventImpl.get_previousPriority(instance);
    }

};
