//! Generated from: background-fetch.idl
//! Generated at: 2025-11-23T01:18:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchEventImpl = @import("impls").BackgroundFetchEvent;
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const BackgroundFetchRegistration = @import("interfaces").BackgroundFetchRegistration;
const BackgroundFetchEventInit = @import("dictionaries").BackgroundFetchEventInit;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const BackgroundFetchEvent = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "registration", "get_registration", null },
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
            .{ "registration", "get_registration", null },
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
            registration: BackgroundFetchRegistration = undefined,
        },
    );

    const delegates = .{

        .get_registration = &get_registration,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BackgroundFetchEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, init_data: BackgroundFetchEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BackgroundFetchEventImpl.call_constructor(allocator, ctx, @"type", init_data);
    }

    pub fn get_registration(instance: *runtime.Instance) anyerror!BackgroundFetchRegistration {
        return try BackgroundFetchEventImpl.get_registration(instance);
    }

};
