//! Generated from: html.idl
//! Generated at: 2025-11-23T19:57:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationCurrentEntryChangeEventImpl = @import("impls").NavigationCurrentEntryChangeEvent;
const Event = @import("interfaces").Event;
const NavigationCurrentEntryChangeEventInit = @import("dictionaries").NavigationCurrentEntryChangeEventInit;
const NavigationType = @import("enums").NavigationType;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;
const DOMString = @import("typedefs").DOMString;

pub const NavigationCurrentEntryChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "NavigationCurrentEntryChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "navigationType", "get_navigationType", null },
            .{ "from", "get_from", null },
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
            .{ "navigationType", "get_navigationType", null },
            .{ "from", "get_from", null },
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
            navigationType: ?NavigationType = null,
            from: *runtime.Instance = undefined,
            _internal: ?*NavigationCurrentEntryChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_from = &get_from,
        .get_navigationType = &get_navigationType,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigationCurrentEntryChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationCurrentEntryChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: NavigationCurrentEntryChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try NavigationCurrentEntryChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigationCurrentEntryChangeEventImpl.get_navigationType(instance);
    }

    pub fn get_from(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try NavigationCurrentEntryChangeEventImpl.get_from(instance);
    }

};
