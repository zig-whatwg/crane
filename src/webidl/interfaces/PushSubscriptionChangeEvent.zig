//! Generated from: push-api.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushSubscriptionChangeEventImpl = @import("impls").PushSubscriptionChangeEvent;
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const PushSubscriptionChangeEventInit = @import("dictionaries").PushSubscriptionChangeEventInit;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const PushSubscription = @import("interfaces").PushSubscription;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const PushSubscriptionChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "PushSubscriptionChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "newSubscription", "get_newSubscription", null },
            .{ "oldSubscription", "get_oldSubscription", null },
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
            "waitUntil",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "newSubscription", "get_newSubscription", null },
            .{ "oldSubscription", "get_oldSubscription", null },
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
            newSubscription: ?*runtime.Instance = null,
            oldSubscription: ?*runtime.Instance = null,
            _internal: ?*PushSubscriptionChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_newSubscription = &get_newSubscription,
        .get_oldSubscription = &get_oldSubscription,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushSubscriptionChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushSubscriptionChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: PushSubscriptionChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PushSubscriptionChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_newSubscription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PushSubscriptionChangeEventImpl.get_newSubscription(instance);
    }

    pub fn get_oldSubscription(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PushSubscriptionChangeEventImpl.get_oldSubscription(instance);
    }

};
