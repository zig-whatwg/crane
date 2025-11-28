//! Generated from: service-workers.idl
//! Generated at: 2025-11-28T19:11:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const InstallEventImpl = @import("impls").InstallEvent;
const mixins = @import("mixins");
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const sequence = @import("interfaces").sequence;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const RouterRule = @import("dictionaries").RouterRule;
const DOMString = @import("typedefs").DOMString;

pub const InstallEvent = struct {
    pub const Meta = struct {
        pub const name = "InstallEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addRoutes", "call_addRoutes", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addRoutes",
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
            _internal: ?*InstallEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_addRoutes = &call_addRoutes,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InstallEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InstallEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(ExtendableEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try InstallEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn call_addRoutes(instance: *runtime.Instance, rules: *const anyopaque) anyerror!*const anyopaque {
        
        return try InstallEventImpl.call_addRoutes(instance, rules);
    }

};
