//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CustomEventImpl = @import("impls").CustomEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const CustomEventInit = @import("dictionaries").CustomEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const CustomEvent = struct {
    pub const Meta = struct {
        pub const name = "CustomEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "detail", "get_detail", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "initCustomEvent", "call_initCustomEvent", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "initCustomEvent",
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
            .{ "detail", "get_detail", null },
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
            detail: runtime.JSValue = undefined,
            _internal: ?*CustomEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_detail = &get_detail,

        .call_initCustomEvent = &call_initCustomEvent,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CustomEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CustomEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(CustomEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CustomEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_detail(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CustomEventImpl.get_detail(instance);
    }

    pub fn call_initCustomEvent(instance: *runtime.Instance, @"type": DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), detail: webidl.Opt(runtime.JSValue)) anyerror!void {
        
        return try CustomEventImpl.call_initCustomEvent(instance, @"type", bubbles, cancelable, detail);
    }

};
