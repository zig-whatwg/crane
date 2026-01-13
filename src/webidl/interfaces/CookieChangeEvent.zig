//! Generated from: cookiestore.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CookieChangeEventImpl = @import("impls").CookieChangeEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("Event.zig").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("EventTarget.zig").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const CookieChangeEventInit = @import("dictionaries").CookieChangeEventInit;
const CookieListItem = @import("dictionaries").CookieListItem;

pub const CookieChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "CookieChangeEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            changed: runtime.JSValue = undefined,
            deleted: runtime.JSValue = undefined,
            cached_changed: ?runtime.JSValue = null,
            cached_deleted: ?runtime.JSValue = null,
            _internal: ?*CookieChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_changed = &get_changed,
        .get_deleted = &get_deleted,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CookieChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CookieChangeEventImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(CookieChangeEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CookieChangeEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
    pub fn get_deleted(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
