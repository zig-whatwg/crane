//! Generated from: cookiestore.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CookieChangeEventImpl = @import("impls").CookieChangeEvent;
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const CookieChangeEventInit = @import("dictionaries").CookieChangeEventInit;
const CookieListItem = @import("dictionaries").CookieListItem;

pub const CookieChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "CookieChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "changed", "get_changed", null },
            .{ "deleted", "get_deleted", null },
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
            .{ "changed", "get_changed", null },
            .{ "deleted", "get_deleted", null },
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
            changed: runtime.FrozenArray(CookieListItem) = undefined,
            deleted: runtime.FrozenArray(CookieListItem) = undefined,
            cached_changed: ?runtime.FrozenArray(CookieListItem) = null,
            cached_deleted: ?runtime.FrozenArray(CookieListItem) = null,
            _internal: ?*CookieChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_changed = &get_changed,
        .get_deleted = &get_deleted,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CookieChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: CookieChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CookieChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_changed(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_changed) |cached| {
            return cached;
        }
        const value = try CookieChangeEventImpl.get_changed(instance);
        state.own.cached_changed = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_deleted(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_deleted) |cached| {
            return cached;
        }
        const value = try CookieChangeEventImpl.get_deleted(instance);
        state.own.cached_deleted = value;
        return value;
    }

};
