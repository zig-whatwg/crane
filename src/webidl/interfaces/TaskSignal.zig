//! Generated from: scheduling-apis.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TaskSignalImpl = @import("impls").TaskSignal;
const mixins = @import("mixins");
const AbortSignal = @import("interfaces").AbortSignal;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Observable = @import("interfaces").Observable;
const TaskPriority = @import("enums").TaskPriority;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const EventListener = @import("interfaces").EventListener;
const TaskSignalAnyInit = @import("dictionaries").TaskSignalAnyInit;
const EventHandler = @import("typedefs").EventHandler;

pub const TaskSignal = struct {
    pub const Meta = struct {
        pub const name = "TaskSignal";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbortSignal;
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
            .{ "priority", "get_priority", null },
            .{ "onprioritychange", "get_onprioritychange", "set_onprioritychange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "_any", "call__any", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "_any",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "abort",
            "timeout",
            "throwIfAborted",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "priority", "get_priority", null },
            .{ "onprioritychange", "get_onprioritychange", "set_onprioritychange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            priority: TaskPriority = undefined,
            onprioritychange: EventHandler = undefined,
            _internal: ?*TaskSignalImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onprioritychange = &get_onprioritychange,
        .get_priority = &get_priority,

        .set_onprioritychange = &set_onprioritychange,

        .call__any = &call__any,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TaskSignalImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TaskSignalImpl.deinit(instance);
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!TaskPriority {
        return try TaskSignalImpl.get_priority(instance);
    }

    pub fn get_onprioritychange(instance: *runtime.Instance) anyerror!EventHandler {
        return try TaskSignalImpl.get_onprioritychange(instance);
    }

    pub fn set_onprioritychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TaskSignalImpl.set_onprioritychange(instance, value);
    }

    /// Extended attributes: [NewObject]
    pub fn call__any(instance: *runtime.Instance, signals: *const anyopaque, init_data: webidl.Opt(TaskSignalAnyInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try TaskSignalImpl.call__any(instance, signals, init_data);
    }

};
